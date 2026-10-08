//
//  CustomServiceCoding.swift
//  stts
//

import Foundation

/// One entry of `custom_services.json`, in the file's own shape: typed rule payloads, `snake_case`
/// keys, and anything at its default left out.
struct CustomServiceRecord: Codable {
    /// The highest entry version this build understands. An entry above it is kept in the file
    /// verbatim but not loaded — see `CustomServiceStore`.
    static let supportedVersion = 1

    var version: Int
    var id: UUID
    var name: String
    var url: URL
    var interval: Int?
    var request: Request?
    var match: CustomService.Matching?
    var rules: [Rule]

    struct Request: Codable {
        enum CodingKeys: String, CodingKey {
            case method
            case followRedirects = "follow_redirects"
            case headers
            case body
        }

        var method: CustomService.Method?
        var followRedirects: Bool?
        var headers: [Header]?
        var body: String?
    }

    struct Header: Codable {
        var name: String
        /// Absent for a secret in the persisted file; present for one in an export.
        var value: String?
        var secret: Bool?
    }

    enum Rule: Codable {
        case status(codes: [String])
        case contains(text: String)
        case omits(text: String)
        case responseTime(maxMilliseconds: Int)
        case certificateExpiry(minDays: Int)

        private enum CodingKeys: String, CodingKey {
            case type
            case codes
            case text
            case maxMilliseconds = "max_ms"
            case minDays = "min_days"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "status": self = .status(codes: try container.decode([String].self, forKey: .codes))
            case "contains": self = .contains(text: try container.decode(String.self, forKey: .text))
            case "omits": self = .omits(text: try container.decode(String.self, forKey: .text))
            case "response_time":
                self = .responseTime(maxMilliseconds: try container.decode(Int.self, forKey: .maxMilliseconds))
            case "certificate_expiry":
                self = .certificateExpiry(minDays: try container.decode(Int.self, forKey: .minDays))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type, in: container, debugDescription: "Unknown rule type \(type)"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .status(codes):
                try container.encode("status", forKey: .type)
                try container.encode(codes, forKey: .codes)
            case let .contains(text):
                try container.encode("contains", forKey: .type)
                try container.encode(text, forKey: .text)
            case let .omits(text):
                try container.encode("omits", forKey: .type)
                try container.encode(text, forKey: .text)
            case let .responseTime(maxMilliseconds):
                try container.encode("response_time", forKey: .type)
                try container.encode(maxMilliseconds, forKey: .maxMilliseconds)
            case let .certificateExpiry(minDays):
                try container.encode("certificate_expiry", forKey: .type)
                try container.encode(minDays, forKey: .minDays)
            }
        }
    }
}

// MARK: - Record ⇄ model

extension CustomServiceRecord {
    /// `includeSecretValues` is for an export; the persisted file never carries them.
    init(_ service: CustomService, includeSecretValues: Bool) {
        version = Self.supportedVersion
        id = service.id
        name = service.name
        url = service.url
        interval = service.interval
        match = service.matching == .all ? nil : service.matching
        rules = service.rules.map(Rule.init)

        let headers = service.requestHeaders.map { header in
            Header(
                name: header.name,
                value: header.isSecret && !includeSecretValues ? nil : header.value,
                secret: header.isSecret ? true : nil
            )
        }
        let request = Request(
            method: service.method == .get ? nil : service.method,
            followRedirects: service.followsRedirects ? nil : false,
            headers: headers.isEmpty ? nil : headers,
            body: service.method.sendsBody && !service.requestBody.isEmpty ? service.requestBody : nil
        )
        let isDefaultRequest = request.method == nil && request.followRedirects == nil
            && request.headers == nil && request.body == nil
        self.request = isDefaultRequest ? nil : request
    }

    /// `secret` supplies a secret header's value when the record doesn't carry one — the Keychain
    /// for the persisted file. A secret with neither comes back with an empty value.
    func service(secret: (_ headerName: String) -> String?) -> CustomService {
        let method = request?.method ?? .get
        return CustomService(
            id: id,
            name: name,
            url: url,
            method: method,
            followsRedirects: request?.followRedirects ?? true,
            requestBody: method.sendsBody ? request?.body ?? "" : "",
            requestHeaders: (request?.headers ?? []).map { header in
                let isSecret = header.secret ?? false
                return CustomService.Header(
                    name: header.name,
                    value: header.value ?? (isSecret ? secret(header.name) ?? "" : ""),
                    isSecret: isSecret
                )
            },
            interval: interval,
            rules: rules.map(\.rule),
            matching: match ?? .all
        )
    }
}

extension CustomServiceRecord.Rule {
    init(_ rule: CustomService.Rule) {
        let rule = rule.normalized
        switch rule.kind {
        case .status: self = .status(codes: rule.statusCodes)
        case .contains: self = .contains(text: rule.value)
        case .omits: self = .omits(text: rule.value)
        case .within: self = .responseTime(maxMilliseconds: Int(rule.value) ?? 0)
        case .certificate: self = .certificateExpiry(minDays: Int(rule.value) ?? 0)
        }
    }

    var rule: CustomService.Rule {
        switch self {
        case let .status(codes): return CustomService.Rule(kind: .status, value: codes.joined(separator: ", "))
        case let .contains(text): return CustomService.Rule(kind: .contains, value: text)
        case let .omits(text): return CustomService.Rule(kind: .omits, value: text)
        case let .responseTime(maxMilliseconds): return CustomService.Rule(kind: .within, value: "\(maxMilliseconds)")
        case let .certificateExpiry(minDays): return CustomService.Rule(kind: .certificate, value: "\(minDays)")
        }
    }
}

extension CustomService.Matching: Codable {}
extension CustomService.Method: Codable {}
