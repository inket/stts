//
//  CustomServicesTests.swift
//  sttsTests
//

import XCTest
@testable import stts

// swiftlint:disable force_unwrapping

final class CustomServicesFormatTests: XCTestCase {
    private let fullService = CustomService(
        name: "Billing worker",
        url: URL(string: "https://ops.acme.co/queue.json")!,
        method: .post,
        followsRedirects: false,
        requestBody: "{\"event\": \"ping\"}",
        requestHeaders: [
            .init(name: "Content-Type", value: "application/json"),
            .init(name: "Authorization", value: "Bearer abc123", isSecret: true)
        ],
        interval: 300,
        rules: [
            .init(kind: .status, value: "200, 204, 3xx"),
            .init(kind: .contains, value: "drained"),
            .init(kind: .omits, value: "error"),
            .init(kind: .within, value: "500"),
            .init(kind: .certificate, value: "30")
        ],
        matching: .any
    )

    func testRoundTripThroughRecord() throws {
        let data = try JSONEncoder().encode(CustomServiceRecord(fullService, includeSecretValues: true))
        let decoded = try JSONDecoder().decode(CustomServiceRecord.self, from: data)
        XCTAssertEqual(decoded.service { _ in nil }, fullService)
    }

    func testPersistedRecordOmitsSecretValues() throws {
        let data = try JSONEncoder().encode(CustomServiceRecord(fullService, includeSecretValues: false))
        let json = String(data: data, encoding: .utf8)!
        XCTAssertFalse(json.contains("Bearer abc123"))

        let decoded = try JSONDecoder().decode(CustomServiceRecord.self, from: data)
        let service = decoded.service { $0 == "Authorization" ? "from keychain" : nil }
        XCTAssertEqual(service.requestHeaders[1].value, "from keychain")
        XCTAssertTrue(service.requestHeaders[1].isSecret)
    }

    func testMinimalEntryUsesDefaults() throws {
        let json = """
        {"version": 1, "id": "B04E7F21-5C6A-4D8B-8E3F-71A92C0D5E64", "name": "Internal API",
         "url": "https://api.acme.internal/health", "rules": [{"type": "status", "codes": ["200"]}]}
        """
        let service = try JSONDecoder().decode(CustomServiceRecord.self, from: Data(json.utf8)).service { _ in nil }
        XCTAssertEqual(service.method, .get)
        XCTAssertTrue(service.followsRedirects)
        XCTAssertEqual(service.requestHeaders, [])
        XCTAssertNil(service.interval)
        XCTAssertEqual(service.matching, .all)
        XCTAssertEqual(service.rules, [.init(kind: .status, value: "200")])
    }

    func testDefaultsAreLeftOutWhenEncoding() throws {
        let service = CustomService(
            name: "Internal API",
            url: URL(string: "https://api.acme.internal/health")!,
            rules: [.init(kind: .status, value: "200")]
        )
        let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(CustomServiceRecord(service, includeSecretValues: false))
        ) as? [String: Any]
        XCTAssertEqual(Set(object?.keys.map { $0 } ?? []), ["version", "id", "name", "url", "rules"])
    }
}

final class CustomServiceStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL { directory.appendingPathComponent("custom_services.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func service(secret: String? = "Bearer abc123") -> CustomService {
        CustomService(
            name: "Internal API",
            url: URL(string: "https://api.acme.internal/health")!,
            requestHeaders: secret.map { [.init(name: "Authorization", value: $0, isSecret: true)] } ?? [],
            rules: [.init(kind: .status, value: "200")]
        )
    }

    func testTooNewAndMalformedEntriesArePreserved() throws {
        let json = """
        {"services": [
          {"version": 99, "id": "6F1C2A9E-3B7D-4E52-9A1F-0C8D2E4B7A31", "future_field": true},
          {"version": 1, "id": "not a uuid"},
          {"version": 1, "id": "B04E7F21-5C6A-4D8B-8E3F-71A92C0D5E64", "name": "Internal API",
           "url": "https://api.acme.internal/health", "rules": [{"type": "status", "codes": ["200"]}]}
        ]}
        """
        try Data(json.utf8).write(to: fileURL)

        let store = CustomServiceStore(fileURL: fileURL, secrets: InMemoryCustomServiceSecrets())
        XCTAssertEqual(store.services.map(\.name), ["Internal API"])
        XCTAssertEqual(store.skippedCount, 2)

        store.add(service(secret: nil))

        let saved = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(saved.contains("future_field"))
        XCTAssertTrue(saved.contains("not a uuid"))
        XCTAssertEqual(CustomServiceStore(fileURL: fileURL, secrets: InMemoryCustomServiceSecrets()).services.count, 2)
    }

