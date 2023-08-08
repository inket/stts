//
//  SendbirdService.swift
//  SendbirdService
//

import Foundation

class SendbirdServiceDefinition: StatusPageServiceDefinition {
    override func build() -> BaseService? {
        SendbirdService(self)
    }
}

class SendbirdService: StatusPageService {}
