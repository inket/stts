//
//  Docker.swift
//  stts
//

import Cocoa

class Docker: Service {
    override var url: URL { return URL(string: "https://status.docker.com/")! }
    
    override func updateStatus(callback: @escaping (Service) -> ()) {
        let lastMessageURL = URL(string: "https://status.docker.com/1.0/status/533c6539221ae15e3f000031")!
        
        URLSession.shared.dataTask(with: lastMessageURL) { [weak self] data, response, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }
            
            let json = try? JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = json as? [String : Any],
                let resultJSON = dict["result"] as? [String : Any],
                let status_overallJSON = resultJSON["status_overall"] as? [String : Any],
                let status_code = status_overallJSON["status_code"] as? Int,
                let status = status_overallJSON["status"] as? String
            else {
                return selfie._fail("Unexpected data")
            }

            
            switch status_code {
            case 100: self?.status = .good  // Operational
            case 300: self?.status = .minor // Degraded Performance
            case 400: self?.status = .minor // Partial Service Disruption
            case 500: self?.status = .major // Service Disruption
            case 600: self?.status = .major // Security Event
            default: self?.status = .undetermined
            }
            
            self?.message = status
            }.resume()
    }
}
