//
//  NFXLineDiff.swift
//  netfox
//
//  B6: a unified line diff of two bodies, computed off the main actor.
//

#if os(iOS)
import Foundation
import NetfoxCore

/// Lines of the left body, the right body, or both, in order.
nonisolated struct NFXLineDiff: Sendable {

    nonisolated enum Change: Sendable {
        case same
        case removed
        case added
    }

    nonisolated struct Line: Identifiable, Sendable {
        let id: Int
        let text: String
        let change: Change
    }

    /// Each side is cut to this many lines before diffing.
    static let maxLines = 2_000
    /// JSON bodies up to this size are pretty-printed first, so the diff is per value.
    static let prettyPrintLimit = 1024 * 1024

    let lines: [Line]
    let isIdentical: Bool
    let isCut: Bool

    /// Compares two bodies. Equal bytes give an empty, identical diff.
    @concurrent
    static func make(left: Data?, right: Data?) async -> NFXLineDiff {
        if left == right {
            return NFXLineDiff(lines: [], isIdentical: true, isCut: false)
        }
        let leftLines = lines(of: left)
        let rightLines = lines(of: right)
        let isCut = leftLines.count > maxLines || rightLines.count > maxLines
        let merged = merge(Array(leftLines.prefix(maxLines)), Array(rightLines.prefix(maxLines)))
        return NFXLineDiff(lines: merged, isIdentical: false, isCut: isCut)
    }

    /// Text lines of a body: pretty JSON when possible, otherwise UTF-8 text.
    private static func lines(of data: Data?) -> [String] {
        guard let data, !data.isEmpty else { return [] }
        if data.count <= prettyPrintLimit, let pretty = NFXJSONFormatter.prettyPrinted(data) {
            return pretty.components(separatedBy: "\n")
        }
        guard let text = NFXBodyText.string(from: data) else {
            return ["<binary body, \(data.count) bytes>"]
        }
        return text.components(separatedBy: "\n")
    }

    /// Walks both sides; lines that are neither removed nor inserted are shared, in order.
    private static func merge(_ left: [String], _ right: [String]) -> [Line] {
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in right.difference(from: left) {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        var result: [Line] = []
        var leftIndex = 0
        var rightIndex = 0
        while leftIndex < left.count || rightIndex < right.count {
            if leftIndex < left.count, removed.contains(leftIndex) {
                result.append(Line(id: result.count, text: left[leftIndex], change: .removed))
                leftIndex += 1
            } else if rightIndex < right.count, inserted.contains(rightIndex) {
                result.append(Line(id: result.count, text: right[rightIndex], change: .added))
                rightIndex += 1
            } else {
                let text = leftIndex < left.count ? left[leftIndex] : right[rightIndex]
                result.append(Line(id: result.count, text: text, change: .same))
                leftIndex += 1
                rightIndex += 1
            }
        }
        return result
    }
}
#endif
