//
//  BodyDisplayTests.swift
//  NetfoxCoreTests
//
//  The body viewer shows at most NFXBodyLoader.displayLimit bytes (iOS only).
//

#if os(iOS)
import Foundation
@testable import netfox
import Testing

@Suite("Body display limit")
struct BodyDisplayTests {

    @Test("text over the limit is cut at a line break, short text is untouched")
    func cutsAtLineBreak() {
        let line = String(repeating: "a", count: 99) + "\n" // 100 bytes per line
        let text = String(repeating: line, count: NFXBodyLoader.displayLimit / 100 + 50)

        let (shown, isCut) = NFXBodyLoader.prefixForDisplay(text)

        #expect(isCut)
        #expect(shown.utf8.count <= NFXBodyLoader.displayLimit)
        #expect(shown.hasSuffix("a"), "the cut should land right before a line break")

        let short = NFXBodyLoader.prefixForDisplay(#"{"a":1}"#)
        #expect(short.text == #"{"a":1}"#)
        #expect(!short.isCut)
    }

    @Test("a cut never splits a multi-byte character")
    func keepsCharactersWhole() {
        // two UTF-8 bytes per character and no line breaks
        let text = String(repeating: "ж", count: NFXBodyLoader.displayLimit / 2 + 1_001)

        let (shown, isCut) = NFXBodyLoader.prefixForDisplay(text)

        #expect(isCut)
        #expect(shown.utf8.count <= NFXBodyLoader.displayLimit)
        #expect(shown.allSatisfy { $0 == "ж" })
    }
}
#endif
