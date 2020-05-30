#!/usr/bin/swift

import Foundation

private struct AppleResponseData: Codable {
    struct Service: Codable {
        let serviceName: String
    }

    let services: [Service]
}

struct AppleService {
    enum ServiceType {
        case category
        case subService
    }

    let parentName: String
    var name: String
    let serviceName: String
    let type: ServiceType

    var className: String {
        var sanitizedName = name
        sanitizedName = sanitizedName.replacingOccurrences(of: " & ", with: "And")
        sanitizedName = sanitizedName.replacingOccurrences(of: "/", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ":", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: "-", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ".", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: "(", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ")", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: "+", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ",", with: "")
        return sanitizedName
            .components(separatedBy: " ")
            .map { $0.capitalized(firstLetterOnly: true) }
            .joined(separator: "")
    }

    init(parentName: String, name: String, type: ServiceType) {
        self.parentName = parentName
        self.type = type
        self.serviceName = name

        if !name.hasPrefix("Apple") {
            self.name = "Apple \(name)"
        } else {
            self.name = name
        }
    }

    var output: String {
        switch type {
        case .category:
            return """
            class \(className)All: \(className), ServiceCategory {
                let categoryName = "\(name)"
                let subServiceSuperclass: AnyObject.Type = Base\(className).self

                let name = "\(name) (All)"
                let serviceName = "*"
            }
            """
        case .subService:
            return """
            class \(className): \(parentName), SubService {
                let name = "\(name)"
                let serviceName = "\(serviceName)"
            }
            """
        }
    }
}

extension String {
    func capitalized(firstLetterOnly: Bool) -> String {
        return firstLetterOnly ? (prefix(1).capitalized + dropFirst()) : self
    }

    var innerJSONString: String {
        let callbackPrefix = "jsonCallback("
        let callbackSuffix = ");"

        guard hasPrefix(callbackPrefix) && hasSuffix(callbackSuffix) else { return self }

        return String(self[
            index(startIndex, offsetBy: callbackPrefix.count) ..< index(endIndex, offsetBy: -callbackSuffix.count)
        ])
    }
}

func envVariable(forKey key: String) -> String {
    guard let variable = ProcessInfo.processInfo.environment[key] else {
        print("error: Environment variable '\(key)' not set")
        exit(1)
    }

    return variable
}

func discoverServices(url: String, categoryName: String, categoryClassName: String) -> [AppleService] {
    var dataResult: Data?

    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: url)!

    URLSession.shared.dataTask(with: url) { data, _, _ in
        dataResult = data
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + .seconds(10))

    guard
        let data = dataResult,
        let jsonData = String(data: data, encoding: .utf8)?.innerJSONString.data(using: .utf8),
        let responseData = try? JSONDecoder().decode(AppleResponseData.self, from: jsonData)
    else {
        print("warning: Build script generate_apple_services could not retrieve list of \(categoryName) services")
        exit(0)
    }

    let result: [AppleService] =
        [AppleService(parentName: "", name: categoryName, type: .category)] +
        responseData.services.map {
            AppleService(parentName: categoryClassName, name: $0.serviceName, type: .subService)
    }
    return result
}

func main() {
    let srcRoot = envVariable(forKey: "SRCROOT")
    let outputPath = "\(srcRoot)/stts/Services/Generated/AppleServices.swift"

    let services = discoverServices(
        url: "https://www.apple.com/support/systemstatus/data/system_status_en_US.js",
        categoryName: "Apple",
        categoryClassName: "Apple"
    )
    var developerServices = discoverServices(
        url: "https://www.apple.com/support/systemstatus/data/developer/system_status_en_US.js",
        categoryName: "Apple Developer",
        categoryClassName: "AppleDeveloper"
    )

    // Fix name collisions
    let serviceNames = services.map { $0.name }
    developerServices = developerServices.map {
        if serviceNames.contains($0.name) {
            var renamedService = $0
            renamedService.name = "\($0.name) (Developer)"
            return renamedService
        } else {
            return $0
        }
    }

    let header = """
    // This file is generated by generate_apple_services.swift and should not be modified manually.

    import Foundation

    """

    let content = (services + developerServices).map { $0.output }.joined(separator: "\n\n")
    let footer = ""

    let output = [header, content, footer].joined(separator: "\n")

    // swiftlint:disable:next force_try
    try! output.write(toFile: outputPath, atomically: true, encoding: .utf8)
}

main()
