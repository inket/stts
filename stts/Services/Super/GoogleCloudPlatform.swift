//
//  GoogleCloudPlatform.swift
//  stts
//

import Foundation

typealias GoogleCloudPlatform = BaseGoogleCloudPlatform & RequiredServiceProperties & GoogleStatusDashboardStoreService

class BaseGoogleCloudPlatform: BaseIndependentService {
    private static var store = GoogleStatusDashboardStore(url: GoogleCloudPlatformServiceDefinition.commonURL)

    override func updateStatus() async throws {
        guard let realSelf = self as? GoogleCloudPlatform else {
            fatalError("BaseGoogleCloudPlatform should not be used directly.")
        }

        statusDescription = try await BaseGoogleCloudPlatform.store.updatedStatus(for: realSelf)
    }
}

class GoogleCloudPlatformServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    static let commonURL = URL(string: "https://status.cloud.google.com")!

    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case oldNames = "old_names"
    }

    let id: String
    let providerIdentifier = "googlecloudplatform"

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)
        let tags = try CodableServiceDefinition.decodeTags(from: decoder)

        super.init(name: name, url: Self.commonURL, isCategory: nil, isSubService: true, oldNames: oldNames, tags: tags)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(id, forKey: .id)
    }

    func build() -> BaseService? {
        GoogleCloudPlatformSubService(self)
    }
}

final class GoogleCloudPlatformSubService: GoogleCloudPlatform, SubService {
    let name: String
    let url = GoogleCloudPlatformServiceDefinition.commonURL
    let dashboardName: String

    init(_ definition: GoogleCloudPlatformServiceDefinition) {
        name = definition.name
        dashboardName = definition.id
        super.init()
    }

    required init() {
        fatalError("GoogleCloudPlatformSubService must be initialized with a definition")
    }
}
