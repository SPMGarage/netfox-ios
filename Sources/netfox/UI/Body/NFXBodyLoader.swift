//
//  NFXBodyLoader.swift
//  netfox
//
//  P1-8 / P2-3: turns stored body bytes into something to show, off the main actor:
//  pretty JSON (order-preserving) with colors up to 200 KB, plain text, an image,
//  or a binary placeholder.
//

#if os(iOS)
import NetfoxCore
import UIKit

/// Raw or pretty-printed JSON.
nonisolated enum NFXBodyMode: String, CaseIterable, Identifiable, Sendable {
    case pretty = "Pretty"
    case raw = "Raw"

    var id: Self { self }
}

/// Text ready for the body text view.
nonisolated struct NFXRenderedText: Sendable, Equatable {
    /// Identity of this rendering; the text view reloads only when it changes.
    let id = UUID()
    let plain: String
    /// Syntax colors (pretty JSON up to ``NFXJSONHighlighter/byteLimit``).
    let highlighted: AttributedString?
    /// The body is JSON, so the Raw / Pretty picker applies.
    let isJSON: Bool
    /// Pretty JSON above the highlight limit is shown without colors.
    let isHighlightSkipped: Bool
}

/// What the body screen shows.
nonisolated enum NFXBodyContent: Sendable {
    case loading
    case empty
    case notCaptured(length: Int?)
    case image(UIImage, byteCount: Int)
    case text(NFXRenderedText)
    case binary(byteCount: Int, mimeType: String?)
}

nonisolated enum NFXBodyLoader {

    /// Builds the content for `data`. Runs off the main actor: a body can be 10 MB.
    @concurrent
    static func content(
        for data: Data?,
        info: NFXBodyInfo,
        mimeType: String?,
        mode: NFXBodyMode
    ) async -> NFXBodyContent {
        guard let data, !data.isEmpty else {
            return info.isEmpty ? .empty : .notCaptured(length: info.length)
        }
        let byteCount = info.length ?? data.count
        if mimeType?.hasPrefix("image/") == true, let image = await UIImage(data: data)?.byPreparingForDisplay() {
            return .image(image, byteCount: byteCount)
        }
        guard let raw = NFXBodyText.string(from: data) else {
            if let image = await UIImage(data: data)?.byPreparingForDisplay() {
                return .image(image, byteCount: byteCount)
            }
            return .binary(byteCount: byteCount, mimeType: mimeType)
        }
        let isJSON = NFXContentKind(contentType: mimeType) == .json || looksLikeJSON(data)
        guard isJSON, mode == .pretty, let pretty = await NFXJSONFormatter.prettyPrintedInBackground(data) else {
            return .text(NFXRenderedText(plain: raw, highlighted: nil, isJSON: isJSON, isHighlightSkipped: false))
        }
        guard pretty.utf8.count <= NFXJSONHighlighter.byteLimit else {
            return .text(NFXRenderedText(plain: pretty, highlighted: nil, isJSON: true, isHighlightSkipped: true))
        }
        let highlighted = await NFXJSONHighlighter.highlight(pretty)
        return .text(NFXRenderedText(plain: pretty, highlighted: highlighted, isJSON: true, isHighlightSkipped: false))
    }

    /// True when the first non-whitespace byte opens an object or an array.
    static func looksLikeJSON(_ data: Data) -> Bool {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        guard let first = data.first(where: { !whitespace.contains($0) }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }
}
#endif
