//
//  AdobeTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class AdobeTests: XCTestCase {
    func testParsingStatus() throws {
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

        let expectation = XCTestExpectation(description: "Retrieve mocked status for Adobe")

        adobePremierePro.updateStatus { service in
            XCTAssertEqual(service.status, .good)
            expectation.fulfill()
        }

        adobeCreativeCloud.updateStatus { service in
            XCTAssertEqual(service.status, .good)
            expectation.fulfill()
        }

        adobeAnalytics.updateStatus { service in
            XCTAssertEqual(service.status, .minor)
            expectation.fulfill()
        }

        adobeExperienceCloud.updateStatus { service in
            XCTAssertEqual(service.status, .minor)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
