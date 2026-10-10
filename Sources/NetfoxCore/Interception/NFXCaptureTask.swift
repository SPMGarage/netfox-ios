//
//  NFXCaptureTask.swift
//  netfox
//
//  One intercepted request: the internal data task, the forwarding to the URL
//  loading system and the record that is built from it.
//

import Foundation
import os

// @unchecked Sendable: the mutable state is touched only on the router's serial
// delegate queue (plus init, which happens before resume); `stopFlag` is
// lock-protected and every other stored property is immutable.
final class NFXCaptureTask: @unchecked Sendable {

    private enum Phase {
        case loading
        /// netfox cancelled the internal task after a 3xx hop.
        case redirected
        case finished
    }

    let id: UUID
    let task: URLSessionDataTask

    private let originalRequest: URLRequest
    private let body: NFXRequestBodyCapture
    private let startDate = Date()
    private let router: NFXSessionRouter
    private let settings: NFXInterceptionSettings
    private let storage: NFXStorage
    private let hub: NFXRecordHub
    private let stopFlag = OSAllocatedUnfairLock(initialState: false)
    /// The thread that called startLoading; challenges are forwarded there.
    private let clientThread = NFXClientThread()

    // Router delegate queue only:
    private var owner: NFXProtocol?
    private var response: URLResponse?
    private var responseData = Data()
    private var responseLength = 0
    private var certificate: NFXCertificateInfo?
    private var metrics: NFXRequestMetrics?
    private var publishedRecord: NFXRecord?
    private var phase = Phase.loading

    init(
        owner: NFXProtocol,
        request: URLRequest,
        router: NFXSessionRouter = .shared,
        settings: NFXInterceptionSettings = .shared,
        storage: NFXStorage = .shared,
        hub: NFXRecordHub = .shared
    ) {
        let id = UUID()
        self.id = id
        self.owner = owner
        self.originalRequest = request
        self.router = router
        self.settings = settings
        self.storage = storage
        self.hub = hub
        let body = NFXRequestBodyCapture(request: request, spillFileURL: storage.uploadSpillFileURL(for: id))
        self.body = body
        self.task = router.session.dataTask(with: NFXProtocol.markedAsInternal(body.request))
    }

    // MARK: - Client thread

    func resume() {
        router.register(self)
        task.resume()
    }

    /// stopLoading: the URL loading system no longer wants callbacks for this request.
    func stop() {
        stopFlag.withLock { $0 = true }
        task.cancel() // no effect once the task has completed
    }

    private var isStopped: Bool {
        stopFlag.withLock { $0 }
    }

    /// The protocol and its client, unless the load was stopped.
    private var forwardTarget: (NFXProtocol, any URLProtocolClient)? {
        guard !isStopped, let owner, let client = owner.client else { return nil }
        return (owner, client)
    }

    // MARK: - Delegate queue

    func didReceive(_ response: URLResponse) -> URLSession.ResponseDisposition {
        self.response = response
        if let (owner, client) = forwardTarget {
            client.urlProtocol(owner, didReceive: response, cacheStoragePolicy: settings.cachePolicy)
        }
        return .allow
    }

    func didReceive(_ data: Data) {
        responseLength += data.count
        let room = NFXStorage.maxBodyBytes - responseData.count
        if room > 0 {
            responseData.append(data.prefix(room))
        }
        if let (owner, client) = forwardTarget {
            client.urlProtocol(owner, didLoad: data)
        }
    }

