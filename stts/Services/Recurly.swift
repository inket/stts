//
//  Recurly.swift
//  stts
//

import Kanna

class Recurly: Service {
    let url = URL(string: "https://status.recurly.com")!
    
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }
            
            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return strongSelf._fail("Couldn't parse response") }
            
            self?.status = strongSelf.status(from: doc)
            self?.message = strongSelf.message(from: doc)
            }.resume()
    }
}

extension Recurly {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        guard document.css(".page-status.status-none").count == 0 else { return .good }
        
        let unresolvedIncidentClasses = document.css(".unresolved-incident").compactMap { $0.className }
        
        if (unresolvedIncidentClasses.filter { $0.range(of: "impact-critical") != nil || $0.range(of: "impact-major") != nil }).count > 0 {
            return .major
        } else if (unresolvedIncidentClasses.filter { $0.range(of: "impact-minor") != nil }).count > 0 {
            return .minor
        } else if (unresolvedIncidentClasses.filter { $0.range(of: "impact-maintenance") != nil }).count > 0 {
            return .maintenance
        } else {
            return .undetermined
        }
    }
    
    fileprivate func message(from document: HTMLDocument) -> String {
        let statusTitle = document.css(".page-status .status").first?.text
        let incidentTitle = document.css(".unresolved-incident .incident-title .actual-title").first?.text
        
        return (statusTitle ?? incidentTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
