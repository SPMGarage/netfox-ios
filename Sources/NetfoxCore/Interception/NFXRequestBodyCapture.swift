//
//  NFXRequestBodyCapture.swift
//  netfox
//
//  P0-1: an app-supplied httpBodyStream can be read only once. netfox drains it
//  once (up to the cap) into httpBody and sends that copy, instead of reading
//  the live stream and re-sending the closed one.
//

import Foundation

/// The request body as netfox captured it, plus the request to send on the internal session.
struct NFXRequestBodyCapture {

    /// The request to send. Its stream body may have been replaced by `httpBody` or a file stream.
    let request: URLRequest
    /// Captured bytes (at most ``NFXStorage/maxBodyBytes``), nil when there is no body or it was not read.
    let data: Data?
    let info: NFXBodyInfo
    /// File holding a stream body larger than the cap; resent through `needNewBodyStream`.
    let spillFileURL: URL?

    /// Captures the body of `request`. `spillFileURL` is used only for oversized streams.
    init(request original: URLRequest, limit: Int = NFXStorage.maxBodyBytes, spillFileURL spillURL: URL) {
        var request = original

        if let body = original.httpBody {
            self.request = request
            self.data = body.isEmpty ? nil : Data(body.prefix(limit))
            self.info = NFXBodyInfo(length: body.count, isStored: !body.isEmpty, isTruncated: body.count > limit)
            self.spillFileURL = nil
            return
        }

        guard let stream = original.httpBodyStream else {
            self.request = request
            self.data = nil
            self.info = .empty
            self.spillFileURL = nil
            return
        }

        // A declared length above the cap: send the stream untouched and record the length only.
        if let declared = original.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init), declared > limit {
            self.request = request
            self.data = nil
            self.info = NFXBodyInfo(length: declared, isStored: false, isTruncated: false)
            self.spillFileURL = nil
            return
        }

        stream.open()
        defer { stream.close() }
        let head = Self.read(stream, upTo: limit + 1)

        if head.count <= limit {
            // the whole body fits: send it as httpBody (this also clears httpBodyStream)
            request.httpBody = head
            self.request = request
            self.data = head.isEmpty ? nil : head
            self.info = NFXBodyInfo(length: head.count, isStored: !head.isEmpty, isTruncated: false)
            self.spillFileURL = nil
            return
        }

        // Larger than the cap: copy everything to a file and send a stream over that file.
        let total = Self.spill(head: head, rest: stream, to: spillURL)
        if let total, let fileStream = InputStream(url: spillURL) {
            request.httpBodyStream = fileStream
            self.spillFileURL = spillURL
            self.info = NFXBodyInfo(length: total, isStored: true, isTruncated: true)
        } else {
            // could not spill: send what was read so the request still goes out
            NFXLog.interception.error("Could not buffer a large upload stream; sending \(head.count) bytes")
            request.httpBody = head
            self.spillFileURL = nil
            self.info = NFXBodyInfo(length: head.count, isStored: true, isTruncated: true)
        }
        self.request = request
        self.data = Data(head.prefix(limit))
    }

    /// Reads at most `maximum` bytes.
    private static func read(_ stream: InputStream, upTo maximum: Int) -> Data {
        var result = Data()
        let chunkSize = 64 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while result.count < maximum {
            let wanted = min(chunkSize, maximum - result.count)
            let count = stream.read(&buffer, maxLength: wanted)
            if count < 0 {
                NFXLog.interception.error("Request body stream failed: \(stream.streamError?.localizedDescription ?? "unknown error", privacy: .public)")
                break
            }
            if count == 0 { break }
            result.append(buffer, count: count)
        }
        return result
    }

    /// Writes `head` plus the rest of `stream` to `url`. Returns the total size, or nil on failure.
    private static func spill(head: Data, rest stream: InputStream, to url: URL) -> Int? {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try head.write(to: url)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            var total = head.count
            while true {
                let chunk = read(stream, upTo: 1024 * 1024)
                if chunk.isEmpty { break }
                try handle.write(contentsOf: chunk)
                total += chunk.count
            }
            return total
        } catch {
            NFXLog.interception.error("Could not write upload spill file: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
