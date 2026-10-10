//
//  NFXHTTPModelManager.swift
//  netfox
//
//  Copyright © 2016 netfox. All rights reserved.
//

import Foundation
import Combine
#if os(iOS)
import UIKit
#endif


final class NFXHTTPModelManager: NSObject, ObservableObject {

    static let shared = NFXHTTPModelManager()

    // Keep custom Publisher for OSX compatibility (used by NFXListController base + NFXStatisticsController)
    let publisher = Publisher<[NFXHTTPModel]>()

    /// Not thread safe. Use only from main thread/queue
    @Published private(set) var models = [NFXHTTPModel]() {
        didSet {
            notifySubscribers()
        }
    }

    /// Not thread safe. Use only from main thread/queue
    @Published var filters = [Bool](repeating: true, count: HTTPModelShortType.allCases.count) {
        didSet {
            notifySubscribers()
        }
    }

    /// Status code filter range (B1)
    @Published var statusCodeFilter: StatusCodeFilter = .all

    /// Pinned request hashes (B9, in-memory only, clears on restart)
    @Published var pinnedHashes = Set<String>()

    // MARK: - Feature Toggles

    /// C1: Group requests by URL host in the list
    @Published var isGroupingEnabled = false

    /// D4: Log intercepted requests to os.Logger
    @Published var isConsoleLoggingEnabled = false

    /// D6: Capture and display TLS certificate info
    @Published var isCertInfoEnabled = true

    /// E2: Haptic feedback on new request
    @Published var isHapticEnabled = false

    /// E4: iPad two-column split view layout
    @Published var isIPadSplitEnabled = true

    /// Not thread safe. Use only from main thread/queue
    var filteredModels: [NFXHTTPModel] {
        let filteredTypes = getCachedFilterTypes()
        var result = models.filter { filteredTypes.contains($0.shortType) }

        // Apply status code filter (B1)
        switch statusCodeFilter {
        case .all:
            break
        case .range(let low, let high):
            result = result.filter { model in
                guard let status = model.responseStatus else { return true }
                return status >= low && status <= high
            }
        }

        return result
    }

    /// Thread safe
    func add(_ obj: NFXHTTPModel) {
        DispatchQueue.main.async {
            self.models.insert(obj, at: 0)

            // E2: Haptic feedback on new request
            #if os(iOS)
            if self.isHapticEnabled {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            #endif
        }
    }

    /// Not thread safe. Use only from main thread/queue
    func clear() {
        models.removeAll()
        pinnedHashes.removeAll()
    }

    /// B9: Toggle pin state for a request
    func togglePin(_ model: NFXHTTPModel) {
        if pinnedHashes.contains(model.randomHash) {
            pinnedHashes.remove(model.randomHash)
        } else {
            pinnedHashes.insert(model.randomHash)
        }
    }

    /// B9: Check if a request is pinned
    func isPinned(_ model: NFXHTTPModel) -> Bool {
        return pinnedHashes.contains(model.randomHash)
    }

    private func getCachedFilterTypes() -> [HTTPModelShortType] {
        return filters
            .enumerated()
            .compactMap { $1 ? HTTPModelShortType.allCases[$0] : nil }
    }

    private func notifySubscribers() {
        if publisher.hasSubscribers {
            publisher(filteredModels)
        }
    }

}

// MARK: - Status Code Filter (B1)

enum StatusCodeFilter: Equatable {
    case all
    case range(Int, Int)

    var label: String {
        switch self {
        case .all: return "All"
        case .range(let low, _):
            switch low {
            case 200: return "2xx"
            case 300: return "3xx"
            case 400: return "4xx"
            case 500: return "5xx"
            default: return "\(low)+"
            }
        }
    }

    static let options: [StatusCodeFilter] = [
        .all,
        .range(200, 299),
        .range(300, 399),
        .range(400, 499),
        .range(500, 599)
    ]
}
