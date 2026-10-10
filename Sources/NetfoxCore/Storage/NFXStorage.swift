//
//  NFXStorage.swift
//  netfox
//
//  P0-3 / P2-1 / P2-3: raw body files and the session log, written on a serial
//  utility queue after the URL loading system has been notified.
//

import Foundation

/// Disk storage for captured bodies and the session log.
///
/// Everything lives in `tmp/NFX/`. Writes and deletions run in order on one
/// serial utility queue, so they never block the request path or the main thread.
package final class NFXStorage: Sendable {

    /// Bodies larger than this are cut; the full length is still recorded (P2-1).
    package static let maxBodyBytes = 10 * 1024 * 1024
    /// session.log is trimmed (oldest entries first) once it grows past this.
    package static let defaultSessionLogLimit = 10 * 1024 * 1024
    /// Each body is cut to this many bytes inside session.log.
    static let maxLogBodyBytes = 256 * 1024

    /// The storage the interception path writes to.
    package static let shared = NFXStorage(
        directoryURL: URL.temporaryDirectory.appending(path: "NFX", directoryHint: .isDirectory)
    )

    /// The folder that holds every netfox file.
    package let directoryURL: URL
    /// The size at which session.log is trimmed.
    package let sessionLogLimit: Int
    private let queue = DispatchQueue(label: "uz.azimjondev.netfox.storage", qos: .utility)

    package init(directoryURL: URL, sessionLogLimit: Int = NFXStorage.defaultSessionLogLimit) {
        self.directoryURL = directoryURL
        self.sessionLogLimit = sessionLogLimit
    }

    // MARK: - Locations

    /// The plain-text log of every captured request ("Share Session Logs").
    package var sessionLogURL: URL {
        directoryURL.appending(path: "session.log", directoryHint: .notDirectory)
    }

    /// Where the raw bytes of one body are stored.
    package func bodyFileURL(for id: UUID, part: NFXBodyPart) -> URL {
        directoryURL.appending(path: "\(id.uuidString).\(part.rawValue)", directoryHint: .notDirectory)
    }

    /// Temporary copy of an upload stream larger than ``maxBodyBytes``.
    func uploadSpillFileURL(for id: UUID) -> URL {
        directoryURL.appending(path: "\(id.uuidString).upload", directoryHint: .notDirectory)
    }

    // MARK: - Maintenance (asynchronous, in order)

    /// Deletes every stored file and recreates an empty folder.
    package func reset() {
        queue.async { [self] in
            removeItemIfPresent(at: directoryURL)
            createDirectoryIfNeeded()
        }
    }

    /// Deletes the body files of records that were dropped from the list.
    package func removeBodies(for ids: [UUID]) {
        guard !ids.isEmpty else { return }
        queue.async { [self] in
            for id in ids {
                for part in NFXBodyPart.allCases {
                    removeItemIfPresent(at: bodyFileURL(for: id, part: part))
                }
            }
        }
    }

    /// Deletes one file on the storage queue.
    func removeFile(at url: URL) {
        queue.async { [self] in removeItemIfPresent(at: url) }
    }

    /// Waits until every write queued so far has finished.
    @concurrent
    package func flush() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
    }

    // MARK: - Capture pipeline

    /// Writes the bodies, appends the session log entry, then publishes the record.
    ///
    /// The record is published only after its body files exist, so a view that
    /// reacts to the record can load the body right away.
    func persist(_ record: NFXRecord, requestBody: Data?, responseBody: Data?, publishTo hub: NFXRecordHub) {
        queue.async { [self] in
            createDirectoryIfNeeded()
            if let requestBody, record.requestBody.isStored {
                write(requestBody, to: bodyFileURL(for: record.id, part: .request))
            }
            if let responseBody, record.responseBody.isStored {
                write(responseBody, to: bodyFileURL(for: record.id, part: .response))
            }
            let entry = NFXSessionLogFormatter.entry(for: record, requestBody: requestBody, responseBody: responseBody)
            appendToSessionLog(entry)
            hub.publish(record)
        }
    }

    /// Publishes an updated record after everything queued before it.
    func publishUpdate(_ record: NFXRecord, to hub: NFXRecordHub) {
        queue.async {
            hub.publish(record)
        }
    }

    // MARK: - Reading (never on the main actor)

    /// The stored bytes of one body, or nil when nothing was stored.
    @concurrent
    package func body(for id: UUID, part: NFXBodyPart) async -> Data? {
        let url = bodyFileURL(for: id, part: part)
        return try? Data(contentsOf: url)
    }

    /// The whole session log.
    @concurrent
    package func sessionLog() async -> Data? {
        try? Data(contentsOf: sessionLogURL)
    }

    /// Synchronous session log read, ordered after pending writes. Backs `NFX.getSessionLog()`.
    package func sessionLogSynchronously() -> Data? {
        queue.sync {
            try? Data(contentsOf: sessionLogURL)
        }
    }

    // MARK: - File helpers (storage queue only)

    private func createDirectoryIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            NFXLog.storage.error("Could not create the netfox folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func removeItemIfPresent(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NFXLog.storage.error("Could not delete \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NFXLog.storage.error("Could not write \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func appendToSessionLog(_ text: String) {
        let data = Data(text.utf8)
        let url = sessionLogURL
        do {
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
                try data.write(to: url, options: .atomic)
                return
            }
            let handle = try FileHandle(forWritingTo: url)
            let previousSize = try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
            if Int(previousSize) + data.count > sessionLogLimit {
                trimSessionLog()
            }
        } catch {
            NFXLog.storage.error("Could not append to session.log: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Drops the oldest entries until the log is at about 3/4 of its limit.
    private func trimSessionLog() {
        let url = sessionLogURL
        guard let data = try? Data(contentsOf: url) else { return }
        let target = sessionLogLimit * 3 / 4
        guard data.count > target else { return }
        var cut = data.count - target
        // start the trimmed log at an entry boundary
        if let marker = data.range(of: Data(NFXSessionLogFormatter.entryMarker.utf8), in: cut..<data.count) {
            cut = marker.lowerBound
        }
        write(data.subdata(in: cut..<data.count), to: url)
    }
}
