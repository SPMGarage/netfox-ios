//
//  NFXSwizzling.swift
//  netfox
//
//  URLSessionConfiguration swizzles that put NFXProtocol into every session,
//  including sessions created before NFX.start(). Installed once per process
//  and never reverted; NFXInterceptionSettings.isEnabled switches them off.
//

import Foundation
import ObjectiveC

// Only the address of this byte is used, as the associated-object key; the value never changes.
nonisolated(unsafe) private var nfxInternalConfigurationKey: UInt8 = 0

/// Installs the configuration swizzles.
package enum NFXSwizzler {

    /// A lazy static is initialized exactly once, thread-safely (P1-3).
    private static let installSwizzles: Void = {
        URLSessionConfiguration.nfx_exchangeInstanceMethod(
            #selector(setter: URLSessionConfiguration.protocolClasses),
            with: #selector(URLSessionConfiguration.nfx_setProtocolClasses(_:))
        )
        URLSessionConfiguration.nfx_exchangeInstanceMethod(
            #selector(getter: URLSessionConfiguration.protocolClasses),
            with: #selector(URLSessionConfiguration.nfx_protocolClasses)
        )
        URLSessionConfiguration.nfx_exchangeClassMethod(
            #selector(getter: URLSessionConfiguration.default),
            with: #selector(getter: URLSessionConfiguration.nfx_default)
        )
        URLSessionConfiguration.nfx_exchangeClassMethod(
            #selector(getter: URLSessionConfiguration.ephemeral),
            with: #selector(getter: URLSessionConfiguration.nfx_ephemeral)
        )
    }()

    /// Installs the swizzles the first time it is called; later calls do nothing.
    package static func installIfNeeded() {
        _ = installSwizzles
    }
}

extension URLSessionConfiguration {

    // MARK: - Internal sessions

    /// Marks a configuration so the getter swizzle never injects NFXProtocol into it.
    static func nfx_markAsInternal(_ configuration: URLSessionConfiguration) {
        objc_setAssociatedObject(configuration, &nfxInternalConfigurationKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    var nfx_isInternal: Bool {
        objc_getAssociatedObject(self, &nfxInternalConfigurationKey) != nil
    }

    // MARK: - Replacement implementations

    /// Getter swizzle: injects NFXProtocol while interception is on. Runs on whatever
    /// thread creates a session, so the switch is read through the settings lock.
    @objc dynamic func nfx_protocolClasses() -> [AnyClass]? {
        // after the exchange this calls the original getter
        let classes = nfx_protocolClasses()
        guard NFXInterceptionSettings.shared.isEnabled, !nfx_isInternal else { return classes }
        guard var classes else { return [NFXProtocol.self] }
        if !classes.contains(where: { $0 == NFXProtocol.self }) {
            classes.insert(NFXProtocol.self, at: 0)
        }
        return classes
    }

    /// Setter swizzle: drops duplicate protocol classes.
    @objc dynamic func nfx_setProtocolClasses(_ newValue: [AnyClass]?) {
        guard let newValue else {
            nfx_setProtocolClasses(nil) // original setter
            return
        }
        var unique: [AnyClass] = []
        for type in newValue where !unique.contains(where: { $0 == type }) {
            unique.append(type)
        }
        nfx_setProtocolClasses(unique) // original setter
    }

    @objc dynamic class var nfx_default: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.nfx_default // original getter after the exchange
        configuration.protocolClasses?.insert(NFXProtocol.self, at: 0)
        return configuration
    }

    @objc dynamic class var nfx_ephemeral: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.nfx_ephemeral // original getter after the exchange
        configuration.protocolClasses?.insert(NFXProtocol.self, at: 0)
        return configuration
    }

    // MARK: - Exchange helpers

    fileprivate static func nfx_exchangeInstanceMethod(_ original: Selector, with replacement: Selector) {
        // the concrete class behind URLSessionConfiguration.default (a private subclass)
        let concreteClass: AnyClass = object_getClass(URLSessionConfiguration.default) ?? URLSessionConfiguration.self
        guard let originalMethod = class_getInstanceMethod(concreteClass, original),
              let replacementMethod = class_getInstanceMethod(concreteClass, replacement) else {
            NFXLog.interception.fault("Could not swizzle \(NSStringFromSelector(original), privacy: .public)")
            assertionFailure("netfox: could not swizzle \(original)")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }

    fileprivate static func nfx_exchangeClassMethod(_ original: Selector, with replacement: Selector) {
        guard let originalMethod = class_getClassMethod(URLSessionConfiguration.self, original),
              let replacementMethod = class_getClassMethod(URLSessionConfiguration.self, replacement) else {
            NFXLog.interception.fault("Could not swizzle \(NSStringFromSelector(original), privacy: .public)")
            assertionFailure("netfox: could not swizzle \(original)")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}
