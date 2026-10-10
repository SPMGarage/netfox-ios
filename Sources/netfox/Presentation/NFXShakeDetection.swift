//
//  NFXHelper.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//

#if os(iOS)

import UIKit

// Shake gesture detection via UIWindow override
extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if NFX.sharedInstance().getSelectedGesture() == .shake {
            if event?.type == .motion && event?.subtype == .motionShake {
                NFX.sharedInstance().motionDetected()
            }
        } else {
            super.motionEnded(motion, with: event)
        }
    }
}

// MARK: - Data Cleaner Protocol

protocol DataCleaner {
    func clearData(sourceView: UIView, originingIn sourceRect: CGRect?, then: @escaping () -> Void)
}

extension DataCleaner where Self: UIViewController {
    func clearData(sourceView: UIView, originingIn sourceRect: CGRect?, then: @escaping () -> Void) {
        let actionSheet = UIAlertController(title: "Clear data?", message: nil, preferredStyle: .actionSheet)
        actionSheet.popoverPresentationController?.sourceView = sourceView
        if let sourceRect = sourceRect {
            actionSheet.popoverPresentationController?.sourceRect = sourceRect
        }

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        actionSheet.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            NFX.sharedInstance().clearOldData()
            then()
        })

        present(actionSheet, animated: true)
    }
}

#endif
