//
//  NFXWebSocketLogger.swift
//  netfox
//
//  B8: WebSocket message logging.
//  Since URLProtocol cannot intercept WebSocket frames, this provides
//  a manual logging API for developers to capture WS messages.
//  Messages are stored in-memory and displayed in the request list
//  with a "WS" badge.
//

#if os(iOS)

import Foundation

// MARK: - WebSocket Message Model

enum WSMessageDirection: String {
    case sent = "Sent"
    case received = "Received"
}

enum WSMessageType: String {
    case text = "Text"
    case binary = "Binary"
    case ping = "Ping"
    case pong = "Pong"
}

struct NFXWebSocketMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let direction: WSMessageDirection
    let type: WSMessageType
    let content: String
    let dataSize: Int
}

// MARK: - WebSocket Logger

final class NFXWebSocketLogger: ObservableObject {
    static let shared = NFXWebSocketLogger()

    @Published private(set) var connections = [String: [NFXWebSocketMessage]]()

    /// Log a text message
    func logText(_ text: String, direction: WSMessageDirection, url: String) {
        let message = NFXWebSocketMessage(
            timestamp: Date(),
            direction: direction,
            type: .text,
            content: text,
            dataSize: text.utf8.count
        )
        appendMessage(message, for: url)
    }

    /// Log a binary message
    func logData(_ data: Data, direction: WSMessageDirection, url: String) {
        let content = "[\(data.count) bytes]"
        let message = NFXWebSocketMessage(
            timestamp: Date(),
            direction: direction,
            type: .binary,
            content: content,
            dataSize: data.count
        )
        appendMessage(message, for: url)
    }

    /// Log a ping/pong
    func logPing(direction: WSMessageDirection, url: String) {
        let message = NFXWebSocketMessage(
            timestamp: Date(),
            direction: direction,
            type: .ping,
            content: "PING",
            dataSize: 0
        )
        appendMessage(message, for: url)
    }

    func clear() {
        connections.removeAll()
    }

    private func appendMessage(_ message: NFXWebSocketMessage, for url: String) {
        if connections[url] == nil {
            connections[url] = []
        }
        connections[url]?.insert(message, at: 0)
    }
}

#endif
