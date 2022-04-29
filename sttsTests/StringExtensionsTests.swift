//
//  StringExtensionsTests.swift
//  sttsTests
//

import XCTest
@testable import stts

class StringExtensionsTests: XCTestCase {

    func testInnerJsonStringWithNewLine() throws {
        let jsonCallback = "jsonCallback(✅);\n"
        XCTAssertEqual(jsonCallback.innerJSONString, "✅")
    }

    func testInnerJsonStringWithoutNewLine() throws {
        let jsonCallback = "jsonCallback(✅);"
        XCTAssertEqual(jsonCallback.innerJSONString, "✅")
    }

    func testInnerJsonStringOther() throws {
        let jsonCallback = "out of scope"
        XCTAssertEqual(jsonCallback.innerJSONString, "out of scope")
    }
}
