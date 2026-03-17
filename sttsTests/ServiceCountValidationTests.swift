//
//  ServiceCountValidationTests.swift
//  sttsTests
//
//  Validates that services.json is valid and the ServiceLoader loads the
//  expected number of services per category.
//

import XCTest
@testable import stts

final class ServiceCountValidationTests: XCTestCase {
    func testServiceCountsMatchJSON() throws {
        // ── Load services.json directly for expected counts ──────────────────
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // sttsTests/
            .deletingLastPathComponent()  // project root
        let jsonURL = projectRoot.appendingPathComponent("Resources/services.json")

        let jsonData = try Data(contentsOf: jsonURL)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: [[String: Any]]] else {
            XCTFail("services.json has unexpected format")
            return
        }

        let jsonCounts = json.mapValues { $0.count }

        // ── Load services via ServiceLoader (JSON provider only) ─────────────
        // swiftlint:disable:next force_try
        let provider = try! AppDefinedServiceDefinitionProvider()
        let loader = ServiceLoader(providers: [provider])

        var loaderCounts: [String: Int] = [:]
        for definition in loader.allServices {
            loaderCounts[definition.providerIdentifier, default: 0] += 1
        }

        // ── Compare ──────────────────────────────────────────────────────────
        let allKeys = Set(loaderCounts.keys).union(jsonCounts.keys).sorted()

        let colWidth = (allKeys.map(\.count) + ["Category".count]).max()! + 2

        func pad(_ string: String) -> String { string.padding(toLength: colWidth, withPad: " ", startingAt: 0) }
        func row(_ label: String, _ loaded: Int, _ json: Int, _ status: String) -> String {
            "\(pad(label))  \(String(format: "%6d", loaded))  \(String(format: "%6d", json))  \(status)"
        }

        let header  = "\(pad("Category"))  Loaded    JSON  Status"
        let divider = String(repeating: "-", count: header.count)

        print("\n" + header)
        print(divider)

        var mismatches: [String] = []
        for key in allKeys {
            let loaded = loaderCounts[key] ?? 0
            let json   = jsonCounts[key] ?? 0
            let match  = loaded == json
            if !match { mismatches.append(key) }
            let status = match ? "OK" : "MISMATCH (diff: \(json - loaded))"
            print(row(key, loaded, json, status))
        }

        print(divider)
        let totalLoaded = allKeys.reduce(0) { $0 + (loaderCounts[$1] ?? 0) }
        let totalJSON   = allKeys.reduce(0) { $0 + (jsonCounts[$1] ?? 0) }
        let totalMatch  = totalLoaded == totalJSON
        print(row("TOTAL", totalLoaded, totalJSON, totalMatch ? "OK" : "MISMATCH"))

        XCTAssert(mismatches.isEmpty, "Service count mismatch in: \(mismatches.joined(separator: ", "))")
    }
}
