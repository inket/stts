//
//  CustomService.swift
//  stts
//

import AppKit

/// A URL the user watches, and the rules that decide whether it's healthy. Persisted by
/// `CustomServiceStore`; whether it's enabled and its notification override live in `Preferences`,
/// keyed by `globalIdentifier`, like any other service.
struct CustomService: Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: URL
    var method: Method = .get
    var followsRedirects = true
    /// Sent with POST; empty otherwise.
    var requestBody = ""
    var requestHeaders: [Header] = []
    /// Seconds between checks; `nil` follows the General setting.
    var interval: Int?
    /// Text rules can repeat; any other kind appears at most once.
    var rules: [Rule]
    var matching: Matching = .all

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        method: Method = .get,
        followsRedirects: Bool = true,
        requestBody: String = "",
        requestHeaders: [Header] = [],
        interval: Int? = nil,
        rules: [Rule],
        matching: Matching = .all
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.method = method
        self.followsRedirects = followsRedirects
        self.requestBody = requestBody
        self.requestHeaders = requestHeaders
        self.interval = interval
        self.rules = rules
        self.matching = matching
    }

    static let providerIdentifier = "custom"

    /// Built from the id rather than the name, which can change.
    var globalIdentifier: String { Self.globalIdentifier(for: id) }

    static func globalIdentifier(for id: UUID) -> String { "\(providerIdentifier).\(id.uuidString)" }

    /// The editor's "Check every" choices: Default (`nil`) then the General pane's own options.
    static let intervalOptions: [Int?] = [nil] + Preferences.refreshIntervalOptions.map(Optional.some)

    /// The rules in plain words, for a row's second line: "Healthy when status is 200 and response
    /// contains “drained”". Joined by hand rather than with `ListFormatter`, which only does "and".
    var rulesSummary: String {
        "Healthy when \(Self.list(rules.map(\.phrase), conjunction: matching.conjunction))"
    }

    /// "a", "a and b", "a, b, and c".
    fileprivate static func list(_ items: [String], conjunction: String) -> String {
        var items = items
        guard let last = items.popLast() else { return "" }
        switch items.count {
        case 0: return last
        case 1: return "\(items[0]) \(conjunction) \(last)"
        default: return items.joined(separator: ", ") + ", \(conjunction) \(last)"
        }
    }

    static func intervalTitle(_ seconds: Int?) -> String {
        guard let seconds else { return "Default" }
        let minutes = seconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

extension CustomService {
    enum Method: String, CaseIterable {
        case get = "GET"
        case head = "HEAD"
        case post = "POST"

        var hasResponseBody: Bool { self != .head }
        var sendsBody: Bool { self == .post }
    }

    struct Header: Identifiable, Equatable {
        /// Only for `ForEach` while editing; not part of equality.
        let id: UUID
        var name: String
        /// For a secret, what's in the Keychain — empty if the item is missing.
        var value: String
        /// Kept in the Keychain rather than the services file.
        var isSecret: Bool

        init(id: UUID = UUID(), name: String, value: String, isSecret: Bool = false) {
            self.id = id
            self.name = name
            self.value = value
            self.isSecret = isSecret
        }

        static func == (lhs: Header, rhs: Header) -> Bool {
            lhs.name == rhs.name && lhs.value == rhs.value && lhs.isSecret == rhs.isSecret
        }

        var isEmpty: Bool { name.isEmpty && value.isEmpty }

        /// An RFC 9110 token: no spaces, colons or other separators.
        var hasValidName: Bool {
            name.range(of: #"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$"#, options: .regularExpression) != nil
        }

        var trimmed: Header {
            Header(
                id: id,
                name: name.trimmingCharacters(in: .whitespaces),
                value: value.trimmingCharacters(in: .whitespaces),
                isSecret: isSecret
            )
        }
    }

    /// Whether every rule has to pass, or just one. Moot with a single rule.
    enum Matching: String, CaseIterable {
        case all
        case any

        var title: String { rawValue }

        var conjunction: String {
            switch self {
            case .all: return "and"
            case .any: return "or"
            }
        }
    }

    struct Rule: Identifiable, Equatable {
        enum Kind: String, CaseIterable, Identifiable {
            case status
            case contains
            case omits
            case within
            case certificate

            var id: String { rawValue }

            var title: String {
                switch self {
                case .status: return "Status code is"
                case .contains: return "Response contains"
                case .omits: return "Response omits"
                case .within: return "Response within"
                case .certificate: return "Certificate valid for more than"
                }
            }

            var prompt: String {
                switch self {
                case .status: return "200, 3xx"
                case .contains, .omits: return "Text"
                case .within: return "500"
                case .certificate: return "30"
                }
            }

            /// What the value field keeps of `input`: a status list takes only digits, `x`, commas
            /// and spaces (`X` is lowered), the numeric kinds only digits, and text rules anything.
            func filtered(_ input: String) -> String {
                switch self {
                case .status:
                    return String(input.lowercased().filter { $0.isASCII && ($0.isNumber || "x, ".contains($0)) })
                case .within, .certificate:
                    return String(input.filter { $0.isASCII && $0.isNumber })
                case .contains, .omits:
                    return input
                }
            }

            /// Shown after the value field.
            var unit: String? {
                switch self {
                case .within: return "ms"
                case .certificate: return "days"
                case .status, .contains, .omits: return nil
                }
            }

            /// Small print under the kind.
            var note: String? {
                switch self {
                case .status: return "Comma-separated list of acceptable status codes. 2xx matches 200–299"
                case .contains, .omits: return "Case-insensitive"
                case .certificate: return "HTTPS only"
                case .within: return nil
                }
            }

            /// Needs the response body, which a HEAD request doesn't get.
            var readsBody: Bool {
                switch self {
                case .contains, .omits: return true
                case .status, .within, .certificate: return false
                }
            }

            /// Several text rules make sense together; two status codes or two time limits don't.
            var isRepeatable: Bool {
                switch self {
                case .contains, .omits: return true
                case .status, .within, .certificate: return false
                }
            }
        }

        /// Only for `ForEach` while editing; not part of equality.
        let id: UUID
        var kind: Kind
        /// Text rules match case-insensitively.
        var value: String

        init(id: UUID = UUID(), kind: Kind, value: String) {
            self.id = id
            self.kind = kind
            self.value = value
        }

        static func == (lhs: Rule, rhs: Rule) -> Bool {
            lhs.kind == rhs.kind && lhs.value == rhs.value
        }

        var phrase: String {
            switch kind {
            case .status: return "status is \(CustomService.list(statusCodes, conjunction: "or"))"
            case .contains: return "response contains “\(value)”"
            case .omits: return "response doesn't contain “\(value)”"
            case .within: return "response arrives within \(value) ms"
            case .certificate: return "certificate is valid for more than \(value == "1" ? "1 day" : "\(value) days")"
            }
        }

        /// A status rule's codes, each exact (`204`) or a class (`5xx`, any code starting with 5).
        var statusCodes: [String] {
            value.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        }

        /// The value trimmed, and a status list rewritten as `200, 204, 3xx`.
        var normalized: Rule {
            var rule = self
            rule.value = kind == .status
                ? statusCodes.joined(separator: ", ")
                : value.trimmingCharacters(in: .whitespacesAndNewlines)
            return rule
        }

        /// A status rule takes one or more comma-separated codes, a time limit or certificate margin
        /// a positive whole number, and a text rule anything non-empty.
        var isValid: Bool {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            switch kind {
            case .status:
                let codes = statusCodes
                return !codes.isEmpty && codes.allSatisfy {
                    $0.range(of: #"^[1-5]([0-9]{2}|xx)$"#, options: .regularExpression) != nil
                }
            case .within, .certificate:
                return Int(trimmed).map { $0 > 0 } ?? false
            case .contains, .omits:
                return true
            }
        }
    }

    struct CheckResult: Equatable {
        enum Verdict {
            /// The rules held.
            case healthy
            /// A response arrived and broke the rules.
            case failed
            /// No usable response: a transport error, a timeout, or a secret missing from the
            /// Keychain.
            case noAnswer
        }

        var verdict: Verdict
        /// The mono label beside the name: "200 OK", "MISMATCH", "503", "NO ANSWER".
        var label: String
        /// What happened: "128 ms", "Response doesn't contain “drained”", "Took 1,240 ms".
        var detail: String
        var date: Date
        /// The request was never sent: the user has to re-enter a secret, so the detail is a warning.
        var isMissingSecret = false

        var color: NSColor {
            switch verdict {
            case .healthy: return PopupLayout.Colors.dotOperational
            case .failed: return PopupLayout.Colors.dotMajor
            case .noAnswer: return PopupLayout.Colors.dotUnknown
            }
        }
    }
}
