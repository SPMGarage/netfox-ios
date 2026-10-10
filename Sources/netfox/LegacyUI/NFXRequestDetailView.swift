//
//  NFXRequestDetailView.swift
//  netfox
//
//  SwiftUI replacement for NFXDetailsController_iOS.
//  Includes segmented tabs (Info/Request/Response), share actions,
//  B5 (Replay), B7 (Metrics timeline in Info tab).
//

#if os(iOS)

import SwiftUI

struct NFXRequestDetailView: View {
    let model: NFXHTTPModel
    @ObservedObject private var manager = NFXHTTPModelManager.shared

    @State private var selectedTab = 0
    @State private var showShareSheet = false
    @State private var shareContent = ""
    @State private var showCurlCopied = false
    @State private var showActionSheet = false

    // B5: Replay
    @State private var showReplayResult = false
    @State private var replayModel: NFXHTTPModel?
    @State private var isReplaying = false

    // B6: Diff
    @State private var showDiffPicker = false


    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Tab", selection: $selectedTab) {
                Text("Info").tag(0)
                Text("Request").tag(1)
                Text("Response").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Tab content
            TabView(selection: $selectedTab) {
                infoTab.tag(0)
                requestTab.tag(1)
                responseTab.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        shareContent = NFXTextFormatter.shareLog(for: model, full: false)
                        showShareSheet = true
                    } label: {
                        Label("Simple Log", systemImage: "doc.text")
                    }

                    Button {
                        shareContent = NFXTextFormatter.shareLog(for: model, full: true)
                        showShareSheet = true
                    } label: {
                        Label("Full Log", systemImage: "doc.richtext")
                    }

                    if model.requestCurl != nil {
                        Button {
                            UIPasteboard.general.string = model.requestCurl
                            showCurlCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showCurlCopied = false
                            }
                        } label: {
                            Label(showCurlCopied ? "Copied!" : "Copy as cURL", systemImage: "terminal")
                        }
                    }

                    Divider()

                    // B5: Replay button
                    Button {
                        replayRequest()
                    } label: {
                        Label(isReplaying ? "Replaying..." : "Replay Request", systemImage: "arrow.clockwise")
                    }
                    .disabled(isReplaying)

                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareContent])
        }
        .sheet(isPresented: $showDiffPicker) {
            NFXDiffPickerSheet(sourceModel: model)
        }
        .background(
            NavigationLink(
                isActive: $showReplayResult,
                destination: {
                    if let replayModel = replayModel {
                        NFXRequestDetailView(model: replayModel)
                    }
                },
                label: { EmptyView() }
            )
            .hidden()
        )
    }

    // MARK: - Info Tab

    private var infoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NFXAttributedTextView(
                    attributedText: NFXTextFormatter.infoString(for: model),
                    onLinkTapped: { _ in }
                )

                // B7: Metrics timeline (if available)
                if let metrics = model.taskMetrics {
                    NFXMetricsView(metrics: metrics)
                }

                // D6: Certificate info (if available and enabled)
                if manager.isCertInfoEnabled, let certInfo = model.certificateInfo {
                    NFXCertificateView(certInfo: certInfo)
                }
            }
            .padding()
        }
    }

    // MARK: - Request Tab

    private var requestTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NFXAttributedTextView(
                    attributedText: NFXTextFormatter.requestString(for: model),
                    onLinkTapped: { link in
                        // Handle [URL] tap - handled via NavigationLink below
                    }
                )

                // Show body button for large payloads
                if let bodyLength = model.requestBodyLength, bodyLength > 1024 {
                    NavigationLink {
                        NFXBodyView(model: model, bodyType: .request)
                    } label: {
                        Text("Show request body")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.NFXOrangeColor()))
                            .cornerRadius(8)
                    }
                }

                // URL query items link
                if let queryItems = model.requestURLQueryItems, !queryItems.isEmpty {
                    NavigationLink {
                        NFXURLQueryView(queryItems: queryItems)
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("View URL Query Parameters (\(queryItems.count))")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color(UIColor.NFXOrangeColor()))
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Response Tab

    private var responseTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NFXAttributedTextView(
                    attributedText: NFXTextFormatter.responseString(for: model),
                    onLinkTapped: { _ in }
                )

                // Show body button for large payloads
                if let bodyLength = model.responseBodyLength, bodyLength > 1024 {
                    NavigationLink {
                        NFXBodyView(model: model, bodyType: .response)
                    } label: {
                        Text("Show response body")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.NFXOrangeColor()))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - B5: Replay Request

    private func replayRequest() {
        guard let urlString = model.requestURL,
              let url = URL(string: urlString) else { return }

        isReplaying = true

        var request = URLRequest(url: url)
        request.httpMethod = model.requestMethod
        request.timeoutInterval = TimeInterval(model.requestTimeout ?? "30") ?? 30

        // Restore headers
        if let headers = model.requestHeaders {
            for (key, value) in headers {
                request.setValue("\(value)", forHTTPHeaderField: "\(key)")
            }
        }

        // Restore body
        let bodyString = model.getRequestBody()
        if !bodyString.isEmpty {
            request.httpBody = bodyString.data(using: .utf8)
        }

        // Mark as internal so NFXProtocol intercepts it normally
        let task = URLSession.shared.dataTask(with: request) { [self] data, response, error in
            DispatchQueue.main.async {
                isReplaying = false

                if let error = error {
                    print("[NFX Replay]: Error - \(error.localizedDescription)")
                    return
                }

                // The replayed request will be captured by NFXProtocol automatically
                // since it goes through URLSession.shared which has our swizzled config.
                // No need to manually create a model.
                print("[NFX Replay]: Completed, check the request list for the new entry")
            }
        }
        task.resume()
    }
}

// MARK: - Diff Picker Sheet (B6)

struct NFXDiffPickerSheet: View {
    let sourceModel: NFXHTTPModel
    @ObservedObject private var manager = NFXHTTPModelManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(manager.filteredModels.enumerated()), id: \.element.randomHash) { _, model in
                    if model.randomHash != sourceModel.randomHash {
                        NavigationLink {
                            NFXDiffView(leftModel: sourceModel, rightModel: model)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.requestMethod ?? "-")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(model.requestURL ?? "-")
                                    .font(.system(size: 13))
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Compare with...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#endif
