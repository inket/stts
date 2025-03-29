#!/usr/bin/swift

import Foundation

enum GooglePlatform: CaseIterable {
    case cloudPlatform
    case firebase

    var url: URL {
        switch self {
        case .cloudPlatform:
            // swiftlint:disable:next force_unwrapping
            return URL(string: "https://status.cloud.google.com")!
        case .firebase:
            // swiftlint:disable:next force_unwrapping
            return URL(string: "https://status.firebase.google.com")!
        }
    }

    func outputPath(root: String) -> String {
        switch self {
        case .cloudPlatform:
            return "\(root)/stts/Services/Generated/GoogleCloudPlatformServices.swift"
        case .firebase:
            return "\(root)/stts/Services/Generated/FirebaseServices.swift"
        }
    }
}

protocol Service {
    var serviceName: String { get }
    var className: String { get }
    var output: String { get }
}

extension Service {
    var className: String {
        var sanitizedName = serviceName
        sanitizedName = sanitizedName.replacingOccurrences(of: " & ", with: "And")
        sanitizedName = sanitizedName.replacingOccurrences(of: "/", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ":", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: "-", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: "(", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ")", with: "")
        return sanitizedName.components(separatedBy: " ")
            .map { $0.capitalized(firstLetterOnly: true) }
            .joined(separator: "")
    }
}

struct GCPService: Service {
    let serviceName: String
    let dashboardName: String

    init(dashboardName: String) {
        self.dashboardName = dashboardName

        if !dashboardName.hasPrefix("Google") {
            serviceName = "Google \(dashboardName)"
        } else {
            serviceName = dashboardName
        }

    }

    var output: String {
        return """
        final class \(className): GoogleCloudPlatform, SubService {
            let name = "\(serviceName)"
            let dashboardName = "\(dashboardName)"
        }
        """
    }
}

struct FirebaseService: Service {
    let serviceName: String

    init(dashboardName: String) {
        if !dashboardName.hasPrefix("Firebase") {
            serviceName = "Firebase \(dashboardName)"
        } else {
            serviceName = dashboardName
        }
    }

    var output: String {
        return """
        final class \(className): FirebaseService, SubService {
            let name = "\(serviceName)"
        }
        """
    }
}

extension String {
    subscript(_ range: NSRange) -> String {
        // Why we still have to do this shit in 2019 I don't know
        let start = self.index(self.startIndex, offsetBy: range.lowerBound)
        let end = self.index(self.startIndex, offsetBy: range.upperBound)
        let subString = self[start..<end]
        return String(subString)
    }

    func capitalized(firstLetterOnly: Bool) -> String {
        return firstLetterOnly ? (prefix(1).capitalized + dropFirst()) : self
    }
}

func envVariable(forKey key: String) -> String {
    guard let variable = ProcessInfo.processInfo.environment[key] else {
        print("error: Environment variable '\(key)' not set")
        exit(1)
    }

    return variable
}

func discoverServices(for platform: GooglePlatform) -> [Service] {
    var result = [Service]()

    var dataResult: Data?

    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: platform.url) { data, _, _ in
        dataResult = data
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + .seconds(10))

    guard let data = dataResult, var body = String(data: data, encoding: .utf8) else {
        print("""
            warning: Build script generate_google_services could not retrieve
            list of Google Cloud Platform/Firebase services
        """)

        exit(0)
    }

    body = body.replacingOccurrences(of: "\n", with: "")

    let regex: NSRegularExpression
    switch platform {
    case .cloudPlatform:
        // swiftlint:disable:next force_try
        regex = try! NSRegularExpression(
            pattern: "__product\">[\\s\\n]*(.+?)[\\s\\n]*<.*?\\/th>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    case .firebase:
        // swiftlint:disable:next force_try
        regex = try! NSRegularExpression(
            pattern: "class=\"product-name\">.*?[\\s\\n]*([^>]*?)[\\s\\n]*<\\/",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    }

    let range = NSRange(location: 0, length: body.count)
    regex.enumerateMatches(in: body, options: [], range: range) { textCheckingResult, _, _ in
        guard let textCheckingResult = textCheckingResult, textCheckingResult.numberOfRanges == 2 else { return }

        let serviceName = body[textCheckingResult.range(at: 1)]

        switch platform {
        case .cloudPlatform:
            result.append(GCPService(dashboardName: serviceName))
        case .firebase:
            result.append(FirebaseService(dashboardName: serviceName))
        }
    }

    return result
}

func main() {
    let srcRoot = envVariable(forKey: "SRCROOT")

    GooglePlatform.allCases.forEach { platform in
        let services = discoverServices(for: platform)

        let header = """
        // This file is generated by generate_google_services.swift and should not be modified manually.
        // swiftlint:disable superfluous_disable_command type_name

        import Foundation

        """

        let content = services.map { $0.output }.joined(separator: "\n\n")
        let footer = ""

        let output = [header, content, footer].joined(separator: "\n")

        // swiftlint:disable:next force_try
        try! output.write(toFile: platform.outputPath(root: srcRoot), atomically: true, encoding: .utf8)
    }

    print("Finished generating Google services.")
}

main()
