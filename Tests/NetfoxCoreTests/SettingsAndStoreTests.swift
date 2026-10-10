//
//  SettingsAndStoreTests.swift
//  NetfoxCoreTests
//
//  P1-2: the settings lock under concurrent access; P2-2: the request store.
//

import Foundation
@testable import netfox
@testable import NetfoxCore
import Testing

@Suite("Interception settings")
struct SettingsTests {

    @Test("concurrent reads and writes from many threads stay consistent")
    func concurrentAccess() throws {
        let settings = NFXInterceptionSettings()
        let url = try #require(URL(string: "https://api.example.com/v1/items"))
        DispatchQueue.concurrentPerform(iterations: 1_000) { index in
            settings.addIgnoredPrefixes(["https://ignored-\(index).example.com"])
            if index.isMultiple(of: 10) {
                settings.addIgnoredPatterns(["^https://regex-\(index)\\.example\\.com"])
            }
            settings.isEnabled = index.isMultiple(of: 2)
            settings.isConsoleLoggingEnabled.toggle()
            settings.cachePolicy = index.isMultiple(of: 3) ? .allowed : .notAllowed
            _ = settings.shouldIgnore(url)
            _ = settings.isCertificateInfoEnabled
        }
        #expect(settings.ignoredPrefixes.count == 1_000)
        #expect(settings.ignoredPatterns.count == 100)
        #expect(Set(settings.ignoredPrefixes).count == 1_000)
        #expect(settings.shouldIgnore(try #require(URL(string: "https://ignored-999.example.com/a"))))
        #expect(settings.shouldIgnore(try #require(URL(string: "https://regex-990.example.com/a"))))
        #expect(!settings.shouldIgnore(url))
    }

    @Test("an invalid regex is reported and skipped")
    func invalidRegex() {
        let settings = NFXInterceptionSettings()
        let invalid = settings.addIgnoredPatterns(["*.example.com", "(unclosed", "^ok$"])
        #expect(invalid == ["*.example.com", "(unclosed"])
        #expect(settings.ignoredPatterns == ["^ok$"])
    }
}

@Suite("Request store")
@MainActor
struct RequestStoreTests {

    private func record(_ index: Int, status: Int = 200, type: String = "application/json") -> NFXRecord {
        NFXRecord(
            url: URL(string: "https://host\(index % 3).example.com/items/\(index)"),
            method: index.isMultiple(of: 2) ? "GET" : "POST",
            startDate: Date(timeIntervalSince1970: TimeInterval(index)),
            endDate: Date(timeIntervalSince1970: TimeInterval(index) + 0.5),
            statusCode: status,
            responseHeaders: [NFXHeader(name: "Content-Type", value: type)]
        )
    }

    private func makeStore(limit: Int) -> NFXRequestStore {
        let directory = URL.temporaryDirectory.appending(path: "netfox-tests-\(UUID().uuidString)")
        return NFXRequestStore(settings: NFXInterceptionSettings(), storage: NFXStorage(directoryURL: directory), recordLimit: limit)
    }

    @Test("newest first, updates replace in place, the cap keeps pinned records")
    func capKeepsPinned() {
        let store = makeStore(limit: 5)
        let records = (0..<5).map { record($0) }
        records.forEach(store.apply)
        #expect(store.records.map(\.id) == records.reversed().map(\.id))

        store.togglePin(records[0].id) // the oldest
        store.apply(record(5))
        store.apply(record(6))
        #expect(store.records.count == 5)
        #expect(store.records.contains { $0.id == records[0].id }, "pinned record must survive the cap")
        #expect(!store.records.contains { $0.id == records[1].id })
        #expect(!store.records.contains { $0.id == records[2].id })

        let updated = store.records[0].withMetrics(NFXRequestMetrics(taskInterval: DateInterval(), transactions: []))
        store.apply(updated)
        #expect(store.records.count == 5)
        #expect(store.records[0].metrics != nil)
        #expect(store.insertionCount == 7)
    }

    @Test("type, status and search filters combine")
    func filters() async {
        let directory = URL.temporaryDirectory.appending(path: "netfox-tests-\(UUID().uuidString)")
        let storage = NFXStorage(directoryURL: directory)
        let store = NFXRequestStore(settings: NFXInterceptionSettings(), storage: storage, recordLimit: 100)
        store.apply(record(1, status: 200, type: "application/json"))
        store.apply(record(2, status: 404, type: "text/html"))
        store.apply(record(3, status: 500, type: "image/png"))
        store.apply(NFXRecord(url: URL(string: "https://offline.invalid"), method: "GET", error: NFXRecordError(domain: "x", code: 1, message: "")))

        store.statusFilter = .clientError
        #expect(store.filteredRecords.map(\.statusCode) == [nil, 404])

        store.statusFilter = .all
        store.enabledKinds = [.image]
        #expect(store.filteredRecords.map(\.statusCode) == [500])

        store.enabledKinds = Set(NFXContentKind.allCases)
        store.searchText = "items/2"
        #expect(store.filteredRecords.map(\.statusCode) == [404])

        store.searchText = ""
        store.clear()
        #expect(store.records.isEmpty && store.pinnedIDs.isEmpty)
        // clear() recreates the storage folder; remove it so the test leaves nothing behind
        await storage.flush()
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("toggles read by the interception path write through to the settings")
    func writeThrough() {
        let settings = NFXInterceptionSettings()
        let store = NFXRequestStore(settings: settings, storage: NFXStorage(directoryURL: URL.temporaryDirectory.appending(path: "netfox-tests-\(UUID().uuidString)")))
        store.isConsoleLoggingEnabled = true
        store.isCertificateInfoEnabled = false
        store.isInterceptionEnabled = true
        #expect(settings.isConsoleLoggingEnabled)
        #expect(!settings.isCertificateInfoEnabled)
        #expect(settings.isEnabled)
    }

    @Test("the WebSocket store caps messages per connection")
    func webSocketCap() throws {
        let store = NFXWebSocketStore(messageLimit: 3)
        let url = try #require(URL(string: "wss://echo.example.com/socket"))
        for index in 0..<5 {
            store.append(.text("message \(index)", direction: index.isMultiple(of: 2) ? .sent : .received), for: url)
        }
        store.append(.ping(direction: .sent), for: try #require(URL(string: "wss://a.example.com")))
        #expect(store.connections.count == 2)
        let echo = try #require(store.connections.first { $0.url == url })
        #expect(echo.messages.map(\.content) == ["message 4", "message 3", "message 2"])
    }
}

@Suite("NFX facade")
struct FacadeTests {

    @Test("thread-safe entry points do not trap off the main thread")
    func offMainCalls() async {
        await Task.detached {
            let nfx = NFX.sharedInstance()
            #expect(NFX.version == "4.0.0")
            nfx.setGesture(.custom)
            nfx.setCachePolicy(.notAllowed)
            nfx.ignoreURLsWithRegex("*.example.com") // invalid: logged and skipped
            nfx.hide()
            nfx.show() // not started: no-op
            nfx.logWebSocketText("hello", direction: .sent, url: URL(fileURLWithPath: "/ws"))
            _ = nfx.isStarted()
            _ = nfx.getSessionLog()
        }.value
    }
}
