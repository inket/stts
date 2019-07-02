//
//  URLSessionMock.swift
//  sttsTests
//

import Foundation

class URLSessionMock: URLSession {
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void

    private func humanSize(data: Data?) -> String {
        guard let data = data else { return "nil" }

        return "\(data.count / 1024)KB"
    }

    override func dataTask(
        with url: URL,
        completionHandler: @escaping CompletionHandler
    ) -> URLSessionDataTask {
        URLSession.shared.dataTask(with: url) { data, response, error in
            print("[URLSessionMock] \(self.humanSize(data: data)) [\(url.absoluteString)]")
            completionHandler(data, response, error)
        }
    }

    override func dataTask(
        with urlRequest: URLRequest,
        completionHandler: @escaping CompletionHandler
    ) -> URLSessionDataTask {
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            print("[URLSessionMock] \(self.humanSize(data: data)) [\(urlRequest.url?.absoluteString ?? "nil")]")
            completionHandler(data, response, error)
        }
    }
}
