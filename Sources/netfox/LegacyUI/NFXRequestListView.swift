//
//  NFXRequestListView.swift
//  netfox
//
//  SwiftUI replacement for NFXListController_iOS.
//  Main request list with search, filtering, pinning (B9), and diff comparison (B6).
//

#if os(iOS)

import SwiftUI

struct NFXRequestListView: View {
    @ObservedObject private var manager = NFXHTTPModelManager.shared
    @State private var searchText = ""
    @State private var showClearConfirmation = false

    // B6: Diff comparison
    @State private var diffSourceModel: NFXHTTPModel?
    @State private var showDiffPicker = false

    // C1: Track collapsed host sections
    @State private var collapsedHosts = Set<String>()

    var body: some View {
        let filtered = filteredModels
        let pinned = filtered.filter { manager.isPinned($0) }
        let unpinned = filtered.filter { !manager.isPinned($0) }

        List {
            // B9: Pinned section
            if !pinned.isEmpty {
                Section(header: Text("Pinned")) {
                    ForEach(pinned, id: \.randomHash) { model in
                        requestRow(for: model, isPinned: true)
                    }
                }
            }

            // C1: Grouped or flat list
            if manager.isGroupingEnabled {
                groupedSections(models: unpinned, hasPinned: !pinned.isEmpty)
            } else {
                flatSection(models: unpinned, hasPinned: !pinned.isEmpty)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search URL, method, type...")
        .navigationTitle("Requests")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    NFX.sharedInstance().hide()
                } label: {
                    Image(systemName: "xmark")
                }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    NFXSettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }

                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Clear data?", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                NFX.sharedInstance().clearOldData()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDiffPicker) {
            if let sourceModel = diffSourceModel {
                NFXDiffPickerSheet(sourceModel: sourceModel)
            }
        }
    }

    // MARK: - C1: Grouped Sections by Host

    @ViewBuilder
    private func groupedSections(models: [NFXHTTPModel], hasPinned: Bool) -> some View {
        let grouped = groupedByHost(models)
        ForEach(grouped, id: \.host) { group in
            Section {
                if !collapsedHosts.contains(group.host) {
                    ForEach(group.models, id: \.randomHash) { model in
                        requestRow(for: model, isPinned: false)
                    }
                }
            } header: {
                Button {
                    withAnimation {
                        if collapsedHosts.contains(group.host) {
                            collapsedHosts.remove(group.host)
                        } else {
                            collapsedHosts.insert(group.host)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: collapsedHosts.contains(group.host) ? "chevron.right" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                        Text(group.host)
                        Spacer()
                        Text("\(group.models.count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Flat Section (original behavior)

    @ViewBuilder
    private func flatSection(models: [NFXHTTPModel], hasPinned: Bool) -> some View {
        Section(header: hasPinned ? Text("All Requests") : nil) {
            ForEach(models, id: \.randomHash) { model in
                requestRow(for: model, isPinned: false)
            }
        }
    }

    // MARK: - Shared Row Builder

    private func requestRow(for model: NFXHTTPModel, isPinned: Bool) -> some View {
        NavigationLink {
            NFXRequestDetailView(model: model)
        } label: {
            NFXRequestRow(
                model: model,
                isPinned: isPinned,
                isNew: isNew(model)
            )
        }
        .swipeActions(edge: .leading) {
            Button {
                manager.togglePin(model)
            } label: {
                Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(Color(UIColor.NFXOrangeColor()))
        }
        .swipeActions(edge: .trailing) {
            // B6: Compare
            Button {
                diffSourceModel = model
                showDiffPicker = true
            } label: {
                Label("Compare", systemImage: "arrow.left.arrow.right")
            }
            .tint(.blue)
        }
    }

    // MARK: - Filtering

    private var filteredModels: [NFXHTTPModel] {
        let models = manager.filteredModels
        guard !searchText.isEmpty else { return models }

        return models.filter { model in
            model.requestURL?.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || model.requestMethod?.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            || model.responseType?.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private func isNew(_ model: NFXHTTPModel) -> Bool {
        guard let responseDate = model.responseDate else { return false }
        return responseDate > NFX.sharedInstance().getLastVisitDate()
    }

    // MARK: - C1: Grouping Helpers

    private struct HostGroup {
        let host: String
        let models: [NFXHTTPModel]
    }

    private func groupedByHost(_ models: [NFXHTTPModel]) -> [HostGroup] {
        var dict = [String: [NFXHTTPModel]]()
        var orderedHosts = [String]()

        for model in models {
            let host = extractHost(from: model.requestURL) ?? "Unknown"
            if dict[host] == nil {
                orderedHosts.append(host)
                dict[host] = []
            }
            dict[host]?.append(model)
        }

        return orderedHosts.compactMap { host in
            guard let models = dict[host] else { return nil }
            return HostGroup(host: host, models: models)
        }
    }

    private func extractHost(from urlString: String?) -> String? {
        guard let urlString = urlString,
              let components = URLComponents(string: urlString) else { return nil }
        return components.host
    }
}

#endif
