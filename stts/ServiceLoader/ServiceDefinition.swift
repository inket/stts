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
        assert(type(of: self) != CodableServiceDefinition.self)

        self.oldNames = oldNames
        self.name = name
        self.isCategory = isCategory
        self.isSubService = isSubService
        self.url = url
    }

    required init(from decoder: Decoder) throws {
        assert(type(of: self) != CodableServiceDefinition.self)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.isCategory = try container.decodeIfPresent(Bool.self, forKey: .isCategory)
        self.isSubService = try container.decodeIfPresent(Bool.self, forKey: .isSubService)
        self.oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.url, forKey: .url)
        try container.encodeIfPresent(self.isCategory, forKey: .isCategory)
        try container.encodeIfPresent(self.isSubService, forKey: .isSubService)
        try container.encodeIfPresent(self.oldNames, forKey: .oldNames)
    }
}
