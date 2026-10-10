//
//  NFXRootView.swift
//  netfox
//
//  E4: list and detail side by side (NavigationSplitView, which collapses to one
//  stack on iPhone and in Slide Over), or a single NavigationStack when the
//  "Split View" setting is off.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// The inspector's root view. The presenter injects the stores and `nfxDismiss`.
struct NFXRootView: View {
    @Environment(NFXRequestStore.self) private var store

    var body: some View {
        if store.isSplitViewEnabled {
            NFXSplitLayout()
        } else {
            NFXStackLayout()
        }
    }
}

/// One navigation stack: list, then detail, body, settings and so on.
private struct NFXStackLayout: View {
    @State private var path: [NFXRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            NFXRequestListView(selection: nil) {
                path.append(.settings)
            }
            .nfxRouteDestinations()
        }
    }
}

/// Sidebar list and a detail column with its own stack.
private struct NFXSplitLayout: View {
    @Environment(NFXRequestStore.self) private var store
    @State private var selection: UUID?
    @State private var isShowingSettings = false
    @State private var detailPath: [NFXRoute] = []
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            NFXRequestListView(selection: $selection, openSettings: showSettings)
                .navigationSplitViewColumnWidth(min: 300, ideal: 380, max: 480)
        } detail: {
            NavigationStack(path: $detailPath) {
                detailRoot
                    .nfxRouteDestinations()
            }
        }
        .onChange(of: selection) { _, newSelection in
            detailPath.removeAll()
            if newSelection != nil {
                isShowingSettings = false
            }
        }
        .onChange(of: store.records.isEmpty) { _, isEmpty in
            // after "Clear" the detail column goes back to "Select a Request"
            if isEmpty {
                selection = nil
            }
        }
    }

    @ViewBuilder
    private var detailRoot: some View {
        if isShowingSettings {
            NFXSettingsView()
        } else if let selection {
            NFXRequestDetailView(recordID: selection)
                .id(selection)
        } else {
            ContentUnavailableView(
                "Select a Request",
                systemImage: "network",
                description: Text("Pick a request in the list to see its details.")
            )
        }
    }

    /// Settings replace the detail column; in compact width the column is pushed.
    private func showSettings() {
        selection = nil
        detailPath.removeAll()
        isShowingSettings = true
        compactColumn = .detail
    }
}
#endif
