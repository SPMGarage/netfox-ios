//
//  NFXStatistics.swift
//  netfox
//
//  Numbers for the statistics screen.
//

import Foundation

/// Totals and timings over a set of records.
package struct NFXStatistics: Sendable, Hashable {
    package let totalCount: Int
    package let successCount: Int
    package let failureCount: Int
    /// Sum of the known request body lengths, in bytes.
    package let totalRequestBytes: Int
    /// Sum of the known response body lengths, in bytes.
    package let totalResponseBytes: Int
    /// Durations in seconds of the records that finished.
    package let durations: [TimeInterval]
    /// Count per status class ("2xx", "3xx", "4xx", "5xx", "Error").
    package let countByStatusClass: [String: Int]
    /// Count per response type.
    package let countByKind: [NFXContentKind: Int]

    package init(records: [NFXRecord]) {
        var success = 0
        var requestBytes = 0
        var responseBytes = 0
        var durations: [TimeInterval] = []
        var byStatus: [String: Int] = [:]
        var byKind: [NFXContentKind: Int] = [:]

        for record in records {
            if record.isSuccess { success += 1 }
            requestBytes += record.requestBody.length ?? 0
            responseBytes += record.responseBody.length ?? 0
            if let duration = record.duration { durations.append(duration) }
            let statusClass = record.statusCode.map { "\($0 / 100)xx" } ?? "Error"
            byStatus[statusClass, default: 0] += 1
            byKind[record.kind, default: 0] += 1
        }

        self.totalCount = records.count
        self.successCount = success
        self.failureCount = records.count - success
        self.totalRequestBytes = requestBytes
        self.totalResponseBytes = responseBytes
        self.durations = durations
        self.countByStatusClass = byStatus
        self.countByKind = byKind
    }

    package var averageRequestBytes: Double {
        totalCount == 0 ? 0 : Double(totalRequestBytes) / Double(totalCount)
    }

    package var averageResponseBytes: Double {
        totalCount == 0 ? 0 : Double(totalResponseBytes) / Double(totalCount)
    }

    package var averageDuration: TimeInterval? {
        durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)
    }

    package var fastestDuration: TimeInterval? { durations.min() }
    package var slowestDuration: TimeInterval? { durations.max() }
}
