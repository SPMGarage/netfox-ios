//
//  NFXRequestListView.swift
//  netfox
//
//  The request list: search, pinned section (B9), compare (B6), group by host (C1),
//  haptics (E2) and the close / settings / clear toolbar.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXRequestListView: View {
    /// The split view's selection; nil when the list is the root of a plain navigation stack.
    let selection: Binding<UUID?>?
    let openSettings: () -> Void

    @Environment(NFXRequestStore.self) private var store
    @Environment(\.nfxDismiss) private var dismiss
    @State private var isConfirmingClear = false
    @State private var compareSource: NFXRecord?
    @State private var collapsedHosts: Set<String> = []

    var body: some View {
        @Bindable var store = store
        let records = store.filteredRecords
        list(of: records)
            .accessibilityIdentifier("nfx.requestList")
            .listStyle(.plain)
            .overlay { emptyState(for: records) }
            .searchable(text: $store.searchText, prompt: "Search URL, method, type")
            .modifier(NFXKeepsToolbarWhileSearching())
            .navigationTitle("Requests")
            .toolbar { toolbar }
            .sheet(item: $compareSource) { source in
                NFXComparePicker(source: source)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: store.insertionCount) { _, _ in
                store.isHapticEnabled
            }
    }

    // MARK: - List

    @ViewBuilder
    private func list(of records: [NFXRecord]) -> some View {
        if let selection {
            List(selection: selection) {
                sections(for: records)
            }
        } else {
            List {
                sections(for: records)
            }
        }
    }

    @ViewBuilder
    private func sections(for records: [NFXRecord]) -> some View {
        let pinned = records.filter { store.isPinned($0.id) }
        let others = records.filter { !store.isPinned($0.id) }
        if !pinned.isEmpty {
            Section("Pinned") {
                ForEach(pinned) { row(for: $0) }
            }
        }
        if store.isGroupingEnabled {
            ForEach(store.groupedByHost(others)) { group in
                hostSection(group)
            }
        } else if pinned.isEmpty {
            ForEach(others) { row(for: $0) }
        } else {
            Section("All Requests") {
                ForEach(others) { row(for: $0) }
            }
        }
    }

    /// C1: a collapsible section per host.
    private func hostSection(_ group: NFXHostGroup) -> some View {
        let isCollapsed = collapsedHosts.contains(group.host)
        return Section {
            if !isCollapsed {
                ForEach(group.records) { row(for: $0) }
            }
        } header: {
            Button {
                withAnimation {
                    if isCollapsed {
                        collapsedHosts.remove(group.host)
                    } else {
                        collapsedHosts.insert(group.host)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    Text(group.host)
                        .lineLimit(1)
                    Spacer()
                    Text(group.records.count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
            .accessibilityHint("Shows or hides the requests of this host")
        }
    }

    // MARK: - Rows

    private func row(for record: NFXRecord) -> some View {
        let isPinned = store.isPinned(record.id)
        return link(for: record, isPinned: isPinned)
            .accessibilityIdentifier("nfx.requestRow")
            .swipeActions(edge: .leading) {
                Button {
                    store.togglePin(record.id)
                } label: {
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                }
                .tint(Color.nfxOrange)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    compareSource = record
                } label: {
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                }
                .tint(.blue)
            }
            .contextMenu {
                rowMenu(for: record, isPinned: isPinned)
            }
    }

    /// Split view: the link updates the list selection. Stack: the link pushes the detail.
    @ViewBuilder
    private func link(for record: NFXRecord, isPinned: Bool) -> some View {
        let label = NFXRequestRow(record: record, isPinned: isPinned, isNew: store.isNew(record))
        if selection != nil {
            NavigationLink(value: record.id) { label }
        } else {
            NavigationLink(value: NFXRoute.record(record.id)) { label }
        }
    }

    @ViewBuilder
    private func rowMenu(for record: NFXRecord, isPinned: Bool) -> some View {
        Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin") {
            store.togglePin(record.id)
        }
        Button("Compare With\u{2026}", systemImage: "arrow.left.arrow.right") {
            compareSource = record
        }
        Button("Copy URL", systemImage: "link") {
            UIPasteboard.general.string = record.urlString
        }
    }

    // MARK: - Empty states

    @ViewBuilder
    private func emptyState(for records: [NFXRecord]) -> some View {
        if store.records.isEmpty {
            ContentUnavailableView(
                "No Requests Yet",
                systemImage: "network",
                description: Text("Requests your app sends will show up here.")
            )
        } else if records.isEmpty {
            if store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "No Matching Requests",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("The status and response type filters in Settings hide every request.")
                )
            } else {
                ContentUnavailableView.search(text: store.searchText)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Close", systemImage: "xmark") {
                store.markVisited()
                dismiss()
            }
            .accessibilityIdentifier("nfx.close")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape", action: openSettings)
                .accessibilityIdentifier("nfx.settings")
            Button("Clear", systemImage: "trash") {
                isConfirmingClear = true
            }
            .accessibilityIdentifier("nfx.clear")
            .disabled(store.records.isEmpty)
            .confirmationDialog(
                "Clear all captured requests?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear Requests", role: .destructive) {
                    store.clear()
                }
            } message: {
                Text("This also deletes the stored bodies and the session log.")
            }
        }
    }
}

/// The inspector is modal, so Close stays reachable while searching. Without this,
/// iOS hides the navigation bar (and its Close button) while the search field is active.
private struct NFXKeepsToolbarWhileSearching: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.1, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}
#endif
