//
//  NFXShakeDetection.swift
//  netfox
//
//  Shake gesture detection through a UIWindow override.
//

#if os(iOS)
import UIKit

extension UIWindow {
    // P2-11: the event always continues up the responder chain (super), and netfox
    // reacts only when it is started and the gesture is .shake.
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NFXShakeHandler.handleShake()
        }
        super.motionEnded(motion, with: event)
    }
}

enum NFXShakeHandler {
    static func handleShake() {
        let nfx = NFX.shared
        guard nfx.isStarted(), nfx.selectedGesture == .shake else { return }
        NFXPresenter.shared.toggle()
    }
}
#endif
