//
//  NFXSessionLogFormatter.swift
//  netfox
//
//  Text entries of session.log ("Share Session Logs").
//

import Foundation

/// Builds the plain-text session log entry of one record.
package enum NFXSessionLogFormatter {

    /// Every entry starts with this marker; trimming cuts at it.
    static let entryMarker = "-------START REQUEST"

    /// The request and response block of one record.
    package static func entry(for record: NFXRecord, requestBody: Data?, responseBody: Data?) -> String {
        var log = ""
        let url = record.urlString

        log += "\(entryMarker) -  \(url) -------\n"
        log += "[Request Method] \(record.method)\n"
        log += "[Request Date] \(record.startDate.formatted(.iso8601))\n"
        if let type = record.requestContentType {
            log += "[Request Type] \(type)\n"
        }
        log += "[Request Timeout] \(record.timeoutInterval)\n"
        log += "[Request Headers]\n\(headerBlock(record.requestHeaders))"
        log += "[Request Body]\n \(bodyText(requestBody, info: record.requestBody, kind: NFXContentKind(contentType: record.requestContentType)))\n"
        log += "-------END REQUEST - \(url) -------\n\n"

        log += "-------START RESPONSE -  \(url) -------\n"
        if let status = record.statusCode {
            log += "[Response Status] \(status)\n"
        }
        if let type = record.responseContentType {
            log += "[Response Type] \(type)\n"
        }
        if let endDate = record.endDate {
            log += "[Response Date] \(endDate.formatted(.iso8601))\n"
        }
        if let duration = record.duration {
            log += "[Duration] \(Int((duration * 1000).rounded())) ms\n"
        }
        if let redirect = record.redirectURL {
            log += "[Redirect To] \(redirect.absoluteString)\n"
        }
        if let error = record.error {
            log += "[Error] \(error.domain) \(error.code): \(error.message)\n"
        }
        log += "[Response Headers]\n\(headerBlock(record.responseHeaders))\n"
        log += "[Response Body]\n \(bodyText(responseBody, info: record.responseBody, kind: record.kind))\n"
        log += "-------END RESPONSE - \(url) -------\n\n"
        return log
    }

    private static func headerBlock(_ headers: [NFXHeader]) -> String {
        headers.map { "\($0.name): \($0.value)\n" }.joined()
    }

    private static func bodyText(_ data: Data?, info: NFXBodyInfo, kind: NFXContentKind) -> String {
        guard let data, !data.isEmpty else {
            if let length = info.length, length > 0 {
                return "<body not captured, \(length) bytes>"
            }
            return ""
        }
        let shown = data.prefix(NFXStorage.maxLogBodyBytes)
        let suffix = data.count > shown.count || info.isTruncated
            ? "\n<truncated, \(info.length ?? data.count) bytes in total>"
            : ""
        if kind == .json, data.count <= NFXStorage.maxLogBodyBytes, let pretty = NFXJSONFormatter.prettyPrinted(data) {
            return pretty + suffix
        }
        if let text = NFXBodyText.string(from: Data(shown)) {
            return text + suffix
        }
        return "<binary body, \(info.length ?? data.count) bytes>"
    }
}
