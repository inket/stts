//
//  Beanstalk.swift
//  stts
//

import Kanna

class Beanstalk: Service {
    let url = URL(string: "http://status.beanstalkapp.com")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }

            guard let data = data else { return selfie._fail(error) }
            guard let body = String(data: data, encoding: .utf8) else { return selfie._fail("Unreadable response") }
            guard let doc = try? HTML(html: body, encoding: .utf8) else { return selfie._fail("Couldn't parse response") }

            self?.status = selfie.status(from: doc)
            self?.message = selfie.message(for: selfie.status)
        }.resume()
    }
}

extension Beanstalk {
    fileprivate func status(from document: HTMLDocument) -> ServiceStatus {
        let firstStatus = document.css("#updates article:first .status").compactMap { $0.text }.first

        guard let status = firstStatus else { return .undetermined }

        switch status {
        case "ok": return .good
        case "maintenance": return .maintenance
        case "problem": return .major
        default: return .undetermined
        }
    }

    fileprivate func message(for status: ServiceStatus) -> String {
        switch status {
        case .good: return "Services operating normally."
        case .major: return "Experiencing service interruptions."
        case .maintenance: return "Scheduled maintenance in progress."
        default: return "Undetermined"
        }
    }
}
