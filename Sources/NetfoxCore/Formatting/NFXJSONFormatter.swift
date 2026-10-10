//
//  NFXJSONFormatter.swift
//  netfox
//
//  P1-11: pretty-prints JSON without re-serializing it, so key order and the
//  original escapes survive (JSONSerialization reorders keys and writes "\/").
//

import Foundation

/// Order-preserving JSON pretty printer.
package enum NFXJSONFormatter {

    /// Re-indents JSON text, keeping key order and string contents as sent.
    ///
    /// The only change inside strings is `\/` -> `/`, which is the same JSON value.
    /// - Returns: nil when `data` is not valid JSON.
    package static func prettyPrinted(_ data: Data, indentWidth: Int = 2) -> String? {
        // JSONSerialization validates; the output below is built from the original bytes.
        guard !data.isEmpty, (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
            return nil
        }
        let bytes = [UInt8](data)
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count + bytes.count / 2)

        var depth = 0
        var isInString = false
        var isEscaped = false
        var index = 0

        func newline() {
            output.append(Byte.newline)
            output.append(contentsOf: repeatElement(Byte.space, count: depth * indentWidth))
        }

        while index < bytes.count {
            let byte = bytes[index]
            index += 1

            if isInString {
                if isEscaped {
                    isEscaped = false
                    if byte == Byte.slash {
                        output.removeLast() // drop the backslash of "\/"
                    }
                    output.append(byte)
                } else if byte == Byte.backslash {
                    isEscaped = true
                    output.append(byte)
                } else {
                    if byte == Byte.quote { isInString = false }
                    output.append(byte)
                }
                continue
            }

            switch byte {
            case Byte.quote:
                isInString = true
                output.append(byte)
            case Byte.openBrace, Byte.openBracket:
                let close = byte == Byte.openBrace ? Byte.closeBrace : Byte.closeBracket
                let next = nextSignificantIndex(in: bytes, from: index)
                if next < bytes.count, bytes[next] == close {
                    // empty container stays on one line: {} or []
                    output.append(byte)
                    output.append(close)
                    index = next + 1
                } else {
                    output.append(byte)
                    depth += 1
                    newline()
                }
            case Byte.closeBrace, Byte.closeBracket:
                depth = max(0, depth - 1)
                newline()
                output.append(byte)
            case Byte.comma:
                output.append(byte)
                newline()
            case Byte.colon:
                output.append(byte)
                output.append(Byte.space)
            case Byte.space, Byte.tab, Byte.newline, Byte.carriageReturn:
                continue
            default:
                output.append(byte)
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// ``prettyPrinted(_:indentWidth:)`` off the caller's actor (bodies can be megabytes).
    @concurrent
    package static func prettyPrintedInBackground(_ data: Data) async -> String? {
        prettyPrinted(data)
    }

    private static func nextSignificantIndex(in bytes: [UInt8], from start: Int) -> Int {
        var index = start
        while index < bytes.count, [Byte.space, Byte.tab, Byte.newline, Byte.carriageReturn].contains(bytes[index]) {
            index += 1
        }
        return index
    }

    private enum Byte {
        static let quote = UInt8(ascii: "\"")
        static let backslash = UInt8(ascii: "\\")
        static let slash = UInt8(ascii: "/")
        static let openBrace = UInt8(ascii: "{")
        static let closeBrace = UInt8(ascii: "}")
        static let openBracket = UInt8(ascii: "[")
        static let closeBracket = UInt8(ascii: "]")
        static let comma = UInt8(ascii: ",")
        static let colon = UInt8(ascii: ":")
        static let space = UInt8(ascii: " ")
        static let tab = UInt8(ascii: "\t")
        static let newline = UInt8(ascii: "\n")
        static let carriageReturn = UInt8(ascii: "\r")
    }
}
