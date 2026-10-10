//
//  NFX.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//
//  The public entry point. Every method is safe to call from any thread:
//  state sits behind a lock, and UI work hops to the main actor.
//

import Foundation
import NetfoxCore
import os
#if os(iOS)
import UIKit
#endif

/// netfox: captures every HTTP(S) request of the app and shows them in an in-app inspector.
///
/// ```swift
/// NFX.shared.start()   // from the app delegate or App.init
/// NFX.shared.show()    // or shake the device
/// ```
///
/// All methods are thread-safe. `show()`, `hide()` and `toggle()` run on the
/// main thread: synchronously when called there, otherwise on its next turn.
@objc
public nonisolated final class NFX: NSObject, Sendable {

    /// How the inspector is opened.
    @objc
    public enum ENFXGesture: Int, Sendable {
        /// Shaking the device toggles the inspector.
        case shake
        /// Only `show()`, `hide()` and `toggle()` open and close it.
        case custom
    }

    private struct State: Sendable {
        var isStarted = false
        var gesture = ENFXGesture.shake
    }

    /// The shared instance.
    @objc public static let shared = NFX()

    /// The netfox release, e.g. "4.0.0".
    public static let version = NFXBuildInfo.version

    private let state = OSAllocatedUnfairLock(initialState: State())

    override private init() {
        super.init()
    }

    /// The shared instance, for Objective-C and 3.x callers.
    @objc
    public static func sharedInstance() -> NFX {
        shared
    }

    // MARK: - Lifecycle

    /// Starts capturing requests: registers the URL protocol, hooks every
    /// `URLSessionConfiguration` and clears data from a previous run.
    @objc
    public func start() {
        let wasStarted = state.withLock { state in
            defer { state.isStarted = true }
            return state.isStarted
        }
        guard !wasStarted else {
            NFXLog.lifecycle.notice("netfox \(Self.version, privacy: .public) is already started")
            return
        }
        NFXMainFeed.connect()
        NFXMainFeed.send(.resetRecords)
        NFXInterception.start()
        NFXLog.lifecycle.notice("netfox \(Self.version, privacy: .public) started")
    }

    /// Stops capturing and deletes the captured data.
    @objc
    public func stop() {
        let wasStarted = state.withLock { state in
            defer { state.isStarted = false }
            return state.isStarted
        }
        guard wasStarted else {
            NFXLog.lifecycle.notice("netfox \(Self.version, privacy: .public) is already stopped")
            return
        }
        NFXInterception.stop()
        NFXMainFeed.send(.resetRecords)
        NFXLog.lifecycle.notice("netfox \(Self.version, privacy: .public) stopped")
    }

    /// Whether `start()` was called (and `stop()` was not called since).
    @objc
    public func isStarted() -> Bool {
        state.withLock { $0.isStarted }
    }

    // MARK: - Configuration

    /// The cache storage policy reported for captured responses. Default: `.notAllowed`.
    @objc
    public func setCachePolicy(_ policy: URLCache.StoragePolicy) {
        NFXInterceptionSettings.shared.cachePolicy = policy
    }

    /// Chooses how the inspector opens. Default: `.shake`.
    @objc
    public func setGesture(_ gesture: ENFXGesture) {
        state.withLock { $0.gesture = gesture }
    }

    /// Skips requests whose URL starts with `url`.
    @objc
    public func ignoreURL(_ url: String) {
        NFXInterceptionSettings.shared.addIgnoredPrefixes([url])
    }

    /// Skips requests whose URL starts with any of `urls`.
    @objc
    public func ignoreURLs(_ urls: [String]) {
        NFXInterceptionSettings.shared.addIgnoredPrefixes(urls)
    }

    /// Skips requests whose URL matches the regular expression. An invalid pattern is logged and ignored.
    @objc
    public func ignoreURLsWithRegex(_ regex: String) {
        NFXInterceptionSettings.shared.addIgnoredPatterns([regex])
    }

    /// Skips requests whose URL matches any of the regular expressions. Invalid patterns are logged and ignored.
    @objc
    public func ignoreURLsWithRegexes(_ regexes: [String]) {
        NFXInterceptionSettings.shared.addIgnoredPatterns(regexes)
    }

    /// The plain-text log of this session's requests, or nil when nothing was captured yet.
    @objc
    public func getSessionLog() -> Data? {
        NFXStorage.shared.sessionLogSynchronously()
    }

    // MARK: - Inspector

    /// Opens the inspector on top of the key window. Does nothing before `start()` or on macOS.
    @objc
    public func show() {
        guard isStarted() else { return }
        #if os(iOS)
        Self.onMain { NFXPresenter.shared.show() }
        #endif
    }

    /// Closes the inspector.
    @objc
    public func hide() {
        #if os(iOS)
        Self.onMain { NFXPresenter.shared.hide() }
        #endif
    }

    /// Opens the inspector, or closes it when it is open.
    @objc
    public func toggle() {
        guard isStarted() else { return }
        #if os(iOS)
        Self.onMain { NFXPresenter.shared.toggle() }
        #endif
    }

    #if os(iOS)
    /// Opens the inspector from `rootViewController`, which must be in a window.
    @MainActor
    @objc
    public func show(on rootViewController: UIViewController) {
        guard isStarted() else { return }
        NFXPresenter.shared.show(on: rootViewController)
    }
    #endif

    // MARK: - WebSocket logging (B8)

    /// Logs a text WebSocket message. Call it from any thread, e.g. from a
    /// `URLSessionWebSocketTask.receive()` loop.
    public func logWebSocketText(_ text: String, direction: NFXWebSocketDirection, url: URL) {
        NFXMainFeed.send(.webSocket(.text(text, direction: direction), url))
    }

    /// Logs a binary WebSocket message (its size is shown).
    public func logWebSocketData(_ data: Data, direction: NFXWebSocketDirection, url: URL) {
        NFXMainFeed.send(.webSocket(.binary(data, direction: direction), url))
    }

    /// Logs a WebSocket ping.
    public func logWebSocketPing(direction: NFXWebSocketDirection, url: URL) {
        NFXMainFeed.send(.webSocket(.ping(direction: direction), url))
    }

    // MARK: - Internal

    var selectedGesture: ENFXGesture {
        state.withLock { $0.gesture }
    }

    /// Runs `work` on the main actor: right away when already on the main thread.
    static func onMain(_ work: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            Task { @MainActor in work() }
        }
    }
}

/// Direction of a logged WebSocket message.
public nonisolated enum NFXWebSocketDirection: Sendable {
    /// From the app to the server.
    case sent
    /// From the server to the app.
    case received
}
