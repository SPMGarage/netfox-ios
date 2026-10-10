//
//  NFXPreviewData.swift
//  netfox
//
//  DEBUG only: fictional sample records (example.com hosts, documentation IP
//  addresses, no personal data) and a store with their bodies, for #Preview.
//

#if DEBUG && os(iOS)
import NetfoxCore
import SwiftUI

enum NFXPreviewData {

    /// A store with the sample records; its bodies live in a preview-only temp folder.
    static let store: NFXRequestStore = {
        let directory = URL.temporaryDirectory.appending(path: "netfox-previews", directoryHint: .isDirectory)
        let storage = NFXStorage(directoryURL: directory)
        let store = NFXRequestStore(settings: NFXInterceptionSettings(), storage: storage)
        // Preview-only setup: writing a few hundred bytes here keeps the samples self-contained.
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for body in bodies {
            try? body.data.write(to: storage.bodyFileURL(for: body.id, part: body.part))
        }
        for record in records.reversed() {
            store.apply(record)
        }
        store.togglePin(postRecord.id)
        return store
    }()

    static let webSocketStore: NFXWebSocketStore = {
        let store = NFXWebSocketStore()
        if let url = URL(string: "wss://chat.example.com/socket") {
            store.append(.text(#"{"type":"hello","user":"preview"}"#, direction: .sent), for: url)
            store.append(.text(#"{"type":"welcome","online":3}"#, direction: .received), for: url)
            store.append(.ping(direction: .sent), for: url)
        }
        return store
    }()

    // MARK: - Records

    static let todoJSON = Data((
        #"{"userId":1,"id":1,"title":"Write the netfox 4 release notes","completed":false,"#
            + #""tags":["docs","release"],"owner":null,"score":4.5,"url":"https://example.com/todos/1"}"#
    ).utf8)
    static let postJSON = Data(#"{"title":"netfox","body":"Swift 6","userId":1}"#.utf8)

    private static let start = Date.now.addingTimeInterval(-90)

    static let jsonRecord = NFXRecord(
        url: URL(string: "https://api.example.com/v1/todos/1?include=tags&lang=en"),
        method: "GET",
        requestHeaders: [
            NFXHeader(name: "Accept", value: "application/json"),
            NFXHeader(name: "User-Agent", value: "NetfoxPreview/1.0")
        ],
        startDate: start,
        endDate: start.addingTimeInterval(0.245),
        statusCode: 200,
        responseHeaders: [
            NFXHeader(name: "Cache-Control", value: "max-age=60"),
            NFXHeader(name: "Content-Type", value: "application/json; charset=utf-8"),
            NFXHeader(name: "Server", value: "example")
        ],
        responseBody: NFXBodyInfo(length: todoJSON.count, isStored: true, isTruncated: false),
        certificate: NFXCertificateInfo(
            subjectSummary: "api.example.com",
            issuerSummary: "Example Issuing CA",
            notValidBefore: start.addingTimeInterval(-86_400 * 30),
            notValidAfter: start.addingTimeInterval(86_400 * 60),
            publicKeyDescription: "ECDSA 256-bit",
            isSelfSigned: false,
            chainLength: 3
        ),
        metrics: sampleMetrics
    )

    static let postRecord = NFXRecord(
        url: URL(string: "https://api.example.com/v1/posts"),
        method: "POST",
        requestHeaders: [NFXHeader(name: "Content-Type", value: "application/json; charset=utf-8")],
        requestBody: NFXBodyInfo(length: postJSON.count, isStored: true, isTruncated: false),
        startDate: start.addingTimeInterval(5),
        endDate: start.addingTimeInterval(5.41),
        statusCode: 201,
        responseHeaders: [NFXHeader(name: "Content-Type", value: "application/json")],
        responseBody: NFXBodyInfo(length: postJSON.count, isStored: true, isTruncated: false)
    )

    static let records: [NFXRecord] = [
        jsonRecord,
        postRecord,
        NFXRecord(
            url: URL(string: "https://www.example.com/missing"),
            method: "GET",
            startDate: start.addingTimeInterval(9),
            endDate: start.addingTimeInterval(9.12),
            statusCode: 404,
            responseHeaders: [NFXHeader(name: "Content-Type", value: "text/html")],
            responseBody: NFXBodyInfo(length: 1_256, isStored: false, isTruncated: false)
        ),
        NFXRecord(
            url: URL(string: "https://offline.example.invalid/ping"),
            method: "GET",
            startDate: start.addingTimeInterval(12),
            endDate: start.addingTimeInterval(12.03),
            error: NFXRecordError(
                domain: NSURLErrorDomain,
                code: NSURLErrorCannotFindHost,
                message: "A server with the specified hostname could not be found."
            )
        )
    ]

    private struct SampleBody {
        let id: UUID
        let part: NFXBodyPart
        let data: Data
    }

    private static let bodies = [
        SampleBody(id: jsonRecord.id, part: .response, data: todoJSON),
        SampleBody(id: postRecord.id, part: .request, data: postJSON),
        SampleBody(id: postRecord.id, part: .response, data: postJSON)
    ]

    private static var sampleMetrics: NFXRequestMetrics {
        let transaction = NFXRequestMetrics.Transaction(
            fetchStartDate: start,
            domainLookupStartDate: start.addingTimeInterval(0.002),
            domainLookupEndDate: start.addingTimeInterval(0.021),
            connectStartDate: start.addingTimeInterval(0.021),
            connectEndDate: start.addingTimeInterval(0.094),
            secureConnectionStartDate: start.addingTimeInterval(0.047),
            secureConnectionEndDate: start.addingTimeInterval(0.094),
            requestStartDate: start.addingTimeInterval(0.095),
            requestEndDate: start.addingTimeInterval(0.096),
            responseStartDate: start.addingTimeInterval(0.226),
            responseEndDate: start.addingTimeInterval(0.245),
            networkProtocolName: "h2",
            remoteAddress: "203.0.113.10",
            remotePort: 443,
            tlsProtocolVersion: "TLS 1.3"
        )
        return NFXRequestMetrics(taskInterval: DateInterval(start: start, duration: 0.245), transactions: [transaction])
    }
}

extension View {
    /// The environment the presenter sets up, filled with the sample data.
    func nfxPreviewEnvironment() -> some View {
        environment(NFXPreviewData.store)
            .environment(NFXPreviewData.webSocketStore)
            .tint(Color.nfxOrange)
    }
}
#endif
