//
//  Sendbird.swift
//  Sendbird
//

import Foundation

typealias SendbirdService = BaseSendbirdService & RequiredServiceProperties & RequiredStatusPageProperties

class BaseSendbirdService: BaseStatusPageService {
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard self is SendbirdService else {
            fatalError("BaseSendbirdService should not be used directly.")
        }

        super.updateStatus(callback: callback)
    }
}
