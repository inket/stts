//
//  ResponseOverridingURLSession.swift
//  sttsTests
//

import Foundation
import stts

class DummyDataTask: URLSessionDataTask {
    override init() {}

    override func resume() {
        // Do nothing
    }
}

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

    func dataTask(
        with url: URL,
        completionHandler: @escaping URLSessionProtocol.CompletionHandler
    ) -> URLSessionDataTask {
        if let override = overrides[url] {
            print("[ResponseOverridingURLSession] Overridden URL: \(url)")

            DispatchQueue.global(qos: .userInitiated).async {
                completionHandler(override.response, nil, nil)
            }

            return DummyDataTask()
        } else {
            print("[ResponseOverridingURLSession] Skipped URL: \(url)")
            return URLSession.shared.dataTask(with: url, completionHandler: completionHandler)
        }
    }

    func dataTask(
        with urlRequest: URLRequest,
        completionHandler: @escaping URLSessionProtocol.CompletionHandler
    ) -> URLSessionDataTask {
        if let override = overrides[urlRequest.url!] {
            print("[ResponseOverridingURLSession] Overridden request URL: \(String(describing: urlRequest.url))")

            DispatchQueue.global(qos: .userInitiated).async {
                completionHandler(override.response, nil, nil)
            }

            return DummyDataTask()
        } else {
            print("[ResponseOverridingURLSession] Skipped URL: \(String(describing: urlRequest.url))")
            return URLSession.shared.dataTask(with: urlRequest, completionHandler: completionHandler)
        }
    }
}
