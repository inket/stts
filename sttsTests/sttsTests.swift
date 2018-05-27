//
//  sttsTests.swift
//  sttsTests
//

import XCTest
import stts

class sttsTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testServices() {
        var expectations = [XCTestExpectation]()

        let services = BaseService.all().sorted()
        services.forEach { service in
            let thisExpectation = XCTestExpectation(description: "Retrieve status for \(type(of: service))")

            expectations.append(thisExpectation)

            service.updateStatus { updatedService in
                XCTAssert(
                    updatedService.status != .undetermined,
                    "Retrieved status for \(type(of: updatedService)) should not be .undetermined"
                )

                thisExpectation.fulfill()
            }
        }

        wait(for: expectations, timeout: 10.0)
    }
}
