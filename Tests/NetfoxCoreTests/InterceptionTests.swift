//
//  InterceptionTests.swift
//  NetfoxCoreTests
//
//  End-to-end tests through the real path: NFXInterception.start() registers the
//  protocol and swizzles URLSessionConfiguration; requests go to a loopback server.
//

import Foundation
@testable import NetfoxCore
import os
import Testing

@Suite("Interception", .serialized)
final class InterceptionTests {

    let server: LoopbackServer
    let collector: RecordCollector

    init() async throws {
        InterceptionFixture.activate()
        server = try LoopbackServer()
        try await server.start()
        collector = RecordCollector()
    }

    deinit {
        server.stop()
    }

    private func makeSession(delegate: (any URLSessionDelegate)? = nil) -> URLSession {
        // .ephemeral goes through the swizzled getter, like any app session
        URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }

    @Test("P0-1: a streamed POST body arrives and the request does not time out", .timeLimit(.minutes(1)))
    func streamedPostBody() async throws {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        let body = Data((0..<50_000).map { UInt8(truncatingIfNeeded: $0 &* 7) })
        var request = URLRequest(url: server.url("/echo?case=stream"))
        request.httpMethod = "POST"
        request.httpBodyStream = InputStream(data: body)
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data == body, "the server must receive the whole streamed body")
        let records = await collector.wait(query: "case=stream") { !$0.isEmpty }
        let record = try #require(records.first)
        #expect(record.requestBody.length == body.count)
        #expect(record.requestBody.isStored)
        let stored = await NFXStorage.shared.body(for: record.id, part: .request)
        #expect(stored == body)
    }

    @Test("P0-2: a 302 gives exactly one 3xx record plus the 200")
    func redirectRecords() async throws {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.data(from: server.url("/redirect?case=redirect"))

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
        #expect(http.url?.path == "/ok")
        #expect(String(decoding: data, as: UTF8.self) == "hello")

        await collector.wait(query: "case=redirect") { $0.count >= 2 && $0.allSatisfy { $0.metrics != nil } }
        try await Task.sleep(for: .milliseconds(500)) // a phantom record would show up by now
        let records = collector.records(query: "case=redirect")
        #expect(records.count == 2)
        let hop = try #require(records.first { $0.statusCode == 302 })
        #expect(hop.url?.path == "/redirect")
        #expect(hop.redirectURL?.path == "/ok")
        #expect(hop.responseHeaders.value(for: "location") == "/ok?case=redirect")
        #expect(hop.error == nil)
        let final = try #require(records.first { $0.statusCode == 200 })
        #expect(final.url?.path == "/ok")
        #expect(final.error == nil)
    }

    @Test("Redirect refused by the app's delegate: the task ends right away and only the 3xx is recorded", .timeLimit(.minutes(1)))
    func redirectRefusedByApp() async throws {
        let delegate = RefuseRedirectDelegate()
        let session = makeSession(delegate: delegate)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: server.url("/redirect?case=refused"))
        request.timeoutInterval = 10
        let clock = ContinuousClock()
        let started = clock.now

        // CustomHTTPProtocol pattern: a refused redirect ends with NSUserCancelledError
        // (documented limitation) instead of waiting for the request timeout.
        let outcome: Result<Int, NSError>
        do {
            let (_, response) = try await session.data(for: request)
            outcome = .success((response as? HTTPURLResponse)?.statusCode ?? -1)
        } catch {
            outcome = .failure(error as NSError)
        }

        #expect(clock.now - started < .seconds(5))
        switch outcome {
        case .success(let status):
            #expect(status == 302)
        case .failure(let error):
            #expect(error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError)
        }
        await collector.wait(query: "case=refused") { !$0.isEmpty }
        try await Task.sleep(for: .milliseconds(300))
        let records = collector.records(query: "case=refused")
        #expect(records.count == 1)
        #expect(records.first?.statusCode == 302)
    }

    @Test("P0-3: a binary body's length is recorded and its bytes stored")
    func binaryBody() async throws {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }

        let (data, _) = try await session.data(from: server.url("/binary?case=binary"))

        #expect(data == LoopbackServer.binaryBody)
        let records = await collector.wait(query: "case=binary") { !$0.isEmpty }
        let record = try #require(records.first)
        #expect(record.responseBody.length == 1024)
        #expect(record.responseBody.isStored)
        #expect(record.responseBody.isTruncated == false)
        let stored = await NFXStorage.shared.body(for: record.id, part: .response)
        #expect(stored == LoopbackServer.binaryBody)
    }

    @Test("P1-6: an HTTP Basic challenge gets default handling: the 401 arrives at once instead of hanging", .timeLimit(.minutes(1)))
    func basicAuthDoesNotHang() async throws {
        // Verified: for HTTP authentication the app's session asks its delegate but never sends the
        // answer back to a URLProtocol's challenge sender, so netfox does not forward these challenges
        // (server trust and client certificates are forwarded). Documented limitation.
        let delegate = BasicAuthDelegate()
        let session = makeSession(delegate: delegate)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: server.url("/basic?case=basic"))
        request.timeoutInterval = 10
        let clock = ContinuousClock()
        let started = clock.now

        let (data, response) = try await session.data(for: request)

        #expect(clock.now - started < .seconds(5))
        #expect((response as? HTTPURLResponse)?.statusCode == 401)
        #expect(String(decoding: data, as: UTF8.self) == "denied")
        let records = await collector.wait(query: "case=basic") { !$0.isEmpty }
        #expect(records.first?.statusCode == 401)
    }

    @Test("P1-6: URL credentials still authenticate through netfox")
    func basicAuthWithURLCredentials() async throws {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        let user = LoopbackServer.basicUser
        let password = LoopbackServer.basicPassword
        let url = try #require(URL(string: "http://\(user):\(password)@127.0.0.1:\(server.port)/basic?case=basic-url"))

        let (data, response) = try await session.data(from: url)

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(String(decoding: data, as: UTF8.self) == "authorized")
    }

    @Test("P2-4: URLSessionTaskMetrics are attached to the record")
    func metricsAttached() async throws {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }

        _ = try await session.data(from: server.url("/ok?case=metrics"))

        let records = await collector.wait(query: "case=metrics") { $0.first?.metrics != nil }
        let record = try #require(records.first)
        let metrics = try #require(record.metrics)
        let transaction = try #require(metrics.finalTransaction)
        #expect(transaction.networkProtocolName == "http/1.1")
        #expect(transaction.httpVersion == "HTTP/1.1")
        #expect(transaction.remoteAddress == "127.0.0.1")
        #expect(transaction.fetchType == .network)
        #expect(collector.publishCount(of: record.id) <= 2, "duplicate metrics must not publish more updates")

        let timings = NFXHARExporter.timings(for: record, transaction: transaction)
        #expect(timings.send >= 0 && timings.wait >= 0 && timings.receive >= 0)
    }

    @Test("Ignore prefix and regex skip requests; an invalid regex does not crash")
    func ignoreRules() async throws {
        let settings = NFXInterceptionSettings.shared
        settings.addIgnoredPrefixes([server.url("/ok?case=ignored-prefix").absoluteString])
        let invalid = settings.addIgnoredPatterns([#"case=ignored-regex$"#, "*.example.com"])
        #expect(invalid == ["*.example.com"])
        #expect(settings.ignoredPatterns == [#"case=ignored-regex$"#])
        defer { InterceptionFixture.activate() }

        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        for query in ["case=ignored-prefix", "case=ignored-regex", "case=not-ignored"] {
            let (data, _) = try await session.data(from: server.url("/ok?\(query)"))
            #expect(String(decoding: data, as: UTF8.self) == "hello")
        }

        await collector.wait(query: "case=not-ignored") { !$0.isEmpty }
        try await Task.sleep(for: .milliseconds(300))
        #expect(collector.records(query: "case=not-ignored").count == 1)
        #expect(collector.records(query: "case=ignored-prefix").isEmpty)
        #expect(collector.records(query: "case=ignored-regex").isEmpty)
    }

    @Test("P1-7: cookie handling stays on netfox's internal session (documented limitation)")
    func cookieBehaviour() async throws {
        // Checked before deciding the fix: (a) the request NFXProtocol receives does NOT carry
        // the app session's Cookie header, and (b) a Set-Cookie delivered through the protocol
        // client does NOT reach the app session's cookie storage. Turning cookies off on the
        // internal session would therefore drop cookies entirely, so 3.x behaviour stays: the
        // internal session uses HTTPCookieStorage.shared. If this test starts failing, the URL
        // loading system changed and the internal session can stop handling cookies.
        let configuration = URLSessionConfiguration.ephemeral
        let jar = try #require(configuration.httpCookieStorage)
        let outerCookie = try #require(HTTPCookie(properties: [
            .domain: "127.0.0.1", .path: "/", .name: "nfxouter", .value: "1",
        ]))
        jar.setCookie(outerCookie)
        let session = URLSession(configuration: configuration)
        let base = server.url("/")
        defer {
            session.finishTasksAndInvalidate()
            HTTPCookieStorage.shared.cookies(for: base)?
                .filter { $0.name == "nfxserver" || $0.name == "nfxouter" }
                .forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }

        _ = try await session.data(from: server.url("/cookie?case=cookie-a"))
        let records = await collector.wait(query: "case=cookie-a") { !$0.isEmpty }
        #expect(records.first?.requestHeaders.value(for: "Cookie") == nil, "(a) NFXProtocol got the app's Cookie header")

        _ = try await session.data(from: server.url("/setcookie?case=cookie-b"))
        let inAppJar = jar.cookies(for: base)?.contains { $0.name == "nfxserver" } ?? false
        #expect(!inAppJar, "(b) Set-Cookie reached the app session's storage")
    }

    @Test("Five sequential requests reuse one connection (one shared internal session)")
    func connectionReuse() async throws {
        let session = makeSession()
        defer { session.finishTasksAndInvalidate() }
        for index in 0..<5 {
            _ = try await session.data(from: server.url("/ok?case=reuse-\(index)"))
        }
        let connections = Set(server.hits.filter { $0.query?.hasPrefix("case=reuse-") == true }.map(\.connectionID))
        #expect(connections.count == 1)
    }
}

// MARK: - Delegates

/// Answers HTTP Basic in the task-level challenge method only (P1-6).
final class BasicAuthDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let count = OSAllocatedUnfairLockBox(0)

    var challengeCount: Int { count.value }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        count.update { $0 += 1 }
        let credential = URLCredential(user: LoopbackServer.basicUser, password: LoopbackServer.basicPassword, persistence: .none)
        completionHandler(.useCredential, credential)
    }
}

/// Refuses every redirect, so the 3xx response becomes the task's final response.
final class RefuseRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

/// A tiny lock-protected value for test delegates.
final class OSAllocatedUnfairLockBox<Value: Sendable>: Sendable {
    private let lock: OSAllocatedUnfairLock<Value>

    init(_ value: Value) {
        lock = OSAllocatedUnfairLock(initialState: value)
    }

    var value: Value { lock.withLock { $0 } }

    func update(_ body: @Sendable (inout Value) -> Void) {
        lock.withLock { body(&$0) }
    }
}
