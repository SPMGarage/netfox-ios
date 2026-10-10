//
//  NFXRequestRow.swift
//  netfox
//
//  One captured request in the list: status dot, method badge, status code,
//  time, URL, then duration, content type and size.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXRequestRow: View {
    let record: NFXRecord
    var isPinned = false
    /// Arrived after the inspector was last closed.
    var isNew = false

    var body: some View {
        let appearance = NFXStatusAppearance(record)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                NFXStatusDot(appearance: appearance)
                NFXMethodBadge(method: record.method, appearance: appearance)
                if let statusCode = record.statusCode {
                    Text(String(statusCode))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(appearance.textColor)
                }
                Spacer(minLength: 8)
                markers
                Text(NFXFormat.time(record.startDate))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(record.urlString)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
            Text(detailLine)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var markers: some View {
        if isPinned {
            Image(systemName: "pin.fill")
                .font(.caption2)
                .foregroundStyle(Color.nfxOrange)
                .accessibilityLabel("Pinned")
        }
        if isNew {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .imageScale(.small)
                .foregroundStyle(Color.nfxOrange)
                .accessibilityLabel("New")
        }
    }

    /// "245ms · application/json · 1.2 kB", or the error for a request without a response.
    private var detailLine: String {
        guard record.hasResponse else {
            return NFXFormat.failure(of: record)
        }
        var parts = [NFXFormat.duration(record.duration)]
        if let type = record.responseContentType {
            parts.append(type)
        }
        if let length = record.responseBody.length {
            parts.append(NFXFormat.bytes(length))
        }
        return parts.joined(separator: " · ")
    }
}

/// The colored outcome dot, with a VoiceOver label.
struct NFXStatusDot: View {
    let appearance: NFXStatusAppearance

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.caption2)
            .imageScale(.small)
            .foregroundStyle(appearance.dotColor)
            .accessibilityLabel(appearance.accessibilityLabel)
    }
}

/// The HTTP method in a tinted badge.
struct NFXMethodBadge: View {
    let method: String
    let appearance: NFXStatusAppearance

    var body: some View {
        Text(method)
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(appearance.textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(appearance.badgeFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel("Method \(method)")
    }
}
#endif
