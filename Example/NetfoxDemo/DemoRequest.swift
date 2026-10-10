//
//  DemoRequest.swift
//  NetfoxDemo
//
//  Sample requests that cover the cases netfox shows differently:
//  JSON, images, HTML/XML, error status codes, redirects, slow and failing requests.
//

import Foundation

struct DemoRequest: Identifiable, Sendable {

    enum Group: String, CaseIterable, Sendable {
        case basics = "Basics"
        case errors = "Errors"
        case advanced = "Advanced"
    }

    let id: String
    let title: String
    let group: Group
    let method: String
    let url: URL
    var jsonBody: String?
    // a separate ephemeral session shows that netfox also catches sessions the app creates itself
    var usesEphemeralSession = false
}

extension DemoRequest {

    static let all: [DemoRequest] = [
        DemoRequest(id: "get-json", title: "GET JSON", group: .basics, method: "GET",
                    url: url("https://jsonplaceholder.typicode.com/todos/1")),
        DemoRequest(id: "get-query", title: "GET with query", group: .basics, method: "GET",
                    url: url("https://jsonplaceholder.typicode.com/posts?userId=1&_limit=3")),
        DemoRequest(id: "post-json", title: "POST JSON", group: .basics, method: "POST",
                    url: url("https://jsonplaceholder.typicode.com/posts"),
                    jsonBody: #"{"title":"netfox","body":"Swift 6","userId":1}"#),
        DemoRequest(id: "patch-json", title: "PATCH JSON", group: .basics, method: "PATCH",
                    url: url("https://jsonplaceholder.typicode.com/posts/1"),
                    jsonBody: #"{"title":"updated"}"#),
        DemoRequest(id: "delete", title: "DELETE", group: .basics, method: "DELETE",
                    url: url("https://jsonplaceholder.typicode.com/posts/1")),
        DemoRequest(id: "image", title: "PNG image", group: .basics, method: "GET",
                    url: url("https://httpbin.org/image/png")),
        DemoRequest(id: "html", title: "HTML page", group: .basics, method: "GET",
                    url: url("https://example.com")),
        DemoRequest(id: "xml", title: "XML", group: .basics, method: "GET",
                    url: url("https://httpbin.org/xml")),

        DemoRequest(id: "status-404", title: "404 Not Found", group: .errors, method: "GET",
                    url: url("https://httpbin.org/status/404")),
        DemoRequest(id: "status-500", title: "500 Server Error", group: .errors, method: "GET",
                    url: url("https://httpbin.org/status/500")),
        DemoRequest(id: "unreachable", title: "Unreachable host", group: .errors, method: "GET",
                    url: url("https://netfox-demo.invalid/ping")),

        DemoRequest(id: "redirect", title: "Redirect x2", group: .advanced, method: "GET",
                    url: url("https://httpbin.org/redirect/2")),
        DemoRequest(id: "slow", title: "Slow (2 s)", group: .advanced, method: "GET",
                    url: url("https://httpbin.org/delay/2")),
        DemoRequest(id: "ephemeral", title: "Ephemeral session", group: .advanced, method: "GET",
                    url: url("https://jsonplaceholder.typicode.com/users/1"),
                    usesEphemeralSession: true),
        DemoRequest(id: "large-json", title: "Large JSON (~1 MB)", group: .advanced, method: "GET",
                    url: url("https://jsonplaceholder.typicode.com/photos")),
        DemoRequest(id: "binary", title: "Binary (16 KB)", group: .advanced, method: "GET",
                    url: url("https://httpbin.org/bytes/16384"))
    ]

    private static func url(_ string: StaticString) -> URL {
        guard let url = URL(string: "\(string)") else {
            preconditionFailure("Invalid demo URL: \(string)")
        }
        return url
    }
}
