import Foundation

// Adobe reports category ("cloud") status through the same flat id-keyed store as its products
// (see stts/Services/Super/AdobeStore.swift) — categories aren't a synthetic "*" aggregate like
// Azure/Firebase, they're real ids Adobe's API assigns. Categories are fully data-driven
// (AdobeServiceDefinition.categoryKey/build()), so a new cloud needs no Swift change at all;
// `knownClouds` is only a heads-up when Adobe adds one, not a required update.
private let knownClouds: Set<String> = [
    "CreativeCloud", "DocumentCloud", "ExperienceCloud", "ExperiencePlatform", "Services"
]

private struct AdobeRegistry {
    struct Product {
        let id: String
        let name: String

        init?(_ dict: [String: Any]) {
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            self.id = id
            self.name = name
        }
    }

    struct Cloud {
        let id: String
        let name: String
        let productIDs: [String]

        init?(_ dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let name = dict["name"] as? String,
                let productIDs = dict["cloudProducts"] as? [String]
            else { return nil }
            self.id = id
            self.name = name
            self.productIDs = productIDs
        }
    }

    let clouds: [Cloud]
    let productsByID: [String: Product]

    init?(_ data: Data) {
        guard let structure = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let productsDictionary = (structure["products"] as? [String: Any]) ?? [:]
        productsByID = productsDictionary.compactMapValues { ($0 as? [String: Any]).flatMap(Product.init) }

        let cloudsDictionary = (structure["clouds"] as? [String: Any]) ?? [:]
        clouds = cloudsDictionary.compactMap { ($0.value as? [String: Any]).flatMap(Cloud.init) }
    }
}

// "Creative Cloud" / "Adobe Services" -> "CreativeCloud" / "Services", matching the dispatch keys
// in AdobeServiceDefinition.build() (the typealias names in Adobe.swift, minus their "Adobe" prefix).
private func cloudKey(from rawName: String) -> String {
    var name = rawName
    if name.hasPrefix("Adobe ") {
        name.removeFirst("Adobe ".count)
    }
    return name.components(separatedBy: .whitespaces).joined()
}

private func prefixedName(_ name: String) -> String {
    name.hasPrefix("Adobe") ? name : "Adobe \(name)"
}

struct AdobeGenerator: ServiceGenerator {
    let providerKey = "adobe"

    private static let registryURL = URL(string: "https://data.status.adobe.com/adobestatus/SnowServiceRegistry")!

    func discover() async -> [DiscoveredEntry] {
        guard
            let data = await HTTPClient.get(Self.registryURL),
            let registry = AdobeRegistry(data)
        else {
            print("warning: could not retrieve list of Adobe services")
            return []
        }

        // Adobe's API can report the same display name for unrelated clouds/products; disambiguate
        // by appending the id, same as the entry ordering being fully data-driven (no fixed list).
        var seenNames = Set<String>()
        var entries: [DiscoveredEntry] = []

        for cloud in registry.clouds.sorted(by: { $0.id < $1.id }) {
            let key = cloudKey(from: cloud.name)
            if !knownClouds.contains(key) {
                print("warning: unknown Adobe cloud \"\(cloud.name)\" (\(cloud.id)) — add it to Adobe.swift")
            }

            var categoryName = prefixedName(cloud.name)
            if seenNames.contains(categoryName) {
                categoryName = "\(categoryName) (\(cloud.id))"
            }
            seenNames.insert(categoryName)

            entries.append(DiscoveredEntry(
                id: cloud.id,
                name: "\(categoryName) (All)",
                extraFields: [
                    ("cloud", .string(key)),
                    ("category", .bool(true)),
                    ("category_name", .string(categoryName))
                ]
            ))

            for productID in cloud.productIDs {
                guard let product = registry.productsByID[productID] else { continue }

                var productName = prefixedName(product.name)
                if seenNames.contains(productName) {
                    productName = "\(productName) (\(product.id))"
                }
                seenNames.insert(productName)

                entries.append(DiscoveredEntry(
                    id: product.id,
                    name: productName,
                    extraFields: [("cloud", .string(key)), ("subservice", .bool(true))]
                ))
            }
        }

        return entries
    }
}
