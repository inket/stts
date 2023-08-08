//
//  ServiceLoader.swift
//  stts
//

import Foundation

typealias ServiceDefinition = BaseServiceDefinition & ServiceDefinitionRequirements

class BaseServiceDefinition: Codable, BaseServiceDefinitionRequirements {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case isCategory = "category"
        case isSubService = "subservice"
        case oldNames = "old_names"
    }

    let name: String
    let url: URL
    let isCategory: Bool?
    let isSubService: Bool?
    let oldNames: Set<String>?

    private(set) lazy var legacyIdentifiers = oldNames ?? .init()

    init(name: String, url: URL, isCategory: Bool?, isSubService: Bool?, oldNames: Set<String>? = nil) {
        self.oldNames = oldNames
        self.name = name
        self.isCategory = isCategory
        self.isSubService = isSubService
        self.url = url
    }
}

protocol BaseServiceDefinitionRequirements {
    var name: String { get }
    var url: URL { get }
    var isCategory: Bool? { get }
    var isSubService: Bool? { get }
    var oldNames: Set<String>? { get }
    var alphanumericName: String { get }
}

extension BaseServiceDefinitionRequirements {
    var alphanumericName: String {
        String(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }
}

protocol ServiceDefinitionRequirements: BaseServiceDefinitionRequirements {
    var providerIdentifier: String { get }

    /// Identifier for this service for use in local storage.
    /// This is how it was stored before switching to JSON definitions
    var legacyIdentifiers: Set<String> { get }

    /// Identifier for this service for use in local storage.
    var globalIdentifier: String { get }

    func build() -> BaseService?
}

extension ServiceDefinitionRequirements {
    var globalIdentifier: String { "\(providerIdentifier).\(alphanumericName)" }

    func eq(_ other: ServiceDefinitionRequirements) -> Bool {
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
        case statusCakeServices = "statuscake"
        case statusPageServices = "statuspage"
        case instatusServices = "instatus"
        case statusCastServices = "statuscast"
        case incidentIOServices = "incidentio"
        case statusioV1Services = "statusiov1"
        case statuspalServices = "statuspal"
        case site24x7Services = "site24x7"
        case cstateServices = "cstate"
        case statusHubServices = "statushub"
        case betterUptimeServices = "betteruptime"
        case betterStackServices = "betterstack"
        case sendbirdServices = "sendbird"
    }

    let independentServices: [IndependentServiceDefinition]?
    let cachetServices: [CachetServiceDefinition]?
    let lambServices: [LambStatusServiceDefinition]?
    let sorryServices: [SorryServiceDefinition]?
    let statusCakeServices: [StatusCakeServiceDefinition]?
    let statusPageServices: [StatusPageServiceDefinition]?
    let instatusServices: [InstatusServiceDefinition]?
    let statusCastServices: [StatusCastServiceDefinition]?
    let incidentIOServices: [IncidentIOServiceDefinition]?
    let statusioV1Services: [StatusioV1ServiceDefinition]?
    let statuspalServices: [StatuspalServiceDefinition]?
    let site24x7Services: [Site24x7ServiceDefinition]?
    let cstateServices: [CStateServiceDefinition]?
    let statusHubServices: [StatusHubServiceDefinition]?
    let betterUptimeServices: [BetterUptimeServiceDefinition]?
    let betterStackServices: [BetterStackServiceDefinition]?
    let sendbirdServices: [SendbirdServiceDefinition]?

    var allServices: [ServiceDefinition] {
        let sections: [[ServiceDefinition]?] = [
            independentServices,
            cachetServices,
            lambServices,
            sorryServices,
            statusCakeServices,
            statusPageServices,
            instatusServices,
            statusCastServices,
            incidentIOServices,
            statusioV1Services,
            statuspalServices,
            site24x7Services,
            cstateServices,
            statusHubServices,
            betterUptimeServices,
            betterStackServices,
            sendbirdServices
        ]

        return sections.compactMap { $0 }.flatMap { $0 }
    }
}

class ServiceLoader {
    static var current = ServiceLoader()

    lazy var allServices: [ServiceDefinition] = {
        (definedServices + bundleServices).sorted(by: ServiceDefinitionSort)
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

        serviceDefinitions.sort(by: ServiceDefinitionSort)

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
