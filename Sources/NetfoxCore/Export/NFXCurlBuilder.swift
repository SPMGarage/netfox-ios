//
//  NFXCurlBuilder.swift
//  netfox
//
//  P1-10: "Copy as cURL" with shell-safe quoting, built from the captured bytes.
//

import Foundation

/// Builds a `curl` command that replays a captured request.
package enum NFXCurlBuilder {

    /// A single-line command. Every argument is single-quoted (`'` becomes `'\''`),
    /// the body goes through `--data-binary`, and `Content-Length` is left out
    /// because curl computes it.
    package static func command(method: String, url: URL?, headers: [NFXHeader], body: Data?, bodyInfo: NFXBodyInfo? = nil) -> String {
        guard let url else { return "" }
        var parts = ["curl", quote(url.absoluteString)]

        switch method.uppercased() {
        case "GET":
            break
        case "HEAD":
            parts.append("--head")
        default:
            parts.append("-X")
            parts.append(quote(method))
        }

        for header in headers where header.name.caseInsensitiveCompare("Content-Length") != .orderedSame {
            parts.append("-H")
            parts.append(quote("\(header.name): \(header.value)"))
        }

        var note: String?
        if let body, !body.isEmpty {
            if bodyInfo?.isTruncated == true {
                note = "# request body (\(bodyInfo?.length ?? body.count) bytes) is larger than netfox stores, not included"
            } else if let text = NFXBodyText.string(from: body) {
                parts.append("--data-binary")
                parts.append(quote(text))
            } else {
                note = "# binary request body (\(body.count) bytes) not included"
            }
        } else if let length = bodyInfo?.length, length > 0 {
            note = "# request body (\(length) bytes) was not captured"
        }

        var command = parts.joined(separator: " ")
        if let note {
            command += " " + note
        }
        return command
    }

    /// The command for a record, given its request body bytes.
    package static func command(for record: NFXRecord, body: Data?) -> String {
        command(method: record.method, url: record.url, headers: record.requestHeaders, body: body, bodyInfo: record.requestBody)
    }

    /// Loads the request body from storage and builds the command, off the caller's actor.
    @concurrent
    package static func command(for record: NFXRecord, storage: NFXStorage = .shared) async -> String {
        var body: Data?
        if record.requestBody.isStored {
            body = await storage.body(for: record.id, part: .request)
        }
        return command(for: record, body: body)
    }

    /// Wraps a value in single quotes for POSIX shells.
    package static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
