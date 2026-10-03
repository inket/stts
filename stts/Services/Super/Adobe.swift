//
//  Adobe.swift
//  stts
//

import Foundation

typealias Adobe = BaseAdobe & RequiredServiceProperties & AdobeStoreService
class BaseAdobe: BaseIndependentService {
    static var store = AdobeStore()

    let url = URL(string: "https://status.adobe.com")!

    override func updateStatus() async throws {
        guard let realSelf = self as? Adobe else {
            fatalError("BaseAdobe should not be used directly.")
        }

        statusDescription = try await BaseAdobe.store.updatedStatus(for: realSelf)
    }
}

class AdobeServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case cloud
        case isCategory = "category"
        case categoryName = "category_name"
        case oldNames = "old_names"
    }

    let id: String
    let cloud: String
    let providerIdentifier = "adobe"

    var categoryKey: String? { cloud }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        id = try container.decode(String.self, forKey: .id)
        cloud = try container.decode(String.self, forKey: .cloud)
        let name = try container.decode(String.self, forKey: .name)
        let isCategory = try container.decodeIfPresent(Bool.self, forKey: .isCategory) ?? false
        let categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        let oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)

        super.init(
            name: name,
            url: URL(string: "https://status.adobe.com")!,
            isCategory: isCategory ? true : nil,
            isSubService: isCategory ? nil : true,
            categoryName: categoryName,
            oldNames: oldNames
        )
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(cloud, forKey: .cloud)
    }

    func build() -> BaseService? {
        isCategory == true ? AdobeCategoryRow(self) : AdobeSubService(self)
    }
}

final class AdobeSubService: Adobe, SubService {
    let name: String
    let id: String

    init(_ definition: AdobeServiceDefinition) {
        name = definition.name
        id = definition.id
        super.init()
    }

    required init() {
        fatalError("AdobeSubService must be initialized with a definition")
    }
}

final class AdobeCategoryRow: Adobe, ServiceCategory {
    let categoryName: String
    let subServiceSuperclass: AnyObject.Type = AdobeSubService.self

    let name: String
    let id: String

    init(_ definition: AdobeServiceDefinition) {
        categoryName = definition.name
        name = definition.name
        id = definition.id
        super.init()
    }

    required init() {
        fatalError("AdobeCategoryRow must be initialized with a definition")
    }
}
