//
//  ScaleGrid.swift
//  stts
//

import Kanna

class ScaleGrid: Service {
    let url = URL(string: "https://scalegrid.io/status.html")!

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let strongSelf = self else { return }
            defer { callback(strongSelf) }

            guard let data = data else { return strongSelf._fail(error) }
            guard let doc = try? HTML(html: data, encoding: .utf8) else {
                return strongSelf._fail("Couldn't parse response")
            }

            let label = doc.css(".jumbotron-area .btn-single .label-lg").first
            let (status, message) = ScaleGrid.status(fromLabel: label)
            strongSelf.status = status
            strongSelf.message = message
        }.resume()
    }
}

extension ScaleGrid {
    private static func status(fromLabel label: XMLElement?) -> (ServiceStatus, String) {
        guard let className = label?.className else {
            return (.undetermined, "Unexpected response")
        }

        let status: ServiceStatus

        if className.contains("label-success") {
            status = .good
        } else if className.contains("label-info") {
            status = .maintenance
        } else if className.contains("label-warning") {
            status = .minor
        } else if className.contains("label-danger") {
            status = .major
        } else {
            status = .undetermined
        }

        return (status, label?.text ?? "Unexpected response")
    }
}
