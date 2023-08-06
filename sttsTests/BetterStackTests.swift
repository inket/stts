//
//  BetterStackTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class BetterStackTests: XCTestCase {
    func testNormalStatus() throws {
        let buildJet = BuildJet()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: buildJet.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "buildjet-good", withExtension: "html")!
                )
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for buildjet.com")

        buildJet.updateStatus { service in
            XCTAssertEqual(service.status, .good)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testMajorStatus() throws {
        let buildJet = BuildJet()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: buildJet.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "eyloo-major", withExtension: "html")!
                )
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for buildjet.com")

        buildJet.updateStatus { service in
            XCTAssertEqual(service.status, .major)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
