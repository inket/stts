//
//  Loading.swift
//  stts
//

import Foundation
import Kanna

private var _sharedWithoutCaching: URLSession?

extension URLSession {
    static var sharedWithoutCaching: URLSession {
        if let session = _sharedWithoutCaching {
            return session
        } else {
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            config.urlCache = nil

            let session = URLSession(configuration: config)
            _sharedWithoutCaching = session
            return session
        }
    }
}

public protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

class DataLoader: URLSessionProtocol {
    #if DEBUG
    // For testing
    static var shared = DataLoader()
    #else
    static let shared = DataLoader()
    #endif

    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.sharedWithoutCaching) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }
}

protocol Loading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension Loading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await DataLoader.shared.data(for: request)
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await DataLoader.shared.data(from: url)
    }

    func rawData(from url: URL) async throws -> Data {
        do {
            return try await self.data(from: url).0
        } catch {
            throw StatusUpdateError.networkError(error)
        }
    }

    func rawString(from url: URL) async throws -> String {
        let data = try await rawData(from: url)

        if let rawContents = String(data: data, encoding: .utf8) {
            return rawContents
        } else {
            throw StatusUpdateError.parseError(nil)
        }
    }

    func html(from url: URL) async throws -> HTMLDocument {
        let data = try await rawData(from: url)

        do {
            return try HTML(html: data, encoding: .utf8)
        } catch {
            throw StatusUpdateError.parseError(error)
        }
    }

    func decoded<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let data = try await rawData(from: url)

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw StatusUpdateError.decodingError(error)
        }
    }

    func rawData(for request: URLRequest) async throws -> Data {
        do {
            return try await self.data(for: request).0
        } catch {
            throw StatusUpdateError.networkError(error)
        }
    }
}
