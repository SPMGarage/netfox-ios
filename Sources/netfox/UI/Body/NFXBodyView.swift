//
//  NFXBodyView.swift
//  netfox
//
//  The full body of a request or response: highlighted JSON (B10) with a Raw /
//  Pretty picker, plain text, an image, or a binary placeholder. Loading and
//  formatting run in .task(id:), off the main actor (P1-8, P2-3).
//

#if os(iOS)
import NetfoxCore
import SwiftUI
import UIKit

struct NFXBodyView: View {
    let recordID: UUID
    let part: NFXBodyPart

    /// Reloads when the record, the side or the mode changes (not when late metrics arrive).
    nonisolated private struct LoadKey: Equatable, Sendable {
        let recordID: UUID
        let part: NFXBodyPart
        let mode: NFXBodyMode
    }

    @Environment(NFXRequestStore.self) private var store
    @State private var mode = NFXBodyMode.pretty
    @State private var content = NFXBodyContent.loading
    @State private var findRequests = 0
    @State private var toast: String?

    var body: some View {
        Group {
            if let record = store.record(with: recordID) {
                contentView(for: record)
                    .task(id: LoadKey(recordID: recordID, part: part, mode: mode)) {
                        await load(record)
                    }
                    .toolbar { toolbar(for: record) }
            } else {
                ContentUnavailableView(
                    "Request Not Available",
                    systemImage: "tray",
                    description: Text("This request was removed from the list.")
                )
            }
        }
        .navigationTitle(part == .request ? "Request Body" : "Response Body")
        .navigationBarTitleDisplayMode(.inline)
        .nfxToast($toast)
    }

    private func load(_ record: NFXRecord) async {
        let data = await store.body(part, of: record)
        let loaded = await NFXBodyLoader.content(
            for: data, info: record.body(part), mimeType: record.contentType(part), mode: mode
        )
        guard !Task.isCancelled else { return }
        content = loaded
    }

    // MARK: - Content

    @ViewBuilder
    private func contentView(for record: NFXRecord) -> some View {
        switch content {
        case .loading:
            ProgressView("Loading Body\u{2026}")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "No Body",
                systemImage: "doc",
                description: Text("This \(part.rawValue) has no body.")
            )
        case .notCaptured(let length):
            ContentUnavailableView(
                "Body Not Captured",
                systemImage: "eye.slash",
                description: Text("netfox did not capture this body (\(NFXFormat.bytes(length))).")
            )
        case .image(let image, let byteCount):
            NFXImageBodyView(image: image, byteCount: byteCount, mimeType: record.contentType(part))
        case .text(let text):
            textContent(text, isTruncated: record.body(part).isTruncated)
        case .binary(let byteCount, let mimeType):
            binaryPlaceholder(for: record, byteCount: byteCount, mimeType: mimeType)
        }
    }

    private func textContent(_ text: NFXRenderedText, isTruncated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isTruncated {
                note(
                    "netfox cut this body at \(NFXFormat.bytes(NFXStorage.maxBodyBytes)); the rest was not stored.",
                    systemImage: "scissors"
                )
            }
            if text.isDisplayTruncated {
                note(
                    "Showing the first \(NFXFormat.bytes(NFXBodyLoader.displayLimit)). Share the body to see all of it.",
                    systemImage: "text.append"
                )
            }
            if text.isHighlightSkipped {
                note(
                    "Colors are off for bodies over \(NFXFormat.bytes(NFXJSONHighlighter.byteLimit)).",
                    systemImage: "paintpalette"
                )
            }
            NFXBodyTextView(text: text, findRequests: findRequests)
        }
    }

    private func note(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 0) {
            Label(text, systemImage: systemImage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
        }
    }

    private func binaryPlaceholder(for record: NFXRecord, byteCount: Int, mimeType: String?) -> some View {
        ContentUnavailableView {
            Label("Binary Body", systemImage: "doc.badge.ellipsis")
        } description: {
            Text(
                "\(NFXFormat.bytes(byteCount)) \u{00B7} \(mimeType ?? "unknown type")\n"
                    + "This body is not text, so netfox can't show it."
            )
        } actions: {
            if let url = store.bodyFileURL(part, of: record) {
                let file = NFXBodyFile(url: url, part: part, mimeType: mimeType)
                ShareLink(item: file, preview: SharePreview(file.fileName)) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(for record: NFXRecord) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if case .text = content {
                Button("Find", systemImage: "magnifyingglass") {
                    findRequests += 1
                }
            }
            if canCopy {
                Button("Copy", systemImage: "doc.on.doc", action: copyContent)
            }
            if let url = store.bodyFileURL(part, of: record) {
                let file = NFXBodyFile(url: url, part: part, mimeType: record.contentType(part))
                ShareLink(item: file, preview: SharePreview(file.fileName)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        if case .text(let text) = content, text.isJSON {
            ToolbarItem(placement: .bottomBar) {
                Picker("Format", selection: $mode) {
                    ForEach(NFXBodyMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var canCopy: Bool {
        switch content {
        case .text, .image: true
        default: false
        }
    }

    private func copyContent() {
        switch content {
        case .text(let text):
            UIPasteboard.general.string = text.plain
        case .image(let image, _):
            UIPasteboard.general.image = image
        default:
            return
        }
        toast = "Copied"
    }
}

/// An image body with its dimensions.
private struct NFXImageBodyView: View {
    let image: UIImage
    let byteCount: Int
    let mimeType: String?

    var body: some View {
        List {
            Section {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Body image")
            }
            Section {
                NFXValueRow(title: "Dimensions", value: pixelSize)
                NFXValueRow(title: "Size", value: NFXFormat.bytes(byteCount))
                if let mimeType {
                    NFXValueRow(title: "Type", value: mimeType)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// "1200 × 800 px".
    private var pixelSize: String {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return "\(width) \u{00D7} \(height) px"
    }
}
#endif
