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
            from: Data("""
            {
                "name": "mastodon.social",
                "url": "https://status.mastodon.social",
                "old_names": [
                    "MastodonSocial"
                ]
            }
            """.utf8)
        )

        return try XCTUnwrap(definition.build() as? InstatusService)
    }

    private func createWherebyService() throws -> InstatusService {
        let definition = try JSONDecoder().decode(
            InstatusServiceDefinition.self,
            from: Data("""
            {
                "url": "https://wherebystatus.com",
                "name": "Whereby"
            }
            """.utf8)
        )

        return try XCTUnwrap(definition.build() as? InstatusService)
    }

    func testNormalStatus() async throws {
        let mastodonSocial = try createMastodonSocialService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: mastodonSocial.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "mastodonsocial-good", withExtension: "html")!
                )
            )
        ]))

        try await mastodonSocial.updateStatus()
        XCTAssertEqual(mastodonSocial.status, .good)
    }

    func testMinorStatus() async throws {
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

        try await whereby.updateStatus()
        XCTAssertEqual(whereby.status, .notice)
    }
}
