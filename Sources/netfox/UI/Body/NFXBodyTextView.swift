//
//  NFXBodyTextView.swift
//  netfox
//
//  P1-8: a read-only, scrolling UITextView (TextKit 1 with non-contiguous layout,
//  so megabytes of text open quickly) with the system find interaction.
//

#if os(iOS)
import SwiftUI
import UIKit

struct NFXBodyTextView: UIViewRepresentable {
    let text: NFXRenderedText
    /// Incremented by the Find button; each change opens the find navigator.
    let findRequests: Int

    private static let baseFontSize: CGFloat = 13
    private static let inset: CGFloat = 12

    final class Coordinator {
        var renderedID: UUID?
        var handledFindRequests = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.isFindInteractionEnabled = true
        textView.adjustsFontForContentSizeCategory = true
        textView.dataDetectorTypes = []
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(
            top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset
        )
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.accessibilityIdentifier = "nfx.body.text"
        context.coordinator.handledFindRequests = findRequests
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.renderedID != text.id {
            coordinator.renderedID = text.id
            textView.attributedText = Self.attributedText(for: text)
        }
        if coordinator.handledFindRequests != findRequests {
            coordinator.handledFindRequests = findRequests
            textView.findInteraction?.presentFindNavigator(showingReplace: false)
        }
    }

    /// The highlighted runs (or plain text) in a monospaced font that follows Dynamic Type.
    private static func attributedText(for text: NFXRenderedText) -> NSAttributedString {
        let font = UIFontMetrics(forTextStyle: .footnote)
            .scaledFont(for: .monospacedSystemFont(ofSize: baseFontSize, weight: .regular))
        let result: NSMutableAttributedString
        if let highlighted = text.highlighted,
           let converted = try? NSAttributedString(highlighted, including: \.uiKit) {
            result = NSMutableAttributedString(attributedString: converted)
        } else {
            result = NSMutableAttributedString(string: text.plain, attributes: [.foregroundColor: UIColor.label])
        }
        result.addAttribute(.font, value: font, range: NSRange(location: 0, length: result.length))
        return result
    }
}
#endif
