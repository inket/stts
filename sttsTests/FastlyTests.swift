//
//  FastlyTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class FastlyTests: XCTestCase {
    func testNormalStatus() throws {
        let fastly = Fastly()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: fastly.url,
                response: try Data(contentsOf: Bundle.test.url(forResource: "fastly-normal", withExtension: "html")!)
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for Fastly")

        fastly.updateStatus { service in
            XCTAssertEqual(service.status, .good)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testUnavailableStatus() throws {
        let fastly = Fastly()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: fastly.url,
                response: try Data(contentsOf: Bundle.test.url(
                    forResource: "fastly-unavailable",
                    withExtension: "html"
                )!)
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for Fastly")

        fastly.updateStatus { service in
            XCTAssertEqual(service.status, .major)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
