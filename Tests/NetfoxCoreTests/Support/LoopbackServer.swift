//
//  LoopbackServer.swift
//  NetfoxCoreTests
//
//  In-process HTTP/1.1 server on 127.0.0.1 (ephemeral port), built on
//  Network.framework. Supports keep-alive, Content-Length and chunked bodies.
//

import Foundation
import Network
import os

final class LoopbackServer: Sendable {

    struct Hit: Sendable {
        let method: String
        let path: String
        let query: String?
        let headers: [String: String]
        let body: Data
        let connectionID: Int
    }

    /// 1 KB that is not valid UTF-8 (bytes 0...255 repeated).
    static let binaryBody = Data((0..<1024).map { UInt8(truncatingIfNeeded: $0) })
    static let basicUser = "netfox"
    static let basicPassword = "s3cret"
    static let jsonBody = #"{"zeta":1,"alpha":"https:\/\/example.com\/a\/b","mike":[true,null]}"#

    private struct State: Sendable {
        var hits: [Hit] = []
        var nextConnectionID = 0
        var port: UInt16 = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let queue = DispatchQueue(label: "netfox.tests.loopback")
    private let listener: NWListener

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    var port: UInt16 { state.withLock { $0.port } }
    var hits: [Hit] { state.withLock { $0.hits } }

    func url(_ pathAndQuery: String) -> URL {
        URL(string: "http://127.0.0.1:\(port)\(pathAndQuery)") ?? URL(fileURLWithPath: "/")
    }

    func start() async throws {
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        let resumed = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            listener.stateUpdateHandler = { newState in
                let first: Bool
                switch newState {
                case .ready, .failed, .cancelled:
                    first = resumed.withLock { done in
                        defer { done = true }
                        return !done
                    }
                default:
                    first = false
                }
                guard first else { return }
                if case .failed(let error) = newState {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            listener.start(queue: queue)
        }
        let port = listener.port?.rawValue ?? 0
        state.withLock { $0.port = port }
    }

    func stop() {
        listener.cancel()
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        let id = state.withLock { state -> Int in
            state.nextConnectionID += 1
            return state.nextConnectionID
        }
        connection.start(queue: queue)
        receive(on: connection, id: id, buffer: Data())
    }

    private func receive(on connection: NWConnection, id: Int, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            while let (request, consumed) = Self.parse(buffer) {
                buffer = Data(buffer.dropFirst(consumed))
                let hit = Hit(
                    method: request.method, path: request.path, query: request.query,
                    headers: request.headers, body: request.body, connectionID: id
                )
                state.withLock { $0.hits.append(hit) }
                connection.send(content: Self.response(for: request), completion: .contentProcessed { _ in })
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            receive(on: connection, id: id, buffer: buffer)
        }
    }

    // MARK: - HTTP parsing

    struct Request {
        let method: String
        let path: String
        let query: String?
        let headers: [String: String]
        let body: Data
    }

    static func parse(_ buffer: Data) -> (Request, Int)? {
        let bytes = [UInt8](buffer)
        guard let headerEnd = indexOf([13, 10, 13, 10], in: bytes, from: 0),
              let head = String(bytes: bytes[0..<headerEnd], encoding: .utf8) else { return nil }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        let target = String(requestLine[1])
        let parts = target.split(separator: "?", maxSplits: 1).map(String.init)
        let bodyStart = headerEnd + 4

        var body = Data()
        var end = bodyStart
        if headers["transfer-encoding"]?.lowercased() == "chunked" {
            var cursor = bodyStart
            while true {
                guard let lineEnd = indexOf([13, 10], in: bytes, from: cursor),
                      let sizeLine = String(bytes: bytes[cursor..<lineEnd], encoding: .ascii),
                      let size = Int(sizeLine.split(separator: ";").first.map(String.init) ?? "", radix: 16) else { return nil }
                cursor = lineEnd + 2
                if size == 0 {
                    // trailer section ends with an empty line
                    guard let trailerEnd = indexOf([13, 10], in: bytes, from: cursor) else { return nil }
                    cursor = trailerEnd + 2
                    break
                }
                guard bytes.count >= cursor + size + 2 else { return nil }
                body.append(contentsOf: bytes[cursor..<cursor + size])
                cursor += size + 2
            }
            end = cursor
        } else {
            let length = Int(headers["content-length"] ?? "0") ?? 0
            guard bytes.count >= bodyStart + length else { return nil }
            body = Data(bytes[bodyStart..<bodyStart + length])
            end = bodyStart + length
        }
        let request = Request(
            method: String(requestLine[0]), path: parts[0], query: parts.count > 1 ? parts[1] : nil,
            headers: headers, body: body
        )
        return (request, end)
    }

    private static func indexOf(_ pattern: [UInt8], in bytes: [UInt8], from start: Int) -> Int? {
        guard bytes.count >= pattern.count, start <= bytes.count - pattern.count else { return nil }
        for index in start...(bytes.count - pattern.count) where Array(bytes[index..<index + pattern.count]) == pattern {
            return index
        }
        return nil
    }

    // MARK: - Routes

    static func response(for request: Request) -> Data {
        let query = request.query.map { "?" + $0 } ?? ""
        switch request.path {
        case "/redirect":
            return make(status: "302 Found", headers: ["Location": "/ok\(query)"], body: Data())
        case "/echo":
            return make(status: "200 OK", headers: ["Content-Type": "application/octet-stream"], body: request.body)
        case "/binary":
            return make(status: "200 OK", headers: ["Content-Type": "application/octet-stream"], body: binaryBody)
        case "/json":
            return make(status: "200 OK", headers: ["Content-Type": "application/json"], body: Data(jsonBody.utf8))
        case "/basic":
            let expected = "Basic " + Data("\(basicUser):\(basicPassword)".utf8).base64EncodedString()
            if request.headers["authorization"] == expected {
                return make(status: "200 OK", headers: ["Content-Type": "text/plain"], body: Data("authorized".utf8))
            }
            return make(
                status: "401 Unauthorized",
                headers: ["WWW-Authenticate": #"Basic realm="netfox""#, "Content-Type": "text/plain"],
                body: Data("denied".utf8)
            )
        case "/setcookie":
            return make(
                status: "200 OK",
                headers: ["Content-Type": "text/plain", "Set-Cookie": "nfxserver=fromserver; Path=/"],
                body: Data("set".utf8)
            )
        case "/cookie":
            let cookie = request.headers["cookie"] ?? "none"
            return make(status: "200 OK", headers: ["Content-Type": "text/plain"], body: Data(cookie.utf8))
        default:
            return make(status: "200 OK", headers: ["Content-Type": "text/plain"], body: Data("hello".utf8))
        }
    }

    private static func make(status: String, headers: [String: String], body: Data) -> Data {
        var head = "HTTP/1.1 \(status)\r\n"
        var allHeaders = headers
        allHeaders["Content-Length"] = String(body.count)
        allHeaders["Cache-Control"] = "no-store"
        for (name, value) in allHeaders.sorted(by: { $0.key < $1.key }) {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        return data
    }
}
