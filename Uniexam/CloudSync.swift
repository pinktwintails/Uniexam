import CloudKit
import CryptoKit
import Foundation
import OSLog

struct UniexamCloudSnapshot: Codable {
    var universities: [UniversityChoice]
    var mockExamResults: [MockExamResult]
    var calendarEvents: [UserCalendarEvent]
    var customColors: [SchoolColor]

    static func local(
        universities: [UniversityChoice],
        mockExamResults: [MockExamResult],
        calendarEvents: [UserCalendarEvent],
        customColors: [SchoolColor]
    ) -> UniexamCloudSnapshot {
        UniexamCloudSnapshot(
            universities: universities,
            mockExamResults: mockExamResults,
            calendarEvents: calendarEvents,
            customColors: customColors
        )
    }
}

enum UniexamCloudSyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case unavailable
    case failed
}

private enum CloudItemKind: String, CaseIterable {
    case university
    case mockExam
    case calendarEvent
    case customColor
}

private struct CloudItem {
    let kind: CloudItemKind
    let itemID: String
    let payload: Data
    let order: Int

    var key: String { "\(kind.rawValue):\(itemID)" }

    var hash: String {
        var hashData = payload
        hashData.append(Data("|order:\(order)".utf8))
        return SHA256.hash(data: hashData).map { String(format: "%02x", $0) }.joined()
    }
}

private struct RemoteCloudItem {
    let key: String
    let kind: CloudItemKind
    let itemID: String
    let payload: Data?
    let order: Int
    let updatedAt: Date
    let isDeleted: Bool
}

private struct CloudSyncMetadata: Codable {
    var didCompleteInitialSync = false
    var lastHashes: [String: String] = [:]
    var knownKeys: Set<String> = []
    var localModifiedAt: [String: Date] = [:]
}

