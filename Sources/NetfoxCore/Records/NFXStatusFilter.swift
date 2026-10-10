//
//  NFXStatusFilter.swift
//  netfox
//
//  B1: status code filter model.
//

import Foundation

/// B1: filters the request list by HTTP status class.
package enum NFXStatusFilter: String, CaseIterable, Sendable, Hashable, Identifiable {
    case all
    case success
    case redirection
    case clientError
    case serverError

    package var id: String { rawValue }

    /// Display name: "All", "2xx", "3xx", "4xx" or "5xx".
    package var title: String {
        switch self {
        case .all: "All"
        case .success: "2xx"
        case .redirection: "3xx"
        case .clientError: "4xx"
        case .serverError: "5xx"
        }
    }

    /// The status codes this filter keeps; nil for ``all``.
    package var statusRange: ClosedRange<Int>? {
        switch self {
        case .all: nil
        case .success: 200...299
        case .redirection: 300...399
        case .clientError: 400...499
        case .serverError: 500...599
        }
    }

    /// Whether a record passes the filter.
    ///
    /// Records without a response (network errors, cancellations) always pass, so
    /// failures stay visible whatever filter is selected (same as netfox 3.x).
    package func matches(_ record: NFXRecord) -> Bool {
        guard let statusRange, let status = record.statusCode else { return true }
        return statusRange.contains(status)
    }
}
