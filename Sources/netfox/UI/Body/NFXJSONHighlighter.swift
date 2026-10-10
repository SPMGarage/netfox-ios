//
//  NFXJSONHighlighter.swift
//  netfox
//
//  B10 / P1-8: JSON syntax colors in one pass over the UTF-8 bytes, off the main
//  actor. Neighbouring tokens of the same kind become one run, so the result is a
//  single AttributedString built from a few appends (no per-character appends and
//  no copies of the remaining text).
//

#if os(iOS)
import Foundation
import UIKit

nonisolated enum NFXJSONHighlighter {

    /// Bodies above this many UTF-8 bytes are shown without colors.
    static let byteLimit = 200 * 1024

    nonisolated enum Token: Int, CaseIterable, Sendable {
        case punctuation
        case key
        case string
        case number
        case literal
        case null
    }

    /// Colors `json` (any text; invalid parts are left in the punctuation color).
    @concurrent
    static func highlight(_ json: String) async -> AttributedString {
        highlighted(json)
    }

    /// The synchronous pass behind ``highlight(_:)``.
    static func highlighted(_ json: String) -> AttributedString {
        var builder = RunBuilder(bytes: Array(json.utf8))
        builder.run()
        return builder.result
    }

    static func color(for token: Token) -> UIColor {
        switch token {
        case .punctuation: .secondaryLabel
        case .key: .nfxOrange
        case .string: .nfxDarkGreen
        case .number: .systemBlue
        case .literal: .systemPurple
        case .null: .systemGray
        }
    }
}

/// Walks the bytes once and appends one attributed run per change of token kind.
private nonisolated struct RunBuilder {
    private let bytes: [UInt8]
    private let containers: [AttributeContainer]
    private var runStart = 0
    private var runToken = NFXJSONHighlighter.Token.punctuation
    private(set) var result = AttributedString()

    init(bytes: [UInt8]) {
        self.bytes = bytes
        self.containers = NFXJSONHighlighter.Token.allCases.map { token in
            var container = AttributeContainer()
            container.uiKit.foregroundColor = NFXJSONHighlighter.color(for: token)
            return container
        }
    }

    mutating func run() {
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == Byte.quote {
                let end = endOfString(from: index)
                begin(isKey(after: end) ? .key : .string, at: index)
                index = end
            } else if byte == Byte.minus || Byte.digits.contains(byte) {
                begin(.number, at: index)
                index = endOfNumber(from: index)
            } else if let literal = literal(at: index) {
                begin(literal.token, at: index)
                index += literal.length
            } else {
                begin(.punctuation, at: index)
                index += 1
            }
        }
        flush(upTo: bytes.count)
    }

    /// Starts a token; a new run begins only when the kind changes.
    private mutating func begin(_ token: NFXJSONHighlighter.Token, at index: Int) {
        guard token != runToken else { return }
        flush(upTo: index)
        runToken = token
    }

    private mutating func flush(upTo end: Int) {
        guard end > runStart else { return }
        // Runs start and end on ASCII bytes of a valid String, so the slice is always valid
        // UTF-8; the non-failable decoder never has to repair anything.
        // swiftlint:disable:next optional_data_string_conversion
        let text = String(decoding: bytes[runStart..<end], as: UTF8.self)
        result.append(AttributedString(text, attributes: containers[runToken.rawValue]))
        runStart = end
    }

    /// Index after the closing quote (or the end of the text for an unterminated string).
    private func endOfString(from start: Int) -> Int {
        var index = start + 1
        while index < bytes.count {
            switch bytes[index] {
            case Byte.backslash: index += 2
            case Byte.quote: return index + 1
            default: index += 1
            }
        }
        return bytes.count
    }

    /// A string followed by ":" is an object key.
    private func isKey(after index: Int) -> Bool {
        var next = index
        while next < bytes.count, Byte.whitespace.contains(bytes[next]) {
            next += 1
        }
        return next < bytes.count && bytes[next] == Byte.colon
    }

    private func endOfNumber(from start: Int) -> Int {
        var index = start + 1
        while index < bytes.count, Byte.numberBody.contains(bytes[index]) {
            index += 1
        }
        return index
    }

    private func literal(at index: Int) -> (token: NFXJSONHighlighter.Token, length: Int)? {
        let rest = bytes[index...]
        if rest.starts(with: Byte.trueLiteral) { return (.literal, Byte.trueLiteral.count) }
        if rest.starts(with: Byte.falseLiteral) { return (.literal, Byte.falseLiteral.count) }
        if rest.starts(with: Byte.nullLiteral) { return (.null, Byte.nullLiteral.count) }
        return nil
    }

    private nonisolated enum Byte {
        static let quote = UInt8(ascii: "\"")
        static let backslash = UInt8(ascii: "\\")
        static let colon = UInt8(ascii: ":")
        static let minus = UInt8(ascii: "-")
        static let digits = UInt8(ascii: "0")...UInt8(ascii: "9")
        static let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        static let numberBody: Set<UInt8> = Set(Array(UInt8(ascii: "0")...UInt8(ascii: "9")) + Array("+-.eE".utf8))
        static let trueLiteral = Array("true".utf8)
        static let falseLiteral = Array("false".utf8)
        static let nullLiteral = Array("null".utf8)
    }
}
#endif
