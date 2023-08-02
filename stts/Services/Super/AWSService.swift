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
                allService.statusDescription = BaseAWSService.store.status(for: allService)
                callback(allService)
            }
        } else if let namedService = self as? AWSNamedService {
            BaseAWSService.store.loadStatus { [weak namedService] in
                guard let namedService else { return }
                namedService.statusDescription = BaseAWSService.store.status(for: namedService)
                callback(namedService)
            }
        } else if let regionService = self as? AWSRegionService {
            BaseAWSService.store.loadStatus { [weak regionService] in
                guard let regionService else { return }
                regionService.statusDescription = BaseAWSService.store.status(for: regionService)
                callback(regionService)
            }
        } else {
            fatalError("BaseAWSService should not be used directly.")
        }
    }
}
