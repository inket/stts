//
//  ServiceCountValidationTests.swift
//  sttsTests
//

import XCTest
@testable import stts

// Confirms every provider array in services.json decodes into exactly as many ServiceDefinitions as
// it has raw JSON entries. Catches two mistakes that Codable alone won't: a new provider key added
// to services.json but never wired into ServicesStructure (silently parses to zero, no error), and
// entries that individually decode fine but get lost/duplicated somewhere in the loading pipeline.
@MainActor
final class ServiceCountValidationTests: XCTestCase {
    func testParsedCountsMatchRawJSONCounts() throws {
        let jsonPath = try XCTUnwrap(
            Bundle.main.path(forResource: "services", ofType: "json"),
            "Could not find services.json in the bundle"
        )
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            "services.json's top level should be an object"
        )

        let definitions = try XCTUnwrap(try AppDefinedServiceDefinitionProvider().definedServices())

        var parsedCountsByProvider: [String: Int] = [:]
        for definition in definitions {
            parsedCountsByProvider[definition.providerIdentifier, default: 0] += 1
        }

        for (key, value) in root {
            guard !key.hasPrefix("_") else { continue }

            let rawCount = (value as? [Any])?.count ?? 0
            let parsedCount = parsedCountsByProvider[key] ?? 0

            XCTAssertEqual(
                parsedCount, rawCount,
                """
                "\(key)" has \(rawCount) entries in services.json but \(parsedCount) were parsed — \
                check it's wired into ServicesStructure and that every entry decodes correctly.
                """
            )
        }
    }

    // Sendbird/Miro subclass StatusPageServiceDefinition/IncidentIOServiceDefinition to reuse their
    // JSON shape, which used to also leak their providerIdentifier ("statuspage"/"incidentio"
    // instead of "sendbird"/"miro") — fixed, with the old prefixed identifiers preserved as
    // old_names so already-stored preferences keep resolving. This locks that in.
    func testSendbirdAndMiroResolveFromLegacyProviderPrefix() throws {
        // swiftlint:disable:next force_try
        let loader = ServiceLoader(providers: [try! AppDefinedServiceDefinitionProvider()])

        for legacyIdentifier in ["statuspage.SendbirdCanada", "statuspage.SendbirdTokyo"] {
            let definition = try XCTUnwrap(
                loader.serviceDefinition(forIdentifier: legacyIdentifier),
                "Expected \(legacyIdentifier) to resolve to a Sendbird definition"
            )
            XCTAssertEqual(definition.providerIdentifier, "sendbird")
        }

        for legacyIdentifier in ["incidentio.MiroAU", "incidentio.MiroEU", "incidentio.MiroUS"] {
            let definition = try XCTUnwrap(
                loader.serviceDefinition(forIdentifier: legacyIdentifier),
                "Expected \(legacyIdentifier) to resolve to a Miro definition"
            )
            XCTAssertEqual(definition.providerIdentifier, "miro")
        }
    }
}
