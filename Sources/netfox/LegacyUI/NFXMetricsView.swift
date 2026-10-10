//
//  NFXMetricsView.swift
//  netfox
//
//  B7: Display URLSessionTaskMetrics timing breakdown.
//  Shows DNS, TLS, connect, request, response timings as a visual timeline.
//

#if os(iOS)

import SwiftUI

struct NFXMetricsView: View {
    let metrics: NFXRequestMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request Timeline")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            // Visual timeline bar
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                timelineBar(totalWidth: totalWidth)
            }
            .frame(height: 24)

            // Detailed timings
            VStack(alignment: .leading, spacing: 6) {
                timingRow(label: "DNS Lookup", duration: metrics.dnsLookupDuration, color: .blue)
                timingRow(label: "TLS Handshake", duration: metrics.tlsHandshakeDuration, color: .purple)
                timingRow(label: "Connect", duration: metrics.connectDuration, color: .orange)
                timingRow(label: "Request Sent", duration: metrics.requestDuration, color: Color(UIColor.NFXGreenColor()))
                timingRow(label: "Waiting (TTFB)", duration: metrics.waitingDuration, color: .gray)
                timingRow(label: "Response Received", duration: metrics.responseDuration, color: Color(UIColor.NFXOrangeColor()))

                Divider()

                timingRow(label: "Total", duration: metrics.totalDuration, color: .primary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Timeline Bar

    @ViewBuilder
    private func timelineBar(totalWidth: CGFloat) -> some View {
        let total = max(metrics.totalDuration, 0.001) // avoid division by zero
        let segments: [(Color, TimeInterval)] = [
            (.blue, metrics.dnsLookupDuration),
            (.purple, metrics.tlsHandshakeDuration),
            (.orange, metrics.connectDuration),
            (Color(UIColor.NFXGreenColor()), metrics.requestDuration),
            (.gray, metrics.waitingDuration),
            (Color(UIColor.NFXOrangeColor()), metrics.responseDuration),
        ]

        HStack(spacing: 1) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                let fraction = CGFloat(segment.1 / total)
                if fraction > 0.005 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(segment.0)
                        .frame(width: max(2, totalWidth * fraction))
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Timing Row

    private func timingRow(label: String, duration: TimeInterval, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(formattedDuration(duration))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return "0ms"
        } else if duration < 1.0 {
            return String(format: "%.1fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

// MARK: - Metrics Data Model

struct NFXRequestMetrics {
    var dnsLookupDuration: TimeInterval = 0
    var tlsHandshakeDuration: TimeInterval = 0
    var connectDuration: TimeInterval = 0
    var requestDuration: TimeInterval = 0
    var waitingDuration: TimeInterval = 0
    var responseDuration: TimeInterval = 0
    var totalDuration: TimeInterval = 0

    /// Constructs metrics from URLSessionTaskMetrics (iOS 15+)
    init(from taskMetrics: URLSessionTaskMetrics) {
        guard let metric = taskMetrics.transactionMetrics.last else { return }

        // DNS
        if let start = metric.domainLookupStartDate, let end = metric.domainLookupEndDate {
            dnsLookupDuration = end.timeIntervalSince(start)
        }

        // TLS (secureConnection)
        if let start = metric.secureConnectionStartDate, let end = metric.secureConnectionEndDate {
            tlsHandshakeDuration = end.timeIntervalSince(start)
        }

        // Connect
        if let start = metric.connectStartDate, let end = metric.connectEndDate {
            connectDuration = end.timeIntervalSince(start)
        }

        // Request
        if let start = metric.requestStartDate, let end = metric.requestEndDate {
            requestDuration = end.timeIntervalSince(start)
        }

        // Waiting (TTFB) = time between request end and response start
        if let reqEnd = metric.requestEndDate, let resStart = metric.responseStartDate {
            waitingDuration = resStart.timeIntervalSince(reqEnd)
        }

        // Response
        if let start = metric.responseStartDate, let end = metric.responseEndDate {
            responseDuration = end.timeIntervalSince(start)
        }

        // Total
        if let start = metric.fetchStartDate, let end = metric.responseEndDate {
            totalDuration = end.timeIntervalSince(start)
        } else {
            totalDuration = taskMetrics.taskInterval.duration
        }
    }

    /// Empty metrics placeholder
    init() {}
}

#endif
