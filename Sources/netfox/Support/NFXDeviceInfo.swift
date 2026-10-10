//
//  NFXDeviceInfo.swift
//  netfox
//
//  App and device details for the "Device Info" screen.
//

import Foundation
import NetfoxCore
#if canImport(UIKit)
import UIKit
#endif

/// App and device details. Main actor (UIKit reads).
enum NFXDeviceInfo {

    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    /// "iOS 27.0" / "macOS 27.0".
    static var systemVersion: String {
        #if canImport(UIKit)
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #endif
    }

    /// Hardware model identifier, e.g. "iPhone17,1" (the simulated model on the Simulator).
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    #if canImport(UIKit)
    /// Native pixel size of the screen showing `scene`, e.g. "1206 x 2622". Avoids the deprecated UIScreen.main.
    static func screenResolution(of scene: UIWindowScene?) -> String {
        guard let screen = scene?.screen else { return "-" }
        let size = screen.nativeBounds.size
        return "\(Int(size.width)) x \(Int(size.height))"
    }
    #endif

    /// P2-9: contacts api.ipify.org. Call only after the user asked for it.
    static func publicIPAddress() async -> String? {
        await NFXPublicIP.lookup()
    }
}
