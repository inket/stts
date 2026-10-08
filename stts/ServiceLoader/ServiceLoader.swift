//
//  ServiceLoader.swift
//  stts
//

import Foundation

@MainActor
final class ServiceLoader {
    private let providers: [ServiceDefinitionProvider]

    init(providers: [ServiceDefinitionProvider]) {
        self.providers = providers
        allServices = Self.buildAllServices(providers: providers)
        allServicesWithoutSubServices = allServices.filter { !($0.isSubService == true) }
        removedIdentifiers = providers.reduce(into: Set<String>()) { $0.formUnion($1.removedIdentifiers) }
    }

    private(set) var allServices: [ServiceDefinition]
    private(set) var allServicesWithoutSubServices: [ServiceDefinition]
    private(set) var removedIdentifiers: Set<String>

    /// Re-reads every provider's backing data and recomputes the cached properties above. Used
    /// after a remote services.json re-fetch (see `RemoteServiceDefinitionProvider`) so the app can
    /// pick up changes without a relaunch.
    func reload() {
        providers.forEach { $0.reload() }
        allServices = Self.buildAllServices(providers: providers)
        allServicesWithoutSubServices = allServices.filter { !($0.isSubService == true) }
        removedIdentifiers = providers.reduce(into: Set<String>()) { $0.formUnion($1.removedIdentifiers) }
    }

    private static func buildAllServices(providers: [ServiceDefinitionProvider]) -> [ServiceDefinition] {
        var uniqueServiceIdentifiers = Set<String>()
        var serviceDefinitions = [ServiceDefinition]()

        let uniqueAppend: ([ServiceDefinition]) -> Void = { definitions in
            definitions.forEach { definition in
                guard definition.isSupported else { return }
                guard !uniqueServiceIdentifiers.contains(definition.globalIdentifier) else { return }

                uniqueServiceIdentifiers.insert(definition.globalIdentifier)
                serviceDefinitions.append(definition)
            }
        }

        for provider in providers {
            // swiftlint:disable:next force_try
            if let providerDefinitions = try! provider.definedServices() {
                uniqueAppend(providerDefinitions)
            }
        }

        return serviceDefinitions.sorted(by: ServiceDefinitionSortByName)
    }

    func services(for definitions: [ServiceDefinition]) -> [BaseService] {
        definitions.compactMap { $0.build() }
    }

    /// Same as `services(for:)`, but keeps each built service paired with the definition it came
    /// from. `build()` discards that link, and the popup needs it to resolve favicons.
    func servicesWithDefinitions(
        for definitions: [ServiceDefinition]
    ) -> [(definition: ServiceDefinition, service: BaseService)] {
        definitions.compactMap { definition in
            guard let service = definition.build() else { return nil }
            return (definition, service)
        }
    }

    func serviceDefinition(forIdentifier identifier: String) -> ServiceDefinition? {
        // An exact match wins outright, ahead of any service whose name merely sorts earlier.
        if let exact = allServices.first(where: { $0.globalIdentifier == identifier }) {
            return exact
        }
        // The fallbacks bridge identifiers stored before providers existed. A custom service is
        // only ever stored by its id, and must not claim, say, a stored "GitHub" by its name.
        return allServices.first {
            !$0.isCustom && (
                $0.alphanumericName.lowercased() == identifier.lowercased() || // The old way (class-name based)
                $0.legacyIdentifiers.contains(identifier) // The old names used for a service
            )
        }
    }
}
