//
//  PagerDutyTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class PagerDutyTests: XCTestCase {
    func testNormalStatus() throws {
        let pagerDuty = PagerDuty()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: pagerDuty.url,
                response: try Data(contentsOf: Bundle.test.url(forResource: "pagerduty-good", withExtension: "html")!)
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for PagerDuty")

        pagerDuty.updateStatus { service in
            XCTAssertEqual(service.status, .good)
            XCTAssertEqual(service.message, "No known issue")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testMinorStatus() throws {
        let pagerDuty = PagerDuty()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: pagerDuty.url,
                response: try Data(contentsOf: Bundle.test.url(
                    forResource: "pagerduty-minor",
                    withExtension: "html"
                )!)
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for PagerDuty")

        pagerDuty.updateStatus { service in
            XCTAssertEqual(service.status, .minor)
            XCTAssertEqual(service.message, "Inconsistent Service Statuses")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
