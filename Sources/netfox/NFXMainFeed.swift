//
//  NFXMainFeed.swift
//  netfox
//
//  Moves events from background threads to the main-actor stores, in order.
//  One AsyncStream keeps FIFO order across records, resets and WebSocket logs,
//  which separate Task { @MainActor } hops would not guarantee.
//

import Foundation
import NetfoxCore

nonisolated enum NFXMainFeed {

    enum Event: Sendable {
        /// A new record, or a newer value of a known record.
        case record(NFXRecord)
        /// start() / stop(): drop the records of the previous run.
        case resetRecords
        /// B8: a logged WebSocket message.
        case webSocket(NFXWebSocketMessage, URL)
    }

    private static let continuation: AsyncStream<Event>.Continuation = {
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        Task { @MainActor in
            for await event in stream {
                apply(event)
            }
        }
        return continuation
    }()

    private static let recordSubscription: NFXRecordSubscription = NFXRecordHub.shared.subscribe { record in
        continuation.yield(.record(record))
    }

    /// Subscribes the stores to captured records. Safe to call more than once.
    static func connect() {
        _ = recordSubscription
    }

    /// Queues an event for the main actor. Callable from any thread.
    static func send(_ event: Event) {
        continuation.yield(event)
    }

    @MainActor
    private static func apply(_ event: Event) {
        switch event {
        case .record(let record):
            NFXRequestStore.shared.apply(record)
        case .resetRecords:
            NFXRequestStore.shared.removeAllRecords()
        case .webSocket(let message, let url):
            NFXWebSocketStore.shared.append(message, for: url)
        }
    }
}
