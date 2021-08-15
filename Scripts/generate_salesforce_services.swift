#!/usr/bin/swift

import Foundation

enum Location: String {
    case na = "NA"
    case emea = "EMEA"
    case apac = "APAC"
    case all = "ALL"

    var suffix: String {
        switch self {
        case .na, .emea, .apac:
            return "(\(rawValue))"
        case .all:
            return "(All Regions)"
        }
    }

    var classFormat: String {
        switch self {
        case .na, .emea, .apac:
            return rawValue
        case .all:
            return "All"
        }
    }

    var appFormat: String {
        switch self {
        case .na, .emea, .apac:
            return rawValue
        case .all:
            return "*"
        }
    }
}

struct SalesforceProductRegion {
    let name: String
    let key: String
    let location: Location

    var className: String {
        var sanitizedName = name
        sanitizedName = sanitizedName.replacingOccurrences(of: " & ", with: "And")
        sanitizedName = sanitizedName.replacingOccurrences(of: "/", with: "")
        sanitizedName = sanitizedName.replacingOccurrences(of: ":", with: "")
        return sanitizedName.components(separatedBy: " ")
            .map { $0.capitalized(firstLetterOnly: true) }
            .joined(separator: "")
    }

    var classNameWithRegion: String {
        "\(className) \(location.classFormat)"
            .components(separatedBy: " ")
            .map { $0.capitalized(firstLetterOnly: true) }
            .joined(separator: "")
    }

    var serviceName: String {
        "\(name) \(location.suffix)"
    }

    init(key: String, location: Location) {
        self.key = key
        self.location = location

        switch key {
        case "Salesforce_Services":
            name = "Salesforce Services"
        case "Marketing_Cloud":
            name = "Marketing Cloud"
        case "B2C_Commerce_Cloud":
            name = "B2C Commerce Cloud"
        case "Social_Studio":
            name = "Social Studio"
        case "Community_Cloud":
            name = "Experience Cloud"
        default:
            // Keep it instead of failing so that we notice when new products are added.
            name = key
        }
    }

    var superOutput: String {
        """
        typealias \(className) = Base\(className) & RequiredServiceProperties & SalesforceStoreService

        class Base\(className): BaseSalesforce {
            private static var store = SalesforceStore(key: "\(key)")
        }
        """
    }

    var output: String {
        let commonDefinitions: [String] = [
            "let name = \"\(serviceName)\"",
            "let key = \"\(key)\"",
            "let location = \"\(location.appFormat)\"",
        ]

        if location == .all {
            return """
            class \(classNameWithRegion): \(className), ServiceCategory {
                let categoryName = "\(name)"
                let subServiceSuperclass: AnyObject.Type = BaseSalesforce.self

                \(commonDefinitions.joined(separator: "\n    "))
            }
            """
        } else {
            return """
            class \(classNameWithRegion): \(className), SubService {
                \(commonDefinitions.joined(separator: "\n    "))
            }
            """
        }
    }
}

struct Instance: Codable {
    enum CodingKeys: String, CodingKey {
        case location
        case products = "Products"
    }

    let location: String
    let products: [Product]
}

struct Product: Codable {
    let key: String
}

extension String {
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

func discoverProducts() -> [SalesforceProductRegion] {
    var result = [SalesforceProductRegion]()

    var dataResult: Data?

    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: "https://api.status.salesforce.com/v1/instances?childProducts=false")!
    URLSession.shared.dataTask(with: url) { data, _, _ in
        dataResult = data
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + .seconds(10))

    guard let data = dataResult, let instances = try? JSONDecoder().decode([Instance].self, from: data) else {
        print("warning: Build script generate_salesforce_services could not retrieve list of Salesforce products")
        exit(0)
    }

    var productsSet = Set<String>()
    var productsAndRegions: [String: Set<String>] = [:]
    instances.forEach {
        guard let product = $0.products.first else { return }

        var regions = productsAndRegions[product.key] ?? Set<String>()
        regions.insert($0.location)
        productsAndRegions[product.key] = regions

        productsSet.insert(product.key)
    }

    let sortedProducts = productsSet.sorted()

    sortedProducts.forEach { productKey in
        result.append(SalesforceProductRegion(key: productKey, location: .all))

        productsAndRegions[productKey]?.forEach {
            guard let location = Location(rawValue: $0) else { return }
            result.append(SalesforceProductRegion(key: productKey, location: location))
        }
    }

    return result
}

func generateProducts(from products: [SalesforceProductRegion]) {
    let srcRoot = envVariable(forKey: "SRCROOT")
    let outputPath = "\(srcRoot)/stts/Services/Generated/SalesforceProducts.swift"

    let header = """
    // This file is generated by generate_salesforce_services.swift and should not be modified manually.

    import Foundation

    """

    let content = products.map { $0.output }.joined(separator: "\n\n")
    let footer = ""

    let output = [header, content, footer].joined(separator: "\n")

    // swiftlint:disable:next force_try
    try! output.write(toFile: outputPath, atomically: true, encoding: .utf8)
}

func generateSuper(from products: [SalesforceProductRegion]) {
    let srcRoot = envVariable(forKey: "SRCROOT")
    let outputPath = "\(srcRoot)/stts/Services/Super/SalesforceCategories.swift"

    let header = """
    // This file is generated by generate_salesforce_services.swift and should not be modified manually.

    import Foundation

    """

    let content = products.filter { $0.location == .all }.map { $0.superOutput }.joined(separator: "\n\n")
    let footer = ""

    let output = [header, content, footer].joined(separator: "\n")

    // swiftlint:disable:next force_try
    try! output.write(toFile: outputPath, atomically: true, encoding: .utf8)
}

func main() {
    let products = discoverProducts()

    generateProducts(from: products)
    generateSuper(from: products)

    print("Finished generating Salesforce services.")
}

main()
