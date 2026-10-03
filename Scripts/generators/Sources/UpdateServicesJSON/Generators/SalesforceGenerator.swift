import Foundation

// Category rows (one "(All Regions)" entry per product, "category": true) are synthesized here
// alongside the region-level entries — both are fully data-driven via SalesforceServiceDefinition.categoryKey,
// no hand-written Swift classes needed per product anymore. Keep `productDisplayNames` covering every
// product Salesforce reports; an unfamiliar product still gets written to services.json (so the diff
// surfaces it) using its raw API key as a fallback display name.
private let productDisplayNames: [String: String] = [
    "B2C_Commerce_Cloud": "Salesforce B2C Commerce Cloud",
    "Community_Cloud": "Salesforce Experience Cloud",
    "Datorama": "Datorama",
    "Heroku": "Heroku",
    "Marketing_Cloud": "Salesforce Marketing Cloud",
    "MCAccountEngagement": "MC Account Engagement",
    "MCPersonalization": "MC Personalization",
    "Mulesoft": "Mulesoft",
    "Point_of_Sale": "Point of Sale",
    "Salesforce_Services": "Salesforce Services",
    "Social_Studio": "Salesforce Social Studio",
    "Spiff": "Spiff",
    "Tableau": "Tableau"
]

private struct SalesforceInstance: Codable {
    enum CodingKeys: String, CodingKey {
        case location
        case products = "Products"
    }

    struct Product: Codable {
        let key: String
    }

    let location: String
    let products: [Product]
}

struct SalesforceGenerator: ServiceGenerator {
    let providerKey = "salesforce"

    func discover() async -> [DiscoveredEntry] {
        guard
            let data = await HTTPClient.get(
                URL(string: "https://api.status.salesforce.com/v1/instances?childProducts=false")!
            ),
            let instances = try? JSONDecoder().decode([SalesforceInstance].self, from: data)
        else {
            print("warning: could not retrieve list of Salesforce products")
            return []
        }

        var regionsByProduct: [String: Set<String>] = [:]
        for instance in instances {
            guard let product = instance.products.first else { continue }
            regionsByProduct[product.key, default: []].insert(instance.location)
        }

        var entries: [DiscoveredEntry] = []
        for (product, regions) in regionsByProduct.sorted(by: { $0.key < $1.key }) {
            let displayName = productDisplayNames[product] ?? product

            entries.append(DiscoveredEntry(
                id: product,
                name: "\(displayName) (All Regions)",
                extraFields: [
                    ("product", .string(product)),
                    ("category", .bool(true)),
                    ("category_name", .string(displayName)),
                ]
            ))

            for region in regions.sorted() {
                entries.append(DiscoveredEntry(
                    id: region,
                    name: "\(displayName) (\(region))",
                    extraFields: [("product", .string(product)), ("subservice", .bool(true))]
                ))
            }
        }

        return entries
    }
}
