//
//  ServiceTagsTests.swift
//  sttsTests
//

import XCTest
@testable import stts

// The lint script checks services.json's "tags" in isolation; these check what the app makes of
// them. Several providers decode their own keys and call the memberwise init, so a missed
// `decodeTags` there would drop tags silently while the JSON still lints clean.
@MainActor
final class ServiceTagsTests: XCTestCase {
    private var loader: ServiceLoader!
    private var model: PreferencesModel!
    private var storeURL: URL!

    override func setUp() async throws {
        // swiftlint:disable:next force_try
        loader = ServiceLoader(providers: [try! AppDefinedServiceDefinitionProvider()])
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ServiceTagsTests-\(UUID().uuidString).json")
        model = PreferencesModel(
            serviceLoader: loader,
            preferences: Preferences(serviceLoader: loader),
            customServiceStore: CustomServiceStore(fileURL: storeURL, secrets: InMemoryCustomServiceSecrets())
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storeURL)
    }

    func testDecodedTagsMatchJSON() throws {
        let jsonPath = try XCTUnwrap(Bundle.main.path(forResource: "services", ofType: "json"))
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: jsonPath))) as? [String: Any]
        )

        let definitions = try XCTUnwrap(try AppDefinedServiceDefinitionProvider().definedServices())
        let definitionsByKey = Dictionary(
            definitions.map { ("\($0.providerIdentifier).\($0.name)", $0) }
        ) { first, _ in first }

        for (provider, value) in root where !provider.hasPrefix("_") {
            for case let entry as [String: Any] in value as? [Any] ?? [] {
                guard let name = entry["name"] as? String else { continue }
                let definition = try XCTUnwrap(definitionsByKey["\(provider).\(name)"], "\(provider).\(name)")
                XCTAssertEqual(
                    definition.tags, entry["tags"] as? [String] ?? [],
                    "\(provider).\(name) decoded different tags than services.json has"
                )
            }
        }
    }

    func testEveryUsedTagIsDefined() {
        let defined = Set(loader.tags.map(\.id))
        for definition in loader.allServices {
            for tag in definition.tags {
                XCTAssertTrue(defined.contains(tag), "\(definition.name) uses \"\(tag)\", which \"_tags\" doesn't define")
            }
        }
    }

    func testEveryTopLevelRowIsInACategory() {
        let categories = loader.tags.map(PreferencesModel.ServicesFilter.category)

        for definition in model.topLevelServices {
            let isListed = categories.contains { model.topLevelServices(in: $0).contains(where: definition.eq) }
            XCTAssertTrue(isListed, "\(definition.name) isn't listed under any category")
        }
    }

    func testTaggedVendorPassesTagsToSubServices() throws {
        let aws = try XCTUnwrap(model.topLevelServices.first { $0.name == "AWS (All)" })
        let hosting = try category("hosting")

        XCTAssertEqual(model.groupRows(of: aws, in: hosting).count, model.groupRows(of: aws, in: .all).count)
        XCTAssertTrue(model.topLevelServices(in: hosting).contains(where: aws.eq))
        XCTAssertFalse(model.topLevelServices(in: try category("gaming")).contains(where: aws.eq))
    }

    func testUntaggedVendorListsOnlyMatchingSubServices() throws {
        let apple = try XCTUnwrap(model.topLevelServices.first { $0.name == "Apple (All)" })
        let gaming = try category("gaming")

        XCTAssertTrue(model.topLevelServices(in: gaming).contains(where: apple.eq))
        XCTAssertEqual(
            Set(model.groupRows(of: apple, in: gaming).map(\.name)),
            ["Apple Arcade", "Apple Game Center"]
        )
        // The vendor's own "everything" row belongs to no category.
        for tag in loader.tags {
            XCTAssertFalse(model.isTagged(apple, tag), "Apple (All) shouldn't be tagged \(tag.id)")
        }
    }

    func testCategoryServicesIncludeSubServices() throws {
        let media = try category("media")
        XCTAssertTrue(model.services(for: media).contains { $0.name == "Apple Music" })
        XCTAssertFalse(model.services(for: media).contains { $0.name == "Apple (All)" })
    }

    private func category(_ id: String) throws -> PreferencesModel.ServicesFilter {
        .category(try XCTUnwrap(loader.tags.first { $0.id == id }, "\"_tags\" doesn't define \(id)"))
    }
}
