//
//  sttsTests.swift
//  sttsTests
//

import XCTest
@testable import stts

// swiftlint:disable force_try force_cast

class sttsTests: XCTestCase {
    override func setUp() {
        super.setUp()

        DataLoader.shared = DataLoader(session: URLSessionMock())
    }

    override func tearDown() {
        super.tearDown()
    }

    func mockLibrarySupportServicesJSON(withContent newContent: String?, execute: () -> Void) {
        guard
            let applicationSupportURL = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else {
            assertionFailure("Could not find Application Support folder")
            return
        }

        let sttsAppSupportURL = applicationSupportURL.appendingPathComponent("stts")

        do {
            try FileManager.default.createDirectory(
                at: sttsAppSupportURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            assertionFailure("Could not create \(sttsAppSupportURL.absoluteString)")
        }

        let servicesJSONURL = sttsAppSupportURL.appendingPathComponent("services.json")
        let backupServicesJSONURL = sttsAppSupportURL.appendingPathComponent("services_backup.json")

        if FileManager.default.fileExists(atPath: servicesJSONURL.path) {
            try! FileManager.default.moveItem(at: servicesJSONURL, to: backupServicesJSONURL)
        }

        if let newContent = newContent {
            try! newContent.write(to: servicesJSONURL, atomically: true, encoding: .utf8)
            execute()
            try! FileManager.default.removeItem(at: servicesJSONURL)
        } else {
            execute()
        }

        if FileManager.default.fileExists(atPath: backupServicesJSONURL.path) {
            try! FileManager.default.moveItem(at: backupServicesJSONURL, to: servicesJSONURL)
        }
    }

    func decode<T: Decodable>(_ type: T.Type, fromJSON json: String) throws -> T {
        try JSONDecoder().decode(type, from: json.data(using: .utf8)!)
    }

    func testLoadingIncludedServices() {
        XCTAssertFalse(ServiceLoader().definedServices.isEmpty)
    }

    func testLoadingUserDefinedServices() {
        var zeroUserDefinedCount = 0

        mockLibrarySupportServicesJSON(withContent: nil) {
            zeroUserDefinedCount = ServiceLoader().definedServices.count
        }

        mockLibrarySupportServicesJSON(
            withContent: """
                {
                    "statusPage": [
                        { "name": "test", "url": "https://example.com", "id": "aaaaaaaaaaaa" }
                    ]
                }
                """
        ) {
            XCTAssertEqual(ServiceLoader().definedServices.count, zeroUserDefinedCount + 1)
        }
    }

    func testDecodingAllDefinitionTypes() {
        XCTAssertNil(try? decode(IndependentServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(IndependentServiceDefinition.self, fromJSON: """
            { "name": "Independent", "url": "https://example.com" }
        """))

        XCTAssertNil(try? decode(CachetServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(CachetServiceDefinition.self, fromJSON: """
            { "name": "Cachet", "url": "https://example.com" }
        """))

        XCTAssertNil(try? decode(LambStatusServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(LambStatusServiceDefinition.self, fromJSON: """
            { "name": "Lamb", "url": "https://example.com" }
        """))

        XCTAssertNil(try? decode(SorryServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(SorryServiceDefinition.self, fromJSON: """
            { "name": "Sorry", "url": "https://example.com", "id": "aaa3640d" }
        """))

        XCTAssertNil(try? decode(StatusCakeServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(StatusCakeServiceDefinition.self, fromJSON: """
            { "name": "StatusCake", "url": "https://example.com", "id": "aaancZazfp" }
        """))

        XCTAssertNil(try? decode(StatusioV1ServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(StatusioV1ServiceDefinition.self, fromJSON: """
            { "name": "StatusIO", "url": "https://example.com", "id": "aaaa70a50a54eb8c710005a9" }
        """))

        XCTAssertNil(try? decode(StatusPageServiceDefinition.self, fromJSON: "{}"))
        XCTAssertNoThrow(try decode(StatusPageServiceDefinition.self, fromJSON: """
            { "name": "StatusPage", "url": "https://example.com", "id": "aaaaaaaaaaaa" }
        """))
    }

    func testServices() {
        var expectations = [XCTestExpectation]()

        let services = ServiceLoader().definedServices.map { ($0, $0.build()!) }

        services.forEach { definition, service in
            let thisExpectation = XCTestExpectation(description: "Retrieve status for \(definition.name)")

            expectations.append(thisExpectation)

            print("Retrieving status for \(definition.name)…")

            service.updateStatus { updatedService in
                print(
                    """
                    Retrieved status for \(definition.name): \(updatedService.status)\
                    (\(updatedService.message))
                    """
                )

                XCTAssert(
                    updatedService.status != .undetermined,
                    "Retrieved status for \(definition.name) should not be .undetermined"
                )

                thisExpectation.fulfill()
            }
        }

        wait(for: expectations, timeout: 20.0)
    }
}
