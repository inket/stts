//
//  MiroService.swift
//  stts
//

import Foundation

class MiroServiceDefinition: IncidentIOServiceDefinition {
    override func build() -> BaseService? {
        MiroService(self)
    }
}

class MiroService: IncidentIOService {}
