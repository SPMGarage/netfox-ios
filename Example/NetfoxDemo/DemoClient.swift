//
//  DemoClient.swift
//  NetfoxDemo
//

import Foundation

enum DemoClient {

    /// Sends the request and returns a short line for the UI ("200 · 1.2 KB" or the error text).
    static func send(_ demo: DemoRequest) async -> String {
        var request = URLRequest(url: demo.url)
        request.httpMethod = demo.method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = demo.jsonBody {
            request.httpBody = Data(body.utf8)
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }

        let session = demo.usesEphemeralSession ? URLSession(configuration: .ephemeral) : URLSession.shared
        defer {
            if session !== URLSession.shared {
                session.finishTasksAndInvalidate()
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            return "\(status) · \(size)"
        } catch {
            return error.localizedDescription
        }
    }
}
