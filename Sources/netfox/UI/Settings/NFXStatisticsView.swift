//
//  NFXStatisticsView.swift
//  netfox
//
//  Totals and Swift Charts over the requests that pass the current filters.
//

#if os(iOS)
import Charts
import NetfoxCore
import SwiftUI

/// One bar or sector: a label and a count.
nonisolated struct NFXChartPoint: Identifiable, Sendable {
    let label: String
    let count: Int

    var id: String { label }
}

struct NFXStatisticsView: View {
    @Environment(NFXRequestStore.self) private var store
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180

    var body: some View {
        let statistics = store.statistics(for: store.filteredRecords)
        List {
            if statistics.totalCount > 0 {
                Section("Requests") {
                    LabeledContent("Total", value: statistics.totalCount, format: .number)
                    LabeledContent("Successful", value: statistics.successCount, format: .number)
                    LabeledContent("Failed", value: statistics.failureCount, format: .number)
                }
                Section("Status Codes") {
                    statusChart(statistics)
                }
                Section("Response Types") {
                    kindChart(statistics)
                }
                Section("Durations") {
                    durationChart(statistics)
                }
                detailSections(statistics)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if statistics.totalCount == 0 {
                ContentUnavailableView(
                    "No Statistics Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Statistics cover the requests that pass the current filters.")
                )
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    @ViewBuilder
    private func detailSections(_ statistics: NFXStatistics) -> some View {
        Section("Sizes") {
            LabeledContent("Total Request Size", value: NFXFormat.bytes(statistics.totalRequestBytes))
            LabeledContent("Average Request Size", value: averageBytes(statistics.averageRequestBytes))
            LabeledContent("Total Response Size", value: NFXFormat.bytes(statistics.totalResponseBytes))
            LabeledContent("Average Response Size", value: averageBytes(statistics.averageResponseBytes))
        }
        Section("Response Times") {
            LabeledContent("Average", value: NFXFormat.duration(statistics.averageDuration))
            LabeledContent("Fastest", value: NFXFormat.duration(statistics.fastestDuration))
            LabeledContent("Slowest", value: NFXFormat.duration(statistics.slowestDuration))
        }
    }

    // MARK: - Charts

    private func statusChart(_ statistics: NFXStatistics) -> some View {
        let order = ["2xx", "3xx", "4xx", "5xx", "Error"]
        let known = Set(order)
        let extra = statistics.countByStatusClass.keys.filter { !known.contains($0) }.sorted()
        let points = (order + extra).compactMap { label in
            statistics.countByStatusClass[label].map { NFXChartPoint(label: label, count: $0) }
        }
        return Chart(points) { point in
            BarMark(
                x: .value("Status", point.label),
                y: .value("Requests", point.count)
            )
            .foregroundStyle(color(forStatusClass: point.label))
            .annotation(position: .top) {
                Text(point.count, format: .number)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: chartHeight)
        .padding(.vertical, 8)
        .accessibilityLabel("Requests by status code")
    }

    private func kindChart(_ statistics: NFXStatistics) -> some View {
        let points = NFXContentKind.allCases.compactMap { kind in
            statistics.countByKind[kind].map { NFXChartPoint(label: kind.title, count: $0) }
        }
        return Chart(points) { point in
            SectorMark(
                angle: .value("Requests", point.count),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Type", point.label))
        }
        .chartLegend(position: .trailing, alignment: .center)
        .frame(height: chartHeight)
        .padding(.vertical, 8)
        .accessibilityLabel("Requests by response type")
    }

    private func durationChart(_ statistics: NFXStatistics) -> some View {
        Chart(NFXDurationBucket.points(for: statistics.durations)) { point in
            BarMark(
                x: .value("Duration", point.label),
                y: .value("Requests", point.count)
            )
            .foregroundStyle(Color.nfxOrange.gradient)
        }
        .frame(height: chartHeight)
        .padding(.vertical, 8)
        .accessibilityLabel("Requests by duration")
    }

    private func averageBytes(_ bytes: Double) -> String {
        NFXFormat.bytes(Int(bytes.rounded()))
    }

    private func color(forStatusClass label: String) -> Color {
        switch label {
        case "2xx": .nfxGreen
        case "3xx": .blue
        case "4xx": .orange
        case "5xx": .nfxRed
        default: .gray
        }
    }
}

/// Duration ranges of the distribution chart.
nonisolated enum NFXDurationBucket: CaseIterable {
    case under100Milliseconds
    case under300Milliseconds
    case underOneSecond
    case underThreeSeconds
    case threeSecondsOrMore

    var label: String {
        switch self {
        case .under100Milliseconds: "<100ms"
        case .under300Milliseconds: "100-300ms"
        case .underOneSecond: "0.3-1s"
        case .underThreeSeconds: "1-3s"
        case .threeSecondsOrMore: "\u{2265}3s"
        }
    }

    /// Exclusive upper bound in seconds; nil for the last bucket.
    var upperBound: TimeInterval? {
        switch self {
        case .under100Milliseconds: 0.1
        case .under300Milliseconds: 0.3
        case .underOneSecond: 1
        case .underThreeSeconds: 3
        case .threeSecondsOrMore: nil
        }
    }

    static func bucket(for duration: TimeInterval) -> NFXDurationBucket {
        allCases.first { bucket in bucket.upperBound.map { duration < $0 } ?? true } ?? .threeSecondsOrMore
    }

    /// Every bucket with its count, in order (empty buckets included, so the axis stays stable).
    static func points(for durations: [TimeInterval]) -> [NFXChartPoint] {
        var counts: [NFXDurationBucket: Int] = [:]
        for duration in durations {
            counts[bucket(for: duration), default: 0] += 1
        }
        return allCases.map { NFXChartPoint(label: $0.label, count: counts[$0] ?? 0) }
    }
}
#endif
