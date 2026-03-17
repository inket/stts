//
//  ResponseOverridingURLSession.swift
//  sttsTests
//

import Foundation
import stts

final class ResponseOverridingURLSession: URLSessionProtocol {
    class Override {
        let url: URL
        let response: Data

        init(url: URL, response: Data) {
            self.url = url
            self.response = response
        }
    }

    let overrides: [URL: Override]

    init(overrides: [Override]) {
        var mappedOverrides: [URL: Override] = [:]
        overrides.forEach {
            mappedOverrides[$0.url] = $0
        }

        self.overrides = mappedOverrides
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        if let override = overrides[url] {
            print("[ResponseOverridingURLSession] Overridden URL: \(url)")

            try await Task.sleep(seconds: 0.5)
            return (override.response, URLResponse())
        } else {
            print("[ResponseOverridingURLSession] Skipped URL: \(url)")
            return try await URLSession.shared.data(from: url)
        }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let override = overrides[request.url!] {
            print("[ResponseOverridingURLSession] Overridden request URL: \(String(describing: request.url))")

            try await Task.sleep(seconds: 0.5)
            return (override.response, URLResponse())
        } else {
            print("[ResponseOverridingURLSession] Skipped URL: \(String(describing: request.url))")
            return try await URLSession.shared.data(for: request)
        }
    }
}
