//
//  IncidentIOTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class IncidentIOTests: XCTestCase {
    private func createAivenService() throws -> IncidentIOService {
        let definition = try JSONDecoder().decode(
            IncidentIOServiceDefinition.self,
            from: Data("""
            {
                "name": "Aiven",
                "url": "https://status.aiven.io"
            }
            """.utf8)
        )

        return try XCTUnwrap(definition.build() as? IncidentIOService)
    }

    private func createLinearService() throws -> IncidentIOService {
        let definition = try JSONDecoder().decode(
            IncidentIOServiceDefinition.self,
            from: Data("""
            {
                "name": "Linear",
                "url": "https://linearstatus.com"
            }
            """.utf8)
        )

        return try XCTUnwrap(definition.build() as? IncidentIOService)
    }

    func testMinorStatus() async throws {
        let aiven = try createAivenService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: aiven.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "aiven-minor", withExtension: "html")!
                )
            )
        ]))

        try await aiven.updateStatus()
        XCTAssertEqual(aiven.status, .minor)
        XCTAssertEqual(aiven.message, "We\u{2019}re currently experiencing issues\n* Aiven")
    }

    func testGoodStatus() async throws {
        let linear = try createLinearService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: linear.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "linear-good", withExtension: "html")!
                )
            )
        ]))

        try await linear.updateStatus()
        XCTAssertEqual(linear.status, .good)
        XCTAssertEqual(linear.message, "We\u{2019}re fully operational")
    }
}
