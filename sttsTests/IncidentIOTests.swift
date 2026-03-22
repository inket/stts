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

    private func createOpenAIService() throws -> IncidentIOService {
        let definition = try JSONDecoder().decode(
            IncidentIOServiceDefinition.self,
            from: Data("""
            {
                "name": "OpenAI",
                "url": "https://status.openai.com"
            }
            """.utf8)
        )

        return try XCTUnwrap(definition.build() as? IncidentIOService)
    }

    private func createRollbarService() throws -> IncidentIOService {
        let definition = try JSONDecoder().decode(
            IncidentIOServiceDefinition.self,
            from: Data("""
            {
                "name": "Rollbar",
                "url": "https://status.rollbar.com"
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
        XCTAssertEqual(aiven.message, "We\u{2019}re currently experiencing issues\n* Amazon Web Services (AWS) ME-CENTRAL-1 region status")
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

    func testMajorStatus() async throws {
        let openai = try createOpenAIService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: openai.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "openai-major", withExtension: "html")!
                )
            )
        ]))

        try await openai.updateStatus()
        XCTAssertEqual(openai.status, .major)
        XCTAssertEqual(
            openai.message,
            "We\u{2019}re currently experiencing issues\n* Elevated errors for sign-in and account creation"
        )
    }

    func testGoodStatusFromLiIcon() async throws {
        let rollbar = try createRollbarService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: rollbar.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "rollbar-good", withExtension: "html")!
                )
            )
        ]))

        try await rollbar.updateStatus()
        XCTAssertEqual(rollbar.status, .good)
        XCTAssertEqual(rollbar.message, "We\u{2019}re fully operational")
    }
}
