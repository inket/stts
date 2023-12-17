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

    func testUnescapedWithNonEscapedString() throws {
        XCTAssertEqual("Test this!".unescaped, "Test this!")
    }

    func testUnescapedWithHardcodedEscapedString() throws {
        XCTAssertEqual("Test this!ç\n\u{003e}".unescaped, "Test this!ç\n\u{003e}")
    }

    func testUnescapedWithEscapedString() throws {
        XCTAssertEqual("\\\"test\\\"".unescaped, "\"test\"")
        XCTAssertEqual(#"\"test\""#.unescaped, #""test""#)
    }

    func testUnescapedWithEscapedUnicodeCodePointsString() throws {
        XCTAssertEqual(#"\u003cp\u003eHTML</p>"#.unescaped, #"<p>HTML</p>"#)
    }

    func testUnescapedWithJSONString() throws {
        // swiftlint:disable:next line_length
        XCTAssertEqual(#"{\"id\":\"aaa\",\"name\":\"Dashboard\",\"nameHtml\":\"\u003cp\u003eDashboard\u003c/p\u003e\",\"description\":\"\",\"descriptionHtml\":\"\",\"nameTranslation\":null,\"nameHtmlTranslation\":null,\"descriptionTranslation\":null,\"descriptionHtmlTranslation\":null,\"isCollapsed\":false,\"order\":1}"#.unescaped, #"{"id":"aaa","name":"Dashboard","nameHtml":"<p>Dashboard</p>","description":"","descriptionHtml":"","nameTranslation":null,"nameHtmlTranslation":null,"descriptionTranslation":null,"descriptionHtmlTranslation":null,"isCollapsed":false,"order":1}"#)
    }
}
