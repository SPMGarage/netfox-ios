//
//  NFXHARExporter.swift
//  netfox
//
//  B4: Export captured requests as HAR 1.2 format (HTTP Archive).
//

#if os(iOS)

import Foundation

enum NFXHARExporter {

    /// Generates a HAR 1.2 JSON string from the given models
    static func generateHAR(from models: [NFXHTTPModel]) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var entries = [[String: Any]]()

        for model in models {
            var entry = [String: Any]()
            let startedDateTime = model.requestDate.map { isoFormatter.string(from: $0) } ?? isoFormatter.string(from: Date())
            entry["startedDateTime"] = startedDateTime
            entry["time"] = Double(model.timeInterval ?? 0) * 1000 // HAR uses ms

            // Request
            var request = [String: Any]()
            request["method"] = model.requestMethod ?? "GET"
            request["url"] = model.requestURL ?? ""
            request["httpVersion"] = "HTTP/1.1"
            request["cookies"] = [[String: Any]]()
            request["headers"] = harHeaders(from: model.requestHeaders)
            request["queryString"] = harQueryString(from: model.requestURLQueryItems)
            request["headersSize"] = -1

            let requestBody = model.getRequestBody()
            if !requestBody.isEmpty {
                request["postData"] = [
                    "mimeType": model.requestType ?? "",
                    "text": requestBody
                ]
                request["bodySize"] = model.requestBodyLength ?? requestBody.count
            } else {
                request["bodySize"] = 0
            }

            entry["request"] = request

            // Response
            var response = [String: Any]()
            response["status"] = model.responseStatus ?? 0
            response["statusText"] = HTTPURLResponse.localizedString(forStatusCode: model.responseStatus ?? 0)
            response["httpVersion"] = "HTTP/1.1"
            response["cookies"] = [[String: Any]]()
            response["headers"] = harHeaders(from: model.responseHeaders)
            response["headersSize"] = -1

            let responseBody = model.getResponseBody()
            var content = [String: Any]()
            content["size"] = model.responseBodyLength ?? 0
            content["mimeType"] = model.responseType ?? ""
            if model.shortType == .IMAGE {
                content["text"] = responseBody
                content["encoding"] = "base64"
            } else {
                content["text"] = responseBody
            }
            response["content"] = content
            response["bodySize"] = model.responseBodyLength ?? 0
            response["redirectURL"] = ""

            entry["response"] = response

            // Timings (minimal, since we only have total time)
            let totalTime = Double(model.timeInterval ?? 0) * 1000
            entry["timings"] = [
                "send": 0,
                "wait": totalTime,
                "receive": 0
            ]

            entry["cache"] = [String: Any]()

            entries.append(entry)
        }

        let har: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": [
                    "name": "netfox-ios",
                    "version": nfxVersion
                ],
                "entries": entries
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: har, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    /// Saves HAR to a temporary file and returns the URL for sharing
    static func exportToFile(from models: [NFXHTTPModel]) -> URL? {
        let harString = generateHAR(from: models)
        let fileName = "netfox_session_\(Int(Date().timeIntervalSince1970)).har"
        let fileURL = NFXPath.nfxDirURL.appendingPathComponent(fileName)
        do {
            try harString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("[NFX]: Failed to export HAR - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func harHeaders(from headers: [AnyHashable: Any]?) -> [[String: String]] {
        guard let headers = headers else { return [] }
        return headers.map { ["name": "\($0.key)", "value": "\($0.value)"] }
    }

    private static func harQueryString(from items: [URLQueryItem]?) -> [[String: String]] {
        guard let items = items else { return [] }
        return items.map { ["name": $0.name, "value": $0.value ?? ""] }
    }
}

#endif
