//
//  NFXInterception.swift
//  netfox
//
//  The switch the public NFX facade flips: register the protocol, install the
//  swizzles once, enable capturing.
//

import Foundation

/// Starts and stops request interception. Thread-safe.
package enum NFXInterception {

    /// Registers NFXProtocol, installs the configuration swizzles once, enables
    /// capturing and starts a fresh storage folder.
    package static func start() {
        NFXSwizzler.installIfNeeded()
        URLProtocol.registerClass(NFXProtocol.self)
        NFXStorage.shared.reset()
        NFXInterceptionSettings.shared.isEnabled = true
    }

    /// Disables capturing, unregisters NFXProtocol and deletes stored data.
    /// The swizzles stay installed and check the disabled switch.
    package static func stop() {
        NFXInterceptionSettings.shared.isEnabled = false
        URLProtocol.unregisterClass(NFXProtocol.self)
        NFXStorage.shared.reset()
    }

    /// The protocol class, for configurations built by hand (tests, custom sessions).
    package static var protocolClass: AnyClass {
        NFXProtocol.self
    }
}
