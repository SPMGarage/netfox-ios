//
//  TestSupport.swift
//  NetfoxCoreTests
//

import Foundation
@testable import NetfoxCore
import os

/// Collects every record the hub publishes (latest value per id).
final class RecordCollector: Sendable {

    private struct State: Sendable {
        var order: [UUID] = []
        var latest: [UUID: NFXRecord] = [:]
        var publishCount: [UUID: Int] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let subscription: NFXRecordSubscription

    init(hub: NFXRecordHub = .shared) {
        let state = self.state
        subscription = hub.subscribe { record in
            state.withLock { state in
                if state.latest[record.id] == nil {
                    state.order.append(record.id)
                }
                state.latest[record.id] = record
                state.publishCount[record.id, default: 0] += 1
            }
        }
    }

    deinit {
        subscription.cancel()
    }

    /// Latest value of every record whose URL query equals `query`, in publication order.
    func records(query: String) -> [NFXRecord] {
        state.withLock { state in
            state.order.compactMap { state.latest[$0] }.filter { $0.url?.query == query }
        }
    }

    /// How many times a record id was published (1 + updates).
    func publishCount(of id: UUID) -> Int {
        state.withLock { $0.publishCount[id] ?? 0 }
    }

    /// Waits until `condition` holds for the records of `query`.
    @discardableResult
    func wait(
        query: String,
        timeout: Duration = .seconds(10),
        until condition: @escaping @Sendable ([NFXRecord]) -> Bool
    ) async -> [NFXRecord] {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            let current = records(query: query)
            if condition(current) { return current }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return records(query: query)
    }
}

/// Starts interception once per test process and restores default settings.
enum InterceptionFixture {

    private static let started: Void = {
        NFXInterception.start()
    }()

    /// Ensures interception is on, with no ignore rules.
    static func activate() {
        _ = started
        let settings = NFXInterceptionSettings.shared
        settings.reset()
        settings.isEnabled = true
    }
}
