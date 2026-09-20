//
//  IndependentServicesJSONTests.swift
//  sttsTests
//

import XCTest
@testable import stts

/// The hand-written ("independent") services are defined in services.json's `"independent"` array
/// rather than discovered by globbing `stts/Services/*.swift` into services.plist. These lock down
/// the two things that migration could silently break.
@MainActor
final class IndependentServicesJSONTests: XCTestCase {
    private func independentDefinitions() throws -> [IndependentServiceDefinition] {
        let definitions = try XCTUnwrap(try AppDefinedServiceDefinitionProvider().definedServices())
        let independent = definitions.compactMap { $0 as? IndependentServiceDefinition }
        XCTAssertFalse(independent.isEmpty, "services.json should define an \"independent\" array")
        return independent
    }

    /// A JSON entry and the class it names both carry a name and a URL, and different parts of the
    /// app read different ones (Preferences uses the definition, the popup uses the built service),
    /// so they have to agree. The name is also what `globalIdentifier` and the favicon filename are
    /// derived from, so a drift here silently disables a user's stored selection.
    func testEveryEntryAgreesWithTheClassItNames() throws {
        for definition in try independentDefinitions() {
            let built = try XCTUnwrap(
                definition.build(),
                "\(definition.globalIdentifier) names class_name \"\(definition.className ?? "-")\", " +
                "which doesn't resolve to a BaseIndependentService subclass"
            )
            let service = try XCTUnwrap(
                built as? Service,
                "\(definition.globalIdentifier) built something without a name/url"
            )

            XCTAssertEqual(definition.name, service.name, "name mismatch for \(definition.globalIdentifier)")
            XCTAssertEqual(definition.url, service.url, "url mismatch for \(definition.globalIdentifier)")
            XCTAssertEqual(
                definition.isCategory == true, service is ServiceCategory,
                "\"category\" doesn't match ServiceCategory conformance for \(definition.globalIdentifier)"
            )
            XCTAssertEqual(
                definition.isSubService == true, service is SubService,
                "\"subservice\" doesn't match SubService conformance for \(definition.globalIdentifier)"
            )
        }
    }
}
