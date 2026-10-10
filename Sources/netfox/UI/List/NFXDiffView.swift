//
//  NFXDiffView.swift
//  netfox
//
//  B6: compares the headers and the response bodies of two requests.
//

#if os(iOS)
import NetfoxCore
import SwiftUI

struct NFXDiffView: View {
    let leftID: UUID
    let rightID: UUID

    nonisolated private enum Aspect: String, CaseIterable, Identifiable {
        case headers = "Headers"
        case body = "Body"
        var id: Self { self }
    }

    @Environment(NFXRequestStore.self) private var store
    @State private var aspect = Aspect.headers
    @State private var bodyDiff: NFXLineDiff?

    var body: some View {
        Group {
            if let left = store.record(with: leftID), let right = store.record(with: rightID) {
                List {
                    Section("Requests") {
                        summaryRow("Left", left)
                        summaryRow("Right", right)
                    }
                    switch aspect {
                    case .headers:
                        headerSection("Request Headers", left.requestHeaders, right.requestHeaders)
                        headerSection("Response Headers", left.responseHeaders, right.responseHeaders)
                    case .body:
                        bodySection
                    }
                }
                .task(id: NFXComparison(leftID: leftID, rightID: rightID)) {
                    let leftBody = await store.body(.response, of: left)
                    let rightBody = await store.body(.response, of: right)
                    bodyDiff = await NFXLineDiff.make(left: leftBody, right: rightBody)
                }
            } else {
                ContentUnavailableView(
                    "Request Not Available",
                    systemImage: "tray",
                    description: Text("One of the requests was cleared.")
                )
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Compare", selection: $aspect) {
                    ForEach(Aspect.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func summaryRow(_ side: String, _ record: NFXRecord) -> some View {
        LabeledContent {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.method) \(record.statusCode.map(NFXFormat.status) ?? NFXFormat.failure(of: record))")
                    .font(.subheadline.weight(.semibold))
                Text(record.urlString)
                    .font(.caption.monospaced())
                    .lineLimit(3)
            }
        } label: {
            Text(side)
        }
        .labeledContentStyle(NFXStackedLabeledContentStyle())
    }

    private func headerSection(_ title: String, _ left: [NFXHeader], _ right: [NFXHeader]) -> some View {
        var displayNames: [String: String] = [:]
        for header in left + right where displayNames[header.name.lowercased()] == nil {
            displayNames[header.name.lowercased()] = header.name
        }
        let keys = displayNames.keys.sorted()
        return Section(title) {
            if keys.isEmpty {
                Text("No headers").foregroundStyle(.secondary)
            }
            ForEach(keys, id: \.self) { key in
                headerRow(name: displayNames[key] ?? key, left: left.value(for: key), right: right.value(for: key))
            }
        }
    }

    private func headerRow(name: String, left: String?, right: String?) -> some View {
        let differs = left != right
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.subheadline.weight(.semibold))
                Spacer()
                if differs {
                    Image(systemName: "not.equal.circle.fill")
                        .foregroundStyle(Color.nfxOrange)
                        .accessibilityLabel("Different")
                }
            }
            LabeledContent("Left", value: left ?? "missing")
            LabeledContent("Right", value: right ?? "missing")
        }
        .font(.caption.monospaced())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var bodySection: some View {
        Section {
            if let bodyDiff {
                if bodyDiff.isIdentical {
                    Label("The response bodies are identical", systemImage: "equal.circle")
                } else {
                    ForEach(bodyDiff.lines) { line in
                        diffLine(line)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        } header: {
            Text("Response Body")
        } footer: {
            if bodyDiff?.isCut == true {
                Text("Only the first \(NFXLineDiff.maxLines) lines of each body are compared.")
            } else {
                Text("\u{2212} only in the left response, + only in the right one.")
            }
        }
    }

    private func diffLine(_ line: NFXLineDiff.Line) -> some View {
        let (prefix, color): (String, Color) = switch line.change {
        case .same: ("  ", .primary)
        case .removed: ("\u{2212} ", .nfxRed)
        case .added: ("+ ", .nfxDarkGreen)
        }
        return Text(prefix + line.text)
            .font(.caption.monospaced())
            .foregroundStyle(color)
            .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
            .listRowSeparator(.hidden)
    }
}
#endif
