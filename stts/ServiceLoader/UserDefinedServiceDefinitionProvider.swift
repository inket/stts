//
//  UserDefinedServiceDefinitionProvider.swift
//  stts
//

import Foundation

// swiftlint:disable:next type_name
enum UserDefinedServiceDefinitionProviderError: Error {
    case applicationSupportDirectoryNotFound
}

class UserDefinedServiceDefinitionProvider: JSONBasedServiceDefinitionProvider {
    init() throws {
        guard
            let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else {
            assertionFailure("Could not find Application Support folder")
            throw UserDefinedServiceDefinitionProviderError.applicationSupportDirectoryNotFound
        }

        let sttsAppSupportURL = applicationSupportURL.appendingPathComponent("stts")

        try FileManager.default.createDirectory(
            at: sttsAppSupportURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let servicesJSONPath = sttsAppSupportURL.appendingPathComponent("services.json").path

        super.init(path: servicesJSONPath, required: false)
    }
}
