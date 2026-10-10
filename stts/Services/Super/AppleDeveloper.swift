//
//  AppleDeveloper.swift
//  stts
//

import Foundation

typealias AppleDeveloper = BaseAppleDeveloper & RequiredServiceProperties & AppleStoreService

class BaseAppleDeveloper: BaseIndependentService {
    private static var store = AppleStore(
        url: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js"
    )

    override func updateStatus() async throws {
        guard let realSelf = self as? AppleDeveloper else {
            fatalError("BaseAppleDeveloper should not be used directly.")
        }

        statusDescription = try await BaseAppleDeveloper.store.updatedStatus(for: realSelf)
    }
}

class AppleDeveloperServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    static let commonURL = URL(string: "https://developer.apple.com/system-status/")!

    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case oldNames = "old_names"
    }

    let id: String
    let providerIdentifier = "appledeveloper"

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
        AppleDeveloperGeneric(self)
    }
}

final class AppleDeveloperGeneric: AppleDeveloper, SubService {
    let name: String
    let url = AppleDeveloperServiceDefinition.commonURL
    let serviceName: String

    init(_ definition: AppleDeveloperServiceDefinition) {
        name = definition.name
        serviceName = definition.id
        super.init()
    }

    required init() {
        fatalError("AppleDeveloperGeneric must be initialized with a definition")
    }
}
