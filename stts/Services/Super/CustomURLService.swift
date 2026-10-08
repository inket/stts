//
//  CustomURLService.swift
//  stts
//

import Foundation
import Security

/// A user-defined service: one request to its URL, judged by its rules.
final class CustomURLService: Service {
    let definition: CustomService

    var name: String { definition.name }
    var url: URL { definition.url }

    /// The outcome of the last check, for the Custom services pane.
    @Atomic private(set) var lastResult: CustomService.CheckResult?
    @Atomic private(set) var lastCheckDate: Date?

    init(_ definition: CustomService) {
        self.definition = definition
    }

    /// Whether a service with its own interval is due on the custom services timer. One that
    /// follows the General interval never is — the main timer checks it.
    func isDue(at date: Date) -> Bool {
        guard let interval = definition.interval else { return false }
        guard let lastCheckDate else { return true }
        // A little slack, so a check that ran a moment late isn't pushed out a whole tick.
        return date.timeIntervalSince(lastCheckDate) >= TimeInterval(interval) - 5
    }

    override func updateStatus() async throws {
        lastCheckDate = Date()

        do {
            let result = try await CustomServiceChecker.run(definition)
            lastResult = result
            statusDescription = ServiceStatusDescription(
                status: result.verdict == .healthy ? .good : .major,
                message: result.verdict == .healthy ? "Operational" : result.detail
            )
        } catch {
            let message = ServiceStatusMessage.from(error)
            lastResult = CustomServiceChecker.noAnswer(error)
            // Missing secret: the request was never sent, so it's not a network failure.
            if case CustomServiceChecker.CheckError.missingSecret = error {
                throw StatusUpdateError.custom(message)
            }
            throw StatusUpdateError.networkError(error)
        }
    }
}

/// Performs a custom service's request and evaluates its rules. Separate from `CustomURLService`
/// so the editor's Test now can run a draft that was never saved.
enum CustomServiceChecker {
    enum CheckError: LocalizedError {
        case missingSecret(headerName: String)
        case notHTTP

        var errorDescription: String? {
            switch self {
            case let .missingSecret(headerName): return "Secret header “\(headerName)” is missing"
            case .notHTTP: return "Not an HTTP response"
            }
        }
    }

    struct Response {
        var statusCode: Int
        var elapsed: Duration
        /// `nil` when no rule needs it, or for HEAD.
        var body: String?
        /// The leaf certificate's not-after date; `nil` over plain HTTP.
        var certificateExpiry: Date?
    }

    static let timeout: TimeInterval = 30
    /// How much of a body the text rules search.
    static let bodyLimit = 2 * 1024 * 1024

    /// For Test now: never throws; a failure to get a response comes back as a no-answer result.
    static func check(
        _ service: CustomService,
        configuration: URLSessionConfiguration = .ephemeral
    ) async -> CustomService.CheckResult {
        do {
            return try await run(service, configuration: configuration)
        } catch {
            return noAnswer(error)
        }
    }

    /// Throws when there's no response to judge.
    static func run(
        _ service: CustomService,
        configuration: URLSessionConfiguration = .ephemeral,
        now: Date = Date()
    ) async throws -> CustomService.CheckResult {
        if let missing = service.requestHeaders.first(where: { $0.isSecret && $0.value.isEmpty }) {
            throw CheckError.missingSecret(headerName: missing.name)
        }
        let response = try await fetch(service, configuration: configuration)
        return evaluate(service, response: response, now: now)
    }

    static func noAnswer(_ error: Error) -> CustomService.CheckResult {
        var isMissingSecret = false
        if case CheckError.missingSecret = error { isMissingSecret = true }
        return CustomService.CheckResult(
            verdict: .noAnswer,
            label: "NO ANSWER",
            detail: ServiceStatusMessage.from(error),
            date: Date(),
            isMissingSecret: isMissingSecret
        )
    }

    // MARK: - Request

