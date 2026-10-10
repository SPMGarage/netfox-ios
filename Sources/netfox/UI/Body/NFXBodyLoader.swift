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
    /// Only the first ``NFXBodyLoader/displayLimit`` bytes are shown (the full file can be shared).
    var isDisplayTruncated = false
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

    /// Text beyond this many UTF-8 bytes is not shown: laying out a 10 MB body
    /// in the text view costs seconds on the main thread.
    static let displayLimit = 2 * 1024 * 1024

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
            let (shown, isCut) = prefixForDisplay(raw)
            return .text(NFXRenderedText(plain: shown, highlighted: nil, isJSON: isJSON, isHighlightSkipped: false, isDisplayTruncated: isCut))
        }
        guard pretty.utf8.count <= NFXJSONHighlighter.byteLimit else {
            let (shown, isCut) = prefixForDisplay(pretty)
            return .text(NFXRenderedText(plain: shown, highlighted: nil, isJSON: true, isHighlightSkipped: true, isDisplayTruncated: isCut))
        }
        let highlighted = await NFXJSONHighlighter.highlight(pretty)
        return .text(NFXRenderedText(plain: pretty, highlighted: highlighted, isJSON: true, isHighlightSkipped: false))
    }

    /// The first ``displayLimit`` bytes of `text`, cut at a line break when there is one nearby.
    static func prefixForDisplay(_ text: String) -> (text: String, isCut: Bool) {
        let utf8 = text.utf8
        guard utf8.count > displayLimit else { return (text, false) }
        var end = utf8.index(utf8.startIndex, offsetBy: displayLimit)
        // don't split a character: step back to the nearest character boundary
        while end > utf8.startIndex, String.Index(end, within: text) == nil {
            end = utf8.index(before: end)
        }
        let head = text[..<end]
        if let newline = head.lastIndex(of: "\n"), head.distance(from: newline, to: head.endIndex) < 4096 {
            return (String(head[..<newline]), true)
        }
        return (String(head), true)
    }

    /// True when the first non-whitespace byte opens an object or an array.
    static func looksLikeJSON(_ data: Data) -> Bool {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        guard let first = data.first(where: { !whitespace.contains($0) }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }
}
#endif
