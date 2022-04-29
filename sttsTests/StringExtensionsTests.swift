//
//  StringExtensionsTests.swift
//  sttsTests
//

import XCTest
@testable import stts

class StringExtensionsTests: XCTestCase {
    func testInnerJSONStringWithNewLine() throws {
        XCTAssertEqual("jsonCallback(✅);\n".innerJSONString, "✅")
        XCTAssertEqual("jsonCallback(✅); \n\n\n ".innerJSONString, "✅")
    }

    func testInnerJSONStringWithoutNewLine() throws {
        XCTAssertEqual("jsonCallback(✅);".innerJSONString, "✅")
    }

    func testInnerJSONStringOther() throws {
        XCTAssertEqual("out of scope".innerJSONString, "out of scope")
    }
}
