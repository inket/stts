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

    func data(from url: URL) async throws -> (Data, URLResponse) {
        let (data, response) = try await URLSession.shared.data(from: url)
        print("[ResponseSizeTrackingURLSession] \(humanSize(data: data)) [\(url.absoluteString)]")
        return (data, response)
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        print("[ResponseSizeTrackingURLSession] \(humanSize(data: data)) [\(request.url?.absoluteString ?? "nil")]")
        return (data, response)
    }
}
