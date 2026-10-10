import Foundation

// Regenerates Resources/services.json from each ServiceGenerator's live data. Each provider's
// array is fully REPLACED (sorted by name), not merged — a diff should surface real upstream
// removals rather than hide them. handEditedKeys are the exception, preserved by "id" since a
// generator can't rediscover them.
final class ServicesJSONUpdater {
    private let handEditedKeys: Set<String> = ["url", "old_names", "tags"]
    // Everything else is either a fixed schema field or provider-specific "extra" data (e.g.
    // Salesforce's "product") that's part of what makes an entry unique — "id" alone isn't
    // globally unique within a provider whose entries are grouped (e.g. "NA" repeats across
    // every Salesforce product), so the match key folds in whatever extra fields are present.
    private let nonMatchKeys: Set<String> = [
        "name", "url", "id", "subservice", "category", "category_name", "old_names", "tags"
    ]

    private let servicesPath: String

    init(servicesPath: String) {
        self.servicesPath = servicesPath
    }

    func run(generators: [ServiceGenerator]) async {
        guard let originalText = try? String(contentsOfFile: servicesPath, encoding: .utf8) else {
            print("error: could not read \(servicesPath)")
            exit(1)
        }

        guard let rootValue = try? JSONParser.parse(originalText), var pairs = rootValue.objectPairs else {
            print("error: \(servicesPath) is not a valid JSON object")
            exit(1)
        }

        // Fetch every provider concurrently, then apply results in the original generators order
        // (not completion order) so output stays deterministic regardless of network timing.
        var discoveredByIndex = [[DiscoveredEntry]](repeating: [], count: generators.count)
        await withTaskGroup(of: (Int, [DiscoveredEntry]).self) { group in
            for (index, generator) in generators.enumerated() {
                group.addTask { (index, await generator.discover()) }
            }
            for await (index, entries) in group {
                discoveredByIndex[index] = entries
            }
        }

        for (index, generator) in generators.enumerated() {
            let discovered = discoveredByIndex[index]

            guard !discovered.isEmpty else {
                print("warning: no entries discovered for \"\(generator.providerKey)\", leaving it untouched")
                continue
            }

            let existing = pairs.first(where: { $0.0 == generator.providerKey })?.1.arrayItems ?? []
            let updated = buildArray(discovered: discovered, existing: existing)

            if let index = pairs.firstIndex(where: { $0.0 == generator.providerKey }) {
                pairs[index] = (generator.providerKey, .array(updated))
            } else {
                // Insert new provider keys right before "_removed", to match the existing file's convention.
                let insertionIndex = pairs.firstIndex(where: { $0.0 == "_removed" }) ?? pairs.count
                pairs.insert((generator.providerKey, .array(updated)), at: insertionIndex)
            }

            print("Updated \"\(generator.providerKey)\": \(discovered.count) entries discovered.")
        }

        let output = serialize(.object(pairs)) + "\n"

        guard output != originalText else {
            print("services.json unchanged.")
            return
        }

        do {
            try output.write(toFile: servicesPath, atomically: true, encoding: .utf8)
            print("Wrote \(servicesPath)")
        } catch {
            print("error: could not write \(servicesPath): \(error.localizedDescription)")
            exit(1)
        }
    }

    private func matchKey(id: String, otherFields: [(String, JSONValue)]) -> String {
        let extras = otherFields
            .filter { !nonMatchKeys.contains($0.0) }
            .sorted { $0.0 < $1.0 }
            .compactMap { $0.1.stringValue }
        return ([id] + extras).joined(separator: "\u{1}")
    }

    private func buildArray(discovered: [DiscoveredEntry], existing: [JSONValue]) -> [JSONValue] {
        var preservedFieldsByKey: [String: [(String, JSONValue)]] = [:]
        for entry in existing {
            guard
                let pairs = entry.objectPairs,
                let id = pairs.first(where: { $0.0 == "id" })?.1.stringValue
            else { continue }

            let preserved = pairs.filter { handEditedKeys.contains($0.0) }
            if !preserved.isEmpty {
                preservedFieldsByKey[matchKey(id: id, otherFields: pairs)] = preserved
            }
        }

        return discovered
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { entry in
                let key = matchKey(id: entry.id, otherFields: entry.extraFields)
                var pairs: [(String, JSONValue)] = [("name", .string(entry.name))]
                // Field order matches the rest of the file: name, url, id, extras, old_names, tags.
                if let url = preservedFieldsByKey[key]?.first(where: { $0.0 == "url" }) {
                    pairs.append(url)
                }
                pairs.append(("id", .string(entry.id)))
                pairs.append(contentsOf: entry.extraFields)
                if let oldNames = preservedFieldsByKey[key]?.first(where: { $0.0 == "old_names" }) {
                    pairs.append(oldNames)
                }
                if let tags = preservedFieldsByKey[key]?.first(where: { $0.0 == "tags" }) {
                    pairs.append(tags)
                }
                return .object(pairs)
            }
    }
}
