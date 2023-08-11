//
//  ServiceDefinition.swift
//  stts
//

import Foundation

protocol ServiceDefinition: CodableServiceDefinition {
    /// Identifier of the provider of the status page (e.g. statuspage, statuspal, cachet, instatus, etc.)
    /// For use in local storage.
    var providerIdentifier: String { get }

    /// Identifier for this service for use in local storage.
    /// This is how it was stored before switching to JSON definitions
    var legacyIdentifiers: Set<String> { get }

    /// Identifier for this service for use in local storage.
    var globalIdentifier: String { get }

    /// Builds the service object from the definition.
    func build() -> BaseService?
}

extension ServiceDefinition {
    var globalIdentifier: String { "\(providerIdentifier).\(alphanumericName)" }

    func eq(_ other: ServiceDefinition) -> Bool {
        globalIdentifier == other.globalIdentifier
    }
}

let ServiceDefinitionSortByName: (ServiceDefinition, ServiceDefinition) -> Bool = { a, b in
    a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
}

class CodableServiceDefinition: Codable {
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

    var alphanumericName: String {
        String(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    init(name: String, url: URL, isCategory: Bool?, isSubService: Bool?, oldNames: Set<String>? = nil) {
        self.oldNames = oldNames
        self.name = name
        self.isCategory = isCategory
        self.isSubService = isSubService
        self.url = url
    }
}
