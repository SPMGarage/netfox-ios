//
//  NFXRequestStore.swift
//  netfox
//
//  P2-2: the inspector's state. @Observable, so a view re-renders only for the
//  properties it reads. Fed by NetfoxCore through NFXMainFeed.
//

import Foundation
import NetfoxCore
import Observation

/// Captured records plus the list filters and feature toggles.
@Observable
@MainActor
package final class NFXRequestStore {

    /// The store the inspector shows.
    package static let shared = NFXRequestStore()

    /// The default number of records kept. Pinned records are never dropped.
    package static let defaultRecordLimit = 1000

    // MARK: - Records

    /// Captured records, newest first. A record's value is replaced when it is updated.
    package private(set) var records: [NFXRecord] = []

    /// B9: ids of pinned records (in memory only).
    package private(set) var pinnedIDs: Set<UUID> = []

    /// Grows by one for every new record; use it as a `.sensoryFeedback` trigger (E2).
    package private(set) var insertionCount = 0

    /// When the inspector was last closed; newer records count as new.
    package private(set) var lastVisitDate = Date()

    // MARK: - Filters

    /// Response types shown in the list.
    package var enabledKinds: Set<NFXContentKind> = Set(NFXContentKind.allCases)

    /// B1: status class shown in the list.
    package var statusFilter: NFXStatusFilter = .all

    /// Search text matched against URL, method, status and response type.
    package var searchText = ""

    // MARK: - Feature toggles

    /// C1: group the list by host.
    package var isGroupingEnabled = false

    /// E2: haptic feedback when a request arrives.
    package var isHapticEnabled = false

    /// E4: two-column layout on iPad.
    package var isSplitViewEnabled = true

    /// The "Logging" switch: capture requests or not. Written through to NetfoxCore.
    package var isInterceptionEnabled: Bool {
        didSet { settings.isEnabled = isInterceptionEnabled }
    }

    /// D4: log every request to the console. Written through to NetfoxCore.
    package var isConsoleLoggingEnabled: Bool {
        didSet { settings.isConsoleLoggingEnabled = isConsoleLoggingEnabled }
    }

    /// D6: capture TLS certificates. Written through to NetfoxCore.
    package var isCertificateInfoEnabled: Bool {
        didSet { settings.isCertificateInfoEnabled = isCertificateInfoEnabled }
    }

    // MARK: - Dependencies

    /// Maximum number of unpinned records kept.
    @ObservationIgnored package let recordLimit: Int
    @ObservationIgnored private let settings: NFXInterceptionSettings
    @ObservationIgnored private let storage: NFXStorage

    package init(
        settings: NFXInterceptionSettings = .shared,
        storage: NFXStorage = .shared,
        recordLimit: Int = NFXRequestStore.defaultRecordLimit
    ) {
        self.settings = settings
        self.storage = storage
        self.recordLimit = recordLimit
        self.isInterceptionEnabled = settings.isEnabled
        self.isConsoleLoggingEnabled = settings.isConsoleLoggingEnabled
        self.isCertificateInfoEnabled = settings.isCertificateInfoEnabled
    }

    // MARK: - Derived lists

    /// Records that pass the type filter, the status filter and the search text, newest first.
    package var filteredRecords: [NFXRecord] {
        let kinds = enabledKinds
        let status = statusFilter
        let query = searchText
        return records.filter { record in
            kinds.contains(record.kind) && status.matches(record) && record.matches(search: query)
        }
    }

    /// B9: the filtered records that are pinned.
    package var pinnedRecords: [NFXRecord] {
        filteredRecords.filter { pinnedIDs.contains($0.id) }
    }

    /// The filtered records that are not pinned.
    package var unpinnedRecords: [NFXRecord] {
        filteredRecords.filter { !pinnedIDs.contains($0.id) }
    }

    /// C1: records grouped by host, in list order.
    package func groupedByHost(_ records: [NFXRecord]) -> [NFXHostGroup] {
        var groups: [NFXHostGroup] = []
        var indexByHost: [String: Int] = [:]
        for record in records {
            let host = record.host ?? "Unknown"
            if let index = indexByHost[host] {
                groups[index].records.append(record)
            } else {
                indexByHost[host] = groups.count
                groups.append(NFXHostGroup(host: host, records: [record]))
            }
        }
        return groups
    }

    /// The current value of a record.
    package func record(with id: UUID) -> NFXRecord? {
        records.first { $0.id == id }
    }

    /// Whether the record arrived after the inspector was last closed.
    package func isNew(_ record: NFXRecord) -> Bool {
        (record.endDate ?? record.startDate) > lastVisitDate
    }

    /// Statistics over `records` (pass `filteredRecords` to follow the filters).
    package func statistics(for records: [NFXRecord]) -> NFXStatistics {
        NFXStatistics(records: records)
    }

    // MARK: - Pins (B9)

    package func isPinned(_ id: UUID) -> Bool {
        pinnedIDs.contains(id)
    }

    package func togglePin(_ id: UUID) {
        if pinnedIDs.contains(id) {
            pinnedIDs.remove(id)
        } else {
            pinnedIDs.insert(id)
        }
    }

    // MARK: - Mutations

    /// Inserts a new record at the top, or replaces the value of a known one.
    package func apply(_ record: NFXRecord) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
            return
        }
        records.insert(record, at: 0)
        insertionCount += 1
        trimToLimit()
    }

    /// "Clear": removes every record and pin and deletes stored bodies and the session log.
    package func clear() {
        removeAllRecords()
        storage.reset()
    }

    /// Removes records and pins only (files are handled by NetfoxCore on start/stop).
    package func removeAllRecords() {
        records.removeAll()
        pinnedIDs.removeAll()
    }

    /// Call when the inspector closes; records after this moment count as new.
    package func markVisited() {
        lastVisitDate = Date()
    }

    /// Re-reads the switches NetfoxCore owns (they can change through the public API).
    package func syncWithCoreSettings() {
        if isInterceptionEnabled != settings.isEnabled {
            isInterceptionEnabled = settings.isEnabled
        }
        if isConsoleLoggingEnabled != settings.isConsoleLoggingEnabled {
            isConsoleLoggingEnabled = settings.isConsoleLoggingEnabled
        }
        if isCertificateInfoEnabled != settings.isCertificateInfoEnabled {
            isCertificateInfoEnabled = settings.isCertificateInfoEnabled
        }
    }

    /// Drops the oldest unpinned records beyond ``recordLimit`` and deletes their body files.
    private func trimToLimit() {
        guard records.count > recordLimit else { return }
        var removed: [UUID] = []
        var index = records.count - 1
        while records.count > recordLimit, index >= 0 {
            if !pinnedIDs.contains(records[index].id) {
                removed.append(records.remove(at: index).id)
            }
            index -= 1
        }
        storage.removeBodies(for: removed)
    }

    // MARK: - Loading and export (all off the main actor)

    /// The stored bytes of a body, or nil when nothing was stored.
    package func body(_ part: NFXBodyPart, of record: NFXRecord) async -> Data? {
        guard record.body(part).isStored else { return nil }
        return await storage.body(for: record.id, part: part)
    }

    /// The file that holds a stored body (for ShareLink), or nil when nothing was stored.
    /// Only builds the URL; it does not touch the disk.
    package func bodyFileURL(_ part: NFXBodyPart, of record: NFXRecord) -> URL? {
        guard record.body(part).isStored else { return nil }
        return storage.bodyFileURL(for: record.id, part: part)
    }

    /// B4: writes a HAR file with the given records (default: all) and returns its URL.
    package func exportHAR(_ records: [NFXRecord]? = nil) async throws -> URL {
        try await NFXHARExporter.exportFile(records: records ?? self.records, storage: storage)
    }

    /// "Copy as cURL" for a record, built from the stored request bytes.
    package func curlCommand(for record: NFXRecord) async -> String {
        await NFXCurlBuilder.command(for: record, storage: storage)
    }

    /// The session log file, for ShareLink.
    package var sessionLogURL: URL {
        storage.sessionLogURL
    }
}

/// C1: records of one host.
package nonisolated struct NFXHostGroup: Identifiable, Sendable, Hashable {
    package var id: String { host }
    package let host: String
    package var records: [NFXRecord]
}
