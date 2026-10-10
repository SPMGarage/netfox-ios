//
//  NFXURLQueryView.swift
//  netfox
//
//  SwiftUI replacement for NFXURLDetailsControllerViewController.
//  Displays URL query parameters in a table format.
//

#if os(iOS)

import SwiftUI

struct NFXURLQueryView: View {
    let queryItems: [URLQueryItem]

    var body: some View {
        List {
            ForEach(Array(queryItems.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(item.value ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("URL Query Strings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#endif
