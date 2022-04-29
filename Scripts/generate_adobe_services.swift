#!/usr/bin/swift

import Foundation

struct JSONStructure: Codable {
    struct Product: Codable {
        struct Service: Codable {
            let id: Int
        }

        let service: Service
        let cloud: Int?
    }

    struct Localization: Codable {
        struct English: Codable {
            let localizeValues: [String: String]
        }

        let en: English
    }

    let products: [Product]
    let localizationValues: Localization
}

struct AdobeService {
    enum ServiceType {
        case category
        case service
        case subService
    }

    let id: Int

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

    init(id: Int, parentName: String, name: String, type: ServiceType) {
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
            class \(className)All: \(className), ServiceCategory {
                let categoryName = "\(name)"
                let subServiceSuperclass: AnyObject.Type = Base\(className).self

                let name = "\(name) (All)"
                let id = \(id)
            }
            """
        case .service:
            return """
            class \(className): \(parentName) {
                let name = "\(name)"
                let id = \(id)
            }
            """
        case .subService:
            return """
            class \(className): \(parentName), SubService {
                let name = "\(name)"
                let id = \(id)
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
    let url = URL(string: "https://data.status.adobe.com/adobestatus/currentstatus")!

    URLSession.shared.dataTask(with: url) { data, _, _ in
        dataResult = data
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + .seconds(10))

    guard let data = dataResult, let structure = try? JSONDecoder().decode(JSONStructure.self, from: data) else {
        print("warning: Build script generate_adobe_services could not retrieve list of Adobe services")
        exit(0)
    }

    var productsWithoutCloudID = [JSONStructure.Product]()

    // Get the category ids (cloud ids)
    var cloudIDs = Set<Int>()
    structure.products.forEach {
        guard let cloud = $0.cloud else {
            productsWithoutCloudID.append($0)
            return
        }

        _ = cloudIDs.insert(cloud)
    }

    var uniqueNames = Set<String>()

    // Create a map of category ids
    var categories = [Int: AdobeService]()

    cloudIDs.forEach { id in
        guard var name = structure.localizationValues.en.localizeValues["serviceName.\(id)"] else { return }

        if uniqueNames.contains(name) {
            name = "\(name) (\(id))"
        }
        uniqueNames.insert(name)

        categories[id] = AdobeService(id: id, parentName: "", name: name, type: .category)
    }

    // Get the sub services and assign their categories in the process
    let subServices = structure.products.compactMap { product -> AdobeService? in
        guard
            let cloudID = product.cloud,
            let category = categories[cloudID],
            var name = structure.localizationValues.en.localizeValues["serviceName.\(product.service.id)"]
        else { return nil }

        if uniqueNames.contains(name) {
            name = "\(name) (\(product.service.id))"
        }
        uniqueNames.insert(name)

        return AdobeService(
            id: product.service.id,
            parentName: category.className,
            name: name,
            type: .subService
        )
    }

    let servicesWithoutCategories = productsWithoutCloudID.compactMap {  product -> AdobeService? in
        guard var name = structure.localizationValues.en.localizeValues["serviceName.\(product.service.id)"] else {
            return nil
        }

        if uniqueNames.contains(name) {
            name = "\(name) (\(product.service.id))"
        }
        uniqueNames.insert(name)

        return AdobeService(id: product.service.id, parentName: "Adobe", name: name, type: .service)
    }

    let result: [AdobeService] =
        categories.values.sorted(by: { $0.name.caseInsensitiveCompare($1.name) != .orderedDescending })
        + servicesWithoutCategories.sorted(by: { $0.name.caseInsensitiveCompare($1.name) != .orderedDescending })
        + subServices.sorted(by: { $0.name.caseInsensitiveCompare($1.name) != .orderedDescending })

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
