//
//  ServiceTag.swift
//  stts
//

import Foundation

/// A category from services.json's `"_tags"`, which entries name in their `"tags"`.
struct ServiceTag: Hashable {
    /// The `"_tags"` key, and what entries' `"tags"` list.
    let id: String
    let name: String
    /// An SF Symbol name.
    let symbol: String

    /// The JSON value under each `"_tags"` key; the key itself becomes `id`.
    struct Body: Codable {
        let name: String
        let symbol: String
    }

    /// Sorted by name, so the vocabulary has one order whatever the JSON object's key order.
    static func tags(from bodies: [String: Body]) -> [ServiceTag] {
        bodies
            .map { ServiceTag(id: $0.key, name: $0.value.name, symbol: $0.value.symbol) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
