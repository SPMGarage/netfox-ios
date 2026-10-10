//
//  NFXRecordHub.swift
//  netfox
//
//  Fan-out of captured records to the UI store (and to tests).
//

import Foundation
import os

/// Delivers every captured record to its subscribers.
///
/// Records are published on netfox's storage queue, after their bodies are on
/// disk, in capture order. A record can be published more than once with the
/// same id: later values replace earlier ones (for example when metrics
/// arrive after the response).
package final class NFXRecordHub: Sendable {

    package typealias Handler = @Sendable (NFXRecord) -> Void

    /// The hub the interception path publishes to.
    package static let shared = NFXRecordHub()

    private let handlers = OSAllocatedUnfairLock(initialState: [UUID: Handler]())

    package init() {}

    /// Registers a handler. It is called on a background queue, in publication order.
    ///
    /// - Returns: a subscription; call ``NFXRecordSubscription/cancel()`` to stop receiving records.
    @discardableResult
    package func subscribe(_ handler: @escaping Handler) -> NFXRecordSubscription {
        let id = UUID()
        handlers.withLock { $0[id] = handler }
        return NFXRecordSubscription(id: id, hub: self)
    }

    func unsubscribe(_ id: UUID) {
        handlers.withLock { _ = $0.removeValue(forKey: id) }
    }

    /// Sends a record to every subscriber.
    package func publish(_ record: NFXRecord) {
        let current = handlers.withLock { Array($0.values) }
        for handler in current {
            handler(record)
        }
    }
}

/// Keeps a ``NFXRecordHub`` subscription alive until cancelled.
package final class NFXRecordSubscription: Sendable {
    private let id: UUID
    private let hub: NFXRecordHub

    init(id: UUID, hub: NFXRecordHub) {
        self.id = id
        self.hub = hub
    }

    /// Stops delivery to this subscription's handler.
    package func cancel() {
        hub.unsubscribe(id)
    }
}
