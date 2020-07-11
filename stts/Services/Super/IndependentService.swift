//
//  IndependentService.swift
//  stts
//

import Foundation

struct IndependentServiceDefinition: Codable, ServiceDefinition {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case oldName = "old_name"
        case className = "class_name"
    }

    let name: String
    let url: URL
    let oldName: String?
    let className: String?

    var legacyIdentifier: String {
        // Before JSON definitions, we were using class names as identifiers. Try to replicate that now.
        oldName ?? className ?? name
    }

    var globalIdentifier: String { "independent.\(alphanumericName)" }

    func build() -> BaseService? {
        let typeName = className ?? name
        let globalTypeName = "stts.\(typeName)"

        return (NSClassFromString(globalTypeName) as? IndependentService.Type)?.init(self)
    }
}

class IndependentService: Service {
    let name: String
    let url: URL
    let oldName: String?
    let className: String?

    public required init(_ definition: IndependentServiceDefinition) {
        name = definition.name
        url = definition.url
        oldName = definition.oldName
        className = definition.className
    }
}
