//
//  NFXValueRow.swift
//  netfox
//
//  One name/value row: LabeledContent with selectable text and a copy menu.
//

#if os(iOS)
import SwiftUI
import UIKit

/// A name/value row. Long values (URLs, header values) use the stacked layout.
struct NFXValueRow: View {

    enum Layout {
        /// Name on the left, value on the right.
        case inline
        /// Name above the value, for long values.
        case stacked
    }

    let title: String
    let value: String
    var layout = Layout.inline
    /// Monospaced value text, for header values, URLs and other raw protocol text.
    var isMonospaced = false
    /// Adds "Copy name: value" to the menu (header and query rows).
    var copiesLine = false

    var body: some View {
        labeledContent
            .contextMenu {
                Button("Copy Value", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = value
                }
                if copiesLine {
                    Button("Copy \u{201C}\(title): \u{2026}\u{201D}", systemImage: "text.badge.plus") {
                        UIPasteboard.general.string = "\(title): \(value)"
                    }
                }
            }
    }

    @ViewBuilder
    private var labeledContent: some View {
        let content = LabeledContent {
            Text(value.isEmpty ? " " : value)
                .font(isMonospaced ? .callout.monospaced() : nil)
                .textSelection(.enabled)
        } label: {
            Text(title)
        }
        switch layout {
        case .inline:
            content
        case .stacked:
            content.labeledContentStyle(NFXStackedLabeledContentStyle())
        }
    }
}

/// LabeledContent with the label above the content, both leading-aligned.
struct NFXStackedLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            configuration.label
                .font(.subheadline)
                .foregroundStyle(.secondary)
            configuration.content
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
