//
//  NFXWebSocketView.swift
//  netfox
//
//  B8: logged WebSocket messages, grouped by connection URL.
//

#if os(iOS)
import SwiftUI
import UIKit

struct NFXWebSocketView: View {
    @Environment(NFXWebSocketStore.self) private var store

    var body: some View {
        List {
            ForEach(store.connections) { connection in
                Section {
                    ForEach(connection.messages) { message in
                        NFXWebSocketMessageRow(message: message)
                    }
                } header: {
                    Text(connection.url.absoluteString)
                        .textCase(nil)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } footer: {
                    Text("\(connection.messages.count) messages")
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if store.connections.isEmpty {
                ContentUnavailableView {
                    Label("No WebSocket Messages", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text(
                        "URLProtocol can't see WebSocket frames. "
                            + "Log them from your app with NFX.shared.logWebSocketText(_:direction:url:)."
                    )
                }
            }
        }
        .navigationTitle("WebSocket")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NFXWebSocketMessageRow: View {
    let message: NFXWebSocketMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.direction == .sent ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(message.direction == .sent ? Color.nfxOrange : Color.nfxGreen)
                .accessibilityLabel(message.direction == .sent ? "Sent" : "Received")
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(message.kind.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(NFXFormat.bytes(message.byteCount))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(message.date.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3))))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(message.content)
                    .font(.footnote.monospaced())
                    .lineLimit(4)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button("Copy Message", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = message.content
            }
        }
    }
}
#endif
