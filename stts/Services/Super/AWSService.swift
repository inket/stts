//
//  AWSService.swift
//  stts
//

import Foundation

typealias AWSAllService = BaseAWSAllService & RequiredServiceProperties & RequiredAWSAllServiceProperties
typealias AWSRegionService = BaseAWSRegionService & RequiredServiceProperties & RequiredAWSRegionServiceProperties
typealias AWSNamedService = BaseAWSNamedService & RequiredServiceProperties & RequiredAWSNamedServiceProperties

protocol RequiredAWSAllServiceProperties {}

protocol RequiredAWSNamedServiceProperties {
    var name: String { get }
    var ids: Set<String> { get }
}

protocol RequiredAWSRegionServiceProperties {
    var name: String { get }
    var id: String { get }
}

class BaseAWSAllService: BaseAWSService {}
class BaseAWSRegionService: BaseAWSService {}
class BaseAWSNamedService: BaseAWSService {}

class BaseAWSService: BaseService {
    private static var store = AWSStore(url: URL(string: "https://health.aws.amazon.com/public/currentevents")!)

    let url = URL(string: "https://health.aws.amazon.com/health/status")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        if let allService = self as? AWSAllService {
            BaseAWSService.store.loadStatus { [weak allService] in
                guard let allService else { return }
                let (status, message) = BaseAWSService.store.status(for: allService)
                allService.status = status
                allService.message = message
                callback(allService)
            }
        } else if let namedService = self as? AWSNamedService {
            BaseAWSService.store.loadStatus { [weak namedService] in
                guard let namedService else { return }
                let (status, message) = BaseAWSService.store.status(for: namedService)
                namedService.status = status
                namedService.message = message
                callback(namedService)
            }
        } else if let regionService = self as? AWSRegionService {
            BaseAWSService.store.loadStatus { [weak regionService] in
                guard let regionService else { return }
                let (status, message) = BaseAWSService.store.status(for: regionService)
                regionService.status = status
                regionService.message = message
                callback(regionService)
            }
        } else {
            fatalError("BaseAWSService should not be used directly.")
        }
    }
}
