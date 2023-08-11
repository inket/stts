//
//  ServiceLoader.swift
//  stts
//

import Foundation

final class ServiceLoader {
    private let providers: [ServiceDefinitionProvider]

    init(providers: [ServiceDefinitionProvider]) {
        self.providers = providers
    }

    private(set) lazy var allServices: [ServiceDefinition] = {
        var uniqueServiceIdentifiers = Set<String>()
        var serviceDefinitions = [ServiceDefinition]()

        var uniqueAppend: ([ServiceDefinition]) -> Void = { definitions in
            definitions.forEach { definition in
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
    }()

    private(set) lazy var allServicesWithoutSubServices: [ServiceDefinition] = {
        allServices.filter { !($0.isSubService == true) }
    }()

    func services(for definitions: [ServiceDefinition]) -> [BaseService] {
        definitions.compactMap { $0.build() }
    }

    func serviceDefinition(forIdentifier identifier: String) -> ServiceDefinition? {
        allServices.first {
            $0.globalIdentifier == identifier || // The recommended way for identifying services
            $0.alphanumericName.lowercased() == identifier.lowercased() || // The old way (class-name based)
            $0.legacyIdentifiers.contains(identifier) // The old names used for a service
        }
    }
}
