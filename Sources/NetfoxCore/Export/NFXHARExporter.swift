//
//  NFXHARExporter.swift
//  netfox
//
//  B4: export captured requests as HAR 1.2 (HTTP Archive), built with Codable.
//  Timings and httpVersion come from URLSessionTaskMetrics when available (P2-4).
//

import Foundation

/// HAR 1.2 document model (http://www.softwareishard.com/blog/har-12-spec/).
package struct NFXHARDocument: Codable, Sendable, Hashable {
    package var log: Log

    package struct Log: Codable, Sendable, Hashable {
        package var version: String
        package var creator: Creator
        package var entries: [Entry]
    }

    package struct Creator: Codable, Sendable, Hashable {
        package var name: String
        package var version: String
    }

    package struct NameValue: Codable, Sendable, Hashable {
        package var name: String
        package var value: String
    }

    package struct Entry: Codable, Sendable, Hashable {
        package var startedDateTime: String
        /// Total time in milliseconds: the sum of the non-negative timings (ssl excluded).
        package var time: Double
        package var request: Request
        package var response: Response
        package var cache: Cache
        package var timings: Timings
        package var serverIPAddress: String?
        package var connection: String?
    }

    package struct Request: Codable, Sendable, Hashable {
        package var method: String
        package var url: String
        package var httpVersion: String
        package var cookies: [NameValue]
        package var headers: [NameValue]
        package var queryString: [NameValue]
        package var postData: PostData?
        package var headersSize: Int
        package var bodySize: Int
    }

    package struct PostData: Codable, Sendable, Hashable {
        package var mimeType: String
        package var text: String
        /// Custom field ("_" prefix per the HAR spec): "base64" for binary bodies.
        package var encoding: String?
        package var comment: String?

        enum CodingKeys: String, CodingKey {
            case mimeType, text, comment
            case encoding = "_encoding"
        }
    }

    package struct Response: Codable, Sendable, Hashable {
        package var status: Int
        package var statusText: String
        package var httpVersion: String
        package var cookies: [NameValue]
        package var headers: [NameValue]
        package var content: Content
        package var redirectURL: String
        package var headersSize: Int
        package var bodySize: Int
        package var comment: String?
    }

    package struct Content: Codable, Sendable, Hashable {
        package var size: Int
        package var mimeType: String
        package var text: String?
        package var encoding: String?
        package var comment: String?
    }

    /// Always `{}`: netfox does not inspect the URL cache.
    package struct Cache: Codable, Sendable, Hashable {
        package init() {}
    }

    /// Milliseconds; -1 marks phases that did not happen (send, wait and receive are never -1).
    package struct Timings: Codable, Sendable, Hashable {
        package var blocked: Double
        package var dns: Double
        package var connect: Double
        package var send: Double
        package var wait: Double
        package var receive: Double
        package var ssl: Double
    }
}

