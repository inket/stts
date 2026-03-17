//
//  AdobeTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class AdobeTests: XCTestCase {
    func testParsingStatus() async throws {
        let adobeCreativeCloud = AdobeCreativeCloudAll()
        let adobePremierePro = AdobePremierePro()

        let adobeExperienceCloud = AdobeExperienceCloudAll() // Should be .minor because Adobe Analytics is affected
        let adobeAnalytics = AdobeAnalytics()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: BaseAdobe.store.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "adobe-analytics-minor", withExtension: "json")!
                )
            )
        ]))

        try await adobePremierePro.updateStatus()
        XCTAssertEqual(adobePremierePro.status, .good)

        try await adobeCreativeCloud.updateStatus()
        XCTAssertEqual(adobeCreativeCloud.status, .good)

        try await adobeAnalytics.updateStatus()
        XCTAssertEqual(adobeAnalytics.status, .minor)

        try await adobeExperienceCloud.updateStatus()
        XCTAssertEqual(adobeExperienceCloud.status, .minor)
    }
}
