#!/usr/bin/swift

import Foundation

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

struct Service: Codable {
    enum CodingKeys: String, CodingKey {
        case id = "service"
        case name = "service_name"
        case regionName = "region_name"
        case regionID = "region_id"
    }

    let id: String
    let name: String
    let regionName: String?
    let regionID: String?
}

protocol OutputService {
    var output: String { get }
    var sortingName: String { get }
}

class OutputNamedService: OutputService {
    let name: String
    var ids = Set<String>()

    var sortingName: String {
        usableName
    }

    var usableName: String {
        var result = name
        if !result.hasPrefix("Amazon "), !result.hasPrefix("AWS ") {
            result = "AWS \(name)"
        }
        return result
    }

    var className: String {
        var sanitizedName = usableName
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

    var output: String {
        """
        class \(className): AWSNamedService, SubService {
            let name = "\(usableName)"
            let ids = Set<String>([
                "\(ids.joined(separator: "\",\n        \""))"
            ])
        }
        """
    }

    init(initialService: Service) {
        name = initialService.name
        add(initialService)
    }

    func add(_ service: Service) {
        ids.insert(service.id)
    }
}

class OutputRegion: OutputService {
    let id: String
    let name: String

    var sortingName: String {
        "111\(usableName)"
    }

    var usableName: String {
        "AWS (\(name))"
    }

    var className: String {
        var sanitizedName = usableName
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

    var output: String {
        """
        class \(className): AWSRegionService, SubService {
            let id = "\(id)"
            let name = "\(usableName)"
        }
        """
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

func discoverServices() -> [OutputService] {
    var dataResult: Data?

    let semaphore = DispatchSemaphore(value: 0)
    let url = URL(string: "https://d3s31nlw3sm5l8.cloudfront.net/services.json")!
    URLSession.shared.dataTask(with: url) { data, _, _ in
        dataResult = data
        semaphore.signal()
    }.resume()

    _ = semaphore.wait(timeout: .now() + .seconds(10))

    guard
        let data = dataResult,
        let services = try? JSONDecoder().decode([Service].self, from: data)
    else {
        print("warning: Build script generate_aws_services could not retrieve list of AWS services")
        exit(0)
    }

    var servicesByName: [String: OutputNamedService] = [:]
    var regions: [String: OutputRegion] = [:]

    services.forEach {
        let namedService = servicesByName[$0.name] ?? OutputNamedService(initialService: $0)
        namedService.add($0)
        servicesByName[$0.name] = namedService

        if let regionID = $0.regionID, let regionName = $0.regionName {
            if regions[regionID] == nil {
                regions[regionID] = OutputRegion(id: regionID, name: regionName)
            }
        }
    }

    let namedServices: [OutputService] = [OutputNamedService](servicesByName.values)
    let regionServices: [OutputService] = [OutputRegion](regions.values)
    return namedServices + regionServices
}

func main() {
    let srcRoot = envVariable(forKey: "SRCROOT")
    let outputPath = "\(srcRoot)/stts/Services/Generated/AWSServices.swift"
    let services = discoverServices()

    let header = """
    // This file is generated by generate_aws_services.swift and should not be modified manually.
    // swiftlint:disable superfluous_disable_command type_name

    import Foundation

    class AWSRegions: AWSAllService, ServiceCategory {
        let categoryName = "Amazon Web Services (by region)"
        let subServiceSuperclass: AnyObject.Type = BaseAWSRegionService.self

        let name = "AWS Regions (All)"
    }

    class AWSServices: AWSAllService, ServiceCategory {
        let categoryName = "Amazon Web Services"
        let subServiceSuperclass: AnyObject.Type = BaseAWSNamedService.self

        let name = "AWS (All)"
    }

    """

    let content = services.sorted(by: { one, two in
        one.sortingName < two.sortingName
    }).map { $0.output }.joined(separator: "\n\n")
    let footer = ""

    let output = [header, content, footer].joined(separator: "\n")

    debugPrint(output)
    // swiftlint:disable:next force_try
    try! output.write(toFile: outputPath, atomically: true, encoding: .utf8)

    print("Finished generating AWS services.")
}

main()
