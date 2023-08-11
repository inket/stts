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

    func testServices() async throws {
        var serviceDefinitionProviders: [ServiceDefinitionProvider] = []
        // swiftlint:disable:next force_try
        serviceDefinitionProviders.append(try! AppDefinedServiceDefinitionProvider())
        // swiftlint:disable:next force_try
        serviceDefinitionProviders.append(try! BundleServiceDefinitionProvider())
        if let userDefinedServiceDefinitionsProvider = try? UserDefinedServiceDefinitionProvider() {
            serviceDefinitionProviders.append(userDefinedServiceDefinitionsProvider)
        }

        let serviceDefinitions = ServiceLoader(providers: serviceDefinitionProviders).allServices

        var testedServices: [BaseService] = [] // Have to retain services until the end of the test

        print("Retrieving status for \(serviceDefinitions.count) services")

        await withTaskGroup(of: Void.self) { group in
            var sleepDuration: TimeInterval = 0

            for serviceDefinition in serviceDefinitions {
                guard let service = serviceDefinition.build() as? Service else {
                    XCTFail("Could not build service for definition: \(serviceDefinition)")
                    return
                }

                testedServices.append(service)

                if service is StatusPageService {
                    // Status page servers don't like being hammered by this many requests, so we slow it down.
                    // I really wish they would add an API for querying the status of many services at once.
                    sleepDuration += 1
                }

                print("Retrieving status for \(service.name)…")

                group.addTask { [sleepDuration] in
                    do {
                        try await Task.sleep(seconds: sleepDuration)
                        try await service.updateStatus()

                        print(
                            """
                            Retrieved status for \(service.name): \(service.status)\
                            (\(service.message))
                            """
                        )

                        XCTAssert(
                            service.status != .undetermined,
                            "Retrieved status for \(service.name) should not be .undetermined"
                        )
                    } catch {
                        XCTFail("Failed retrieving status for \(service.name): \(error)")
                    }
                }
            }
        }

        testedServices = []
    }
}
