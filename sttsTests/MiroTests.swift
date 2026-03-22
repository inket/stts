//
//  MiroTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class MiroTests: XCTestCase {
    private func createService() -> MiroAll {
        MiroAll()
    }

    func testGoodStatus() async throws {
        let miro = createService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: miro.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "miro-good", withExtension: "html")!
                )
            )
        ]))

        try await miro.updateStatus()
        XCTAssertEqual(miro.status, .good)
        XCTAssertEqual(miro.message, "We\u{2019}re fully operational")
    }

    func testIssueStatus() async throws {
        let miro = createService()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: miro.url,
                response: try Data(
                    contentsOf: Bundle.test.url(forResource: "miro-issue", withExtension: "html")!
                )
            )
        ]))

        try await miro.updateStatus()
        XCTAssertEqual(miro.status, .major)
        XCTAssertEqual(miro.message, "EU: We\u{2019}re currently experiencing issues")
    }
}
