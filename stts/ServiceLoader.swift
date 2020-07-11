//
//  ServiceLoader.swift
//  stts
//

import Foundation

protocol ServiceDefinition {
    var name: String { get }
    var url: URL { get }

    /// Identifier for this service for use in local storage.
    /// This is how it was stored before switching to JSON definitions
    var legacyIdentifier: String { get }

    /// Identifier for this service for use in local storage.
    var globalIdentifier: String { get }

    func build() -> BaseService?
}

extension ServiceDefinition {
    var alphanumericName: String {
        String(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    func eq(_ other: ServiceDefinition) -> Bool {
        globalIdentifier == other.globalIdentifier
    }
}

let ServiceDefinitionSort: (ServiceDefinition, ServiceDefinition) -> Bool = { a, b in
    a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
}

private struct ServicesStructure: Codable {
    enum CodingKeys: String, CodingKey {
        case independentServices = "independent"
        case cachetServices = "cachet"
        case lambServices = "lamb"
        case sorryServices = "sorry"
        case statusCakeServices = "statusCake"
        case statusPageServices = "statusPage"
    }

    let independentServices: [IndependentServiceDefinition]?
    let cachetServices: [CachetServiceDefinition]?
    let lambServices: [LambStatusServiceDefinition]?
    let sorryServices: [SorryServiceDefinition]?
    let statusCakeServices: [StatusCakeServiceDefinition]?
    let statusPageServices: [StatusPageServiceDefinition]?

    var allServices: [ServiceDefinition] {
        let sections: [[ServiceDefinition]?] = [
            independentServices, cachetServices, lambServices, sorryServices, statusCakeServices, statusPageServices
        ]

        return sections.compactMap { $0 }.flatMap { $0 }
    }
}

class ServiceLoader {
    static var current = ServiceLoader()

    lazy var definedServices: [ServiceDefinition] = {
        var uniqueServiceIdentifiers = Set<String>()
        var serviceDefinitions = [ServiceDefinition]()

        var uniqueAppend: ([ServiceDefinition]) -> Void = { definitions in
            definitions.forEach { definition in
                guard !uniqueServiceIdentifiers.contains(definition.globalIdentifier) else { return }

                uniqueServiceIdentifiers.insert(definition.globalIdentifier)
                serviceDefinitions.append(definition)
            }
        }

        // Load the user-defined services
        uniqueAppend(loadUserDefinedServices() ?? [])

        // Load the included services
        uniqueAppend(loadIncludedServices())

        serviceDefinitions.sort(by: ServiceDefinitionSort)

        return serviceDefinitions
    }()

    init() {}

    func services(for definitions: [ServiceDefinition]) -> [BaseService] {
        definitions.compactMap { $0.build() }
    }

    func serviceDefinition(forIdentifier identifier: String) -> ServiceDefinition? {
        serviceDefinition(forGlobalIdentifier: identifier)
            ?? serviceDefinition(forLegacyIdentifier: identifier)
    }

    private func serviceDefinition(forLegacyIdentifier legacyIdentifier: String) -> ServiceDefinition? {
        definedServices.first { $0.legacyIdentifier == legacyIdentifier }
    }

    private func serviceDefinition(forGlobalIdentifier globalIdentifier: String) -> ServiceDefinition? {
        definedServices.first { $0.globalIdentifier == globalIdentifier }
    }

    private func loadIncludedServices() -> [ServiceDefinition] {
        guard let bundleServicesJSONPath = Bundle.main.path(forResource: "services", ofType: "json") else {
            fatalError("Could not find services.json in the bundle")
        }

        return loadServices(inPath: bundleServicesJSONPath, silentFailure: false)!
    }

    private func loadUserDefinedServices() -> [ServiceDefinition]? {
        guard
            let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else {
            assertionFailure("Could not find Application Support folder")
            return nil
        }

        let sttsAppSupportURL = applicationSupportURL.appendingPathComponent("stts")

        do {
            try FileManager.default.createDirectory(
                at: sttsAppSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            assertionFailure("Could not create \(sttsAppSupportURL.absoluteString)")
            return nil
        }

        let servicesJSONPath = sttsAppSupportURL.appendingPathComponent("services.json").path
        return loadServices(inPath: servicesJSONPath, silentFailure: true)
    }

    private func loadServices(inPath path: String, silentFailure: Bool) -> [ServiceDefinition]? {
        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            guard silentFailure else { fatalError("Could not load services.json") }
            return nil
        }

        guard let decodedServices = try? JSONDecoder().decode(ServicesStructure.self, from: jsonData) else {
            guard silentFailure else { fatalError("Could not decode services.json") }
            return nil
        }

        return decodedServices.allServices
    }
}
