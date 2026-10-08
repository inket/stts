//
//  CustomServiceStore.swift
//  stts
//

import Foundation

/// Owns `custom_services.json` and the Keychain items behind its secret headers.
///
/// Entries are decoded one at a time. One whose `version` is above
/// `CustomServiceRecord.supportedVersion`, or that doesn't decode, isn't loaded but is kept as raw
/// JSON and written back in place on every save, so an older build never destroys what a newer one
/// wrote.
///
/// Used from the main thread only.
final class CustomServiceStore {
    private enum Entry {
        case service(CustomService)
        /// A JSON object this build can't load, kept verbatim.
        case preserved(Any)
    }

    struct ImportSummary: Equatable {
        var addedIDs: [UUID] = []
        var replacedIDs: [UUID] = []
        /// Too new for this build, or unreadable.
        var skippedCount = 0
    }

    enum StoreError: Error {
        case notAServicesFile
    }

    let fileURL: URL?
    private let secrets: CustomServiceSecrets
    private var entries: [Entry] = []

    var services: [CustomService] {
        entries.compactMap { entry in
            if case let .service(service) = entry { return service }
            return nil
        }
    }

    /// Entries in the file this build doesn't load.
    var skippedCount: Int { entries.count - services.count }

    /// `fileURL` nil keeps everything in memory.
    init(fileURL: URL?, secrets: CustomServiceSecrets) {
        self.fileURL = fileURL
        self.secrets = secrets
        reload()
    }

    /// `~/Library/Application Support/stts/custom_services.json`, inside the sandbox container.
    static func defaultFileURL() throws -> URL {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("stts")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("custom_services.json")
    }

    func reload() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            entries = []
            return
        }

        do {
            entries = try Self.items(in: data).map { item in
                guard let record = Self.record(from: item) else { return .preserved(item) }
                return .service(record.service { self.secrets.value(serviceID: record.id, headerName: $0) })
            }
        } catch {
            debugPrint("Couldn't read \(fileURL.lastPathComponent): \(error)")
            entries = []
        }
    }

    // MARK: - Changes

    func add(_ service: CustomService) {
        entries.append(.service(service))
        syncSecrets(from: nil, to: service)
        save()
    }

    func update(_ service: CustomService) {
        guard let index = index(of: service.id), case let .service(old) = entries[index] else { return }
        entries[index] = .service(service)
        syncSecrets(from: old, to: service)
        save()
    }

    func delete(id: UUID) {
        guard let index = index(of: id), case let .service(old) = entries[index] else { return }
        entries.remove(at: index)
        syncSecrets(from: old, to: nil)
        save()
    }

    private func index(of id: UUID) -> Int? {
        entries.firstIndex { entry in
            if case let .service(service) = entry { return service.id == id }
            return false
        }
    }

    /// Writes new and changed secret values, and removes items for headers that are gone or no
    /// longer secret. A secret with an empty value (its item went missing) is left alone.
    private func syncSecrets(from old: CustomService?, to new: CustomService?) {
        guard let id = new?.id ?? old?.id else { return }

        let newSecrets = (new?.requestHeaders ?? []).filter(\.isSecret)
        let newNames = Set(newSecrets.map { $0.name.lowercased() })

        for header in old?.requestHeaders ?? [] where header.isSecret && !newNames.contains(header.name.lowercased()) {
            secrets.removeValue(serviceID: id, headerName: header.name)
        }
        for header in newSecrets where !header.value.isEmpty {
            secrets.setValue(header.value, serviceID: id, headerName: header.name)
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try Self.fileData(for: entries, includeSecretValues: false).write(to: fileURL, options: .atomic)
        } catch {
            debugPrint("Couldn't save \(fileURL.lastPathComponent): \(error)")
        }
    }

    // MARK: - Import / export

    /// The same format as the file, with each secret header's value inlined from the Keychain.
    func exportData() throws -> Data {
        try Self.fileData(for: entries, includeSecretValues: true)
    }

    /// Adds every loadable entry in `data`, replacing an existing service with the same id. Secret
    /// values go to the Keychain; an imported secret without a value keeps whatever the Keychain
    /// already has for it.
    func importData(_ data: Data) throws -> ImportSummary {
        var summary = ImportSummary()

        for item in try Self.items(in: data) {
            guard let record = Self.record(from: item) else {
                summary.skippedCount += 1
                continue
            }

            let service = record.service { self.secrets.value(serviceID: record.id, headerName: $0) }
            if let index = index(of: service.id), case let .service(old) = entries[index] {
                entries[index] = .service(service)
                syncSecrets(from: old, to: service)
                summary.replacedIDs.append(service.id)
            } else {
                entries.append(.service(service))
                syncSecrets(from: nil, to: service)
                summary.addedIDs.append(service.id)
            }
        }

        save()
        return summary
    }

    // MARK: - JSON

    private static func items(in data: Data) throws -> [Any] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["services"] as? [Any]
        else { throw StoreError.notAServicesFile }
        return items
    }

    /// `nil` for an entry this build can't load: too new, or malformed.
    private static func record(from item: Any) -> CustomServiceRecord? {
        guard
            let object = item as? [String: Any],
            let version = object["version"] as? Int,
            version <= CustomServiceRecord.supportedVersion,
            let data = try? JSONSerialization.data(withJSONObject: object)
        else { return nil }
        return try? JSONDecoder().decode(CustomServiceRecord.self, from: data)
    }

    private static func fileData(for entries: [Entry], includeSecretValues: Bool) throws -> Data {
        let encoder = JSONEncoder()
        let items: [Any] = try entries.map { entry in
            switch entry {
            case let .service(service):
                let record = CustomServiceRecord(service, includeSecretValues: includeSecretValues)
                return try JSONSerialization.jsonObject(with: encoder.encode(record))
            case let .preserved(item):
                return item
            }
        }
        return try JSONSerialization.data(
            withJSONObject: ["services": items],
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }
}
