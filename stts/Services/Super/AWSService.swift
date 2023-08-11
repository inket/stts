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

class BaseAWSService: BaseIndependentService {
    private static var store = AWSStore(url: URL(string: "https://health.aws.amazon.com/public/currentevents")!)

    let url = URL(string: "https://health.aws.amazon.com/health/status")!

    override func updateStatus() async throws {
        if let allService = self as? AWSAllService {
            statusDescription = try await BaseAWSService.store.updatedStatus(for: allService)
        } else if let namedService = self as? AWSNamedService {
            statusDescription = try await BaseAWSService.store.updatedStatus(for: namedService)
        } else if let regionService = self as? AWSRegionService {
            statusDescription = try await BaseAWSService.store.updatedStatus(for: regionService)
        } else {
            fatalError("BaseAWSService should not be used directly.")
        }
    }
}
