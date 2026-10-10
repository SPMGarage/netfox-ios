//
//  NFXQueryItemsView.swift
//  netfox
//
//  The URL query parameters of a request.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXQueryItemsView: View {
    let recordID: UUID

    @Environment(NFXRequestStore.self) private var store

    var body: some View {
        let record = store.record(with: recordID)
        let items = record?.queryItems ?? []
        List {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    NFXValueRow(
                        title: item.name,
                        value: item.value ?? "",
                        layout: .stacked,
                        isMonospaced: true,
                        copiesLine: true
                    )
                }
            } footer: {
                if let record {
                    Text(record.urlString)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No Query Parameters", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("Query Parameters")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
