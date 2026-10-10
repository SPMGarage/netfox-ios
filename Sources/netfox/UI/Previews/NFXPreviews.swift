//
//  NFXPreviews.swift
//  netfox
//
//  DEBUG only: Xcode previews of the main inspector screens, using NFXPreviewData.
//

#if DEBUG && os(iOS)
import NetfoxCore
import SwiftUI

#Preview("Inspector") {
    NFXRootView()
        .nfxPreviewEnvironment()
}

#Preview("Request list") {
    NavigationStack {
        NFXRequestListView(selection: nil) {}
            .nfxRouteDestinations()
    }
    .nfxPreviewEnvironment()
}

#Preview("Request row", traits: .sizeThatFitsLayout) {
    List(NFXPreviewData.records) { record in
        NFXRequestRow(record: record, isPinned: record.id == NFXPreviewData.postRecord.id, isNew: true)
    }
    .listStyle(.plain)
    .frame(height: 420)
    .nfxPreviewEnvironment()
}

#Preview("Request detail") {
    NavigationStack {
        NFXRequestDetailView(recordID: NFXPreviewData.jsonRecord.id)
            .nfxRouteDestinations()
    }
    .nfxPreviewEnvironment()
}

#Preview("Response body") {
    NavigationStack {
        NFXBodyView(recordID: NFXPreviewData.jsonRecord.id, part: .response)
    }
    .nfxPreviewEnvironment()
}

#Preview("Settings") {
    NavigationStack {
        NFXSettingsView()
            .nfxRouteDestinations()
    }
    .nfxPreviewEnvironment()
}

#Preview("Statistics") {
    NavigationStack {
        NFXStatisticsView()
    }
    .nfxPreviewEnvironment()
}
#endif
