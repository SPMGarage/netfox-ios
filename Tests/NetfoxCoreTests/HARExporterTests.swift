//
//  HARExporterTests.swift
//  NetfoxCoreTests
//
//  B4: required HAR 1.2 fields.
//

import Foundation
@testable import NetfoxCore
import Testing

@Suite("HAR export")
struct HARExporterTests {

    private static let start = Date(timeIntervalSince1970: 1_791_613_998.25)

    private static func makeRecords() throws -> [NFXRecord] {
        let transaction = NFXRequestMetrics.Transaction(
            fetchStartDate: start,
            domainLookupStartDate: start.addingTimeInterval(0.001),
            domainLookupEndDate: start.addingTimeInterval(0.004),
            connectStartDate: start.addingTimeInterval(0.004),
            connectEndDate: start.addingTimeInterval(0.020),
            secureConnectionStartDate: start.addingTimeInterval(0.010),
            secureConnectionEndDate: start.addingTimeInterval(0.020),
            requestStartDate: start.addingTimeInterval(0.021),
            requestEndDate: start.addingTimeInterval(0.022),
            responseStartDate: start.addingTimeInterval(0.050),
            responseEndDate: start.addingTimeInterval(0.060),
            networkProtocolName: "h2",
            remoteAddress: "93.184.216.34",
            remotePort: 443
        )
        let metrics = NFXRequestMetrics(
            taskInterval: DateInterval(start: start, duration: 0.06),
            transactions: [transaction]
        )
        let json = NFXRecord(
            url: URL(string: "https://example.com/items?page=2&q=a"),
            method: "POST",
            requestHeaders: [NFXHeader(name: "Content-Type", value: "application/json")],
            requestBody: NFXBodyInfo(length: 13, isStored: true, isTruncated: false),
            startDate: start,
            endDate: start.addingTimeInterval(0.06),
            statusCode: 201,
            responseHeaders: [NFXHeader(name: "Content-Type", value: "application/json; charset=utf-8")],
            responseBody: NFXBodyInfo(length: 11, isStored: true, isTruncated: false),
            metrics: metrics
        )
        let binary = NFXRecord(
            url: URL(string: "http://127.0.0.1/binary"),
            method: "GET",
            startDate: start.addingTimeInterval(1),
            endDate: start.addingTimeInterval(1.5),
            statusCode: 200,
            responseHeaders: [NFXHeader(name: "Content-Type", value: "application/octet-stream")],
            responseBody: NFXBodyInfo(length: 4, isStored: true, isTruncated: false)
        )
        let failed = NFXRecord(
            url: URL(string: "https://offline.invalid/"),
            method: "GET",
            requestBody: NFXBodyInfo(length: nil, isStored: false, isTruncated: false),
            startDate: start.addingTimeInterval(2),
            endDate: start.addingTimeInterval(2.1),
            error: NFXRecordError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, message: "not found")
        )
        return [failed, binary, json] // newest first, like the store
    }

    private static func bodies(for records: [NFXRecord]) -> (UUID, NFXBodyPart) -> Data? {
        let json = records[2].id
        let binary = records[1].id
        return { id, part in
            switch (id, part) {
            case (json, .request): Data(#"{"name":"a"}"#.utf8) + Data([0x0A])
            case (json, .response): Data(#"{"id":"a/b"}"#.utf8)
            case (binary, .response): Data([0xFF, 0x00, 0xFE, 0x01])
            default: nil
            }
        }
    }

    @Test("log, creator, entries and every required entry field")
    func requiredFields() throws {
        let records = try Self.makeRecords()
        let document = NFXHARExporter.makeDocument(records: records, creatorVersion: "4.0.0", bodies: Self.bodies(for: records))
        let data = try NFXHARExporter.encode(document)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let log = try #require(root["log"] as? [String: Any])
        #expect(log["version"] as? String == "1.2")
        let creator = try #require(log["creator"] as? [String: Any])
        #expect(creator["name"] as? String == "netfox")
        #expect(creator["version"] as? String == "4.0.0")
        let entries = try #require(log["entries"] as? [[String: Any]])
        #expect(entries.count == 3)

        for entry in entries {
            let started = try #require(entry["startedDateTime"] as? String)
            #expect(try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(started) > .distantPast)
            #expect((entry["time"] as? Double ?? -1) >= 0)
            let request = try #require(entry["request"] as? [String: Any])
            for key in ["method", "url", "httpVersion", "cookies", "headers", "queryString", "headersSize", "bodySize"] {
                #expect(request[key] != nil, "request.\(key) missing")
            }
            #expect(request["headersSize"] as? Int == -1)
            let response = try #require(entry["response"] as? [String: Any])
            for key in ["status", "statusText", "httpVersion", "cookies", "headers", "content", "redirectURL", "headersSize", "bodySize"] {
                #expect(response[key] != nil, "response.\(key) missing")
            }
            let content = try #require(response["content"] as? [String: Any])
            #expect(content["size"] != nil && content["mimeType"] != nil)
            let cache = try #require(entry["cache"] as? [String: Any])
            #expect(cache.isEmpty)
            let timings = try #require(entry["timings"] as? [String: Any])
            for key in ["send", "wait", "receive"] {
                let value = try #require(timings[key] as? Double, "timings.\(key) missing")
                #expect(value >= 0)
            }
        }
    }

    @Test("entries are oldest first; metrics drive timings, httpVersion and serverIPAddress")
    func metricsTimings() throws {
        let records = try Self.makeRecords()
        let document = NFXHARExporter.makeDocument(records: records, creatorVersion: "4.0.0", bodies: Self.bodies(for: records))
        let first = try #require(document.log.entries.first)
        #expect(first.request.url == "https://example.com/items?page=2&q=a")
        #expect(first.request.httpVersion == "HTTP/2")
        #expect(first.serverIPAddress == "93.184.216.34")
        #expect(first.request.queryString == [.init(name: "page", value: "2"), .init(name: "q", value: "a")])
        #expect(first.timings.dns == 3)
        #expect(first.timings.connect == 16)
        #expect(first.timings.ssl == 10)
        #expect(first.timings.send == 1)
        #expect(first.timings.wait == 28)
        #expect(first.timings.receive == 10)
        #expect(first.timings.blocked == 1)
        #expect(first.time == 59)
        #expect(first.request.postData?.text == #"{"name":"a"}"# + "\n")
        #expect(first.response.content.text == #"{"id":"a/b"}"#)
        #expect(first.response.content.mimeType == "application/json")
    }

    @Test("binary content is base64; unknown sizes are -1; no metrics means -1 phases")
    func binaryAndUnknown() throws {
        let records = try Self.makeRecords()
        let document = NFXHARExporter.makeDocument(records: records, creatorVersion: "4.0.0", bodies: Self.bodies(for: records))
        let binary = document.log.entries[1]
        #expect(binary.response.content.encoding == "base64")
        #expect(binary.response.content.text == Data([0xFF, 0x00, 0xFE, 0x01]).base64EncodedString())
        #expect(binary.timings.dns == -1 && binary.timings.connect == -1 && binary.timings.ssl == -1 && binary.timings.blocked == -1)
        #expect(binary.timings.wait == 500)

        let failed = document.log.entries[2]
        #expect(failed.response.status == 0)
        #expect(failed.response.bodySize == -1)
        #expect(failed.request.bodySize == -1)
        #expect(failed.response.comment?.contains("\(NSURLErrorCannotFindHost)") == true)

        let encoded = String(decoding: try NFXHARExporter.encode(document), as: UTF8.self)
        #expect(!encoded.contains(#"\/"#))
    }
}
