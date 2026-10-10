//
//  NFXProtocol.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//

import Foundation
import os

@objc
open class NFXProtocol: URLProtocol {
    static let nfxInternalKey = "com.netfox.NFXInternal"

    private lazy var session: URLSession = {
        // Mark config as internal so the protocolClasses getter swizzle skips NFXProtocol injection
        let config = URLSessionConfiguration.default
        URLSessionConfiguration.markAsNFXInternal(config)
        config.protocolClasses = config.protocolClasses?.filter { $0 != NFXProtocol.self }
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private let model = NFXHTTPModel()
    private var response: URLResponse?
    private var responseData: NSMutableData?

    override open class func canInit(with request: URLRequest) -> Bool {
        return canServeRequest(request)
    }

    override open class func canInit(with task: URLSessionTask) -> Bool {
        if #available(iOS 13.0, macOS 10.15, *) {
            if task is URLSessionWebSocketTask {
                return false
            }
        }

        // iOS 15+ sometimes passes nil currentRequest in canInit — fall back to originalRequest
        guard let request = task.currentRequest ?? task.originalRequest else { return false }
        return canServeRequest(request)
    }

    private class func canServeRequest(_ request: URLRequest) -> Bool {
        guard NFX.sharedInstance().isEnabled() else {
            return false
        }

        guard URLProtocol.property(forKey: NFXProtocol.nfxInternalKey, in: request) == nil,
              let url = request.url,
              (url.absoluteString.hasPrefix("http") || url.absoluteString.hasPrefix("https")) else {
            return false
        }

        let absoluteString = url.absoluteString
        guard !NFX.sharedInstance().getIgnoredURLs().contains(where: { absoluteString.hasPrefix($0) }) else {
            return false
        }

        let regexMatches = NFX.sharedInstance().getIgnoredURLsRegexes()
            .contains { $0.matches(url.absoluteString) }

        guard !regexMatches else {
            return false
        }

        return true
    }

    override open func startLoading() {
        model.saveRequest(request)

        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: NFXProtocol.nfxInternalKey, in: mutableRequest)
        session.dataTask(with: mutableRequest as URLRequest).resume()
    }

    override open func stopLoading() {
        session.getTasksWithCompletionHandler { dataTasks, _, _ in
            dataTasks.forEach { $0.cancel() }
            self.session.invalidateAndCancel()
        }
    }

    override open class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
}

extension NFXProtocol: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseData?.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        responseData = NSMutableData()

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: NFX.swiftSharedInstance.cacheStoragePolicy)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            if let error = error {
                client?.urlProtocol(self, didFailWithError: error)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        }

        guard let request = task.originalRequest else {
            return
        }

        model.saveRequestBody(request)
        model.logRequest(request)

        if error != nil {
            model.saveErrorResponse()
        } else if let response = response {
            let data = (responseData ?? NSMutableData()) as Data
            model.saveResponse(response, data: data)
        }

        // D4: Console logging
        NFXProtocol.logToConsoleIfNeeded(model: model)

        NFXHTTPModelManager.shared.add(model)
    }

    // MARK: - D4: Console Logging

    @available(iOS 14.0, macOS 11.0, *)
    private static let nfxLogger = Logger(subsystem: "netfox", category: "network")

    private static func logToConsoleIfNeeded(model: NFXHTTPModel) {
        guard NFXHTTPModelManager.shared.isConsoleLoggingEnabled else { return }
        let method = model.requestMethod ?? "?"
        let status = model.responseStatus ?? 0
        let url = model.requestURL ?? "?"
        let duration: String
        if let interval = model.timeInterval {
            duration = String(format: "%.0fms", interval * 1000)
        } else {
            duration = "?ms"
        }

        let message = "[NFX] \(method) \(status) \(url) (\(duration))"

        if #available(iOS 14.0, macOS 11.0, *) {
            switch status {
            case 200..<300:
                nfxLogger.info("\(message, privacy: .public)")
            case 400..<500:
                nfxLogger.warning("\(message, privacy: .public)")
            case 500..<600:
                nfxLogger.error("\(message, privacy: .public)")
            default:
                nfxLogger.info("\(message, privacy: .public)")
            }
        } else {
            NSLog("%@", message)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {

        let updatedRequest: URLRequest
        if URLProtocol.property(forKey: NFXProtocol.nfxInternalKey, in: request) != nil {
            let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
            URLProtocol.removeProperty(forKey: NFXProtocol.nfxInternalKey, in: mutableRequest)
            updatedRequest = mutableRequest as URLRequest
        } else {
            updatedRequest = request
        }

        client?.urlProtocol(self, wasRedirectedTo: updatedRequest, redirectResponse: response)
        completionHandler(updatedRequest)
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // D6: Capture TLS certificate info before forwarding the challenge
        #if os(iOS)
        if NFXHTTPModelManager.shared.isCertInfoEnabled,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            model.certificateInfo = NFXCertificateInfo(from: serverTrust)
        }
        #endif

        let wrappedChallenge = URLAuthenticationChallenge(authenticationChallenge: challenge, sender: NFXAuthenticationChallengeSender(handler: completionHandler))
        client?.urlProtocol(self, didReceive: wrappedChallenge)
    }

    #if !os(OSX)
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        client?.urlProtocolDidFinishLoading(self)
    }
    #endif
}
