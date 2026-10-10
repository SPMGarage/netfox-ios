//
//  NFXComparePicker.swift
//  netfox
//
//  B6: after "Compare" on a row, pick the second request; the diff is pushed
//  programmatically with navigationDestination(item:).
//

#if os(iOS)
import NetfoxCore
import SwiftUI

/// Two records to compare.
nonisolated struct NFXComparison: Hashable, Sendable {
    let leftID: UUID
    let rightID: UUID
}

struct NFXComparePicker: View {
    let source: NFXRecord

    @Environment(NFXRequestStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var comparison: NFXComparison?

    var body: some View {
        let candidates = store.filteredRecords.filter { $0.id != source.id }
        NavigationStack {
            List {
                Section("Compare") {
                    NFXRequestRow(record: source)
                }
                Section("With") {
                    ForEach(candidates) { record in
                        Button {
                            comparison = NFXComparison(leftID: source.id, rightID: record.id)
                        } label: {
                            NFXRequestRow(record: record)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("nfx.compare.candidate")
                    }
                }
            }
            .overlay {
                if candidates.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Compare",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Capture another request first.")
                    )
                }
            }
            .navigationTitle("Compare With")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .navigationDestination(item: $comparison) { pair in
                NFXDiffView(leftID: pair.leftID, rightID: pair.rightID)
            }
        }
    }
}
#endif
