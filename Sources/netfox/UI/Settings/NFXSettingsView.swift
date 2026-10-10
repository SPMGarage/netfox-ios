//
//  NFXSettingsView.swift
//  netfox
//
//  Logging switch, status filter (B1), feature toggles (C1, D4, D6, E2, E4),
//  response type filters, tools (statistics, device info, WebSocket B8), sharing
//  (session log, HAR B4) and clearing data.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// B4: progress of the HAR export.
nonisolated enum NFXHARExportState: Equatable, Sendable {
    case idle
    case exporting
    case ready(URL)
    case failed(String)
}

struct NFXSettingsView: View {
    @Environment(NFXRequestStore.self) private var store
    @Environment(NFXWebSocketStore.self) private var webSocketStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isConfirmingClear = false
    @State private var harExport = NFXHARExportState.idle

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Logging", isOn: $store.isInterceptionEnabled)
            } footer: {
                Text("When off, netfox stops capturing new requests.")
            }
            toolsSection
            Section("Status Code Filter") {
                Picker("Status Code", selection: $store.statusFilter) {
                    ForEach(NFXStatusFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section("Features") {
                Toggle("Group by Host", isOn: $store.isGroupingEnabled)
                Toggle("Console Logging", isOn: $store.isConsoleLoggingEnabled)
                Toggle("Certificate Info", isOn: $store.isCertificateInfoEnabled)
                Toggle("Haptic Feedback", isOn: $store.isHapticEnabled)
                if horizontalSizeClass == .regular {
                    Toggle("Split View", isOn: $store.isSplitViewEnabled)
                }
            }
            Section {
                ForEach(NFXContentKind.allCases) { kind in
                    Toggle(kind.title, isOn: $store.enabledKinds.containing(kind))
                }
            } header: {
                Text("Response Types")
            } footer: {
                Text("Select the types of responses that you want to see.")
            }
            exportSection
            clearSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var toolsSection: some View {
        Section("Tools") {
            NavigationLink(value: NFXRoute.statistics) {
                Label("Statistics", systemImage: "chart.bar.xaxis")
            }
            .accessibilityIdentifier("nfx.settings.statistics")
            NavigationLink(value: NFXRoute.deviceInfo) {
                Label("Device Info", systemImage: "info.circle")
            }
            .accessibilityIdentifier("nfx.settings.deviceInfo")
            NavigationLink(value: NFXRoute.webSocket) {
                Label("WebSocket Messages", systemImage: "antenna.radiowaves.left.and.right")
            }
            .accessibilityIdentifier("nfx.settings.webSocket")
        }
    }

    private var exportSection: some View {
        Section {
            // P1-9: the log is shared as a file; nothing is put on the pasteboard
            ShareLink(item: store.sessionLogURL, preview: SharePreview("netfox session log")) {
                Label("Share Session Log", systemImage: "square.and.arrow.up")
            }
            .disabled(!store.hasRecords)
            .accessibilityIdentifier("nfx.settings.shareLog")
            Button(action: exportHAR) {
                LabeledContent {
                    if harExport == .exporting {
                        ProgressView()
                    }
                } label: {
                    Label("Export as HAR", systemImage: "doc.badge.arrow.up")
                }
            }
            .disabled(!store.hasRecords || harExport == .exporting)
            .accessibilityIdentifier("nfx.settings.exportHAR")
            switch harExport {
            case .ready(let url):
                ShareLink(item: url, preview: SharePreview(url.lastPathComponent)) {
                    Label("Share \(url.lastPathComponent)", systemImage: "square.and.arrow.up.on.square")
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.nfxRed)
            case .idle, .exporting:
                EmptyView()
            }
        } header: {
            Text("Share")
        } footer: {
            Text("Logs and HAR files include headers and bodies, which can contain tokens and personal data.")
        }
    }

    private var clearSection: some View {
        Section {
            Button("Clear Data", systemImage: "trash", role: .destructive) {
                isConfirmingClear = true
            }
            .accessibilityIdentifier("nfx.settings.clear")
            .confirmationDialog(
                "Clear all captured data?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear Data", role: .destructive) {
                    store.clear()
                    webSocketStore.clear()
                    harExport = .idle
                }
            } message: {
                Text("Requests, stored bodies, the session log and WebSocket messages are deleted.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            if let homepage = URL(string: NFXBuildInfo.homepage) {
                Link(destination: homepage) {
                    Label("netfox on GitHub", systemImage: "safari")
                }
            }
        } footer: {
            Text("netfox \(NFX.version)")
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    // MARK: - Actions

    /// B4: writes the HAR file off the main actor, then offers it with a ShareLink.
    private func exportHAR() {
        harExport = .exporting
        Task {
            do {
                harExport = .ready(try await store.exportHAR())
            } catch {
                harExport = .failed("Could not create the HAR file: \(error.localizedDescription)")
            }
        }
    }
}

extension Binding where Value == Set<NFXContentKind> {
    /// A switch for one member of the set.
    func containing(_ kind: NFXContentKind) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.contains(kind) },
            set: { isOn in
                if isOn {
                    wrappedValue.insert(kind)
                } else {
                    wrappedValue.remove(kind)
                }
            }
        )
    }
}
#endif
