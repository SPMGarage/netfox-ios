//
//  NFXSettingsView.swift
//  netfox
//
//  SwiftUI replacement for NFXSettingsController_iOS.
//  Includes B1 (status code filter), B4 (HAR export).
//

#if os(iOS)

import SwiftUI
import MessageUI

struct NFXSettingsView: View {
    @ObservedObject private var manager = NFXHTTPModelManager.shared

    @State private var loggingEnabled = NFX.sharedInstance().isEnabled()
    @State private var showClearConfirmation = false
    @State private var showMailCompose = false
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    private let nfxVersionString = "netfox - \(nfxVersion)"
    private let nfxURL = "https://github.com/azimxxm/netfox-ios"

    var body: some View {
        Form {
            // Logging toggle
            Section {
                Toggle("Logging", isOn: $loggingEnabled)
                    .tint(Color(UIColor.NFXOrangeColor()))
                    .onChange(of: loggingEnabled) { newValue in
                        if newValue {
                            NFX.sharedInstance().enable()
                        } else {
                            NFX.sharedInstance().disable()
                        }
                    }
            }

            // B1: Status code filter
            Section(header: Text("Status Code Filter")) {
                ForEach(Array(StatusCodeFilter.options.enumerated()), id: \.offset) { _, filter in
                    Button {
                        manager.statusCodeFilter = filter
                    } label: {
                        HStack {
                            Text(filter.label)
                                .foregroundColor(.primary)
                            Spacer()
                            if manager.statusCodeFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(UIColor.NFXOrangeColor()))
                            }
                        }
                    }
                }
            }

            // Feature toggles
            Section(header: Text("Features")) {
                Toggle("Group by Host", isOn: $manager.isGroupingEnabled)
                    .tint(Color(UIColor.NFXOrangeColor()))

                Toggle("Console Logging", isOn: $manager.isConsoleLoggingEnabled)
                    .tint(Color(UIColor.NFXOrangeColor()))

                Toggle("Certificate Info", isOn: $manager.isCertInfoEnabled)
                    .tint(Color(UIColor.NFXOrangeColor()))

                Toggle("Haptic on Request", isOn: $manager.isHapticEnabled)
                    .tint(Color(UIColor.NFXOrangeColor()))

                // E4: Only show iPad split toggle on iPad
                if UIDevice.current.userInterfaceIdiom == .pad {
                    Toggle("iPad Split View", isOn: $manager.isIPadSplitEnabled)
                        .tint(Color(UIColor.NFXOrangeColor()))
                }
            }

            // Response type filters
            Section(
                header: Text("Response Type Filters"),
                footer: Text("Select the types of responses that you want to see")
            ) {
                ForEach(Array(HTTPModelShortType.allCases.enumerated()), id: \.offset) { index, type in
                    Button {
                        manager.filters[index].toggle()
                    } label: {
                        HStack {
                            Text(type.rawValue)
                                .foregroundColor(.primary)
                            Spacer()
                            if manager.filters[index] {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color(UIColor.NFXOrangeColor()))
                            }
                        }
                    }
                }
            }

            // Navigation links
            Section {
                NavigationLink(destination: NFXStatisticsView()) {
                    Label("Statistics", systemImage: "chart.bar")
                }
                NavigationLink(destination: NFXInfoView()) {
                    Label("Device Info", systemImage: "info.circle")
                }
                NavigationLink(destination: NFXWebSocketView()) {
                    Label("WebSocket Messages", systemImage: "antenna.radiowaves.left.and.right")
                }
            }

            // Actions
            Section {
                // Share session logs
                Button {
                    if MFMailComposeViewController.canSendMail() {
                        showMailCompose = true
                    } else {
                        // Fallback to share sheet with session log
                        if let logData = NFX.sharedInstance().getSessionLog(),
                           let logString = String(data: logData, encoding: .utf8) {
                            shareURL = nil
                            showShareSheet = true
                            // Use a temp approach - share the string
                            UIPasteboard.general.string = logString
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Share Session Logs")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(UIColor.NFXGreenColor()))
                        Spacer()
                    }
                }

                // B4: HAR Export
                Button {
                    if let harURL = NFXHARExporter.exportToFile(from: manager.models) {
                        shareURL = harURL
                        showShareSheet = true
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Export as HAR")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(UIColor.systemBlue))
                        Spacer()
                    }
                }

                // Clear data
                Button {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Clear Data")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(UIColor.NFXRedColor()))
                        Spacer()
                    }
                }
            }

            // Version footer
            Section {
                VStack(spacing: 4) {
                    Text(nfxVersionString)
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.NFXOrangeColor()))

                    Button {
                        if let url = URL(string: nfxURL) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text(nfxURL)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear data?", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                NFX.sharedInstance().clearOldData()
                NFXWebSocketLogger.shared.clear()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showMailCompose) {
            let logData = try? Data(contentsOf: NFXPath.sessionLogURL)
            MailComposeView(
                subject: "netfox log - Session Log \(formattedDate())",
                attachmentData: logData,
                attachmentFileName: NFXPath.sessionLogName,
                isPresented: $showMailCompose
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

#endif
