//
//  NFXDiffView.swift
//  netfox
//
//  B6: Side-by-side comparison of two requests.
//  Shows differences in headers and body between two captured requests.
//

#if os(iOS)

import SwiftUI

struct NFXDiffView: View {
    let leftModel: NFXHTTPModel
    let rightModel: NFXHTTPModel

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                Text("Headers").tag(0)
                Text("Body").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                if selectedTab == 0 {
                    headersDiff
                } else {
                    bodyDiff
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Headers Diff

    @ViewBuilder
    private var headersDiff: some View {
        let leftHeaders = flattenHeaders(leftModel.responseHeaders)
        let rightHeaders = flattenHeaders(rightModel.responseHeaders)
        let allKeys = Array(Set(leftHeaders.keys).union(Set(rightHeaders.keys))).sorted()

        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(allKeys, id: \.self) { key in
                let leftVal = leftHeaders[key]
                let rightVal = rightHeaders[key]
                let isDifferent = leftVal != rightVal

                VStack(alignment: .leading, spacing: 4) {
                    Text(key)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading) {
                            Text("Left")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(leftVal ?? "(missing)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(leftVal == nil ? .secondary : .primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading) {
                            Text("Right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(rightVal ?? "(missing)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(rightVal == nil ? .secondary : .primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(isDifferent ? Color(UIColor.NFXOrangeColor()).opacity(0.1) : Color.clear)

                Divider()
            }
        }
    }

    // MARK: - Body Diff

    @ViewBuilder
    private var bodyDiff: some View {
        let leftBody = leftModel.getResponseBody()
        let rightBody = rightModel.getResponseBody()

        if leftBody == rightBody {
            Text("Bodies are identical")
                .foregroundColor(.secondary)
                .padding()
        } else {
            HStack(alignment: .top, spacing: 1) {
                VStack(alignment: .leading) {
                    Text("Left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)

                    ScrollView(.vertical) {
                        Text(leftBody.isEmpty ? "(empty)" : leftBody)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))

                VStack(alignment: .leading) {
                    Text("Right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)

                    ScrollView(.vertical) {
                        Text(rightBody.isEmpty ? "(empty)" : rightBody)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Helpers

    private func flattenHeaders(_ headers: [AnyHashable: Any]?) -> [String: String] {
        guard let headers = headers else { return [:] }
        var result = [String: String]()
        for (key, value) in headers {
            result["\(key)"] = "\(value)"
        }
        return result
    }
}

#endif
