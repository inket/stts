//
//  AzureDevOpsDevOps.swift
//  stts
//

import Foundation

typealias AzureDevOps = BaseAzureDevOps & RequiredServiceProperties & AzureDevOpsStoreService

class BaseAzureDevOps: BaseIndependentService {
    private static let store = AzureDevOpsStore()

    override func updateStatus() async throws {
        guard let realSelf = self as? AzureDevOps else {
            fatalError("BaseAzureDevOps should not be used directly.")
        }

        statusDescription = try await BaseAzureDevOps.store.updatedStatus(for: realSelf)
    }
}

class AzureDevOpsServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    // Default url for entries that don't override it; every entry is always a subservice of AzureDevOpsAll.
    static let commonURL = URL(string: "https://status.dev.azure.com")!

    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case url
        case oldNames = "old_names"
    }

    let id: String
    let providerIdentifier = "azuredevops"

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
        AzureDevOpsService(self)
    }
}

final class AzureDevOpsService: AzureDevOps, SubService {
    let name: String
    let url: URL
    let serviceName: String

    init(_ definition: AzureDevOpsServiceDefinition) {
        name = definition.name
        url = definition.url
        serviceName = definition.id
        super.init()
    }

    required init() {
        fatalError("AzureDevOpsService must be initialized with a definition")
    }
}
