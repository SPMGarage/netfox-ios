//
//  NFXStatisticsView.swift
//  netfox
//
//  SwiftUI replacement for NFXStatisticsController_iOS
//

#if os(iOS)

import SwiftUI

struct NFXStatisticsView: View {
    @ObservedObject private var manager = NFXHTTPModelManager.shared

    var body: some View {
        let stats = computeStatistics(manager.filteredModels)
        ScrollView {
            NFXAttributedTextView(attributedText: formatReport(stats))
                .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Statistics computation (extracted from NFXStatisticsController for reuse)

    private struct Stats {
        var totalModels = 0
        var successfulRequests = 0
        var failedRequests = 0
        var totalRequestSize = 0
        var totalResponseSize = 0
        var totalResponseTime: Float = 0
        var fastestResponseTime: Float = 999
        var slowestResponseTime: Float = 0
    }

    private func computeStatistics(_ models: [NFXHTTPModel]) -> Stats {
        var stats = Stats()
        stats.totalModels = models.count

        for model in models {
            if model.isSuccessful() {
                stats.successfulRequests += 1
            } else {
                stats.failedRequests += 1
            }

            if let bodyLength = model.requestBodyLength {
                stats.totalRequestSize += bodyLength
            }

            if let bodyLength = model.responseBodyLength {
                stats.totalResponseSize += bodyLength
            }

            if let interval = model.timeInterval {
                stats.totalResponseTime += interval
                if interval < stats.fastestResponseTime {
                    stats.fastestResponseTime = interval
                }
                if interval > stats.slowestResponseTime {
                    stats.slowestResponseTime = interval
                }
            }
        }

        return stats
    }

    private func formatReport(_ stats: Stats) -> NSAttributedString {
        var tempString = ""

        tempString += "[Total requests] \n\(stats.totalModels)\n\n"
        tempString += "[Successful requests] \n\(stats.successfulRequests)\n\n"
        tempString += "[Failed requests] \n\(stats.failedRequests)\n\n"

        let totalReqKB = Float(stats.totalRequestSize) / 1024.0
        tempString += "[Total request size] \n\(String(format: "%.1f", totalReqKB)) KB\n\n"

        if stats.totalModels > 0 {
            let avgReqKB = Float(stats.totalRequestSize) / Float(stats.totalModels) / 1024.0
            tempString += "[Avg request size] \n\(String(format: "%.1f", avgReqKB)) KB\n\n"
        } else {
            tempString += "[Avg request size] \n0.0 KB\n\n"
        }

        let totalResKB = Float(stats.totalResponseSize) / 1024.0
        tempString += "[Total response size] \n\(String(format: "%.1f", totalResKB)) KB\n\n"

        if stats.totalModels > 0 {
            let avgResKB = Float(stats.totalResponseSize) / Float(stats.totalModels) / 1024.0
            tempString += "[Avg response size] \n\(String(format: "%.1f", avgResKB)) KB\n\n"
        } else {
            tempString += "[Avg response size] \n0.0 KB\n\n"
        }

        if stats.totalModels > 0 {
            let avgTime = stats.totalResponseTime / Float(stats.totalModels)
            tempString += "[Avg response time] \n\(String(format: "%.3f", avgTime))s\n\n"

            let fastest = stats.fastestResponseTime == 999 ? Float(0) : stats.fastestResponseTime
            tempString += "[Fastest response time] \n\(String(format: "%.3f", fastest))s\n\n"
        } else {
            tempString += "[Avg response time] \n0.0s\n\n"
            tempString += "[Fastest response time] \n0.0s\n\n"
        }

        tempString += "[Slowest response time] \n\(String(format: "%.3f", stats.slowestResponseTime))s\n\n"

        return NFXTextFormatter.formatNFXString(tempString)
    }
}

#endif
