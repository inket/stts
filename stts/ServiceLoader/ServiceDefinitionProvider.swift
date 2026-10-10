//
//  ServiceDefinitionProvider.swift
//  stts
//

import Foundation

protocol ServiceDefinitionProvider {
    func definedServices() throws -> [ServiceDefinition]?

    /// Identifiers (see `ServiceLoader.serviceDefinition(forIdentifier:)`) of services confirmed
    /// gone for good — not just currently broken/unreachable — so a stored preference for them can
    /// be pruned instead of silently never matching anything again. See
    /// `ServicesStructure.removedServices` for the exact bar for "gone for good".
    var removedIdentifiers: Set<String> { get }

    /// The category vocabulary this provider's data defines (`"_tags"`), sorted by name.
    var tags: [ServiceTag] { get }

    /// Re-reads whatever backs this provider, so a subsequent call to `definedServices()` reflects
    /// changes made since this provider was created (e.g. a remote services.json re-fetched after
    /// launch — see `RemoteServiceDefinitionProvider`/`ServiceLoader.reload()`). A no-op for
    /// providers whose data can't change at runtime.
    func reload()
}

extension ServiceDefinitionProvider {
    var removedIdentifiers: Set<String> { [] }
    var tags: [ServiceTag] { [] }
    func reload() {}
}

class JSONBasedServiceDefinitionProvider: ServiceDefinitionProvider {
    private let path: String
    let required: Bool

    private var decodeResult: Result<ServicesStructure, Error>

    var removedIdentifiers: Set<String> {
        Set((try? decodeResult.get())?.removedServices ?? [])
    }

    var tags: [ServiceTag] {
        (try? decodeResult.get())?.tags ?? []
    }

    init(path: String, required: Bool) {
        self.path = path
        self.required = required
        self.decodeResult = Self.decode(path: path)
    }

    func reload() {
        decodeResult = Self.decode(path: path)
    }

    private static func decode(path: String) -> Result<ServicesStructure, Error> {
        Result {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
            return try JSONDecoder().decode(ServicesStructure.self, from: jsonData)
        }
    }

    func definedServices() throws -> [ServiceDefinition]? {
        do {
            return try decodeResult.get().allServices
        } catch {
            if required {
                throw error
            } else {
                return []
            }
        }
    }
}
