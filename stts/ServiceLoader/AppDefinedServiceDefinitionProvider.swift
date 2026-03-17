//
//  AppDefinedServiceDefinitionProvider.swift
//  stts
//

import Foundation

enum AppDefinedServiceDefinitionProviderError: Error {
    case bundleServicesJSONNotFound
}

class AppDefinedServiceDefinitionProvider: JSONBasedServiceDefinitionProvider {
    init() throws {
        guard let bundleServicesJSONPath = Bundle.main.path(forResource: "services", ofType: "json") else {
            assertionFailure("Could not find services.json in the bundle")
            throw AppDefinedServiceDefinitionProviderError.bundleServicesJSONNotFound
        }

        super.init(path: bundleServicesJSONPath, required: true)
    }
}
