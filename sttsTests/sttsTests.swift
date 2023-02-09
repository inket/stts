//
//  sttsTests.swift
//  sttsTests
//

import XCTest
@testable import stts

class SttsTests: XCTestCase {
    override func setUpWithError() throws {
        DataLoader.shared = DataLoader(session: ResponseSizeTrackingURLSession())
    }

    func testServices() throws {
        var expectations = [XCTestExpectation]()

        let services = BaseService.all().sorted()
        services.forEach { service in
            let thisExpectation = XCTestExpectation(description: "Retrieve status for \(type(of: service))")

            expectations.append(thisExpectation)

            if service is StatusPageService {
                // Status page servers don't like being hammered by this many requests, so we slow it down.
                // I really wish they would add an API for querying the status of many services at once.
                sleep(1)
            }

            print("Retrieving status for \(type(of: service))…")

            service.updateStatus { updatedService in
                print(
                    """
                    Retrieved status for \(type(of: updatedService)): \(updatedService.status)\
                    (\(updatedService.message))
                    """
                )

                XCTAssert(
                    updatedService.status != .undetermined,
                    "Retrieved status for \(type(of: updatedService)) should not be .undetermined"
                )

                thisExpectation.fulfill()
            }
        }

        let timeout = TimeInterval(services.count) + 2 // Expect to wait one second per service, worst case scenario
        wait(for: expectations, timeout: timeout)
    }
}
