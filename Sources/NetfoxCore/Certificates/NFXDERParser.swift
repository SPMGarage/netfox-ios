//
//  NFXDERParser.swift
//  netfox
//
//  P0-4: reads the validity period of an X.509 certificate by walking its ASN.1
//  structure. Used below iOS 18 / macOS 15, where SecCertificateCopyNotValid*Date
//  is not available. No byte scanning: serial numbers and names can contain the
//  UTCTime tag byte (0x17).
//

import Foundation

/// A minimal DER reader for the X.509 fields netfox shows.
package enum NFXDERParser {

    /// The `Validity` field of a certificate.
    package struct Validity: Sendable, Hashable {
        package let notBefore: Date
        package let notAfter: Date
    }

    /// Reads `notBefore` / `notAfter` from a DER-encoded certificate.
    ///
    /// Certificate → TBSCertificate → skip the optional `[0]` version, serialNumber,
    /// signature and issuer → Validity → the two Time values (RFC 5280 §4.1).
    /// - Returns: nil when the bytes are not a certificate this parser understands.
    package static func validity(ofCertificate der: Data) -> Validity? {
        var outer = Reader(bytes: ArraySlice(der))
        guard let certificate = outer.next(), certificate.tag == Tag.sequence else { return nil }

        var certificateReader = Reader(bytes: certificate.content)
        guard let tbs = certificateReader.next(), tbs.tag == Tag.sequence else { return nil }

        var tbsReader = Reader(bytes: tbs.content)
        guard var field = tbsReader.next() else { return nil }
        if field.tag == Tag.explicitVersion {
            guard let serial = tbsReader.next() else { return nil }
            field = serial
        }
        guard field.tag == Tag.integer,
              let signature = tbsReader.next(), signature.tag == Tag.sequence,
              let issuer = tbsReader.next(), issuer.tag == Tag.sequence,
              let validity = tbsReader.next(), validity.tag == Tag.sequence else {
            return nil
        }

        var validityReader = Reader(bytes: validity.content)
        guard let first = validityReader.next(), let second = validityReader.next(),
              let notBefore = date(from: first), let notAfter = date(from: second) else {
            return nil
        }
        return Validity(notBefore: notBefore, notAfter: notAfter)
    }

    // MARK: - Time values

    /// Parses UTCTime (`YYMMDDHHMMSSZ`) or GeneralizedTime (`YYYYMMDDHHMMSS[.fff]Z`).
    static func date(from element: Element) -> Date? {
        guard let text = String(bytes: element.content, encoding: .ascii), text.hasSuffix("Z") else { return nil }
        var digits = Substring(text.dropLast())
        var fraction: Double = 0
        if let dot = digits.firstIndex(of: ".") {
            fraction = Double("0" + digits[dot...]) ?? 0
            digits = digits[..<dot]
        }
        guard digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber) else { return nil }

        let year: Int
        var rest: Substring
        switch element.tag {
        case Tag.utcTime:
            guard digits.count == 12 || digits.count == 10, let yy = Int(digits.prefix(2)) else { return nil }
            year = yy >= 50 ? 1900 + yy : 2000 + yy // RFC 5280 §4.1.2.5.1
            rest = digits.dropFirst(2)
        case Tag.generalizedTime:
            guard digits.count == 14 || digits.count == 12, let yyyy = Int(digits.prefix(4)) else { return nil }
            year = yyyy
            rest = digits.dropFirst(4)
        default:
            return nil
        }

        var values: [Int] = []
        while !rest.isEmpty {
            guard let value = Int(rest.prefix(2)) else { return nil }
            values.append(value)
            rest = rest.dropFirst(2)
        }
        guard values.count >= 4 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = DateComponents(
            calendar: calendar, timeZone: .gmt,
            year: year, month: values[0], day: values[1],
            hour: values[2], minute: values[3], second: values.count > 4 ? values[4] : 0
        )
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return date.addingTimeInterval(fraction)
    }

    // MARK: - TLV reading

    enum Tag {
        static let integer: UInt8 = 0x02
        static let utcTime: UInt8 = 0x17
        static let generalizedTime: UInt8 = 0x18
        static let sequence: UInt8 = 0x30
        static let explicitVersion: UInt8 = 0xA0
    }

    struct Element {
        let tag: UInt8
        let content: ArraySlice<UInt8>
    }

    struct Reader {
        let bytes: ArraySlice<UInt8>
        private var index: Int

        init(bytes: ArraySlice<UInt8>) {
            self.bytes = bytes
            self.index = bytes.startIndex
        }

        /// Reads the next tag-length-value element, or nil at the end or on malformed input.
        mutating func next() -> Element? {
            guard index < bytes.endIndex else { return nil }
            let tag = bytes[index]
            index += 1
            // high-tag-number form never appears in the fields read here
            guard tag & 0x1F != 0x1F, index < bytes.endIndex else { return nil }

            let first = bytes[index]
            index += 1
            var length = 0
            if first & 0x80 == 0 {
                length = Int(first)
            } else {
                let count = Int(first & 0x7F)
                guard count > 0, count <= 4, bytes.endIndex - index >= count else { return nil }
                for _ in 0..<count {
                    length = (length << 8) | Int(bytes[index])
                    index += 1
                }
            }
            guard bytes.endIndex - index >= length else { return nil }
            let content = bytes[index..<(index + length)]
            index += length
            return Element(tag: tag, content: content)
        }
    }
}