@MainActor
final class UniexamCloudSync {
    static let shared = UniexamCloudSync()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Uniexam",
        category: "CloudSync"
    )
    private let recordType = "UniexamItem"
    private let recordNamespace = "v4:"
    private let manifestRecordName = "v4:metadata:manifest"
    private let metadataKey = "uniexam.cloudSync.metadata.v5"
    private let backupKey = "uniexam.cloudSync.preCloudBackup.v2"
    private let legacySnapshotKey = "uniexam.cloudSync.snapshot.v1"
    private let diagnosticKey = "uniexam.cloudSync.lastDiagnostic"
    private let database = CKContainer.default().privateCloudDatabase
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private(set) var status: UniexamCloudSyncStatus = .idle
    private var isSyncing = false
    private var queuedSnapshot: UniexamCloudSnapshot?

    private init() {}

    func synchronize(_ snapshot: UniexamCloudSnapshot) async -> UniexamCloudSnapshot? {
        queuedSnapshot = snapshot
        guard !isSyncing else { return nil }

        isSyncing = true
        status = .syncing
        var latestResult: UniexamCloudSnapshot?

        while let nextSnapshot = queuedSnapshot {
            queuedSnapshot = nil
            latestResult = await performSync(nextSnapshot) ?? latestResult
        }

        isSyncing = false
        return latestResult
    }

    private func performSync(_ localSnapshot: UniexamCloudSnapshot) async -> UniexamCloudSnapshot? {
        makeSafetyBackupIfNeeded(localSnapshot)

        do {
            let accountStatus = try await CKContainer.default().accountStatus()
            guard accountStatus == .available else {
                logger.notice("iCloud account is unavailable: \(String(describing: accountStatus), privacy: .public)")
                saveDiagnostic("iCloud account unavailable: \(accountStatus)")
                status = .unavailable
                return nil
            }
            let cloudUserID = (try? await CKContainer.default().userRecordID().recordName)
                ?? "unknown"

            var metadata = loadMetadata()
            let syncSnapshot = mergeLegacySnapshot(into: localSnapshot)
            let localItems = try makeItems(from: syncSnapshot)
            let localMap = Dictionary(uniqueKeysWithValues: localItems.map { ($0.key, $0) })
            let remoteMap = try await fetchRemoteItems()

            if !metadata.didCompleteInitialSync {
                let result = try await performInitialSync(
                    localSnapshot: syncSnapshot,
                    localMap: localMap,
                    remoteMap: remoteMap,
                    metadata: &metadata
                )
                saveMetadata(metadata)
                status = .synced(Date())
                publishFallbackSnapshot(result)
                saveDiagnostic(
                    "Synced successfully | user=\(cloudUserID) | universities=\(result.universities.count)"
                )
                return result
            }

            markLocalChanges(localMap: localMap, metadata: &metadata)
            saveMetadata(metadata)

            let result = try await reconcile(
                localSnapshot: syncSnapshot,
                localMap: localMap,
                remoteMap: remoteMap,
                metadata: &metadata
            )
            saveMetadata(metadata)
            status = .synced(Date())
            publishFallbackSnapshot(result)
            saveDiagnostic(
                "Synced successfully | user=\(cloudUserID) | universities=\(result.universities.count)"
            )
            return result
        } catch {
            logger.error("Cloud sync failed: \(error.localizedDescription, privacy: .public)")
            saveDiagnostic("\(String(reflecting: error)) | \(error.localizedDescription)")
            status = isCloudUnavailable(error) ? .unavailable : .failed
            return nil
        }
    }

    private func performInitialSync(
        localSnapshot: UniexamCloudSnapshot,
        localMap: [String: CloudItem],
        remoteMap: [String: RemoteCloudItem],
        metadata: inout CloudSyncMetadata
    ) async throws -> UniexamCloudSnapshot {
        guard !remoteMap.isEmpty else {
            for item in localMap.values {
                try await save(item: item, updatedAt: Date())
            }
            try await saveManifest(keys: Set(localMap.keys))
            metadata.didCompleteInitialSync = true
            metadata.knownKeys = Set(localMap.keys)
            metadata.lastHashes = localMap.mapValues(\.hash)
            return localSnapshot
        }

        var finalItems: [String: CloudItem] = [:]

        for remote in remoteMap.values where !remote.isDeleted {
            if let item = cloudItem(from: remote) {
                finalItems[item.key] = item
            }
        }

        // Cloudに存在しない端末内データだけを追加する。競合時は初回同期前の
        // バックアップを残した上で、先に同期済みのCloud側を採用する。
        for item in localMap.values
            where remoteMap[item.key] == nil || remoteMap[item.key]?.isDeleted == true {
            try await save(item: item, updatedAt: Date())
            finalItems[item.key] = item
        }

        try await saveManifest(keys: Set(remoteMap.keys).union(localMap.keys))
        metadata.didCompleteInitialSync = true
        metadata.knownKeys = Set(finalItems.keys)
        metadata.lastHashes = finalItems.mapValues(\.hash)
        return try makeSnapshot(from: finalItems.values)
    }

    private func reconcile(
        localSnapshot: UniexamCloudSnapshot,
        localMap: [String: CloudItem],
        remoteMap: [String: RemoteCloudItem],
        metadata: inout CloudSyncMetadata
    ) async throws -> UniexamCloudSnapshot {
        var finalItems = localMap
        let allKeys = metadata.knownKeys
            .union(localMap.keys)
            .union(remoteMap.keys)

        for key in allKeys {
            let local = localMap[key]
            let remote = remoteMap[key]
            let localModifiedAt = metadata.localModifiedAt[key]

            if let localModifiedAt {
                if let remote, remote.updatedAt > localModifiedAt {
                    apply(remote: remote, to: &finalItems)
                    metadata.localModifiedAt.removeValue(forKey: key)
                } else if let local {
                    try await save(item: local, updatedAt: localModifiedAt)
                    finalItems[key] = local
                    metadata.localModifiedAt.removeValue(forKey: key)
                } else {
                    try await saveTombstone(key: key, updatedAt: localModifiedAt)
                    finalItems.removeValue(forKey: key)
                    metadata.localModifiedAt.removeValue(forKey: key)
                }
            } else if let remote {
                if remote.isDeleted, let local {
                    try await save(item: local, updatedAt: Date())
                    finalItems[key] = local
                } else {
                    apply(remote: remote, to: &finalItems)
                }
            } else if let local {
                // Cloud側のレコードが欠けている場合は、端末内の既存データを
                // 再送する。端末の保存内容は変更・削除しない。
                try await save(item: local, updatedAt: Date())
                finalItems[key] = local
            }
        }

        metadata.knownKeys = Set(finalItems.keys)
        metadata.lastHashes = finalItems.mapValues(\.hash)
        try await saveManifest(keys: allKeys)
        return try makeSnapshot(from: finalItems.values)
    }

    private func markLocalChanges(
        localMap: [String: CloudItem],
        metadata: inout CloudSyncMetadata
    ) {
        let now = Date()

        for (key, item) in localMap where metadata.lastHashes[key] != item.hash {
            if metadata.localModifiedAt[key] == nil {
                metadata.localModifiedAt[key] = now
            }
        }

        for key in metadata.knownKeys where localMap[key] == nil {
            if metadata.localModifiedAt[key] == nil {
                metadata.localModifiedAt[key] = now
            }
        }
    }

    private func apply(
        remote: RemoteCloudItem,
        to items: inout [String: CloudItem]
    ) {
        if remote.isDeleted {
            items.removeValue(forKey: remote.key)
        } else if let item = cloudItem(from: remote) {
            items[remote.key] = item
        }
    }

    private func fetchRemoteItems() async throws -> [String: RemoteCloudItem] {
        let manifest: CKRecord
        do {
            manifest = try await database.record(
                for: CKRecord.ID(recordName: manifestRecordName)
            )
        } catch let error as CKError where error.code == .unknownItem {
            return [:]
        }

        guard let payload = manifest["payload"] as? Data,
              let keys = try? decoder.decode([String].self, from: payload),
              !keys.isEmpty else {
            return [:]
        }

        let recordIDs = keys.map { cloudRecordID(for: $0) }
        var records: [CKRecord] = []
        for recordID in recordIDs {
            records.append(try await database.record(for: recordID))
        }

        return Dictionary(uniqueKeysWithValues: records.compactMap { record in
            guard let kindValue = record["kind"] as? String,
                  let kind = CloudItemKind(rawValue: kindValue),
                  let itemID = record["itemID"] as? String,
                  let updatedAt = record["updatedAt"] as? Date else {
                return nil
            }

            let deletedNumber = record["isDeleted"] as? NSNumber
            let key = "\(kind.rawValue):\(itemID)"
            let remote = RemoteCloudItem(
                key: key,
                kind: kind,
                itemID: itemID,
                payload: record["payload"] as? Data,
                order: (record["sortOrder"] as? NSNumber)?.intValue ?? 0,
                updatedAt: updatedAt,
                isDeleted: deletedNumber?.boolValue ?? false
            )
            return (remote.key, remote)
        })
    }

    private func saveManifest(keys: Set<String>) async throws {
        guard !keys.isEmpty else { return }

        let recordID = CKRecord.ID(recordName: manifestRecordName)
        let record: CKRecord
        var mergedKeys = keys

        do {
            record = try await database.record(for: recordID)
            if let payload = record["payload"] as? Data,
               let existingKeys = try? decoder.decode([String].self, from: payload) {
                mergedKeys.formUnion(existingKeys)
            }
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        record["payload"] = try encoder.encode(mergedKeys.sorted()) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
    }

    private func save(item: CloudItem, updatedAt: Date) async throws {
        let recordID = cloudRecordID(for: item.key)
        let record: CKRecord

        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        record["kind"] = item.kind.rawValue as CKRecordValue
        record["itemID"] = item.itemID as CKRecordValue
        record["payload"] = item.payload as CKRecordValue
        record["sortOrder"] = item.order as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        record["isDeleted"] = false as CKRecordValue
        _ = try await database.save(record)
    }

    private func saveTombstone(key: String, updatedAt: Date) async throws {
        guard let separator = key.firstIndex(of: ":"),
              let kind = CloudItemKind(rawValue: String(key[..<separator])) else {
            return
        }

        let itemID = String(key[key.index(after: separator)...])
        let recordID = cloudRecordID(for: key)
        let record: CKRecord

        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        record["kind"] = kind.rawValue as CKRecordValue
        record["itemID"] = itemID as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue
        record["isDeleted"] = true as CKRecordValue
        record["payload"] = nil
        record["sortOrder"] = nil
        _ = try await database.save(record)
    }

    private func makeItems(from snapshot: UniexamCloudSnapshot) throws -> [CloudItem] {
        var items: [CloudItem] = []

        for (index, university) in snapshot.universities.enumerated() {
            items.append(CloudItem(
                kind: .university,
                itemID: university.id.uuidString,
                payload: try encoder.encode(university),
                order: index
            ))
        }

        for (index, result) in snapshot.mockExamResults.enumerated() {
            items.append(CloudItem(
                kind: .mockExam,
                itemID: result.id.uuidString,
                payload: try encoder.encode(result),
                order: index
            ))
        }

        for (index, event) in snapshot.calendarEvents.enumerated() {
            items.append(CloudItem(
                kind: .calendarEvent,
                itemID: event.id.uuidString,
                payload: try encoder.encode(event),
                order: index
            ))
        }

        for (index, color) in snapshot.customColors.filter(\.isCustom).enumerated() {
            items.append(CloudItem(
                kind: .customColor,
                itemID: cloudSafeID(color.id),
                payload: try encoder.encode(color),
                order: index
            ))
        }

        return items
    }

    private func makeSnapshot<S: Sequence>(from items: S) throws -> UniexamCloudSnapshot
    where S.Element == CloudItem {
        let sortedItems = items.sorted {
            if $0.kind.rawValue == $1.kind.rawValue {
                return $0.order < $1.order
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }

        return UniexamCloudSnapshot(
            universities: try sortedItems.filter { $0.kind == .university }.map {
                try decoder.decode(UniversityChoice.self, from: $0.payload)
            },
            mockExamResults: try sortedItems.filter { $0.kind == .mockExam }.map {
                try decoder.decode(MockExamResult.self, from: $0.payload)
            },
            calendarEvents: try sortedItems.filter { $0.kind == .calendarEvent }.map {
                try decoder.decode(UserCalendarEvent.self, from: $0.payload)
            },
            customColors: try sortedItems.filter { $0.kind == .customColor }.map {
                try decoder.decode(SchoolColor.self, from: $0.payload)
            }
        )
    }

    private func cloudItem(from remote: RemoteCloudItem) -> CloudItem? {
        guard let payload = remote.payload else { return nil }
        return CloudItem(
            kind: remote.kind,
            itemID: remote.itemID,
            payload: payload,
            order: remote.order
        )
    }

    private func cloudSafeID(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func cloudRecordID(for key: String) -> CKRecord.ID {
        CKRecord.ID(recordName: recordNamespace + key)
    }

    private func makeSafetyBackupIfNeeded(_ snapshot: UniexamCloudSnapshot) {
        let defaults = UserDefaults.standard
        guard defaults.data(forKey: backupKey) == nil,
              let data = try? encoder.encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: backupKey)
    }

    private func mergeLegacySnapshot(
        into local: UniexamCloudSnapshot
    ) -> UniexamCloudSnapshot {
        let legacyStore = NSUbiquitousKeyValueStore.default
        legacyStore.synchronize()
        guard let data = legacyStore.data(forKey: legacySnapshotKey),
              let legacy = try? decoder.decode(UniexamCloudSnapshot.self, from: data) else {
            return local
        }

        var merged = local

        for legacyUniversity in legacy.universities {
            guard let index = merged.universities.firstIndex(where: {
                $0.id == legacyUniversity.id
            }) else {
                merged.universities.append(legacyUniversity)
                continue
            }

            for option in legacyUniversity.examOptions
                where !merged.universities[index].examOptions.contains(where: { $0.id == option.id }) {
                merged.universities[index].examOptions.append(option)
            }
            for link in legacyUniversity.customLinks
                where !merged.universities[index].customLinks.contains(where: { $0.id == link.id }) {
                merged.universities[index].customLinks.append(link)
            }
        }

        for result in legacy.mockExamResults
            where !merged.mockExamResults.contains(where: { $0.id == result.id }) {
            merged.mockExamResults.append(result)
        }
        for event in legacy.calendarEvents
            where !merged.calendarEvents.contains(where: { $0.id == event.id }) {
            merged.calendarEvents.append(event)
        }
        for color in legacy.customColors where !merged.customColors.contains(color) {
            merged.customColors.append(color)
        }

        return merged
    }

    private func publishFallbackSnapshot(_ snapshot: UniexamCloudSnapshot) {
        guard let data = try? encoder.encode(snapshot), data.count < 900_000 else {
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: legacySnapshotKey)
        store.synchronize()
    }

    private func loadMetadata() -> CloudSyncMetadata {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let metadata = try? decoder.decode(CloudSyncMetadata.self, from: data) else {
            return CloudSyncMetadata()
        }
        return metadata
    }

    private func saveMetadata(_ metadata: CloudSyncMetadata) {
        guard let data = try? encoder.encode(metadata) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }

    private func saveDiagnostic(_ message: String) {
        UserDefaults.standard.set(message, forKey: diagnosticKey)
    }

    private func isCloudUnavailable(_ error: Error) -> Bool {
        guard let error = error as? CKError else { return false }
        return [
            .notAuthenticated,
            .networkUnavailable,
            .networkFailure,
            .serviceUnavailable,
            .requestRateLimited,
            .zoneBusy
        ].contains(error.code)
    }
}

extension Notification.Name {
    static let uniexamCustomColorsDidChange = Notification.Name("Uniexam.customColorsDidChange")
}
