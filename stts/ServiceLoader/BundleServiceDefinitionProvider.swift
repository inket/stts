//
//  BundleServiceDefinitionProvider.swift
//  stts
//

import Foundation

enum BundleServiceDefinitionProviderError: Error {
    case bundledServicesPlistNotFound
    case bundledServicesPlistWrongFormat
}

class BundleServiceDefinitionProvider: ClassBasedServiceDefinitionProvider {
    init() throws {
        guard let servicesPlist = Bundle.main.path(forResource: "services", ofType: "plist") else {
            throw BundleServiceDefinitionProviderError.bundledServicesPlistNotFound
        }

        guard let classNames = NSDictionary(contentsOfFile: servicesPlist)?["services"] as? [String] else {
            throw BundleServiceDefinitionProviderError.bundledServicesPlistWrongFormat
        }

        super.init(classNames: classNames)
    }
}