    func testSecretsLiveInTheSecretStoreOnly() throws {
        let secrets = InMemoryCustomServiceSecrets()
        let store = CustomServiceStore(fileURL: fileURL, secrets: secrets)
        let service = service()
        store.add(service)

        XCTAssertFalse(try String(contentsOf: fileURL, encoding: .utf8).contains("Bearer abc123"))
        XCTAssertEqual(secrets.value(serviceID: service.id, headerName: "authorization"), "Bearer abc123")

        let reloaded = CustomServiceStore(fileURL: fileURL, secrets: secrets)
        XCTAssertEqual(reloaded.services.first?.requestHeaders.first?.value, "Bearer abc123")
    }

    func testUnmarkingASecretMovesItIntoTheFile() throws {
        let secrets = InMemoryCustomServiceSecrets()
        let store = CustomServiceStore(fileURL: fileURL, secrets: secrets)
        var service = service()
        store.add(service)

        service.requestHeaders[0].isSecret = false
        store.update(service)

        XCTAssertTrue(secrets.values.isEmpty)
        XCTAssertTrue(try String(contentsOf: fileURL, encoding: .utf8).contains("Bearer abc123"))
    }

    func testDeletingAServiceRemovesItsSecrets() {
        let secrets = InMemoryCustomServiceSecrets()
        let store = CustomServiceStore(fileURL: fileURL, secrets: secrets)
        let service = service()
        store.add(service)
        store.delete(id: service.id)

        XCTAssertTrue(store.services.isEmpty)
        XCTAssertTrue(secrets.values.isEmpty)
    }

    func testMissingSecretComesBackEmpty() {
        let store = CustomServiceStore(fileURL: fileURL, secrets: InMemoryCustomServiceSecrets())
        store.add(service())

        let elsewhere = CustomServiceStore(fileURL: fileURL, secrets: InMemoryCustomServiceSecrets())
        let header = elsewhere.services.first?.requestHeaders.first
        XCTAssertEqual(header?.isSecret, true)
        XCTAssertEqual(header?.value, "")
    }

    func testExportInlinesSecretsAndImportMovesThemBack() throws {
        let source = CustomServiceStore(fileURL: nil, secrets: InMemoryCustomServiceSecrets())
        let service = service()
        source.add(service)

        let exported = try source.exportData()
        XCTAssertTrue(String(data: exported, encoding: .utf8)!.contains("Bearer abc123"))

        let secrets = InMemoryCustomServiceSecrets()
        let destination = CustomServiceStore(fileURL: fileURL, secrets: secrets)
        let summary = try destination.importData(exported)

        XCTAssertEqual(summary.addedIDs, [service.id])
        XCTAssertEqual(secrets.value(serviceID: service.id, headerName: "Authorization"), "Bearer abc123")
        XCTAssertFalse(try String(contentsOf: fileURL, encoding: .utf8).contains("Bearer abc123"))
    }

    func testImportReplacesBySameIDAndSkipsTooNew() throws {
        let store = CustomServiceStore(fileURL: fileURL, secrets: InMemoryCustomServiceSecrets())
        var service = service(secret: nil)
        store.add(service)

        service.name = "Renamed"
        let record = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(CustomServiceRecord(service, includeSecretValues: true))
        )
        let file = try JSONSerialization.data(withJSONObject: ["services": [record, ["version": 2]]])

        let summary = try store.importData(file)
        XCTAssertEqual(summary.replacedIDs, [service.id])
        XCTAssertEqual(summary.skippedCount, 1)
        XCTAssertEqual(store.services.map(\.name), ["Renamed"])
    }

    func testImportRejectsOtherFiles() {
        let store = CustomServiceStore(fileURL: nil, secrets: InMemoryCustomServiceSecrets())
        XCTAssertThrowsError(try store.importData(Data("[1, 2, 3]".utf8)))
    }
}

@MainActor
final class CustomServiceLoaderTests: XCTestCase {
    func testCustomServiceDoesNotClaimALegacyIdentifierByName() throws {
        let store = CustomServiceStore(fileURL: nil, secrets: InMemoryCustomServiceSecrets())
        let custom = CustomService(
            name: "GitHub",
            url: URL(string: "https://example.com")!,
            rules: [.init(kind: .status, value: "200")]
        )
        store.add(custom)

        let loader = ServiceLoader(providers: [
            try AppDefinedServiceDefinitionProvider(),
            CustomServiceDefinitionProvider(store: store)
        ])

        XCTAssertFalse(loader.serviceDefinition(forIdentifier: "GitHub")?.isCustom ?? true)
        XCTAssertTrue(loader.serviceDefinition(forIdentifier: custom.globalIdentifier)?.isCustom ?? false)
    }
}

