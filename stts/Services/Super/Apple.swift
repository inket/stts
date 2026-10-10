//
//  Apple.swift
//  stts
//

import Foundation

typealias Apple = BaseApple & RequiredServiceProperties & AppleStoreService

class BaseApple: BaseIndependentService {
    private static var store = AppleStore(
        url: "https://www.apple.com/support/systemstatus/data/system_status_en_US.js"
    )

    override func updateStatus() async throws {
        guard let realSelf = self as? Apple else {
            fatalError("BaseApple should not be used directly.")
        }

        statusDescription = try await BaseApple.store.updatedStatus(for: realSelf)
    }
}

class AppleServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    static let commonURL = URL(string: "https://www.apple.com/support/systemstatus/")!

    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case oldNames = "old_names"
    }

    let id: String
    let providerIdentifier = "apple"

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
        AppleGeneric(self)
    }
}

final class AppleGeneric: Apple, SubService {
    let name: String
    let url = AppleServiceDefinition.commonURL
    let serviceName: String

    init(_ definition: AppleServiceDefinition) {
        name = definition.name
        serviceName = definition.id
        super.init()
    }

    required init() {
        fatalError("AppleGeneric must be initialized with a definition")
    }
}
