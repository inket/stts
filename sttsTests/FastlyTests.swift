//
//  FastlyTests.swift
//  sttsTests
//

import XCTest
@testable import stts

final class FastlyTests: XCTestCase {
    func testNormalStatus() async throws {
        let fastly = Fastly()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: fastly.url,
                response: try Data(contentsOf: Bundle.test.url(forResource: "fastly-good", withExtension: "html")!)
            )
        ]))

        try await fastly.updateStatus()
        XCTAssertEqual(fastly.status, .good)
    }

    func testMajorStatus() async throws {
        let fastly = Fastly()

        DataLoader.shared = DataLoader(session: ResponseOverridingURLSession(overrides: [
            .init(
                url: fastly.url,
                response: try Data(contentsOf: Bundle.test.url(
                    forResource: "fastly-major",
                    withExtension: "html"
                )!)
            )
        ]))

        try await fastly.updateStatus()
        XCTAssertEqual(fastly.status, .major)
    }
}
