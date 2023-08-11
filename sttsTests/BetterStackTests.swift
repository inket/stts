//
//  BetterStackTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class BetterStackTests: XCTestCase {
    private func createService() throws -> BetterStackService {
        let definition = try JSONDecoder().decode(
            BetterStackServiceDefinition.self,
            from: """
            {
                "url": "https://status.buildjet.com",
                "name": "BuildJet"
            }
            """.data(using: .utf8)!
        )

        return try XCTUnwrap(definition.build() as? BetterStackService)
    }

    func testNormalStatus() async throws {
        let buildJet = try createService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: buildJet.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "buildjet-good", withExtension: "html")!
                )
            )
        ]))

        try await buildJet.updateStatus()
        XCTAssertEqual(buildJet.status, .good)
    }

    func testMajorStatus() async throws {
        let buildJet = try createService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: buildJet.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "eyloo-major", withExtension: "html")!
                )
            )
        ]))

        try await buildJet.updateStatus()
        XCTAssertEqual(buildJet.status, .major)
    }
}
