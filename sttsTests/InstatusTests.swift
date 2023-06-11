//
//  InstatusTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class InstatusTests: XCTestCase {
    func testNormalStatus() throws {
        let mastodonSocial = MastodonSocial()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: mastodonSocial.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "mastodonsocial-good", withExtension: "html")!
                )
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for mastodon.social")

        mastodonSocial.updateStatus { service in
            XCTAssertEqual(service.status, .good)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }

    func testMinorStatus() throws {
        let whereby = Whereby()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: whereby.url,
                response: try Data(contentsOf: Bundle.test.url(
                    forResource: "whereby-notice",
                    withExtension: "html"
                )!)
            )
        ]))

        let expectation = XCTestExpectation(description: "Retrieve mocked status for Whereby")

        whereby.updateStatus { service in
            XCTAssertEqual(service.status, .notice)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3)
    }
}