final class CustomServiceCheckerTests: XCTestCase {
    private var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }

    override func tearDown() {
        StubURLProtocol.responses = [:]
    }

    private func service(
        _ url: String = "https://stub.test/health",
        followsRedirects: Bool = true,
        headers: [CustomService.Header] = [],
        rules: [CustomService.Rule],
        matching: CustomService.Matching = .all
    ) -> CustomService {
        CustomService(
            name: "Stub",
            url: URL(string: url)!,
            followsRedirects: followsRedirects,
            requestHeaders: headers,
            rules: rules,
            matching: matching
        )
    }

    func testStatusAndTextRules() async throws {
        StubURLProtocol.responses["https://stub.test/health"] = .init(status: 200, body: "Queue: DRAINED")

        let healthy = try await CustomServiceChecker.run(
            service(rules: [.init(kind: .status, value: "2xx"), .init(kind: .contains, value: "drained")]),
            configuration: configuration
        )
        XCTAssertEqual(healthy.verdict, .healthy)
        XCTAssertEqual(healthy.label, "200 OK")

        let failed = try await CustomServiceChecker.run(
            service(rules: [.init(kind: .status, value: "200"), .init(kind: .omits, value: "drained")]),
            configuration: configuration
        )
        XCTAssertEqual(failed.verdict, .failed)
        XCTAssertEqual(failed.label, "MISMATCH")
        XCTAssertEqual(failed.detail, "Response contains “drained”")
    }

    func testFailedStatusLabelsWithTheCode() async throws {
        StubURLProtocol.responses["https://stub.test/health"] = .init(status: 503, body: "")

        let result = try await CustomServiceChecker.run(
            service(rules: [.init(kind: .status, value: "200, 3xx")]),
            configuration: configuration
        )
        XCTAssertEqual(result.verdict, .failed)
        XCTAssertEqual(result.label, "503")
        XCTAssertEqual(result.detail, "Got 503")
    }

    func testAnyNeedsOnlyOneRule() async throws {
        StubURLProtocol.responses["https://stub.test/health"] = .init(status: 500, body: "ok")

        let result = try await CustomServiceChecker.run(
            service(
                rules: [.init(kind: .status, value: "200"), .init(kind: .contains, value: "ok")],
                matching: .any
            ),
            configuration: configuration
        )
        XCTAssertEqual(result.verdict, .healthy)
    }

    func testRedirects() async throws {
        StubURLProtocol.responses["https://stub.test/old"] = .init(
            status: 301, body: "", location: "https://stub.test/new"
        )
        StubURLProtocol.responses["https://stub.test/new"] = .init(status: 200, body: "")

        let followed = try await CustomServiceChecker.run(
            service("https://stub.test/old", rules: [.init(kind: .status, value: "200")]),
            configuration: configuration
        )
        XCTAssertEqual(followed.verdict, .healthy)

        let notFollowed = try await CustomServiceChecker.run(
            service("https://stub.test/old", followsRedirects: false, rules: [.init(kind: .status, value: "3xx")]),
            configuration: configuration
        )
        XCTAssertEqual(notFollowed.verdict, .healthy)
        XCTAssertEqual(notFollowed.label, "301")
    }

    func testMissingSecretNeverSendsTheRequest() async {
        let service = service(
            headers: [.init(name: "Authorization", value: "", isSecret: true)],
            rules: [.init(kind: .status, value: "200")]
        )
        let result = await CustomServiceChecker.check(service, configuration: configuration)
        XCTAssertEqual(result.verdict, .noAnswer)
        XCTAssertEqual(result.detail, "Secret header “Authorization” is missing")
    }

    func testResponseTimeAndCertificate() {
        let now = Date()
        let service = service(rules: [.init(kind: .within, value: "500"), .init(kind: .certificate, value: "30")])

        let fine = CustomServiceChecker.Response(
            statusCode: 200, elapsed: .milliseconds(120), body: nil,
            certificateExpiry: now.addingTimeInterval(90 * 86_400)
        )
        XCTAssertEqual(CustomServiceChecker.evaluate(service, response: fine, now: now).verdict, .healthy)

        let slow = CustomServiceChecker.Response(
            statusCode: 200, elapsed: .milliseconds(1_240), body: nil,
            certificateExpiry: now.addingTimeInterval(90 * 86_400)
        )
        XCTAssertEqual(CustomServiceChecker.evaluate(service, response: slow, now: now).detail, "Took 1,240 ms")

        let expiring = CustomServiceChecker.Response(
            statusCode: 200, elapsed: .milliseconds(120), body: nil,
            certificateExpiry: now.addingTimeInterval(12.5 * 86_400)
        )
        XCTAssertEqual(
            CustomServiceChecker.evaluate(service, response: expiring, now: now).detail,
            "Certificate expires in 12 days"
        )
    }
}

/// Serves canned responses by URL, including redirects.
private final class StubURLProtocol: URLProtocol {
    struct Stub {
        var status: Int
        var body: String
        var location: String?
    }

    nonisolated(unsafe) static var responses: [String: Stub] = [:]

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = Self.responses[url.absoluteString] else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }

        var headers: [String: String] = [:]
        if let location = stub.location { headers["Location"] = location }
        let response = HTTPURLResponse(
            url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: headers
        )!

        if let location = stub.location, let target = URL(string: location) {
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
