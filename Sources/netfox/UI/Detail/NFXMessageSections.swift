//
//  NFXMessageSections.swift
//  netfox
//
//  The Request and Response tabs: body (preview + "Show Body"), URL query
//  parameters and headers. The body comes first so "Show Body" is on screen.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXMessageSections: View {
    let record: NFXRecord
    let part: NFXBodyPart

    var body: some View {
        if part == .response, !record.hasResponse {
            Section("No Response") {
                Label(NFXFormat.failure(of: record), systemImage: "wifi.exclamationmark")
                    .foregroundStyle(Color.nfxRed)
                if let error = record.error {
                    NFXValueRow(title: "Error Code", value: "\(error.domain) \(error.code)")
                }
            }
        } else {
            if part == .response, let statusCode = record.statusCode {
                Section {
                    NFXValueRow(title: "Status", value: NFXFormat.status(statusCode))
                }
            }
            NFXBodySection(record: record, part: part)
            if part == .request, !record.queryItems.isEmpty {
                Section("URL Query") {
                    NavigationLink(value: NFXRoute.queryItems(record.id)) {
                        LabeledContent("Query Parameters", value: record.queryItems.count, format: .number)
                    }
                }
            }
            NFXHeadersSection(
                title: part == .request ? "Request Headers" : "Response Headers",
                headers: part == .request ? record.requestHeaders : record.responseHeaders
            )
        }
    }
}

/// Header rows: selectable values and a copy menu ("Copy Value", "Copy name: value").
struct NFXHeadersSection: View {
    let title: String
    let headers: [NFXHeader]

    var body: some View {
        Section {
            if headers.isEmpty {
                Text("No headers")
                    .foregroundStyle(.secondary)
            }
            ForEach(headers, id: \.self) { header in
                NFXValueRow(
                    title: header.name, value: header.value, layout: .stacked, isMonospaced: true, copiesLine: true
                )
            }
        } header: {
            Text(title)
        }
    }
}

/// Size, type, a short preview and the "Show Body" link.
struct NFXBodySection: View {
    let record: NFXRecord
    let part: NFXBodyPart

    @Environment(NFXRequestStore.self) private var store
    @State private var preview: NFXBodyPreview?

    var body: some View {
        let info = record.body(part)
        Section {
            if info.isEmpty {
                Text("No body")
                    .foregroundStyle(.secondary)
            } else if info.isStored {
                NavigationLink(value: NFXRoute.body(record.id, part)) {
                    LabeledContent {
                        Text(NFXFormat.bytes(info.length))
                    } label: {
                        Label("Show Body", systemImage: "doc.text.magnifyingglass")
                    }
                }
                .accessibilityIdentifier("nfx.detail.showBody")
                .task(id: record.id) {
                    preview = await loadPreview(info: info)
                }
                if let type = record.contentType(part) {
                    NFXValueRow(title: "Content Type", value: type)
                }
                previewRow
            } else {
                Label(notCapturedText(info), systemImage: "eye.slash")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Body")
        } footer: {
            if info.isTruncated {
                Text("netfox stored only the first \(NFXFormat.bytes(NFXStorage.maxBodyBytes)) of this body.")
            }
        }
    }

    @ViewBuilder
    private var previewRow: some View {
        switch preview {
        case .text(let text):
            Text(text)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(NFXBodyPreview.lineLimit)
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: NFXBodyPreview.imageHeight)
                .accessibilityLabel("Image preview")
        case nil:
            EmptyView()
        }
    }

    private func loadPreview(info: NFXBodyInfo) async -> NFXBodyPreview? {
        guard let length = info.length, length <= NFXBodyPreview.byteLimit else { return nil }
        let data = await store.body(part, of: record)
        return await NFXBodyPreview.make(from: data, mimeType: record.contentType(part))
    }

    private func notCapturedText(_ info: NFXBodyInfo) -> String {
        guard let length = info.length else {
            return "netfox did not capture this body (an upload stream of unknown size)."
        }
        return "netfox did not capture these \(NFXFormat.bytes(length))."
    }
}
#endif
