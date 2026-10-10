//
//  NFXRequestDetailView.swift
//  netfox
//
//  Info / Request / Response tabs of one request, plus the share menu:
//  simple and full log (ShareLink), copy as cURL, replay (B5).
//

#if os(iOS)
import NetfoxCore
import SwiftUI
import UIKit

/// The tabs of the detail screen. The raw values are the segment titles.
nonisolated enum NFXDetailTab: String, CaseIterable, Identifiable, Sendable {
    case info = "Info"
    case request = "Request"
    case response = "Response"

    var id: Self { self }
}

struct NFXRequestDetailView: View {
    /// The record is looked up on every render: late metrics replace its value.
    let recordID: UUID

    @Environment(NFXRequestStore.self) private var store
    @State private var tab = NFXDetailTab.info
    @State private var replay = NFXReplayState.idle
    @State private var replayedRecordID: UUID?
    @State private var toast: String?

    var body: some View {
        Group {
            if let record = store.record(with: recordID) {
                content(for: record)
                    .toolbar { toolbar(for: record) }
            } else {
                ContentUnavailableView(
                    "Request Not Available",
                    systemImage: "tray",
                    description: Text("This request was removed from the list.")
                )
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $replayedRecordID) { id in
            NFXRequestDetailView(recordID: id)
        }
        .nfxToast($toast)
    }

    private func content(for record: NFXRecord) -> some View {
        List {
            switch tab {
            case .info:
                NFXReplaySection(state: replay, originalID: record.id) { capturedID in
                    replayedRecordID = capturedID
                }
                NFXInfoSections(record: record)
            case .request:
                NFXMessageSections(record: record, part: .request)
            case .response:
                NFXMessageSections(record: record, part: .response)
            }
        }
        .listStyle(.insetGrouped)
        .id(tab)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbar(for record: NFXRecord) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Section", selection: $tab) {
                ForEach(NFXDetailTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("nfx.detail.tabs")
        }
        ToolbarItem(placement: .topBarTrailing) {
            actionsMenu(for: record)
        }
    }

    private func actionsMenu(for record: NFXRecord) -> some View {
        Menu {
            ShareLink(item: NFXRequestLog.summary(of: record), subject: Text("netfox request log")) {
                Label("Share Simple Log", systemImage: "doc.text")
            }
            ShareLink(item: fullLog(for: record), preview: SharePreview("Full Request Log")) {
                Label("Share Full Log", systemImage: "doc.richtext")
            }
            Button("Copy as cURL", systemImage: "terminal") {
                copyCurl(for: record)
            }
            Divider()
            Button("Replay Request", systemImage: "arrow.clockwise") {
                startReplay(of: record)
            }
            .disabled(!NFXReplay.canReplay(record) || replay == .running)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("nfx.detail.share")
    }

    // MARK: - Actions

    /// The full log reads the body files only when the share sheet asks for it.
    private func fullLog(for record: NFXRecord) -> NFXRequestLog {
        NFXRequestLog(
            record: record,
            requestBodyURL: store.bodyFileURL(.request, of: record),
            responseBodyURL: store.bodyFileURL(.response, of: record)
        )
    }

    /// Builds the command off the main actor, then copies it on the user's behalf.
    private func copyCurl(for record: NFXRecord) {
        Task {
            let command = await store.curlCommand(for: record)
            UIPasteboard.general.string = command
            toast = "cURL command copied"
        }
    }

    /// B5: sends the captured request again; netfox captures the replay as a new row.
    private func startReplay(of record: NFXRecord) {
        tab = .info
        replay = .running
        Task {
            let body = await store.body(.request, of: record)
            replay = await NFXReplay.send(record, body: body)
        }
    }
}
#endif
