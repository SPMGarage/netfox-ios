//
//  NFXColors.swift
//  netfox
//
//  netfox palette, adapting to light and dark mode (was NFXColor.NFX*Color() in 3.x).
//  nonisolated: the JSON highlighter builds its colors off the main actor.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

nonisolated extension UIColor {
    private static func nfxDynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(nfxHex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    private convenience init(nfxHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Accent / tint.
    static let nfxOrange = nfxDynamic(light: 0xEC5E28, dark: 0xF28C5E)
    /// Success status.
    static let nfxGreen = nfxDynamic(light: 0x38BB93, dark: 0x4CD6A8)
    static let nfxDarkGreen = nfxDynamic(light: 0x2D7C6E, dark: 0x38BB93)
    /// Error status.
    static let nfxRed = nfxDynamic(light: 0xD34A33, dark: 0xE8705A)
    static let nfxDarkRed = nfxDynamic(light: 0x643026, dark: 0xD34A33)
}

nonisolated extension Color {
    static let nfxOrange = Color(uiColor: .nfxOrange)
    static let nfxGreen = Color(uiColor: .nfxGreen)
    static let nfxDarkGreen = Color(uiColor: .nfxDarkGreen)
    static let nfxRed = Color(uiColor: .nfxRed)
    static let nfxDarkRed = Color(uiColor: .nfxDarkRed)
}
#endif
