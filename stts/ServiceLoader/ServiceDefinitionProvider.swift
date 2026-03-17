//
//  ServiceDefinitionProvider.swift
//  stts
//

import Foundation

protocol ServiceDefinitionProvider {
    func definedServices() throws -> [ServiceDefinition]?
}

class JSONBasedServiceDefinitionProvider: ServiceDefinitionProvider {
    private let path: String
    let required: Bool

    init(path: String, required: Bool) {
        self.path = path
        self.required = required
    }

    func definedServices() throws -> [ServiceDefinition]? {
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
            let decodedServices = try JSONDecoder().decode(ServicesStructure.self, from: jsonData)
            return decodedServices.allServices
        } catch {
            if required {
                throw error
            } else {
                return []
            }
        }
    }
}

class ClassBasedServiceDefinitionProvider: ServiceDefinitionProvider {
    private let classNames: [String]

    init(classNames: [String]) {
        self.classNames = classNames
    }

    func definedServices() throws -> [ServiceDefinition]? {
        classNames.compactMap {
            IndependentServiceDefinition(fromClassName: $0)
        }
    }
}
