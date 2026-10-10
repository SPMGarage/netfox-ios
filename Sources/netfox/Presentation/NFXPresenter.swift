//
//  NFXPresenter.swift
//  netfox
//
//  P1-12: presents the SwiftUI inspector in a UIHostingController. Whether it
//  is on screen is read from UIKit, never from a stored flag that can get stuck.
//

import SwiftUI
#if os(iOS)
import NetfoxCore
import UIKit
#endif

/// Closes the inspector. Read it with `@Environment(\.nfxDismiss)` and call it: `dismiss()`.
///
/// SwiftUI's own `dismiss` cannot close a hosting controller that UIKit presented.
package nonisolated struct NFXDismissAction: Sendable {
    private let action: @MainActor @Sendable () -> Void

    package init(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    @MainActor
    package func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    /// Closes the netfox inspector.
    @Entry package var nfxDismiss = NFXDismissAction {}
}

#if os(iOS)
/// Presents and dismisses the inspector.
final class NFXPresenter: NSObject, UIAdaptivePresentationControllerDelegate {

    static let shared = NFXPresenter()

    /// The hosting controller while it is (or was last) presented.
    private weak var hostingController: UIViewController?

    override private init() {
        super.init()
    }

    /// True while the inspector is presented.
    var isPresented: Bool {
        hostingController?.presentingViewController != nil
    }

    /// Presents the inspector from `base`, or from the top-most controller of the key window.
    func show(on base: UIViewController? = nil) {
        guard !isPresented else { return }
        guard let presenter = base ?? Self.topViewController() else {
            NFXLog.ui.error("netfox could not find a view controller to present from")
            return
        }
        guard presenter.viewIfLoaded?.window != nil else {
            NFXLog.ui.error("netfox can only present from a view controller that is in a window")
            return
        }

        let requestStore = NFXRequestStore.shared
        requestStore.syncWithCoreSettings()
        let rootView = NFXRootView()
            .environment(requestStore)
            .environment(NFXWebSocketStore.shared)
            .environment(\.nfxDismiss, NFXDismissAction { [weak self] in self?.hide() })
            .tint(Color.nfxOrange)

        let controller = UIHostingController(rootView: rootView)
        // E4: in regular width a sheet is too narrow for the split view's two columns
        // (it collapses), so the inspector covers the screen there. Compact width keeps the sheet.
        if presenter.traitCollection.horizontalSizeClass == .regular {
            controller.modalPresentationStyle = .fullScreen
        }
        controller.presentationController?.delegate = self
        hostingController = controller
        presenter.present(controller, animated: true)
    }

    /// Dismisses the inspector. Works whether or not netfox is started.
    func hide() {
        guard let presenting = hostingController?.presentingViewController else {
            hostingController = nil
            return
        }
        presenting.dismiss(animated: true) {
            NFXRequestStore.shared.markVisited()
        }
    }

    func toggle() {
        isPresented ? hide() : show()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    /// Swipe-down dismissal.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        NFXRequestStore.shared.markVisited()
    }

    // MARK: - Helpers

    /// The top-most presented controller of the foreground key window.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { $0.activationState.presentationPriority < $1.activationState.presentationPriority }
        let window = scenes.lazy.compactMap { scene in
            scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        }.first
        var top = window?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed {
            top = next
        }
        return top
    }
}

private extension UIScene.ActivationState {
    var presentationPriority: Int {
        switch self {
        case .foregroundActive: 0
        case .foregroundInactive: 1
        case .background: 2
        case .unattached: 3
        @unknown default: 4
        }
    }
}
#endif
