//
//  Adobe.swift
//  stts
//

import Foundation

typealias AdobeCreativeCloud = BaseAdobeCreativeCloud & RequiredServiceProperties & AdobeStoreService
class BaseAdobeCreativeCloud: BaseAdobe {}

class BaseAdobeDocumentCloud: BaseAdobe {}
typealias AdobeDocumentCloud = BaseAdobeDocumentCloud & RequiredServiceProperties & AdobeStoreService

typealias AdobeExperienceCloud = BaseAdobeExperienceCloud & RequiredServiceProperties & AdobeStoreService
class BaseAdobeExperienceCloud: BaseAdobe {}

typealias AdobeExperiencePlatform = BaseAdobeExperiencePlatform & RequiredServiceProperties & AdobeStoreService
class BaseAdobeExperiencePlatform: BaseAdobe {}

typealias AdobeServices = BaseAdobeServices & RequiredServiceProperties & AdobeStoreService
class BaseAdobeServices: BaseAdobe {}

typealias Adobe = BaseAdobe & RequiredServiceProperties & AdobeStoreService
class BaseAdobe: BaseIndependentService {
    static var store = AdobeStore()

    let url = URL(string: "https://status.adobe.com")!

    override func updateStatus() async throws {
        guard let realSelf = self as? Adobe else {
            fatalError("BaseAdobe should not be used directly.")
        }

        statusDescription = try await BaseAdobe.store.updatedStatus(for: realSelf)
    }
}
