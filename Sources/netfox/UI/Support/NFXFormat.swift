//
//  NFXFormat.swift
//  netfox
//
//  Display strings shared by the inspector screens (P2-3: FormatStyle, no DateFormatter per call).
//

#if os(iOS)
import Foundation
import NetfoxCore

/// Formats durations, sizes, dates and status codes for display.
nonisolated enum NFXFormat {

    /// "245ms" below one second, "1.24s" from one second up, "-" while unknown.
    static func duration(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "-" }
        if seconds < 1 {
            return Duration.seconds(seconds).formatted(.units(allowed: [.milliseconds], width: .narrow))
        }
        return Duration.seconds(seconds).formatted(
            .units(allowed: [.seconds], width: .narrow, fractionalPart: .show(length: 2))
        )
    }

    /// Whole seconds for settings such as the timeout: "60 seconds".
    static func seconds(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.seconds], width: .wide))
    }

    /// "83 bytes", "1.2 MB"; "-" when unknown.
    static func bytes(_ count: Int?) -> String {
        guard let count else { return "-" }
        return Int64(count).formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    /// Date and time with seconds: "10/10/2026, 11:24:30 AM".
    static func dateTime(_ date: Date) -> String {
        date.formatted(date: .numeric, time: .standard)
    }

    /// Time of day with seconds: "11:24:30 AM".
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    /// "404 Not Found".
    static func status(_ code: Int) -> String {
        "\(code) \(reasonPhrase(for: code))"
    }

    /// The reason phrase of a status code. Foundation's text for 200 is "no error",
    /// so common codes use the RFC 9110 phrases.
    static func reasonPhrase(for code: Int) -> String {
        if let phrase = reasonPhrases[code] {
            return phrase
        }
        return HTTPURLResponse.localizedString(forStatusCode: code).capitalized
    }

    private static let reasonPhrases: [Int: String] = [
        200: "OK", 201: "Created", 202: "Accepted", 204: "No Content", 206: "Partial Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified",
        307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 408: "Request Timeout", 409: "Conflict", 410: "Gone",
        413: "Content Too Large", 415: "Unsupported Media Type", 422: "Unprocessable Content",
        429: "Too Many Requests",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
        503: "Service Unavailable", 504: "Gateway Timeout"
    ]

    /// Readable name of a cache policy.
    static func cachePolicy(_ policy: URLRequest.CachePolicy) -> String {
        switch policy {
        case .useProtocolCachePolicy: "Use Protocol Cache Policy"
        case .reloadIgnoringLocalCacheData: "Reload Ignoring Local Cache Data"
        case .reloadIgnoringLocalAndRemoteCacheData: "Reload Ignoring Local and Remote Cache Data"
        case .returnCacheDataElseLoad: "Return Cache Data Else Load"
        case .returnCacheDataDontLoad: "Return Cache Data, Don't Load"
        case .reloadRevalidatingCacheData: "Reload Revalidating Cache Data"
        @unknown default: "Unknown"
        }
    }

    /// One line for a record without a response: the error, or "Cancelled".
    static func failure(of record: NFXRecord) -> String {
        guard let error = record.error else { return "No response" }
        return error.isCancellation ? "Cancelled" : error.message
    }
}
#endif
