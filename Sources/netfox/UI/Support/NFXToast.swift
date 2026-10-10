//
//  NFXToast.swift
//  netfox
//
//  A short confirmation ("Copied") at the bottom of a screen. Hides itself with
//  Task.sleep inside .task(id:), so a newer message restarts the timer.
//

#if os(iOS)
import SwiftUI

private struct NFXToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let visibleDuration = Duration.seconds(2)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        // the timer lives on the toast itself, so it runs exactly while the toast is shown
                        .task(id: message) {
                            AccessibilityNotification.Announcement(message).post()
                            // sleep throws when a newer message replaces this one; that one hides itself
                            guard (try? await Task.sleep(for: Self.visibleDuration)) != nil else { return }
                            self.message = nil
                        }
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: message)
    }
}

extension View {
    /// Shows `message` briefly at the bottom, then sets it back to nil.
    func nfxToast(_ message: Binding<String?>) -> some View {
        modifier(NFXToastModifier(message: message))
    }
}
#endif
