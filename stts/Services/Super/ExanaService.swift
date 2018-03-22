//
//  ExanaService.swift
//  stts
//

import Kanna

class ExanaService: Service {
    var serviceID: String { return "" }

    override func updateStatus(callback: @escaping (Service) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = try? HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            guard let jwt = doc.css("meta[name=jwt]").first?["content"] else { return selfie._fail("Couldn't get authorization") }

            selfie.getStatus(authorization: jwt, callback: callback)
        }.resume()
    }

    func getStatus(authorization: String, callback: @escaping (Service) -> Void) {
        let params: [String : Any] = [
            "method": "components.query",
            "params": [
                "serviceId": serviceID
            ],
            "id": String.init(repeating: "a", count: 40),
            "jsonrpc": "2.0"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            return _fail("Couldn't serialize parameters for ExanaService request")
        }

        var request = URLRequest(url: URL(string: "https://statuspage.exana.io/api/components.query")!)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard let jsonRoot = json as? [String : Any],
                let result = jsonRoot["result"] as? [String : Any],
                let components = result["components"] as? [[String : Any]] else { return selfie._fail("Unexpected data") }

            let downComponents = components.filter { ($0["status"] as? String)?.lowercased() != "operational" }

            selfie.status = downComponents.isEmpty ? .good : .major

            if downComponents.isEmpty {
                selfie.message = "Operational"
            } else {
                selfie.message = downComponents.map { $0["name"] as? String }.flatMap { $0 }.joined(separator: ", ")
            }
        }.resume()
    }
}