    /// A new session per check: a reused connection skips the TLS handshake, and with it the only
    /// chance to see the certificate.
    static func fetch(_ service: CustomService, configuration: URLSessionConfiguration) async throws -> Response {
        var request = URLRequest(
            url: service.url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = service.method.rawValue
        for header in service.requestHeaders where !header.name.isEmpty {
            request.addValue(header.value, forHTTPHeaderField: header.name)
        }
        if service.method.sendsBody, !service.requestBody.isEmpty {
            request.httpBody = Data(service.requestBody.utf8)
        }

        let configuration = configuration.copy() as? URLSessionConfiguration ?? .ephemeral
        configuration.urlCache = nil
        let delegate = SessionDelegate(followsRedirects: service.followsRedirects)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let clock = ContinuousClock()
        let start = clock.now
        let (bytes, urlResponse) = try await session.bytes(for: request)
        let elapsed = start.duration(to: clock.now)

        guard let httpResponse = urlResponse as? HTTPURLResponse else { throw CheckError.notHTTP }

        var body: String?
        if service.method.hasResponseBody, service.rules.contains(where: \.kind.readsBody) {
            var data = Data()
            for try await byte in bytes {
                data.append(byte)
                if data.count >= bodyLimit { break }
            }
            // Lenient on purpose: the cut at `bodyLimit` can split a character, and a failable
            // decode would then throw away the whole body.
            // swiftlint:disable:next optional_data_string_conversion
            body = String(decoding: data, as: UTF8.self)
        }
        bytes.task.cancel()

        return Response(
            statusCode: httpResponse.statusCode,
            elapsed: elapsed,
            body: body,
            certificateExpiry: delegate.certificateExpiry
        )
    }

    private final class SessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        let followsRedirects: Bool
        /// The last server's leaf certificate — after redirects across hosts, the final one's.
        @Atomic var certificateExpiry: Date?

        init(followsRedirects: Bool) {
            self.followsRedirects = followsRedirects
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest
        ) async -> URLRequest? {
            // `nil` hands back the 3xx itself, for the rules to judge.
            followsRedirects ? request : nil
        }

        /// Task-level, which also receives connection-level challenges when the session-level
        /// method isn't implemented. Only observes; the system still decides whether to trust.
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didReceive challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trust = challenge.protectionSpace.serverTrust {
                certificateExpiry = CustomServiceChecker.expiry(of: trust)
            }
            return (.performDefaultHandling, nil)
        }
    }

    static func expiry(of trust: SecTrust) -> Date? {
        guard
            let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first,
            let values = SecCertificateCopyValues(leaf, [kSecOIDX509V1ValidityNotAfter] as CFArray, nil)
                as? [String: Any],
            let notAfter = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
            let seconds = notAfter[kSecPropertyKeyValue as String] as? NSNumber
        else { return nil }
        return Date(timeIntervalSinceReferenceDate: seconds.doubleValue)
    }

    // MARK: - Rules

    static func evaluate(
        _ service: CustomService,
        response: Response,
        now: Date
    ) -> CustomService.CheckResult {
        let milliseconds = Int(response.elapsed / .milliseconds(1))
        let failures = service.rules.compactMap {
            failure(of: $0, response: response, milliseconds: milliseconds, now: now)
        }
        let passed = service.matching == .all ? failures.isEmpty : failures.count < service.rules.count

        let code = response.statusCode
        if passed {
            let label = (200..<300).contains(code) ? "\(code) OK" : "\(code)"
            return CustomService.CheckResult(verdict: .healthy, label: label, detail: "\(milliseconds) ms", date: now)
        }

        let failedOnStatus = service.rules.contains { $0.kind == .status && !matchesStatus($0, code: code) }
        return CustomService.CheckResult(
            verdict: .failed,
            label: failedOnStatus ? "\(code)" : "MISMATCH",
            detail: failures.first ?? "",
            date: now
        )
    }

    /// Why `rule` failed, or `nil` if it held.
    private static func failure(
        of rule: CustomService.Rule,
        response: Response,
        milliseconds: Int,
        now: Date
    ) -> String? {
        let rule = rule.normalized
        switch rule.kind {
        case .status:
            return matchesStatus(rule, code: response.statusCode) ? nil : "Got \(response.statusCode)"
        case .contains:
            return body(response, contains: rule.value) ? nil : "Response doesn't contain “\(rule.value)”"
        case .omits:
            return body(response, contains: rule.value) ? "Response contains “\(rule.value)”" : nil
        case .within:
            let limit = Int(rule.value) ?? 0
            return milliseconds <= limit ? nil : "Took \(milliseconds.formatted()) ms"
        case .certificate:
            guard let expiry = response.certificateExpiry else { return "No certificate" }
            let minimumDays = Int(rule.value) ?? 0
            guard expiry > now else { return "Certificate expired" }
            let daysLeft = Int(expiry.timeIntervalSince(now) / 86_400)
            if expiry > now.addingTimeInterval(TimeInterval(minimumDays) * 86_400) { return nil }
            return daysLeft == 1 ? "Certificate expires in 1 day" : "Certificate expires in \(daysLeft) days"
        }
    }

    /// `2xx` matches any code starting with 2; anything else must match exactly.
    private static func matchesStatus(_ rule: CustomService.Rule, code: Int) -> Bool {
        rule.normalized.statusCodes.contains { pattern in
            if pattern.hasSuffix("xx") {
                return String(code).first == pattern.first
            }
            return Int(pattern) == code
        }
    }

    private static func body(_ response: Response, contains text: String) -> Bool {
        (response.body ?? "").range(of: text, options: .caseInsensitive) != nil
    }
}
