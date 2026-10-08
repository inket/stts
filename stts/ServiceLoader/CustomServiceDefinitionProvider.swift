//
//  CustomServiceDefinitionProvider.swift
//  stts
//

import Foundation

/// Serves the store's services to `ServiceLoader`, so the popup, notifications and enablement treat
/// them like any other service. Reads the store live: the store is the source of truth and saves
/// on every change, so there's nothing to re-read on `reload()`.
final class CustomServiceDefinitionProvider: ServiceDefinitionProvider {
    private let store: CustomServiceStore

    init(store: CustomServiceStore) {
        self.store = store
    }

    func definedServices() throws -> [ServiceDefinition]? {
        store.services.map(CustomServiceDefinition.init)
    }
}

final class CustomServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    let providerIdentifier = CustomService.providerIdentifier
    let service: CustomService

    init(_ service: CustomService) {
        self.service = service
        super.init(name: service.name, url: service.url, isCategory: nil, isSubService: nil)
    }

    /// Custom services come from `CustomServiceStore`, never from a catalogue file.
    required init(from decoder: Decoder) throws {
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Custom services aren't decoded from services.json")
        )
    }

    var globalIdentifier: String { service.globalIdentifier }

    func build() -> BaseService? {
        CustomURLService(service)
    }
}

extension ServiceDefinition {
    var isCustom: Bool { providerIdentifier == CustomService.providerIdentifier }
}
