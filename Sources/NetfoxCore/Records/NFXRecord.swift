//
//  NFXRecord.swift
//  netfox
//
//  P1-5: one captured request/response, immutable and Sendable. Built on the
//  router's delegate queue and handed by value to the main-actor store.
//

import Foundation

/// One HTTP header field.
package struct NFXHeader: Sendable, Hashable {
    package let name: String
    package let value: String

    package init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    /// Converts a header dictionary into fields sorted by name (case-insensitive).
    package static func list(from fields: [String: String]?) -> [NFXHeader] {
        (fields ?? [:])
            .map { NFXHeader(name: $0.key, value: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Converts `HTTPURLResponse.allHeaderFields` into sorted fields.
    package static func list(from fields: [AnyHashable: Any]) -> [NFXHeader] {
        var strings: [String: String] = [:]
        for (key, value) in fields {
            strings["\(key)"] = "\(value)"
        }
        return list(from: strings)
    }
}

extension [NFXHeader] {
    /// Case-insensitive header lookup.
    package func value(for name: String) -> String? {
        first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

/// Which body of a record.
package enum NFXBodyPart: String, Sendable, Hashable, CaseIterable {
    case request
    case response
}

/// What netfox knows about one body (P0-3: the length is recorded for every body).
package struct NFXBodyInfo: Sendable, Hashable {
    /// Total size in bytes. nil when unknown (an upload stream netfox did not read).
    package let length: Int?
    /// Whether bytes were stored on disk (all of them, or the first ``NFXStorage/maxBodyBytes``).
    package let isStored: Bool
    /// Whether only the first ``NFXStorage/maxBodyBytes`` bytes were stored.
    package let isTruncated: Bool

    package init(length: Int?, isStored: Bool, isTruncated: Bool) {
        self.length = length
        self.isStored = isStored
        self.isTruncated = isTruncated
    }

    /// No body.
    package static let empty = NFXBodyInfo(length: 0, isStored: false, isTruncated: false)

    /// True when the body is known to be empty.
    package var isEmpty: Bool { length == 0 }
}

/// A transport error, flattened so it is Sendable and Hashable.
package struct NFXRecordError: Sendable, Hashable {
    package let domain: String
    package let code: Int
    package let message: String

    package init(domain: String, code: Int, message: String) {
        self.domain = domain
        self.code = code
        self.message = message
    }

    package init(_ error: any Error) {
        let nsError = error as NSError
        self.init(domain: nsError.domain, code: nsError.code, message: nsError.localizedDescription)
    }

    /// True for `NSURLErrorCancelled`.
    package var isCancellation: Bool {
        domain == NSURLErrorDomain && code == NSURLErrorCancelled
    }
}

/// One captured request and its response.
///
/// Records are values: an update (for example metrics that arrive after the
/// response) is published as a new value with the same ``id``.
package struct NFXRecord: Sendable, Identifiable, Hashable {

    // MARK: Identity

    package let id: UUID

    // MARK: Request

    package let url: URL?
    package let method: String
    /// Request headers as the app's session handed them to netfox, sorted by name.
    package let requestHeaders: [NFXHeader]
    package let requestBody: NFXBodyInfo
    package let cachePolicy: URLRequest.CachePolicy
    package let timeoutInterval: TimeInterval
    package let startDate: Date

    // MARK: Response

    /// When the response finished, failed or redirected.
    package let endDate: Date?
    /// HTTP status, nil when no response arrived.
    package let statusCode: Int?
    package let responseHeaders: [NFXHeader]
    package let responseBody: NFXBodyInfo
    /// Target of a 3xx hop, nil otherwise.
    package let redirectURL: URL?
    package let error: NFXRecordError?

    // MARK: Extras

    /// D6: server certificate, when certificate capture is on and the request used HTTPS.
    package let certificate: NFXCertificateInfo?
    /// B7: URLSessionTaskMetrics of the internal task.
    package let metrics: NFXRequestMetrics?

    package init(
        id: UUID = UUID(),
        url: URL?,
        method: String,
        requestHeaders: [NFXHeader] = [],
        requestBody: NFXBodyInfo = .empty,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 60,
        startDate: Date = Date(),
        endDate: Date? = nil,
        statusCode: Int? = nil,
        responseHeaders: [NFXHeader] = [],
        responseBody: NFXBodyInfo = .empty,
        redirectURL: URL? = nil,
        error: NFXRecordError? = nil,
        certificate: NFXCertificateInfo? = nil,
        metrics: NFXRequestMetrics? = nil
    ) {
        self.id = id
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
        self.startDate = startDate
        self.endDate = endDate
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.redirectURL = redirectURL
        self.error = error
        self.certificate = certificate
        self.metrics = metrics
    }

    /// A copy with metrics attached (late metrics arrive after the record was published).
    package func withMetrics(_ metrics: NFXRequestMetrics?) -> NFXRecord {
        NFXRecord(
            id: id, url: url, method: method, requestHeaders: requestHeaders, requestBody: requestBody,
            cachePolicy: cachePolicy, timeoutInterval: timeoutInterval, startDate: startDate,
            endDate: endDate, statusCode: statusCode, responseHeaders: responseHeaders,
            responseBody: responseBody, redirectURL: redirectURL, error: error,
            certificate: certificate, metrics: metrics
        )
    }
}

// MARK: - Derived values

extension NFXRecord {

    /// The absolute URL string, or "-".
    package var urlString: String { url?.absoluteString ?? "-" }

    /// The URL host, used for grouping (C1).
    package var host: String? { url?.host() }

    /// Query items of the URL (empty when there are none).
    package var queryItems: [URLQueryItem] {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return [] }
        return components.queryItems ?? []
    }

    /// Seconds from start to the end of the response, nil while unknown.
    package var duration: TimeInterval? {
        endDate.map { $0.timeIntervalSince(startDate) }
    }

    /// MIME type of the request body (`Content-Type` without parameters).
    package var requestContentType: String? {
        NFXMIME.mimeType(from: requestHeaders.value(for: "Content-Type"))
    }

    /// MIME type of the response body (`Content-Type` without parameters).
    package var responseContentType: String? {
        NFXMIME.mimeType(from: responseHeaders.value(for: "Content-Type"))
    }

    /// Response type used by the type filters.
    package var kind: NFXContentKind {
        NFXContentKind(contentType: responseContentType)
    }

    /// True once a response (any status) arrived.
    package var hasResponse: Bool { statusCode != nil }

    /// Status below 400 and no transport error (netfox 3.x `isSuccessful`).
    package var isSuccess: Bool {
        guard error == nil, let statusCode else { return false }
        return statusCode < 400
    }

    /// True for a 3xx hop recorded on its own.
    package var isRedirect: Bool {
        guard let statusCode else { return false }
        return (300...399).contains(statusCode) && redirectURL != nil
    }

    /// Body info for one side.
    package func body(_ part: NFXBodyPart) -> NFXBodyInfo {
        part == .request ? requestBody : responseBody
    }

    /// MIME type for one side.
    package func contentType(_ part: NFXBodyPart) -> String? {
        part == .request ? requestContentType : responseContentType
    }

    /// Case-insensitive search over URL, method, status and response type.
    package func matches(search text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let fields = [urlString, method, responseContentType ?? "", statusCode.map(String.init) ?? ""]
        return fields.contains { $0.range(of: query, options: options) != nil }
    }
}
