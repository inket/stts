//
//  Loading.swift
//  stts
//

import Foundation

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

class DataLoader {
    #if DEBUG
    // For testing
    static var shared = DataLoader()
    #else
    static let shared = DataLoader()
    #endif

    private let session: URLSession

    init(session: URLSession = .sharedWithoutCaching) {
        self.session = session
    }

    func loadData(
        with urlRequest: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let task = session.dataTask(with: urlRequest, completionHandler: completionHandler)
        task.resume()
        return task
    }

    func loadData(
        with url: URL,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        let task = session.dataTask(with: url, completionHandler: completionHandler)
        task.resume()
        return task
    }
}

protocol Loading {
    func loadData(
        with urlRequest: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask

    func loadData(
        with url: URL,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask
}

extension Loading {
    @discardableResult
    public func loadData(
        with urlRequest: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return DataLoader.shared.loadData(with: urlRequest, completionHandler: completionHandler)
    }

    @discardableResult
    public func loadData(
        with url: URL,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        return DataLoader.shared.loadData(with: url, completionHandler: completionHandler)
    }
}
