#!/usr/bin/swift

import Foundation

struct Cloud {
    let id: String
    let name: String
    let products: [Product]

    init?(dictionary: [String: Any], productsMap: [String: Product]) {
        guard
            let id = dictionary["id"] as? String,
            let name = dictionary["name"] as? String,
            let productIDs = dictionary["cloudProducts"] as? [String]
        else {
            return nil
        }

        self.id = id
        self.name = name
        products = productIDs.compactMap { productsMap[$0] }
    }
}

struct Product {
    let id: String
    let name: String

    init?(dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let name = dictionary["name"] as? String
        else {
            return nil
        }

        self.id = id
        self.name = name
    }
}

struct AdobeService {
    enum ServiceType {
        case category
        case service
        case subService
    }

    let id: String

    let parentName: String
    let name: String
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
        return sanitizedName
            .components(separatedBy: " ")
            .map { $0.capitalized(firstLetterOnly: true) }
            .joined(separator: "")
    }

    init(id: String, parentName: String, name: String, type: ServiceType) {
        self.id = id
        self.parentName = parentName
        self.type = type

        if !name.hasPrefix("Adobe") {
            self.name = "Adobe \(name)"
        } else {
            self.name = name
        }
    }

    var output: String {
        switch type {
        case .category:
            return """
            final class \(className)All: \(className), ServiceCategory {
                let categoryName = "\(name)"
                let subServiceSuperclass: AnyObject.Type = Base\(className).self

                let name = "\(name) (All)"
                let id = "\(id)"
            }
            """
        case .service:
            return """
            final class \(className): \(parentName) {
                let name = "\(name)"
                let id = "\(id)"
            }
            """
        case .subService:
            return """
            final class \(className): \(parentName), SubService {
                let name = "\(name)"
                let id = "\(id)"
            }
            """
        }
    }
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

func discoverServices() -> [AdobeService] {
    var dataResult: Data?

    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: "https://data.status.adobe.com/adobestatus/SnowServiceRegistry")!

    URLSession.shared.dataTask(with: url) { data, _, _ in
        dataResult = data
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + .seconds(10))

    guard
        let data = dataResult,
        let structure = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        print("warning: Build script generate_adobe_services could not retrieve list of Adobe services")
        exit(0)
    }

    let productsDictionary = (structure["products"] as? [String: Any]) ?? [:]
    let productsMap = productsDictionary.compactMapValues { (value: Any) -> Product? in
        guard let dict = value as? [String: Any] else { return nil }
        return Product(dictionary: dict)
    }

    let cloudsDictionary = (structure["clouds"] as? [String: Any]) ?? [:]
    let clouds = cloudsDictionary.compactMap { (_, value) -> Cloud? in
        guard let dict = value as? [String: Any] else { return nil }
        return Cloud(dictionary: dict, productsMap: productsMap)
    }

    var uniqueNames = Set<String>()

    // Create the categories from the clouds
    var categories = [String: AdobeService]()
    clouds.forEach { cloud in
        var name = cloud.name

        if uniqueNames.contains(name) {
            name = "\(name) (\(cloud.id))"
        }
        uniqueNames.insert(name)

        let category = AdobeService(id: cloud.id, parentName: "", name: name, type: .category)
        categories[cloud.id] = category

        // Create the subservices from the products
        cloud.products.forEach { product in
            var name = product.name

            if uniqueNames.contains(name) {
                name = "\(name) (\(product.id))"
            }
            uniqueNames.insert(name)

            let subService = AdobeService(id: product.id, parentName: category.className, name: name, type: .subService)
            categories[product.id] = subService
        }
    }

    let result: [AdobeService] = categories.values.sorted {
        $0.name.caseInsensitiveCompare($1.name) != .orderedDescending
    }

    return result
}

func main() {
    let srcRoot = envVariable(forKey: "SRCROOT")
    let outputPath = "\(srcRoot)/stts/Services/Generated/AdobeServices.swift"
    let services = discoverServices()

    let header = """
    // This file is generated by generate_adobe_services.swift and should not be modified manually.
    // swiftlint:disable superfluous_disable_command type_name

    import Foundation

    """

    let content = services.map { $0.output }.joined(separator: "\n\n")
    let footer = ""

    let output = [header, content, footer].joined(separator: "\n")

    // swiftlint:disable:next force_try
    try! output.write(toFile: outputPath, atomically: true, encoding: .utf8)

    print("Finished generating Adobe services.")
}

main()
