//
//  NFXPublicIP.swift
//  netfox
//
//  P2-9: the device's public IP, looked up only when the user asks for it.
//  The request never shows up in the captured list.
//

import Foundation

/// Opt-in public IP lookup (contacts api.ipify.org).
package enum NFXPublicIP {

    private struct Reply: Decodable {
        let ip: String
    }

    /// A session netfox never intercepts (internal config, no cookies, no cache).
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        URLSessionConfiguration.nfx_markAsInternal(configuration)
        configuration.protocolClasses = configuration.protocolClasses?.filter { $0 != NFXProtocol.self }
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }()

    /// The public IP address, or nil when the lookup fails. Call this only after an explicit user action.
    @concurrent
    package static func lookup() async -> String? {
        guard let url = URL(string: "https://api.ipify.org/?format=json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tagged = NFXProtocol.markedAsInternal(request)
        do {
            let (data, response) = try await session.data(for: tagged)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(Reply.self, from: data).ip
        } catch {
            NFXLog.ui.debug("Public IP lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
