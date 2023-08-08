//
//  InstatusTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class InstatusTests: XCTestCase {
    private func createMastodonSocialService() throws -> InstatusService {
        let definition = try JSONDecoder().decode(
            InstatusServiceDefinition.self,
            from: """
            {
                "name": "mastodon.social",
                "url": "https://status.mastodon.social",
                "old_names": [
                    "MastodonSocial"
                ]
            }
            """.data(using: .utf8)!
        )

        return try XCTUnwrap(definition.build() as? InstatusService)
    }

    private func createWherebyService() throws -> InstatusService {
        let definition = try JSONDecoder().decode(
            InstatusServiceDefinition.self,
            from: """
            {
                "url": "https://wherebystatus.com",
                "name": "Whereby"
            }
            """.data(using: .utf8)!
        )

        return try XCTUnwrap(definition.build() as? InstatusService)
    }

    func testNormalStatus() throws {
        let mastodonSocial = try createMastodonSocialService()

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
        let whereby = try createWherebyService()

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
