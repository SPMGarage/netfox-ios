//
//  NFXWebSocketStore.swift
//  netfox
//
//  B8 / P1-13: WebSocket message log. URLProtocol cannot see WebSocket frames,
//  so apps log them through NFX.logWebSocketText/Data/Ping (any thread).
//

import Foundation
import Observation

/// One logged WebSocket message.
package nonisolated struct NFXWebSocketMessage: Identifiable, Sendable, Hashable {

    package enum Kind: String, Sendable, Hashable {
        case text = "Text"
        case binary = "Binary"
        case ping = "Ping"
    }

    /// Longer text messages are cut to this many characters.
    package static let textLimit = 64 * 1024

    package let id: UUID
    package let date: Date
    package let direction: NFXWebSocketDirection
    package let kind: Kind
    /// The text (cut to ``textLimit``), "[N bytes]" for binary data, or "PING".
    package let content: String
    /// Size of the original payload in bytes.
    package let byteCount: Int

    package init(id: UUID = UUID(), date: Date = Date(), direction: NFXWebSocketDirection, kind: Kind, content: String, byteCount: Int) {
        self.id = id
        self.date = date
        self.direction = direction
        self.kind = kind
        self.content = content
        self.byteCount = byteCount
    }

    static func text(_ text: String, direction: NFXWebSocketDirection) -> NFXWebSocketMessage {
        NFXWebSocketMessage(
            direction: direction,
            kind: .text,
            content: text.count > textLimit ? String(text.prefix(textLimit)) + "…" : text,
            byteCount: text.utf8.count
        )
    }

    static func binary(_ data: Data, direction: NFXWebSocketDirection) -> NFXWebSocketMessage {
        NFXWebSocketMessage(direction: direction, kind: .binary, content: "[\(data.count) bytes]", byteCount: data.count)
    }

    static func ping(direction: NFXWebSocketDirection) -> NFXWebSocketMessage {
        NFXWebSocketMessage(direction: direction, kind: .ping, content: "PING", byteCount: 0)
    }
}

/// The messages of one WebSocket URL, newest first.
package nonisolated struct NFXWebSocketConnection: Identifiable, Sendable, Hashable {
    package var id: URL { url }
    package let url: URL
    package var messages: [NFXWebSocketMessage]
}

/// Logged WebSocket messages, grouped by URL.
@Observable
@MainActor
package final class NFXWebSocketStore {

    /// The store the inspector shows.
    package static let shared = NFXWebSocketStore()

    /// The default number of messages kept per connection; older ones are dropped.
    package static let defaultMessageLimit = 500

    /// Connections sorted by URL; each holds its messages newest first.
    package private(set) var connections: [NFXWebSocketConnection] = []

    @ObservationIgnored package let messageLimit: Int

    package init(messageLimit: Int = NFXWebSocketStore.defaultMessageLimit) {
        self.messageLimit = messageLimit
    }

    /// Adds a message to the connection of `url`.
    package func append(_ message: NFXWebSocketMessage, for url: URL) {
        if let index = connections.firstIndex(where: { $0.url == url }) {
            connections[index].messages.insert(message, at: 0)
            if connections[index].messages.count > messageLimit {
                connections[index].messages.removeLast(connections[index].messages.count - messageLimit)
            }
        } else {
            connections.append(NFXWebSocketConnection(url: url, messages: [message]))
            connections.sort { $0.url.absoluteString < $1.url.absoluteString }
        }
    }

    /// Removes every message.
    package func clear() {
        connections.removeAll()
    }
}
