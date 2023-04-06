//
//  AdobeTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class AdobeTests: XCTestCase {
    func testNormalStatus() throws {
        let adobePremierePro = AdobePremierePro()

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

        wait(for: [expectation], timeout: 3)
    }

    func testMinorStatus() throws {
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

        adobeAnalytics.updateStatus { service in
            XCTAssertEqual(service.status, .minor)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
