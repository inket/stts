//
//  Azure.swift
//  stts
//

import Foundation

typealias Azure = BaseAzure & RequiredServiceProperties & AzureStoreService

class BaseAzure: BaseIndependentService {
    private static var store = AzureStore()

    override func updateStatus() async throws {
        guard let realSelf = self as? Azure else {
            fatalError("BaseAzure should not be used directly.")
        }

        statusDescription = try await BaseAzure.store.updatedStatus(for: realSelf)
    }
}

class AzureServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    // Default url for entries that don't override it; every entry is always a subservice of AzureAll.
    static let commonURL = URL(string: "https://azure.status.microsoft/en-us/status")!

    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case url
        case oldNames = "old_names"
    }

    let id: String
    let providerIdentifier = "azure"

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let url = try container.decodeIfPresent(URL.self, forKey: .url) ?? Self.commonURL
        let oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)
        let tags = try CodableServiceDefinition.decodeTags(from: decoder)

        super.init(name: name, url: url, isCategory: nil, isSubService: true, oldNames: oldNames, tags: tags)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(id, forKey: .id)
    }

    func build() -> BaseService? {
        AzureService(self)
    }
}

final class AzureService: Azure, SubService {
    let name: String
    let url: URL
    let zoneIdentifier: String

    init(_ definition: AzureServiceDefinition) {
        name = definition.name
        url = definition.url
        zoneIdentifier = definition.id
        super.init()
    }

    required init() {
        fatalError("AzureService must be initialized with a definition")
    }
}
