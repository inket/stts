//
//  IndependentService.swift
//  stts
//

import Foundation

class IndependentServiceDefinition: CodableServiceDefinition, ServiceDefinition {
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

    /// The class this definition names, or nil if this build doesn't have it. Resolving the class
    /// is cheap (no instance is created), unlike `build()`.
    var serviceClass: BaseIndependentService.Type? {
        NSClassFromString("stts.\(className ?? alphanumericName)") as? BaseIndependentService.Type
    }

    /// An `independent` entry only supplies a service's *identity* — its behaviour is compiled in.
    /// A newer remote services.json can therefore name a class this build doesn't have, which isn't
    /// an error: the service is simply skipped until the app updates. Anything else would either
    /// crash on a perfectly ordinary remote update or leave a dead row in the list that can never
    /// report a status.
    var isSupported: Bool { serviceClass != nil }

    func build() -> BaseService? {
        serviceClass?.init()
    }
}

typealias IndependentService = BaseIndependentService & RequiredServiceProperties

class BaseIndependentService: BaseService {
    public required override init() {}
}
