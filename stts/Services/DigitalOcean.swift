//
//  DigitalOcean.swift
//  stts
//

import Kanna

class DigitalOcean: IndependentService {
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return strongSelf._fail("Couldn't parse response") }

            self?.status = strongSelf.status(from: doc)
            self?.message = strongSelf.message(from: doc)
        }
    }
}

extension DigitalOcean {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        guard document.css(".page-status.status-none").count == 0 else { return .good }

        let unresolvedIncidentClasses = document.css(".unresolved-incident").compactMap { $0.className }

        var resultStatus: ServiceStatus = .undetermined

        for incidentClass in unresolvedIncidentClasses {
            if incidentClass.range(of: "impact-critical") != nil || incidentClass.range(of: "impact-major") != nil {
                resultStatus = .major
                break // Can't get worse than major
            }

            guard resultStatus < .minor else { continue }

            if incidentClass.range(of: "impact-minor") != nil {
                resultStatus = .minor
            }

            guard resultStatus < .maintenance else { continue }

            if incidentClass.range(of: "impact-maintenance") != nil {
                resultStatus = .maintenance
            }
        }

        return resultStatus
    }

    fileprivate func message(from document: HTMLDocument) -> String {
        let statusTitle = document.css(".page-status .status").first?.text
        let incidentTitle = document.css(".unresolved-incident .incident-title .actual-title").first?.text

        return (statusTitle ?? incidentTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
