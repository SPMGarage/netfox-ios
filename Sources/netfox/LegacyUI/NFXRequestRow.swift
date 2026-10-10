//
//  NFXRequestRow.swift
//  netfox
//
//  SwiftUI row for the request list, replaces NFXListCell_iOS
//

#if os(iOS)

import SwiftUI

struct NFXRequestRow: View {
    let model: NFXHTTPModel
    let isPinned: Bool
    let isNew: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                // Top row: method badge + time
                HStack {
                    methodBadge
                    Spacer()
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(UIColor.NFXOrangeColor()))
                    }
                    if isNew {
                        Circle()
                            .fill(Color(UIColor.NFXOrangeColor()))
                            .frame(width: 6, height: 6)
                    }
                    Text(model.requestTime ?? "-")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // URL
                Text(model.requestURL ?? "-")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                // Bottom row: duration + type + size
                HStack(spacing: 8) {
                    Text(formattedDuration)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text(model.responseType ?? "-")
                        .font(.system(size: 11))
                        .foregroundColor(Color(UIColor.tertiaryLabel))

                    if let size = model.responseBodyLength {
                        Text(formattedSize(size))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Sub-views

    private var methodBadge: some View {
        Text(model.requestMethod ?? "-")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(methodTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(methodBackgroundColor)
            .cornerRadius(4)
    }

    // MARK: - Computed properties

    private var statusColor: Color {
        guard let status = model.responseStatus else {
            return Color(UIColor.secondaryLabel)
        }
        if status < 400 {
            return Color(UIColor.NFXGreenColor())
        }
        return Color(UIColor.NFXRedColor())
    }

    private var methodTextColor: Color {
        guard let status = model.responseStatus else {
            return Color(UIColor.secondaryLabel)
        }
        if status < 400 {
            return Color(UIColor.NFXDarkGreenColor())
        }
        return Color(UIColor.NFXDarkRedColor())
    }

    private var methodBackgroundColor: Color {
        guard let status = model.responseStatus else {
            return Color(UIColor.systemGray5)
        }
        if status < 400 {
            return Color(UIColor.NFXGreenColor()).opacity(0.15)
        }
        return Color(UIColor.NFXRedColor()).opacity(0.15)
    }

    private var formattedDuration: String {
        guard let interval = model.timeInterval else { return "..." }
        if interval < 1.0 {
            return String(format: "%.0fms", interval * 1000)
        }
        return String(format: "%.2fs", interval)
    }

    // MARK: - Helpers

    private func formattedSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Float(bytes) / 1024.0)
        } else {
            return String(format: "%.1f MB", Float(bytes) / (1024.0 * 1024.0))
        }
    }
}

#endif
