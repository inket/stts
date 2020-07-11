//
//  Beanstalk.swift
//  stts
//

import Kanna

class Beanstalk: IndependentService {
    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        loadData(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else { return strongSelf._fail("Couldn't parse response") }

            self?.status = strongSelf.status(from: doc)
            self?.message = strongSelf.message(for: strongSelf.status)
        }
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
