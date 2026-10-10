//
//  NFXRoute.swift
//  netfox
//
//  Value-based navigation: every pushed screen is an NFXRoute.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// A screen pushed onto a navigation stack. Records are referenced by id, because
/// a record's value is replaced when late metrics arrive.
nonisolated enum NFXRoute: Hashable, Sendable {
    case record(UUID)
    case body(UUID, NFXBodyPart)
    case queryItems(UUID)
    case settings
    case statistics
    case deviceInfo
    case webSocket
}

/// The screen of a route.
struct NFXRouteView: View {
    let route: NFXRoute

    var body: some View {
        switch route {
        case .record(let id):
            NFXRequestDetailView(recordID: id)
        case .body(let id, let part):
            NFXBodyView(recordID: id, part: part)
        case .queryItems(let id):
            NFXQueryItemsView(recordID: id)
        case .settings:
            NFXSettingsView()
        case .statistics:
            NFXStatisticsView()
        case .deviceInfo:
            NFXDeviceInfoView()
        case .webSocket:
            NFXWebSocketView()
        }
    }
}

extension View {
    /// Registers the destination of every ``NFXRoute`` on the enclosing navigation stack.
    func nfxRouteDestinations() -> some View {
        navigationDestination(for: NFXRoute.self) { route in
            NFXRouteView(route: route)
        }
    }
}
#endif
