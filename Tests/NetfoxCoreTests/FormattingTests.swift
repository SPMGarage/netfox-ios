//
//  FormattingTests.swift
//  NetfoxCoreTests
//
//  cURL builder (P1-10) and the order-preserving JSON pretty printer (P1-11).
//

import Foundation
@testable import NetfoxCore
import Testing

@Suite("cURL builder")
struct CurlBuilderTests {

    @Test("JSON body and quotes are single-quoted; Content-Length is skipped")
    func quoting() throws {
        let url = try #require(URL(string: "http://127.0.0.1:18765/echo?q=a b"))
        let body = Data(#"{"name":"netfox","note":"it's"}"#.utf8)
        let command = NFXCurlBuilder.command(
            method: "POST",
            url: url,
            headers: [
                NFXHeader(name: "Content-Length", value: "31"),
                NFXHeader(name: "Content-Type", value: "application/json"),
                NFXHeader(name: "X-Quote", value: "it's")
            ],
            body: body
        )
        #expect(command == #"curl 'http://127.0.0.1:18765/echo?q=a%20b' -X 'POST' -H 'Content-Type: application/json' -H 'X-Quote: it'\''s' --data-binary '{"name":"netfox","note":"it'\''s"}'"#)
    }

    @Test("GET has no -X, HEAD uses --head")
    func methods() throws {
        let url = try #require(URL(string: "https://example.com/a"))
        #expect(NFXCurlBuilder.command(method: "GET", url: url, headers: [], body: nil) == "curl 'https://example.com/a'")
        #expect(NFXCurlBuilder.command(method: "HEAD", url: url, headers: [], body: nil) == "curl 'https://example.com/a' --head")
    }

    @Test("A binary body is not pasted into the shell")
    func binaryBody() throws {
        let url = try #require(URL(string: "https://example.com/upload"))
        let command = NFXCurlBuilder.command(method: "PUT", url: url, headers: [], body: Data([0xFF, 0xFE, 0x00, 0x01]))
        #expect(command == "curl 'https://example.com/upload' -X 'PUT' # binary request body (4 bytes) not included")
    }

    @Test("quote() escapes embedded single quotes")
    func quoteHelper() {
        #expect(NFXCurlBuilder.quote("a'b") == #"'a'\''b'"#)
        #expect(NFXCurlBuilder.quote("") == "''")
    }
}

@Suite("JSON pretty printer")
struct JSONFormatterTests {

    @Test("keeps key order and writes slashes unescaped")
    func orderAndSlashes() throws {
        let raw = #"{"zeta":1,"alpha":"https:\/\/example.com\/a\/b","mike":[],"nested":{"b":true,"a":null},"list":[1,{"x":"y"}]}"#
        let pretty = try #require(NFXJSONFormatter.prettyPrinted(Data(raw.utf8)))
        let expected = """
            {
              "zeta": 1,
              "alpha": "https://example.com/a/b",
              "mike": [],
              "nested": {
                "b": true,
                "a": null
              },
              "list": [
                1,
                {
                  "x": "y"
                }
              ]
            }
            """
        #expect(pretty == expected)
        #expect(!pretty.contains(#"\/"#))
    }

    @Test("escapes inside strings survive; unicode is kept")
    func stringEscapes() throws {
        let raw = #"{"quote":"say \"hi\", {not: a key}","backslash":"a\\/b","emoji":"salom 👋"}"#
        let pretty = try #require(NFXJSONFormatter.prettyPrinted(Data(raw.utf8)))
        #expect(pretty.contains(#""quote": "say \"hi\", {not: a key}""#))
        #expect(pretty.contains(#""backslash": "a\\/b""#))
        #expect(pretty.contains("salom 👋"))
        // the output is still valid JSON with the same values
        let original = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? NSDictionary
        let reparsed = try JSONSerialization.jsonObject(with: Data(pretty.utf8)) as? NSDictionary
        #expect(original == reparsed)
    }

    @Test("invalid JSON and empty data give nil; fragments are allowed")
    func invalidInput() {
        #expect(NFXJSONFormatter.prettyPrinted(Data("{\"a\":".utf8)) == nil)
        #expect(NFXJSONFormatter.prettyPrinted(Data()) == nil)
        #expect(NFXJSONFormatter.prettyPrinted(Data("not json".utf8)) == nil)
        #expect(NFXJSONFormatter.prettyPrinted(Data("42".utf8)) == "42")
    }
}
