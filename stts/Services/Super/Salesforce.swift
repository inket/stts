//
//  Salesforce.swift
//  Salesforce
//

import Foundation

typealias Salesforce = BaseSalesforce & RequiredServiceProperties & SalesforceStoreService

class BaseSalesforce: BaseIndependentService {
    override func updateStatus() async throws {
        guard let realSelf = self as? Salesforce else {
            fatalError("BaseSalesforce should not be used directly.")
        }

        statusDescription = try await realSelf.store.updatedStatus(for: realSelf)
    }
}

class SalesforceServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case product
        case isCategory = "category"
        case categoryName = "category_name"
        case oldNames = "old_names"
    }

    let id: String
    let product: String
    let providerIdentifier = "salesforce"

    var categoryKey: String? { product }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        id = try container.decode(String.self, forKey: .id)
        product = try container.decode(String.self, forKey: .product)
        let name = try container.decode(String.self, forKey: .name)
        let isCategory = try container.decodeIfPresent(Bool.self, forKey: .isCategory) ?? false
        let categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        let oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)
        let tags = try CodableServiceDefinition.decodeTags(from: decoder)
        let url = URL(string: "https://status.salesforce.com/products/\(product)")!

        super.init(
            name: name,
            url: url,
            isCategory: isCategory ? true : nil,
            isSubService: isCategory ? nil : true,
            categoryName: categoryName,
            oldNames: oldNames,
            tags: tags
        )
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(product, forKey: .product)
    }

    func build() -> BaseService? {
        isCategory == true ? SalesforceCategoryRow(self) : SalesforceSubService(self)
    }
}

final class SalesforceSubService: Salesforce, SubService {
    let name: String
    let url: URL
    let key: String
    let location: String

    init(_ definition: SalesforceServiceDefinition) {
        name = definition.name
        url = definition.url
        key = definition.product
        location = definition.id
        super.init()
    }

    required init() {
        fatalError("SalesforceSubService must be initialized with a definition")
    }
}

final class SalesforceCategoryRow: Salesforce, ServiceCategory {
    let categoryName: String
    let subServiceSuperclass: AnyObject.Type = SalesforceSubService.self

    let name: String
    let url: URL
    let key: String
    let location = "*"

    init(_ definition: SalesforceServiceDefinition) {
        categoryName = definition.name
        name = definition.name
        url = definition.url
        key = definition.product
        super.init()
    }

    required init() {
        fatalError("SalesforceCategoryRow must be initialized with a definition")
    }
}
