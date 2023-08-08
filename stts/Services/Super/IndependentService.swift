//
//  IndependentService.swift
//  stts
//

import Foundation

class IndependentServiceDefinition: ServiceDefinition {
    enum ExtraKeys: String, CodingKey {
        case className = "class_name"
    }

    let className: String?
    let providerIdentifier = "independent"

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        className = try container.decodeIfPresent(String.self, forKey: .className)

        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(className, forKey: .className)
    }

    init?(fromClassName className: String) {
        let globalTypeName = "stts.\(className)"
        let klass = NSClassFromString(globalTypeName) as? BaseIndependentService.Type

        guard let service = klass?.init() as? Service else {
            assertionFailure("Failed to initialize service definition from class name")
            return nil
        }

        self.className = className

        super.init(
            name: service.name,
            url: service.url,
            isCategory: service is ServiceCategory,
            isSubService: service is SubService
        )
    }

    private lazy var overriddenLegacyIdentifiers: Set<String> = {
        var set = oldNames ?? .init()
        if let className {
            // Before JSON definitions, we were using class names as identifiers. Try to replicate that now.
            set.insert(className)
        }
        return set
    }()

    override var legacyIdentifiers: Set<String> {
        overriddenLegacyIdentifiers
    }

    func build() -> BaseService? {
        let typeName = className ?? alphanumericName
        let globalTypeName = "stts.\(typeName)"

        guard let service = (NSClassFromString(globalTypeName) as? BaseIndependentService.Type)?.init() else {
            assertionFailure("Failed to initialize service from class name")
            return nil
        }

        return service
    }
}

typealias IndependentService = BaseIndependentService & RequiredServiceProperties

class BaseIndependentService: BaseService {
    public required override init() {}
}
