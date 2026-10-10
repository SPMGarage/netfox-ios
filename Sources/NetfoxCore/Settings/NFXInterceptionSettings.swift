//
//  NFXInterceptionSettings.swift
//  netfox
//
//  P1-2: every value the interception path reads on CFNetwork threads lives here,
//  behind one lock. The UI and the public NFX facade write it from any thread.
//

import Foundation
import os

/// Thread-safe settings for the interception path.
///
/// `NFXProtocol.canInit`, the swizzled `protocolClasses` getter and the session
/// router read these values on arbitrary threads, so every access goes through
/// one `OSAllocatedUnfairLock`.
package final class NFXInterceptionSettings: Sendable {

    /// The instance the interception path reads.
    package static let shared = NFXInterceptionSettings()

    private struct State: Sendable {
        var isEnabled = false
        var ignoredPrefixes: [String] = []
        var ignoredRegexes: [NSRegularExpression] = []
        var cachePolicy: URLCache.StoragePolicy = .notAllowed
        var isConsoleLoggingEnabled = false
        var isCertificateInfoEnabled = true
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Creates an independent settings object. The app uses ``shared``.
    package init() {}

    // MARK: - Interception switch

    /// Whether intercepted requests are captured. `canInit` returns false while this is off.
    package var isEnabled: Bool {
        get { state.withLock { $0.isEnabled } }
        set { state.withLock { $0.isEnabled = newValue } }
    }

    // MARK: - Ignore rules

    /// Requests whose absolute URL starts with any of these strings are not captured.
    package var ignoredPrefixes: [String] {
        state.withLock { $0.ignoredPrefixes }
    }

    /// The regex patterns currently used to skip requests.
    package var ignoredPatterns: [String] {
        state.withLock { $0.ignoredRegexes.map(\.pattern) }
    }

    /// Adds URL prefixes that should not be captured.
    package func addIgnoredPrefixes(_ prefixes: [String]) {
        let usable = prefixes.filter { !$0.isEmpty }
        guard !usable.isEmpty else { return }
        state.withLock { $0.ignoredPrefixes.append(contentsOf: usable) }
    }

    /// Compiles and adds regex patterns. Invalid patterns are logged and skipped.
    ///
    /// - Returns: the patterns that failed to compile (empty when all were valid).
    @discardableResult
    package func addIgnoredPatterns(_ patterns: [String]) -> [String] {
        var compiled: [NSRegularExpression] = []
        var invalid: [String] = []
        for pattern in patterns {
            do {
                compiled.append(try NSRegularExpression(pattern: pattern))
            } catch {
                invalid.append(pattern)
                NFXLog.lifecycle.error("Ignoring invalid URL regex \(pattern, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        if !compiled.isEmpty {
            let additions = compiled
            state.withLock { $0.ignoredRegexes.append(contentsOf: additions) }
        }
        return invalid
    }

    /// Whether `url` matches an ignore prefix or regex.
    package func shouldIgnore(_ url: URL) -> Bool {
        let absolute = url.absoluteString
        let (prefixes, regexes) = state.withLock { ($0.ignoredPrefixes, $0.ignoredRegexes) }
        if prefixes.contains(where: { absolute.hasPrefix($0) }) {
            return true
        }
        let range = NSRange(absolute.startIndex..., in: absolute)
        return regexes.contains { $0.firstMatch(in: absolute, options: [], range: range) != nil }
    }

    // MARK: - Cache policy

    /// The cache storage policy reported to the URL loading system for every response.
    package var cachePolicy: URLCache.StoragePolicy {
        get { state.withLock { $0.cachePolicy } }
        set { state.withLock { $0.cachePolicy = newValue } }
    }

    // MARK: - Feature switches read by the interception path

    /// D4: log every captured request to the unified log.
    package var isConsoleLoggingEnabled: Bool {
        get { state.withLock { $0.isConsoleLoggingEnabled } }
        set { state.withLock { $0.isConsoleLoggingEnabled = newValue } }
    }

    /// D6: capture the server certificate chain of HTTPS requests.
    package var isCertificateInfoEnabled: Bool {
        get { state.withLock { $0.isCertificateInfoEnabled } }
        set { state.withLock { $0.isCertificateInfoEnabled = newValue } }
    }

    /// Restores every setting to its default value. Used by tests.
    package func reset() {
        state.withLock { $0 = State() }
    }
}
