//
//  NFXInfoSections.swift
//  netfox
//
//  The Info tab: overview, timing, the metrics timeline (B7) and the TLS certificate (D6).
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXInfoSections: View {
    let record: NFXRecord

    @Environment(NFXRequestStore.self) private var store

    var body: some View {
        Section("Overview") {
            NFXValueRow(title: "URL", value: record.urlString, layout: .stacked, isMonospaced: true)
            NFXValueRow(title: "Method", value: record.method)
            NFXValueRow(title: "Status", value: statusText)
            if let redirect = record.redirectURL {
                NFXValueRow(title: "Redirects To", value: redirect.absoluteString, layout: .stacked, isMonospaced: true)
            }
            if let error = record.error {
                NFXValueRow(title: "Error", value: "\(error.message)\n\(error.domain) \(error.code)", layout: .stacked)
            }
        }
        Section("Timing") {
            NFXValueRow(title: "Request Date", value: NFXFormat.dateTime(record.startDate))
            NFXValueRow(title: "Response Date", value: record.endDate.map(NFXFormat.dateTime) ?? "-")
            NFXValueRow(title: "Duration", value: NFXFormat.duration(record.duration))
            NFXValueRow(title: "Timeout", value: NFXFormat.seconds(record.timeoutInterval))
            NFXValueRow(title: "Cache Policy", value: NFXFormat.cachePolicy(record.cachePolicy))
        }
        if let metrics = record.metrics {
            NFXMetricsSection(metrics: metrics)
        }
        if store.isCertificateInfoEnabled, let certificate = record.certificate {
            NFXCertificateSection(certificate: certificate)
        }
    }

    private var statusText: String {
        guard let code = record.statusCode else {
            return NFXFormat.failure(of: record)
        }
        return NFXFormat.status(code)
    }
}
#endif
