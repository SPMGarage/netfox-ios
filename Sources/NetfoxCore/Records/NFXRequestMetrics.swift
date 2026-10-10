//
//  NFXRequestMetrics.swift
//  netfox
//
//  B7 / P2-4: URLSessionTaskMetrics of the internal task, copied into Sendable values.
//

import Foundation
import Security

/// Timing and connection details of one captured request.
package struct NFXRequestMetrics: Sendable, Hashable {

    /// One request/response exchange. A task with an auth retry has several.
    package struct Transaction: Sendable, Hashable {

        /// How the response was obtained.
        package enum FetchType: String, Sendable, Hashable {
            case network
            case serverPush
            case localCache
            case unknown
        }

        package let fetchStartDate: Date?
        package let domainLookupStartDate: Date?
        package let domainLookupEndDate: Date?
        package let connectStartDate: Date?
        package let connectEndDate: Date?
        package let secureConnectionStartDate: Date?
        package let secureConnectionEndDate: Date?
        package let requestStartDate: Date?
        package let requestEndDate: Date?
        package let responseStartDate: Date?
        package let responseEndDate: Date?

        /// ALPN protocol id: "http/1.1", "h2", "h3".
        package let networkProtocolName: String?
        package let remoteAddress: String?
        package let remotePort: Int?
        package let isReusedConnection: Bool
        package let isProxyConnection: Bool
        package let fetchType: FetchType
        /// "TLS 1.3" etc., nil for plain HTTP.
        package let tlsProtocolVersion: String?
        package let requestBodyBytesSent: Int64
        package let responseBodyBytesReceived: Int64

        package init(
            fetchStartDate: Date? = nil,
            domainLookupStartDate: Date? = nil,
            domainLookupEndDate: Date? = nil,
            connectStartDate: Date? = nil,
            connectEndDate: Date? = nil,
            secureConnectionStartDate: Date? = nil,
            secureConnectionEndDate: Date? = nil,
            requestStartDate: Date? = nil,
            requestEndDate: Date? = nil,
            responseStartDate: Date? = nil,
            responseEndDate: Date? = nil,
            networkProtocolName: String? = nil,
            remoteAddress: String? = nil,
            remotePort: Int? = nil,
            isReusedConnection: Bool = false,
            isProxyConnection: Bool = false,
            fetchType: FetchType = .network,
            tlsProtocolVersion: String? = nil,
            requestBodyBytesSent: Int64 = 0,
            responseBodyBytesReceived: Int64 = 0
        ) {
            self.fetchStartDate = fetchStartDate
            self.domainLookupStartDate = domainLookupStartDate
            self.domainLookupEndDate = domainLookupEndDate
            self.connectStartDate = connectStartDate
            self.connectEndDate = connectEndDate
            self.secureConnectionStartDate = secureConnectionStartDate
            self.secureConnectionEndDate = secureConnectionEndDate
            self.requestStartDate = requestStartDate
            self.requestEndDate = requestEndDate
            self.responseStartDate = responseStartDate
            self.responseEndDate = responseEndDate
            self.networkProtocolName = networkProtocolName
            self.remoteAddress = remoteAddress
            self.remotePort = remotePort
            self.isReusedConnection = isReusedConnection
            self.isProxyConnection = isProxyConnection
            self.fetchType = fetchType
            self.tlsProtocolVersion = tlsProtocolVersion
            self.requestBodyBytesSent = requestBodyBytesSent
            self.responseBodyBytesReceived = responseBodyBytesReceived
        }

        init(_ metric: URLSessionTaskTransactionMetrics) {
            self.init(
                fetchStartDate: metric.fetchStartDate,
                domainLookupStartDate: metric.domainLookupStartDate,
                domainLookupEndDate: metric.domainLookupEndDate,
                connectStartDate: metric.connectStartDate,
                connectEndDate: metric.connectEndDate,
                secureConnectionStartDate: metric.secureConnectionStartDate,
                secureConnectionEndDate: metric.secureConnectionEndDate,
                requestStartDate: metric.requestStartDate,
                requestEndDate: metric.requestEndDate,
                responseStartDate: metric.responseStartDate,
                responseEndDate: metric.responseEndDate,
                networkProtocolName: metric.networkProtocolName,
                remoteAddress: metric.remoteAddress,
                remotePort: metric.remotePort,
                isReusedConnection: metric.isReusedConnection,
                isProxyConnection: metric.isProxyConnection,
                fetchType: FetchType(metric.resourceFetchType),
                tlsProtocolVersion: metric.negotiatedTLSProtocolVersion.map(Self.describe),
                requestBodyBytesSent: metric.countOfRequestBodyBytesSent,
                responseBodyBytesReceived: metric.countOfResponseBodyBytesReceived
            )
        }

        private static func describe(_ version: tls_protocol_version_t) -> String {
            switch version {
            case .TLSv10: "TLS 1.0"
            case .TLSv11: "TLS 1.1"
            case .TLSv12: "TLS 1.2"
            case .TLSv13: "TLS 1.3"
            case .DTLSv10: "DTLS 1.0"
            case .DTLSv12: "DTLS 1.2"
            @unknown default: "TLS 0x" + String(version.rawValue, radix: 16)
            }
        }

        // MARK: Phase durations in seconds (nil when the phase did not happen)

        /// Waiting for a connection: fetch start to DNS / connect / request start.
        package var blockedDuration: TimeInterval? {
            guard let fetchStartDate,
                  let next = domainLookupStartDate ?? connectStartDate ?? requestStartDate else { return nil }
            return max(0, next.timeIntervalSince(fetchStartDate))
        }

        package var dnsDuration: TimeInterval? {
            Self.interval(domainLookupStartDate, domainLookupEndDate)
        }

        /// TCP connect including TLS (HAR semantics).
        package var connectDuration: TimeInterval? {
            Self.interval(connectStartDate, connectEndDate)
        }

        package var tlsDuration: TimeInterval? {
            Self.interval(secureConnectionStartDate, secureConnectionEndDate)
        }

        /// Sending the request.
        package var sendDuration: TimeInterval? {
            Self.interval(requestStartDate, requestEndDate)
        }

        /// Waiting for the first response byte (TTFB after the request was sent).
        package var waitDuration: TimeInterval? {
            Self.interval(requestEndDate, responseStartDate)
        }

        /// Receiving the response.
        package var receiveDuration: TimeInterval? {
            Self.interval(responseStartDate, responseEndDate)
        }

        /// HTTP version for HAR, derived from the ALPN id.
        package var httpVersion: String {
            switch networkProtocolName?.lowercased() {
            case "http/1.0": "HTTP/1.0"
            case "http/1.1": "HTTP/1.1"
            case "h2", "h2c": "HTTP/2"
            case "h3": "HTTP/3"
            case let other?: other.uppercased()
            case nil: "HTTP/1.1"
            }
        }

        private static func interval(_ start: Date?, _ end: Date?) -> TimeInterval? {
            guard let start, let end else { return nil }
            return max(0, end.timeIntervalSince(start))
        }
    }

    /// Start and end of the whole task.
    package let taskInterval: DateInterval
    package let redirectCount: Int
    /// Every transaction, in order.
    package let transactions: [Transaction]

    package init(taskInterval: DateInterval, redirectCount: Int = 0, transactions: [Transaction]) {
        self.taskInterval = taskInterval
        self.redirectCount = redirectCount
        self.transactions = transactions
    }

    package init(_ metrics: URLSessionTaskMetrics) {
        self.init(
            taskInterval: metrics.taskInterval,
            redirectCount: metrics.redirectCount,
            transactions: metrics.transactionMetrics.map(Transaction.init)
        )
    }

    /// The transaction that produced the final response.
    package var finalTransaction: Transaction? {
        transactions.last { $0.fetchType == .network } ?? transactions.last
    }

    /// Total task time in seconds.
    package var totalDuration: TimeInterval { taskInterval.duration }
}

extension NFXRequestMetrics.Transaction.FetchType {
    init(_ type: URLSessionTaskMetrics.ResourceFetchType) {
        switch type {
        case .networkLoad: self = .network
        case .serverPush: self = .serverPush
        case .localCache: self = .localCache
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }
}
