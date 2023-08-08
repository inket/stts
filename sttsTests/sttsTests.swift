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

        let serviceDefinitions = ServiceLoader.current.allServices
        var testedServices: [BaseService] = [] // Have to retain services until the end of the test

        print("Retrieving status for \(serviceDefinitions.count) services")

        serviceDefinitions.forEach { serviceDefinition in
            guard let service = serviceDefinition.build() as? Service else {
                XCTFail("Could not build service for definition: \(serviceDefinition)")
                return
            }

            testedServices.append(service)

            let thisExpectation = XCTestExpectation(description: "Retrieve status for \(service.name)")

            expectations.append(thisExpectation)

            if service is StatusPageService {
                // Status page servers don't like being hammered by this many requests, so we slow it down.
                // I really wish they would add an API for querying the status of many services at once.
                sleep(1)
            }

            print("Retrieving status for \(service.name)…")

            service.updateStatus { updatedService in
                let updatedService = updatedService as! Service // swiftlint:disable:this force_cast
                print(
                    """
                    Retrieved status for \(updatedService.name): \(updatedService.status)\
                    (\(updatedService.message))
                    """
                )

                XCTAssert(
                    updatedService.status != .undetermined,
                    "Retrieved status for \(updatedService.name) should not be .undetermined"
                )

                thisExpectation.fulfill()
            }
        }

        wait(for: expectations, timeout: 5)
        testedServices = []
    }
}