/// Builds and writes HAR files.
package enum NFXHARExporter {

    /// The HAR document for `records`, oldest request first.
    ///
    /// - Parameter bodies: stored bytes of a record's body, nil when nothing was stored.
    package static func makeDocument(
        records: [NFXRecord],
        creatorVersion: String = NFXBuildInfo.version,
        bodies: (UUID, NFXBodyPart) -> Data?
    ) -> NFXHARDocument {
        let entries = records
            .sorted { $0.startDate < $1.startDate }
            .map { entry(for: $0, bodies: bodies) }
        return NFXHARDocument(log: .init(
            version: "1.2",
            creator: .init(name: "netfox", version: creatorVersion),
            entries: entries
        ))
    }

    /// Pretty-printed JSON with sorted keys and unescaped slashes.
    package static func encode(_ document: NFXHARDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    /// Writes `netfox-<date>.har` into the netfox folder and returns its URL.
    ///
    /// Entries are encoded and written one record at a time, so memory stays at about one
    /// record's bodies instead of every body of the session. Earlier exports are deleted.
    @concurrent
    package static func exportFile(
        records: [NFXRecord],
        creatorVersion: String = NFXBuildInfo.version,
        storage: NFXStorage = .shared
    ) async throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: storage.directoryURL, withIntermediateDirectories: true)
        let previousExports = (try? fileManager.contentsOfDirectory(at: storage.directoryURL, includingPropertiesForKeys: nil)) ?? []
        for file in previousExports where file.pathExtension == "har" {
            try? fileManager.removeItem(at: file)
        }

        let stamp = Int(Date().timeIntervalSince1970)
        let url = storage.directoryURL.appending(path: "netfox-\(stamp).har", directoryHint: .notDirectory)
        guard fileManager.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path(percentEncoded: false)])
        }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // the envelope is written by hand so every entry can be encoded and released on its own
        let creator = try encoder.encode(NFXHARDocument.Creator(name: "netfox", version: creatorVersion))
        try handle.write(contentsOf: Data(#"{"log":{"creator":"#.utf8))
        try handle.write(contentsOf: creator)
        try handle.write(contentsOf: Data(#","entries":["#.utf8))
        for (index, record) in records.sorted(by: { $0.startDate < $1.startDate }).enumerated() {
            var bodies: [NFXBodyPart: Data] = [:]
            for part in NFXBodyPart.allCases where record.body(part).isStored {
                bodies[part] = await storage.body(for: record.id, part: part)
            }
            let entry = entry(for: record) { _, part in bodies[part] }
            if index > 0 {
                try handle.write(contentsOf: Data(",".utf8))
            }
            try handle.write(contentsOf: try encoder.encode(entry))
        }
        try handle.write(contentsOf: Data(#"],"version":"1.2"}}"#.utf8))
        return url
    }

    // MARK: - Entry building

    static func entry(for record: NFXRecord, bodies: (UUID, NFXBodyPart) -> Data?) -> NFXHARDocument.Entry {
        let transaction = record.metrics?.finalTransaction
        let httpVersion = transaction?.httpVersion ?? "HTTP/1.1"
        let timings = timings(for: record, transaction: transaction)
        let total = [timings.blocked, timings.dns, timings.connect, timings.send, timings.wait, timings.receive]
            .filter { $0 >= 0 }
            .reduce(0, +)

        return NFXHARDocument.Entry(
            startedDateTime: record.startDate.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
            time: total,
            request: request(for: record, httpVersion: httpVersion, body: bodies(record.id, .request)),
            response: response(for: record, httpVersion: httpVersion, body: bodies(record.id, .response)),
            cache: .init(),
            timings: timings,
            serverIPAddress: transaction?.remoteAddress,
            connection: transaction?.remotePort.map(String.init)
        )
    }

    private static func request(for record: NFXRecord, httpVersion: String, body: Data?) -> NFXHARDocument.Request {
        var postData: NFXHARDocument.PostData?
        if let body, !body.isEmpty {
            let encoded = encodeBody(body)
            postData = .init(
                mimeType: record.requestContentType ?? "",
                text: encoded.text,
                encoding: encoded.encoding,
                comment: record.requestBody.isTruncated ? "netfox stored only the first \(body.count) bytes" : nil
            )
        }
        return NFXHARDocument.Request(
            method: record.method,
            url: record.urlString,
            httpVersion: httpVersion,
            cookies: [],
            headers: nameValues(record.requestHeaders),
            queryString: record.queryItems.map { .init(name: $0.name, value: $0.value ?? "") },
            postData: postData,
            headersSize: -1,
            bodySize: record.requestBody.length ?? -1
        )
    }

    private static func response(for record: NFXRecord, httpVersion: String, body: Data?) -> NFXHARDocument.Response {
        let status = record.statusCode ?? 0
        var content = NFXHARDocument.Content(
            size: record.responseBody.length ?? (record.hasResponse ? -1 : 0),
            mimeType: record.responseContentType ?? "",
            text: nil,
            encoding: nil,
            comment: record.responseBody.isTruncated ? "netfox stored only the first \(body?.count ?? 0) bytes" : nil
        )
        if let body, !body.isEmpty {
            let encoded = encodeBody(body)
            content.text = encoded.text
            content.encoding = encoded.encoding
        }
        return NFXHARDocument.Response(
            status: status,
            statusText: status == 0 ? "" : HTTPURLResponse.localizedString(forStatusCode: status),
            httpVersion: httpVersion,
            cookies: [],
            headers: nameValues(record.responseHeaders),
            content: content,
            redirectURL: record.redirectURL?.absoluteString ?? record.responseHeaders.value(for: "Location") ?? "",
            headersSize: -1,
            bodySize: record.hasResponse ? (record.responseBody.length ?? -1) : -1,
            comment: record.error.map { "\($0.domain) \($0.code): \($0.message)" }
        )
    }

    /// Phase timings in milliseconds. Without metrics the whole duration counts as `wait`.
    static func timings(for record: NFXRecord, transaction: NFXRequestMetrics.Transaction?) -> NFXHARDocument.Timings {
        func milliseconds(_ seconds: TimeInterval?) -> Double {
            seconds.map { ($0 * 1000 * 1000).rounded() / 1000 } ?? -1
        }
        guard let transaction else {
            let wait = max(0, milliseconds(record.duration))
            return .init(blocked: -1, dns: -1, connect: -1, send: 0, wait: wait, receive: 0, ssl: -1)
        }
        return .init(
            blocked: milliseconds(transaction.blockedDuration),
            dns: milliseconds(transaction.dnsDuration),
            connect: milliseconds(transaction.connectDuration),
            send: max(0, milliseconds(transaction.sendDuration)),
            wait: max(0, milliseconds(transaction.waitDuration)),
            receive: max(0, milliseconds(transaction.receiveDuration)),
            ssl: milliseconds(transaction.tlsDuration)
        )
    }

    private static func nameValues(_ headers: [NFXHeader]) -> [NFXHARDocument.NameValue] {
        headers.map { .init(name: $0.name, value: $0.value) }
    }

    /// UTF-8 text as is, anything else as base64.
    private static func encodeBody(_ data: Data) -> (text: String, encoding: String?) {
        if let text = NFXBodyText.string(from: data) {
            return (text, nil)
        }
        return (data.base64EncodedString(), "base64")
    }
}
