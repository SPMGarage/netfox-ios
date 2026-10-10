//
//  NFXDeviceInfoView.swift
//  netfox
//
//  App and device details. P2-9: the public IP is looked up only after a tap.
//

#if os(iOS)
import NetfoxCore
import SwiftUI
import UIKit

struct NFXDeviceInfoView: View {

    private enum PublicIPState: Equatable {
        case idle
        case loading
        case loaded(String)
        case failed
    }

    @State private var publicIP = PublicIPState.idle

    var body: some View {
        List {
            Section("App") {
                NFXValueRow(title: "Name", value: NFXDeviceInfo.appName)
                NFXValueRow(title: "Version", value: "\(NFXDeviceInfo.appVersion) (\(NFXDeviceInfo.appBuild))")
                NFXValueRow(
                    title: "Bundle Identifier",
                    value: NFXDeviceInfo.bundleIdentifier,
                    layout: .stacked,
                    isMonospaced: true
                )
            }
            Section("Device") {
                NFXValueRow(title: "System", value: NFXDeviceInfo.systemVersion)
                NFXValueRow(title: "Model", value: NFXDeviceInfo.modelIdentifier)
                NFXValueRow(title: "Screen", value: NFXDeviceInfo.screenResolution(of: Self.activeScene))
            }
            Section {
                publicIPRow
            } header: {
                Text("Network")
            } footer: {
                Text(
                    "The lookup asks api.ipify.org for this device's public address. "
                        + "netfox does not capture that request."
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Device Info")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var publicIPRow: some View {
        switch publicIP {
        case .idle, .failed:
            Button("Look Up Public IP Address", systemImage: "network") {
                lookUpPublicIP()
            }
            if publicIP == .failed {
                Label(
                    "The lookup failed. Check the connection and try again.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                    .foregroundStyle(Color.nfxRed)
            }
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text("Looking up\u{2026}")
            }
        case .loaded(let address):
            NFXValueRow(title: "Public IP Address", value: address, isMonospaced: true)
        }
    }

    private func lookUpPublicIP() {
        publicIP = .loading
        Task {
            let address = await NFXDeviceInfo.publicIPAddress()
            publicIP = address.map(PublicIPState.loaded) ?? .failed
        }
    }

    /// The foreground scene that shows the inspector; its screen gives the resolution.
    private static var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
#endif