    /// P0-2: records the 3xx hop and hands the redirect to the URL loading system,
    /// which starts a new NFXProtocol for the target. The router then cancels this task.
    func willRedirect(response: HTTPURLResponse, to newRequest: URLRequest) {
        phase = .redirected
        let record = makeRecord(response: response, responseBody: .empty, redirectURL: newRequest.url, error: nil)
        publish(record, responseBody: nil)
        if let (owner, client) = forwardTarget {
            client.urlProtocol(owner, wasRedirectedTo: NFXProtocol.removingInternalMark(newRequest), redirectResponse: response)
            // CustomHTTPProtocol: end this load; the URL loading system runs the redirect in a new
            // protocol. (Finishing with urlProtocolDidFinishLoading instead crashes the loader when
            // the app refuses the redirect; this way the refused task ends with NSUserCancelledError.)
            client.urlProtocol(owner, didFailWithError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        }
    }

    /// P1-6: server trust and client-certificate challenges go to the app's session (so its
    /// certificate pinning still runs); HTTP authentication keeps the default handling.
    func didReceive(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           settings.isCertificateInfoEnabled,
           let trust = space.serverTrust,
           let info = NFXCertificateInfo(trust: trust) {
            certificate = info
            router.rememberCertificate(info, host: space.host, port: space.port)
        }
        // Verified on Xcode 27 / macOS 27: for HTTP authentication (Basic, Digest, NTLM, ...)
        // the app's session consults its delegate but never sends the answer back to a
        // URLProtocol's challenge sender, so a forwarded challenge would hang until the
        // request times out. Those keep the default handling netfox 3.x used (credential
        // storage, URL user/password, otherwise the 401 reaches the app).
        guard Self.forwardedMethods.contains(space.authenticationMethod) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        guard let (owner, client) = forwardTarget else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let sender = NFXAuthenticationChallengeSender(handler: completionHandler)
        let forwarded = URLAuthenticationChallenge(authenticationChallenge: challenge, sender: sender)
        let target = NFXUncheckedSendable(value: owner)
        // the client answers on the thread that calls it, so call it on the client thread
        clientThread.perform { [stopFlag] in
            guard !stopFlag.withLock({ $0 }) else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            client.urlProtocol(target.value, didReceive: forwarded)
        }
    }

    /// Challenges the app's session answers back to netfox: server trust (certificate
    /// pinning keeps working) and client certificates.
    private static let forwardedMethods: Set<String> = [
        NSURLAuthenticationMethodServerTrust,
        NSURLAuthenticationMethodClientCertificate,
    ]

    /// A fresh body stream when the internal session has to resend the body (auth retry).
    func makeBodyStream() -> InputStream? {
        if let url = body.spillFileURL {
            return InputStream(url: url)
        }
        if let data = body.request.httpBody {
            return InputStream(data: data)
        }
        return nil
    }

    /// P2-4: keeps the first metrics callback; later duplicates are ignored.
    ///
    /// - Returns: true when nothing else is expected for this task.
    func didCollect(_ taskMetrics: URLSessionTaskMetrics) -> Bool {
        guard metrics == nil else { return phase != .loading }
        let collected = NFXRequestMetrics(taskMetrics)
        metrics = collected
        if let record = publishedRecord {
            // metrics arrived after the record went out: publish an update
            let updated = record.withMetrics(collected)
            publishedRecord = updated
            storage.publishUpdate(updated, to: hub)
        }
        return phase != .loading
    }

    /// - Returns: true when nothing else is expected for this task (metrics already arrived).
    func didComplete(error: (any Error)?) -> Bool {
        defer {
            if let spill = body.spillFileURL {
                storage.removeFile(at: spill)
            }
        }
        switch phase {
        case .redirected:
            // the cancellation netfox caused after a 3xx hop: no record, no client call
            owner = nil
            return metrics != nil
        case .finished:
            return metrics != nil
        case .loading:
            break
        }
        phase = .finished

        // P2-1: the URL loading system hears about the end before netfox does any work
        if let (owner, client) = forwardTarget {
            if let error {
                client.urlProtocol(owner, didFailWithError: error)
            } else {
                client.urlProtocolDidFinishLoading(owner)
            }
        }
        owner = nil

        let responseBody = NFXBodyInfo(
            length: response == nil ? 0 : responseLength,
            isStored: responseLength > 0,
            isTruncated: responseLength > NFXStorage.maxBodyBytes
        )
        let record = makeRecord(
            response: response,
            responseBody: responseBody,
            redirectURL: nil,
            error: error.map(NFXRecordError.init)
        )
        let data = responseData
        responseData = Data()
        publish(record, responseBody: data)
        return metrics != nil
    }

    // MARK: - Records

    private func makeRecord(response: URLResponse?, responseBody: NFXBodyInfo, redirectURL: URL?, error: NFXRecordError?) -> NFXRecord {
        let http = response as? HTTPURLResponse
        return NFXRecord(
            id: id,
            url: originalRequest.url,
            method: originalRequest.httpMethod ?? "GET",
            requestHeaders: NFXHeader.list(from: originalRequest.allHTTPHeaderFields),
            requestBody: body.info,
            cachePolicy: originalRequest.cachePolicy,
            timeoutInterval: originalRequest.timeoutInterval,
            startDate: startDate,
            endDate: Date(),
            statusCode: http?.statusCode,
            responseHeaders: http.map { NFXHeader.list(from: $0.allHeaderFields) } ?? [],
            responseBody: responseBody,
            redirectURL: redirectURL,
            error: error,
            certificate: settings.isCertificateInfoEnabled ? (certificate ?? router.certificate(for: originalRequest.url)) : nil,
            metrics: metrics
        )
    }

    private func publish(_ record: NFXRecord, responseBody: Data?) {
        publishedRecord = record
        storage.persist(record, requestBody: body.data, responseBody: responseBody, publishTo: hub)
        logToConsoleIfEnabled(record)
    }

    /// D4: opt-in console logging. URLs stay public here because the user turned this on explicitly.
    private func logToConsoleIfEnabled(_ record: NFXRecord) {
        guard settings.isConsoleLoggingEnabled else { return }
        let status = record.statusCode.map(String.init) ?? "ERR"
        let duration = record.duration.map { "\(Int(($0 * 1000).rounded()))ms" } ?? "?ms"
        let message = "[NFX] \(record.method) \(status) \(record.urlString) (\(duration))"
        switch record.statusCode {
        case .some(200..<400):
            NFXLog.console.info("\(message, privacy: .public)")
        case .some(400..<500):
            NFXLog.console.warning("\(message, privacy: .public)")
        default:
            NFXLog.console.error("\(message, privacy: .public)")
        }
    }
}
