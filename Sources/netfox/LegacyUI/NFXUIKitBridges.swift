//
//  NFXUIKitBridges.swift
//  netfox
//
//  UIViewRepresentable / UIViewControllerRepresentable bridges for SwiftUI
//

#if os(iOS)

import SwiftUI
import UIKit
import MessageUI

// MARK: - Attributed Text View (supports tappable [URL] links and formatNFXString output)

struct NFXAttributedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    var onLinkTapped: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTapped: onLinkTapped)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = .NFXFont(size: 13)
        textView.textColor = .NFXSecondaryTextColor()
        textView.dataDetectorTypes = []
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedText
        context.coordinator.onLinkTapped = onLinkTapped
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTapped: ((String) -> Void)?

        init(onLinkTapped: ((String) -> Void)?) {
            self.onLinkTapped = onLinkTapped
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            let decoded = URL.absoluteString.removingPercentEncoding ?? URL.absoluteString
            onLinkTapped?(decoded)
            return false
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    var subject: String = ""
    var toRecipients: [String] = []
    var attachmentData: Data?
    var attachmentMimeType: String = "text/plain"
    var attachmentFileName: String = "log.txt"
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setSubject(subject)
        controller.setToRecipients(toRecipients)
        if let data = attachmentData {
            controller.addAttachmentData(data, mimeType: attachmentMimeType, fileName: attachmentFileName)
        }
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }
}

#endif
