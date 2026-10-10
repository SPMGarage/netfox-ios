//
//  NFXReplay.swift
//  netfox
//
//  B5 / P1-11: replays a captured request with its raw body bytes through
//  URLSession.shared, so netfox captures the replay as a new row.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// The outcome of one replay.
nonisolated struct NFXReplayResult: Equatable, Sendable {
    let url: URL
    let method: String
    let startedAt: Date
    let statusCode: Int?
    let byteCount: Int
    let duration: TimeInterval
    let errorMessage: String?
}

/// Replay progress shown on the Info tab.
nonisolated enum NFXReplayState: Equatable, Sendable {
    case idle
    case running
    case finished(NFXReplayResult)
}

/// Rebuilds and sends captured requests.
enum NFXReplay {

    /// URLSession sets these itself; copying them could make the replay invalid.
    private static let skippedHeaders: Set<String> = ["content-length", "host"]

    /// False when the URL is missing or the request body was not captured completely.
    static func canReplay(_ record: NFXRecord) -> Bool {
        guard record.url != nil else { return false }
        let body = record.requestBody
        guard !body.isTruncated, let length = body.length else { return false }
        return length == 0 || body.isStored
    }

    /// The captured request: method, headers (without Content-Length and Host) and raw body bytes.
    static func makeRequest(for record: NFXRecord, body: Data?) -> URLRequest? {
        guard let url = record.url else { return nil }
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: record.timeoutInterval > 0 ? record.timeoutInterval : 60
        )
        request.httpMethod = record.method
        for header in record.requestHeaders where !skippedHeaders.contains(header.name.lowercased()) {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        request.httpBody = body
        return request
    }

    /// Sends the replay. Not marked internal, so it shows up in the list like any request.
    static func send(_ record: NFXRecord, body: Data?) async -> NFXReplayState {
        guard let request = makeRequest(for: record, body: body), let url = request.url else {
            return .idle
        }
        let startedAt = Date.now
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return .finished(NFXReplayResult(
                url: url,
                method: record.method,
                startedAt: startedAt,
                statusCode: (response as? HTTPURLResponse)?.statusCode,
                byteCount: data.count,
                duration: Date.now.timeIntervalSince(startedAt),
                errorMessage: nil
            ))
        } catch {
            return .finished(NFXReplayResult(
                url: url,
                method: record.method,
                startedAt: startedAt,
                statusCode: nil,
                byteCount: 0,
                duration: Date.now.timeIntervalSince(startedAt),
                errorMessage: error.localizedDescription
            ))
        }
    }
}

/// B5: the replay result, inline at the top of the Info tab.
struct NFXReplaySection: View {
    let state: NFXReplayState
    let originalID: UUID
    let openCaptured: (UUID) -> Void

    @Environment(NFXRequestStore.self) private var store

    var body: some View {
        switch state {
        case .idle:
            EmptyView()
        case .running:
            Section("Replay") {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Replaying\u{2026}")
                }
            }
        case .finished(let result):
            Section("Replay") {
                if let message = result.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.nfxRed)
                } else {
                    NFXValueRow(title: "Status", value: result.statusCode.map(NFXFormat.status) ?? "-")
                    NFXValueRow(title: "Duration", value: NFXFormat.duration(result.duration))
                    NFXValueRow(title: "Size", value: NFXFormat.bytes(result.byteCount))
                }
                if let captured = capturedRecord(for: result) {
                    Button("Show Captured Replay", systemImage: "arrow.right.circle") {
                        openCaptured(captured.id)
                    }
                }
            }
        }
    }

    /// The row netfox captured for the replay (newest first, so the latest replay wins).
    private func capturedRecord(for result: NFXReplayResult) -> NFXRecord? {
        store.records.first { record in
            record.id != originalID
                && record.method == result.method
                && record.url == result.url
                && record.startDate >= result.startedAt
        }
    }
}
#endif
