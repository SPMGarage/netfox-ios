//
//  NFXRootView.swift
//  netfox
//
//  TEMPORARY placeholder so the package builds while the 4.0 views are ported
//  from LegacyUI/. Keeps the demo usable: a list of captured requests and a close button.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXRootView: View {
    @Environment(NFXRequestStore.self) private var store
    @Environment(\.nfxDismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(store.filteredRecords) { record in
                NavigationLink {
                    Text(record.urlString)
                        .padding()
                        .navigationTitle("Details")
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(record.method) \(record.statusCode.map(String.init) ?? "-")")
                            .font(.caption.monospaced().bold())
                        Text(record.urlString)
                            .font(.footnote)
                            .lineLimit(2)
                    }
                }
                .accessibilityIdentifier("nfx.requestRow")
            }
            .accessibilityIdentifier("nfx.requestList")
            .navigationTitle("Requests")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                    .accessibilityIdentifier("nfx.close")
                }
            }
        }
    }
}
#endif
