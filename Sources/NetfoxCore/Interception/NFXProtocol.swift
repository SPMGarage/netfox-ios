//
//  NFXProtocol.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//
//  The URLProtocol netfox registers. Each intercepted request is sent again on
//  one shared internal URLSession (see NFXSessionRouter) and every callback is
//  forwarded to the URL loading system.
//
//  URLProtocol's Sendable conformance is unavailable while URLSession delegates
//  must be Sendable, so this class is not a session delegate itself.
//

import Foundation

final class NFXProtocol: URLProtocol {

    /// Requests carrying this property are netfox's own and are never captured.
    static let internalKey = "com.netfox.NFXInternal"

    /// Set in startLoading and read in stopLoading; both run on the protocol's client thread.
    private var capture: NFXCaptureTask?

    override class func canInit(with request: URLRequest) -> Bool {
        shouldCapture(request)
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        if task is URLSessionWebSocketTask {
            return false
        }
        // currentRequest can still be nil here; fall back to originalRequest
        guard let request = task.currentRequest ?? task.originalRequest else { return false }
        return shouldCapture(request)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let capture = NFXCaptureTask(owner: self, request: request)
        self.capture = capture
        capture.resume()
    }

    override func stopLoading() {
        capture?.stop()
    }

    // MARK: - Request filtering

    /// Whether netfox should capture `request`. Called on CFNetwork threads.
    static func shouldCapture(_ request: URLRequest) -> Bool {
        let settings = NFXInterceptionSettings.shared
        guard settings.isEnabled,
              URLProtocol.property(forKey: internalKey, in: request) == nil,
              let url = request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return !settings.shouldIgnore(url)
    }

    // MARK: - Internal marker

    /// A copy of `request` that netfox will not capture.
    static func markedAsInternal(_ request: URLRequest) -> URLRequest {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else { return request }
        URLProtocol.setProperty(true, forKey: internalKey, in: mutable)
        return mutable as URLRequest
    }

    /// A copy of `request` without netfox's marker (redirect targets go back to the app's session).
    static func removingInternalMark(_ request: URLRequest) -> URLRequest {
        guard URLProtocol.property(forKey: internalKey, in: request) != nil,
              let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.removeProperty(forKey: internalKey, in: mutable)
        return mutable as URLRequest
    }
}
