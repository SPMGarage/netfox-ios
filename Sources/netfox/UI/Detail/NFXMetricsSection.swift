//
//  NFXMetricsSection.swift
//  netfox
//
//  B7: the URLSessionTaskMetrics timeline of the final transaction.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// One phase of a transaction, e.g. "DNS Lookup".
nonisolated struct NFXTimingPhase: Identifiable, Sendable {
    let title: String
    let duration: TimeInterval
    let color: Color

    var id: String { title }

    /// The phases that happened, in order. Connect excludes the TLS handshake, which has its own row.
    static func phases(of transaction: NFXRequestMetrics.Transaction) -> [NFXTimingPhase] {
        let tls = transaction.tlsDuration
        let connect = transaction.connectDuration.map { max(0, $0 - (tls ?? 0)) }
        let phases: [NFXTimingPhase?] = [
            phase("Blocked", transaction.blockedDuration, .gray),
            phase("DNS Lookup", transaction.dnsDuration, .teal),
            phase("Connect", connect, .orange),
            phase("TLS Handshake", tls, .purple),
            phase("Request Sent", transaction.sendDuration, .green),
            phase("Waiting (TTFB)", transaction.waitDuration, .yellow),
            phase("Response Received", transaction.receiveDuration, .blue)
        ]
        return phases.compactMap { $0 }
    }

    /// A phase, or nil when it did not happen.
    private static func phase(_ title: String, _ duration: TimeInterval?, _ color: Color) -> NFXTimingPhase? {
        duration.map { NFXTimingPhase(title: title, duration: $0, color: color) }
    }
}

struct NFXMetricsSection: View {
    let metrics: NFXRequestMetrics

    var body: some View {
        Section("Timeline") {
            if let transaction = metrics.finalTransaction {
                let phases = NFXTimingPhase.phases(of: transaction)
                if !phases.isEmpty {
                    NFXTimelineBar(phases: phases)
                }
                ForEach(phases) { phase in
                    LabeledContent {
                        Text(NFXFormat.duration(phase.duration))
                            .monospacedDigit()
                    } label: {
                        Label {
                            Text(phase.title)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .imageScale(.small)
                                .foregroundStyle(phase.color)
                        }
                    }
                }
                NFXValueRow(title: "Total", value: NFXFormat.duration(metrics.totalDuration))
                connectionRows(transaction)
            } else {
                NFXValueRow(title: "Total", value: NFXFormat.duration(metrics.totalDuration))
            }
        }
    }

    @ViewBuilder
    private func connectionRows(_ transaction: NFXRequestMetrics.Transaction) -> some View {
        NFXValueRow(title: "Protocol", value: transaction.httpVersion)
        if let address = transaction.remoteAddress {
            let port = transaction.remotePort.map { ":\($0)" } ?? ""
            NFXValueRow(title: "Remote Address", value: address + port, isMonospaced: true)
        }
        if let tlsVersion = transaction.tlsProtocolVersion {
            NFXValueRow(title: "TLS Version", value: tlsVersion)
        }
        NFXValueRow(title: "Connection", value: transaction.isReusedConnection ? "Reused" : "New")
        if transaction.fetchType == .localCache {
            NFXValueRow(title: "Source", value: "Local cache")
        }
        if metrics.redirectCount > 0 {
            NFXValueRow(title: "Redirects", value: metrics.redirectCount.formatted())
        }
    }
}

/// The phases as one proportional bar (the rows below carry the numbers for VoiceOver).
struct NFXTimelineBar: View {
    let phases: [NFXTimingPhase]

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 12
    private let minimumSegmentWidth: CGFloat = 2

    var body: some View {
        let total = max(phases.reduce(0) { $0 + $1.duration }, .leastNonzeroMagnitude)
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(phases) { phase in
                    Rectangle()
                        .fill(phase.color)
                        .frame(width: max(minimumSegmentWidth, proxy.size.width * phase.duration / total))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}
#endif
