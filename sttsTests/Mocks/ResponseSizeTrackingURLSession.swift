//
//  ResponseSizeTrackingURLSession.swift
//  sttsTests
//

import Foundation
import stts

final class ResponseSizeTrackingURLSession: URLSessionProtocol {
    private func humanSize(data: Data?) -> String {
        guard let data = data else { return "nil" }

        return "\(data.count / 1024)KB"
    }

    func dataTask(
        with url: URL,
        completionHandler: @escaping URLSessionProtocol.CompletionHandler
    ) -> URLSessionDataTask {
        URLSession.shared.dataTask(with: url) { data, response, error in
            print("[ResponseSizeTrackingURLSession] \(self.humanSize(data: data)) [\(url.absoluteString)]")
            completionHandler(data, response, error)
        }
    }

    func dataTask(
        with urlRequest: URLRequest,
        completionHandler: @escaping URLSessionProtocol.CompletionHandler
    ) -> URLSessionDataTask {
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            print("""
            [ResponseSizeTrackingURLSession] \(self.humanSize(data: data)) [\(urlRequest.url?.absoluteString ?? "nil")]
            """)

            completionHandler(data, response, error)
        }
    }
}
