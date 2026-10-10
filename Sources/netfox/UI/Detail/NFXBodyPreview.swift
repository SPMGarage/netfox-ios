//
//  NFXBodyPreview.swift
//  netfox
//
//  The short body preview on the Request / Response tabs, built off the main actor.
//

#if os(iOS)
import NetfoxCore
import UIKit

/// A few lines of text, or a decoded image.
nonisolated enum NFXBodyPreview: Sendable {
    case text(String)
    case image(UIImage)

    /// Bodies above this size get no preview (the body screen shows them).
    static let byteLimit = 2 * 1024 * 1024
    /// Characters kept for a text preview.
    static let characterLimit = 1_200
    static let lineLimit = 12
    static let imageHeight: CGFloat = 160

    /// Pretty JSON, other UTF-8 text, or an image; nil for binary bodies.
    @concurrent
    static func make(from data: Data?, mimeType: String?) async -> NFXBodyPreview? {
        guard let data, !data.isEmpty else { return nil }
        if mimeType?.hasPrefix("image/") == true {
            guard let image = await UIImage(data: data)?.byPreparingForDisplay() else { return nil }
            return .image(image)
        }
        let text: String?
        if NFXContentKind(contentType: mimeType) == .json || NFXBodyLoader.looksLikeJSON(data) {
            text = await NFXJSONFormatter.prettyPrintedInBackground(data) ?? NFXBodyText.string(from: data)
        } else {
            text = NFXBodyText.string(from: data)
        }
        guard let text else { return nil }
        guard text.count > characterLimit else { return .text(text) }
        return .text(String(text.prefix(characterLimit)) + "\u{2026}")
    }
}
#endif
