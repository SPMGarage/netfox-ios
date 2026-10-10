//
//  NFXSessionRouter.swift
//  netfox
//
//  P1-1: one internal URLSession for every intercepted request, so connections
//  are pooled like in the app's own sessions. Its delegate routes each callback
//  to the NFXCaptureTask that owns the task (the QNSURLSessionDemux pattern from
//  Apple's CustomHTTPProtocol sample).
//

import Foundation
import os

// @unchecked Sendable: every stored property is immutable; the two mutable maps sit
// behind OSAllocatedUnfairLock. Delegate callbacks run serially on `queue`.
final class NFXSessionRouter: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    /// The router of the shared internal session.
    static let shared = NFXSessionRouter()

    /// How long a finished capture waits for late metrics (iOS 18.4+ may deliver them after completion).
    private static let lateMetricsWindow: DispatchTimeInterval = .seconds(10)

    /// Serial queue behind the session's delegate queue. Client callbacks are made from here.
    let queue = DispatchQueue(label: "uz.azimjondev.netfox.router", qos: .userInitiated)

    private let captures = OSAllocatedUnfairLock(initialState: [Int: NFXCaptureTask]())
    /// D6: last certificate seen per "host:port"; reused connections get no new trust challenge.
    private let certificates = OSAllocatedUnfairLock(initialState: [String: NFXCertificateInfo]())

    /// The internal session. Created on first use, never invalidated.
    var session: URLSession {
        NFXInternalSession.shared
    }

    /// The delegate queue handed to the internal session.
    fileprivate func makeDelegateQueue() -> OperationQueue {
        let operationQueue = OperationQueue()
        operationQueue.name = "uz.azimjondev.netfox.router"
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = queue
        return operationQueue
    }

    // MARK: - Capture registry

    func register(_ capture: NFXCaptureTask, for task: URLSessionTask) {
        let identifier = task.taskIdentifier
        captures.withLock { $0[identifier] = capture }
    }

    private func capture(for task: URLSessionTask) -> NFXCaptureTask? {
        captures.withLock { $0[task.taskIdentifier] }
    }

    private func remove(_ task: URLSessionTask) {
        _ = captures.withLock { $0.removeValue(forKey: task.taskIdentifier) }
    }

    /// Keeps a finished capture around for late metrics, then drops it.
    private func removeLater(_ capture: NFXCaptureTask, identifier: Int) {
        queue.asyncAfter(deadline: .now() + Self.lateMetricsWindow) { [captures] in
            captures.withLock { map in
                if map[identifier] === capture {
                    map[identifier] = nil
                }
            }
        }
    }

    // MARK: - Certificates

    func rememberCertificate(_ info: NFXCertificateInfo, host: String, port: Int) {
        certificates.withLock { $0["\(host.lowercased()):\(port)"] = info }
    }

    func certificate(for url: URL?) -> NFXCertificateInfo? {
        guard let url, url.scheme?.lowercased() == "https", let host = url.host() else { return nil }
        let key = "\(host.lowercased()):\(url.port ?? 443)"
        return certificates.withLock { $0[key] }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let capture = capture(for: dataTask) else {
            completionHandler(.cancel)
            return
        }
        completionHandler(capture.didReceive(response))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        capture(for: dataTask)?.didReceive(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let capture = capture(for: task) else {
            completionHandler(nil)
            return
        }
        // P0-2 (CustomHTTPProtocol pattern): record the hop, let the app's session follow
        // the redirect with a new NFXProtocol, and stop this internal task.
        capture.willRedirect(response: response, to: request)
        completionHandler(nil)
        task.cancel()
    }

    // Only the task-level challenge method is implemented on purpose. When a session
    // delegate lacks urlSession(_:didReceive:completionHandler:), URLSession sends
    // connection-level challenges (server trust, client certificates, NTLM, Negotiate)
    // here as well, with the task attached. A session-level method on this shared
    // session would get them without a task, so they could not reach the app that
    // owns the request (its certificate pinning would be skipped).
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let capture = capture(for: task) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        capture.didReceive(challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping @Sendable (InputStream?) -> Void
    ) {
        completionHandler(capture(for: task)?.makeBodyStream())
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let capture = capture(for: task) else { return }
        if capture.didCollect(metrics) {
            remove(task)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let capture = capture(for: task) else { return }
        if capture.didComplete(error: error) {
            remove(task)
        } else {
            removeLater(capture, identifier: task.taskIdentifier)
        }
    }
}

/// Holder of the one internal session (a lazy static is created once, thread-safely).
enum NFXInternalSession {

    /// P1-7: decided by `cookiesStayInTheAppSession` in the tests; see the configuration below.
    static let shared: URLSession = {
        let router = NFXSessionRouter.shared
        return URLSession(
            configuration: makeConfiguration(),
            delegate: router,
            delegateQueue: router.makeDelegateQueue()
        )
    }()

    static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        URLSessionConfiguration.nfx_markAsInternal(configuration)
        // the .default swizzle inserted NFXProtocol; the internal session must not recurse into it
        configuration.protocolClasses = configuration.protocolClasses?.filter { $0 != NFXProtocol.self }
        return configuration
    }
}
