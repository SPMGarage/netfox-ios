//
//  NFXWebSocketView.swift
//  netfox
//
//  B8: Displays logged WebSocket messages grouped by connection URL.
//

#if os(iOS)

import SwiftUI

struct NFXWebSocketView: View {
    @ObservedObject private var logger = NFXWebSocketLogger.shared

    var body: some View {
        Group {
            if logger.connections.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No WebSocket Messages")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Use NFXWebSocketLogger.shared to log messages")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(logger.connections.keys.sorted()), id: \.self) { url in
                        Section(header: Text(url).lineLimit(1)) {
                            if let messages = logger.connections[url] {
                                ForEach(messages) { message in
                                    wsMessageRow(message)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("WebSocket")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func wsMessageRow(_ message: NFXWebSocketMessage) -> some View {
        HStack(spacing: 8) {
            // Direction arrow
            Image(systemName: message.direction == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(message.direction == .sent ? Color(UIColor.NFXOrangeColor()) : Color(UIColor.NFXGreenColor()))
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.type.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }

                Text(message.content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

#endif
