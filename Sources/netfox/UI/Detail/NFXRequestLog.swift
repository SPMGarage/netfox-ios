//
//  NFXRequestLog.swift
//  netfox
//
//  The single-request log shared from the detail screen. The text is built only
//  when the share sheet asks for it, off the main actor (bodies can be megabytes).
//

#if os(iOS)
import CoreTransferable
import Foundation
import NetfoxCore
import UniformTypeIdentifiers

/// Plain-text log of one record with its bodies (the "full log"), built lazily.
/// The "simple log" is ``summary(of:)``, shared as a String.
nonisolated struct NFXRequestLog: Transferable {
    let record: NFXRecord
    /// Stored body files, read when the share sheet asks for the text.
    let requestBodyURL: URL?
    let responseBodyURL: URL?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .utf8PlainText) { log in
            Data(await log.text().utf8)
        }
        .suggestedFileName { log in log.fileName }
    }

    private static let footer = "logged via netfox \(NFXBuildInfo.version) - \(NFXBuildInfo.homepage)\n"

    var fileName: String {
        "netfox-\(record.host ?? "request").txt"
    }

    /// The full log: the session log entry (bodies cut at 256 KB, pretty JSON).
    @concurrent
    func text() async -> String {
        let requestBody = requestBodyURL.flatMap { try? Data(contentsOf: $0) }
        let responseBody = responseBodyURL.flatMap { try? Data(contentsOf: $0) }
        let entry = NFXSessionLogFormatter.entry(for: record, requestBody: requestBody, responseBody: responseBody)
        return entry + Self.footer
    }

    /// The simple log: overview and headers, without bodies.
    static func summary(of record: NFXRecord) -> String {
        var lines = ["** INFO **"]
        lines.append("URL: \(record.urlString)")
        lines.append("Method: \(record.method)")
        lines.append("Status: \(record.statusCode.map(NFXFormat.status) ?? NFXFormat.failure(of: record))")
        lines.append("Request date: \(record.startDate.formatted(.iso8601))")
        if let endDate = record.endDate {
            lines.append("Response date: \(endDate.formatted(.iso8601))")
        }
        lines.append("Duration: \(NFXFormat.duration(record.duration))")
        lines.append("Timeout: \(NFXFormat.seconds(record.timeoutInterval))")
        lines.append("Cache policy: \(NFXFormat.cachePolicy(record.cachePolicy))")
        if let redirect = record.redirectURL {
            lines.append("Redirect to: \(redirect.absoluteString)")
        }
        lines.append("")
        lines.append("** REQUEST HEADERS **")
        lines.append(contentsOf: record.requestHeaders.map { "\($0.name): \($0.value)" })
        lines.append("Body: \(NFXFormat.bytes(record.requestBody.length))")
        lines.append("")
        lines.append("** RESPONSE HEADERS **")
        lines.append(contentsOf: record.responseHeaders.map { "\($0.name): \($0.value)" })
        lines.append("Body: \(NFXFormat.bytes(record.responseBody.length))")
        return lines.joined(separator: "\n") + "\n\n" + footer
    }
}
#endif
