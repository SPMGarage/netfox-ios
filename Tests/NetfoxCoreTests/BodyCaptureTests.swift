//
//  BodyCaptureTests.swift
//  NetfoxCoreTests
//
//  The three ways an upload stream is captured: spilled to a file, sent untouched
//  (declared length over the cap), and failed when it can't be kept whole.
//

import Foundation
@testable import NetfoxCore
import Testing

@Suite("Request body capture")
struct BodyCaptureTests {

    private func streamRequest(_ body: Data, contentLength: Int? = nil) throws -> URLRequest {
        var request = URLRequest(url: try #require(URL(string: "https://example.com/upload")))
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)
        if let contentLength {
            request.setValue(String(contentLength), forHTTPHeaderField: "Content-Length")
        }
        return request
    }

    private func spillURL() -> URL {
        URL.temporaryDirectory
            .appending(path: "netfox-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "body.upload", directoryHint: .notDirectory)
    }

    @Test("a stream over the cap is copied to a file and sent whole")
    func spillKeepsTheWholeBody() throws {
        let body = Data((0..<5_000).map { UInt8(truncatingIfNeeded: $0) })
        let url = spillURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let capture = NFXRequestBodyCapture(request: try streamRequest(body), limit: 1_000, spillFileURL: url)

        #expect(capture.failure == nil)
        #expect(capture.spillFileURL == url)
        #expect(capture.info.length == 5_000)
        #expect(capture.info.isTruncated)
        #expect(capture.data?.count == 1_000)
        #expect(try Data(contentsOf: url) == body)
        #expect(capture.request.httpBodyStream != nil)
    }

    @Test("a stream that can't be copied fails the request instead of sending part of it")
    func failedSpillFailsTheRequest() throws {
        let body = Data(repeating: 7, count: 5_000)
        // /dev/null is not a folder, so the spill file can't be created
        let unwritable = URL(fileURLWithPath: "/dev/null/netfox/body.upload")

        let capture = NFXRequestBodyCapture(request: try streamRequest(body), limit: 1_000, spillFileURL: unwritable)

        let failure = try #require(capture.failure) as NSError
        #expect(failure.domain == NSURLErrorDomain)
        #expect(failure.code == NSURLErrorRequestBodyStreamExhausted)
        #expect(capture.spillFileURL == nil)
    }

    @Test("a declared Content-Length over the cap sends the stream untouched")
    func declaredLengthOverTheCap() throws {
        let body = Data(repeating: 1, count: 2_000)
        let request = try streamRequest(body, contentLength: body.count)

        let capture = NFXRequestBodyCapture(request: request, limit: 1_000, spillFileURL: spillURL())

        #expect(capture.failure == nil)
        #expect(capture.data == nil)
        #expect(capture.info.length == 2_000)
        #expect(!capture.info.isStored)
        #expect(capture.request.httpBodyStream != nil)
        #expect(capture.request.httpBody == nil)
    }
}
