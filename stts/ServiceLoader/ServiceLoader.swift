//
//  ServiceLoader.swift
//  stts
//

import Foundation

class ServiceLoader {
    static var current = ServiceLoader()

    lazy var allServices: [ServiceDefinition] = {
        (definedServices + bundleServices).sorted(by: ServiceDefinitionSortByName)
    }()

    lazy var allServicesWithoutSubServices: [ServiceDefinition] = {
        allServices.filter { !($0.isSubService == true) }
    }()

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

        serviceDefinitions.sort(by: ServiceDefinitionSortByName)

        return serviceDefinitions
    }()

    lazy var bundleServices: [ServiceDefinition] = {
        guard let servicesPlist = Bundle.main.path(forResource: "services", ofType: "plist"),
            let services = NSDictionary(contentsOfFile: servicesPlist)?["services"] as? [String] else {
                fatalError("The services.plist file does not exist. The build phase script might have failed.")
        }

        return services.compactMap { IndependentServiceDefinition(fromClassName: $0) }
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
        allServices.first {
            $0.alphanumericName.lowercased() == legacyIdentifier.lowercased() ||
            $0.legacyIdentifiers.contains(legacyIdentifier)
        }
    }

    private func serviceDefinition(forGlobalIdentifier globalIdentifier: String) -> ServiceDefinition? {
        allServices.first { $0.globalIdentifier == globalIdentifier }
    }

    private func loadIncludedServices() -> [ServiceDefinition] {
        guard let bundleServicesJSONPath = Bundle.main.path(forResource: "services", ofType: "json") else {
            fatalError("Could not find services.json in the bundle")
        }

        // swiftlint:disable:next force_try
        return try! loadServices(inPath: bundleServicesJSONPath)
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

        do {
            return try loadServices(inPath: servicesJSONPath)
        } catch {
            // Silent failure
            print(error.localizedDescription)
            return nil
        }
    }

    private func loadServices(inPath path: String) throws -> [ServiceDefinition] {
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
        let decodedServices = try JSONDecoder().decode(ServicesStructure.self, from: jsonData)

        return decodedServices.allServices
    }
}
