//
//  NFXContentKind.swift
//  netfox
//
//  Content-type detection for captured bodies (replaces HTTPModelShortType).
//

import Foundation

/// The response type filters shown in the inspector.
package enum NFXContentKind: String, CaseIterable, Sendable, Hashable, Identifiable {
    case json
    case xml
    case html
    case image
    case other

    package var id: String { rawValue }

    /// Display name, e.g. "JSON".
    package var title: String {
        switch self {
        case .json: "JSON"
        case .xml: "XML"
        case .html: "HTML"
        case .image: "Image"
        case .other: "Other"
        }
    }

    /// Detects the kind from a MIME type or a full `Content-Type` header value.
    package init(contentType: String?) {
        guard let mime = NFXMIME.mimeType(from: contentType) else {
            self = .other
            return
        }
        if mime.contains("json") {
            self = .json
        } else if mime == "application/xml" || mime == "text/xml" || mime.hasSuffix("+xml") {
            self = .xml
        } else if mime == "text/html" || mime == "application/xhtml+xml" {
            self = .html
        } else if mime.hasPrefix("image/") {
            self = .image
        } else {
            self = .other
        }
    }
}

/// MIME helpers.
package enum NFXMIME {

    /// The lowercased MIME type of a `Content-Type` value, without parameters.
    /// `"application/json; charset=utf-8"` -> `"application/json"`.
    package static func mimeType(from contentType: String?) -> String? {
        guard let contentType else { return nil }
        let mime = contentType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        return mime.isEmpty ? nil : mime
    }

    /// Whether a MIME type usually carries text.
    package static func isTextual(_ mime: String?) -> Bool {
        guard let mime else { return false }
        if mime.hasPrefix("text/") { return true }
        let textualMarkers = ["json", "xml", "javascript", "x-www-form-urlencoded", "graphql", "yaml", "csv"]
        return textualMarkers.contains { mime.contains($0) }
    }
}

/// Decoding helpers for showing captured bytes.
package enum NFXBodyText {

    /// The body as UTF-8 text, or nil when the bytes are not valid UTF-8 (binary bodies).
    package static func string(from data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }
}
