//
//  NFXRootView.swift
//  netfox
//
//  E4: Root view that chooses between iPad split layout and iPhone stack layout.
//  Uses NavigationView with .stack on iPhone and sidebar+detail on iPad.
//

#if os(iOS)

import SwiftUI

struct NFXRootView: View {
    @ObservedObject private var manager = NFXHTTPModelManager.shared

    var body: some View {
        if isIPad && manager.isIPadSplitEnabled {
            iPadSplitView
        } else {
            // Default stack navigation for iPhone (or iPad with split disabled)
            NavigationView {
                NFXRequestListView()
            }
            .navigationViewStyle(.stack)
        }
    }

    // MARK: - iPad Split View

    private var iPadSplitView: some View {
        NavigationView {
            NFXRequestListView()
            // Default detail placeholder when nothing is selected
            VStack(spacing: 16) {
                Image(systemName: "network")
                    .font(.system(size: 48))
                    .foregroundColor(Color(UIColor.NFXOrangeColor()))
                Text("Select a request")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}

#endif
