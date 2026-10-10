#!/usr/bin/swift

import AppKit
import Foundation

// Keep this in sync with ServicesStructure.CodingKeys (stts/ServiceLoader/ServicesStructure.swift).
let knownProviders: Set<String> = [
    "independent", "cachet", "lamb", "sorry", "statuscake", "statuspage", "instatus",
    "statuscast", "incidentio", "statusiov1", "statuspal", "site24x7", "cstate",
    "statushub", "betteruptime", "betterstack", "sendbird", "miro", "pagerduty",
    "azure", "azuredevops", "firebase", "salesforce", "adobe", "apple", "appledeveloper",
    "googlecloudplatform", "awsregions", "awsservices"
]

// Not a provider: a flat array of identifier strings for services confirmed gone for good (company
// shut down/bankrupt, product discontinued) — NOT services that are just currently unreachable/broken
// for a company that's still operating (those might get a working integration again later, so they
// must not be listed here).
let removedServicesKey = "_removed"

// The one provider whose entries name a Swift class instead of describing a status page — see
// IndependentServiceDefinition.
let independentProvider = "independent"

// Providers that don't require "url" per entry — either a fixed commonURL with an optional
// per-entry override (Azure, Azure DevOps, Firebase), or a url computed from other fields and
// never stored at all (Salesforce, from "product"). See each provider's *ServiceDefinition.
let providersWithOptionalURL: Set<String> = [
    "azure", "azuredevops", "firebase", "salesforce", "adobe", "apple", "appledeveloper",
    "googlecloudplatform", "awsregions", "awsservices"
]

// Providers with data-driven categories (see ServiceDefinition.categoryKey): the JSON field that
// carries the shared grouping value between a "category": true row and its "subservice": true
// children. Keep in sync with each provider's *ServiceDefinition.categoryKey in stts/Services/Super/.
let categoryKeyFieldByProvider: [String: String] = [
    "salesforce": "product",
    "adobe": "cloud"
]

// Not a provider: the category vocabulary, as {"<id>": {"name": ..., "symbol": <SF Symbol>}}.
let tagsKey = "_tags"
// Filled from "_tags" before any entry is linted.
var knownTags = Set<String>()
let maxTagsPerEntry = 3

// Providers whose definitions are always sub-services, grouped under their "(All)" row by Swift
// type, so their entries carry no "subservice" key. Keep in sync with each provider's
// *ServiceDefinition (they pass `isSubService: true` unconditionally).
let subServiceOnlyProviders: Set<String> = [
    "apple", "appledeveloper", "googlecloudplatform", "azure", "azuredevops", "firebase"
]

// Vendor rows deliberately left untagged because each of their sub-services carries its own tags,
// as "provider.name". Every other row that isn't a
// sub-service must be tagged; listing a vendor here is the decision that it isn't.
let perProductVendorRows: Set<String> = [
    "independent.Apple (All)"
]

func envVariable(forKey key: String) -> String {
    guard let variable = ProcessInfo.processInfo.environment[key] else {
        print("error: Environment variable '\(key)' not set")
        exit(1)
    }

    return variable
}

var errors: [String] = []

func fail(_ message: String) {
    errors.append(message)
}

func lintEntry(provider: String, entry: Any, index: Int, seenIdentifiers: inout Set<String>) {
    guard let entry = entry as? [String: Any] else {
        fail("\(provider)[\(index)] is not an object")
        return
    }

    guard let name = entry["name"] as? String, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
        fail("\(provider)[\(index)] is missing a non-empty \"name\"")
        return
    }

    if let urlValue = entry["url"] {
        guard let urlString = urlValue as? String,
              let url = URL(string: urlString),
              let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            fail("\(provider).\(name) has an invalid \"url\"")
            return
        }
    } else if !providersWithOptionalURL.contains(provider) {
        fail("\(provider).\(name) has a missing or invalid \"url\"")
        return
    }

    let normalizedName = String(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains)).lowercased()
    let identifier = "\(provider).\(normalizedName)"
    if seenIdentifiers.contains(identifier) {
        fail("\(provider).\(name) is a duplicate (same provider + name already defined)")
    }
    seenIdentifiers.insert(identifier)

    if let oldNames = entry["old_names"], !(oldNames is [String]) {
        fail("\(provider).\(name) has \"old_names\" that isn't an array of strings")
    }

    for key in ["category", "subservice"] {
        if let value = entry[key], !(value is Bool) {
            fail("\(provider).\(name) has \"\(key)\" that isn't a boolean")
        }
    }

    lintCategoryName(provider: provider, name: name, entry: entry)
    lintTags(provider: provider, name: name, entry: entry)
}

func lintTags(provider: String, name: String, entry: [String: Any]) {
    let isSubService = subServiceOnlyProviders.contains(provider)
        || (entry["subservice"] as? Bool == true && entry["category"] as? Bool != true)

    guard let value = entry["tags"] else {
        if !isSubService && !perProductVendorRows.contains("\(provider).\(name)") {
            fail("\(provider).\(name) has no \"tags\"")
        }
        return
    }

    guard let tags = value as? [String], !tags.isEmpty else {
        fail("\(provider).\(name) has \"tags\" that isn't a non-empty array of strings")
        return
    }
    if perProductVendorRows.contains("\(provider).\(name)") {
        fail("\(provider).\(name) is a per-product vendor row, so its sub-services carry the tags instead")
    }
    if tags.count > maxTagsPerEntry {
        fail("\(provider).\(name) has \(tags.count) tags (at most \(maxTagsPerEntry))")
    }
    if Set(tags).count != tags.count {
        fail("\(provider).\(name) has duplicate tags")
    }
    for tag in tags where !knownTags.contains(tag) {
        fail("\(provider).\(name) has tag \"\(tag)\", which \"\(tagsKey)\" doesn't define")
    }
}

// "category_name" is the header label shown above a category's subservices (the row itself keeps
// the full "name", e.g. "Azure (All Regions)"), so it's required on every category and meaningless
// anywhere else.
func lintCategoryName(provider: String, name: String, entry: [String: Any]) {
    let categoryName = entry["category_name"]
    if entry["category"] as? Bool == true {
        if (categoryName as? String)?.isEmpty ?? true {
            fail("\(provider).\(name) is a category but is missing a non-empty \"category_name\"")
        }
    } else if categoryName != nil {
        fail("\(provider).\(name) has \"category_name\" but isn't a category")
    }
}

// The services.plist that used to list these classes was generated by globbing the same files, so
// this check preserves exactly the guarantee that removing it gave up: a new Swift service that
// nobody added to services.json would otherwise silently not exist.
func lintIndependentClassCoverage(srcRoot: String, entries: [Any]) {
    let servicesRoot = "\(srcRoot)/stts/Services"
    guard let enumerator = FileManager.default.enumerator(atPath: servicesRoot) else {
        fail("Could not read \(servicesRoot) to check \"\(independentProvider)\" coverage")
        return
    }

    var classNamesOnDisk = Set<String>()
    for case let relativePath as String in enumerator {
        guard relativePath.hasSuffix(".swift") else { continue }
        // Super/ holds the base classes and the generic definition-driven services (AppleGeneric,
        // AdobeSubService, ...) — those belong to other providers, not to "independent".
        guard !relativePath.hasPrefix("Super/") else { continue }

        classNamesOnDisk.insert((relativePath as NSString).lastPathComponent.replacingOccurrences(
            of: ".swift", with: ""
        ))
    }

    // An "independent" entry only supplies identity — the behaviour lives in the Swift class it
    // names. IndependentServiceDefinition treats "class_name" as optional and falls back to the
    // name with non-alphanumerics stripped, but that fallback is wrong for any service whose
    // display name isn't its class name ("Firebase (All)" -> Firebase, "jsDelivr" -> JSDelivr,
    // "Uptime.com" -> UptimeDotCom, PayPal, PSN...) and fails silently, so require it.
    var classNamesInJSON = Set<String>()
    for entry in entries {
        guard let entry = entry as? [String: Any] else { continue }

        let name = entry["name"] as? String ?? "<unnamed>"
        guard let className = entry["class_name"] as? String,
              !className.trimmingCharacters(in: .whitespaces).isEmpty else {
            fail("\(independentProvider).\(name) is missing a non-empty \"class_name\"")
            continue
        }

        classNamesInJSON.insert(className)
    }

    for className in classNamesOnDisk.subtracting(classNamesInJSON).sorted() {
        fail("""
        stts/Services/\(className).swift has no \"\(independentProvider)\" entry in services.json \
        (add one with \"class_name\": \"\(className)\", or the service won't exist in the app)
        """)
    }

    for className in classNamesInJSON.subtracting(classNamesOnDisk).sorted() {
        fail("""
        \(independentProvider) entry names \"class_name\": \"\(className)\" but there is no \
        stts/Services/\(className).swift — typo, or the class was removed without its entry?
        """)
    }
}

// Foundation's JSONSerialization (used both here and by the app) tolerates trailing commas before
// a closing ] or }, even though they're invalid per the JSON spec. That's harmless for the app, but
// flag it anyway as a warning: it can trip up stricter tools (jq, other language's JSON parsers) and
// is usually just a leftover from editing.
func warnAboutTrailingCommas(in text: String) {
    // swiftlint:disable:next force_try
    let regex = try! NSRegularExpression(pattern: ",\\s*[\\]}]", options: [])
    let range = NSRange(text.startIndex..., in: text)

    regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
        guard let match, let matchRange = Range(match.range, in: text) else { return }

        let line = text[..<matchRange.lowerBound].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
        print("warning: services.json:\(line): trailing comma before a closing bracket")
    }
}

func lintCategoryKeys(provider: String, entries: [Any]) {
    guard let field = categoryKeyFieldByProvider[provider] else { return }

    var categoryKeys = Set<String>()
    var duplicateCategoryKeys = Set<String>()
    var subServiceKeys = Set<String>()

    for entry in entries {
        guard let entry = entry as? [String: Any], let key = entry[field] as? String else { continue }

        if entry["category"] as? Bool == true {
            if !categoryKeys.insert(key).inserted {
                duplicateCategoryKeys.insert(key)
            }
        } else if entry["subservice"] as? Bool == true {
            subServiceKeys.insert(key)
        }
    }

    for key in duplicateCategoryKeys.sorted() {
        fail("\(provider) has more than one \"category\": true entry with \"\(field)\" == \"\(key)\"")
    }

    for key in subServiceKeys.subtracting(categoryKeys).sorted() {
        fail("\(provider) has a \"subservice\": true entry with \"\(field)\" == \"\(key)\" but no matching \"category\": true entry")
    }

    lintInheritedTags(provider: provider, field: field, entries: entries)
}

// A tagged vendor row passes its tags to its sub-services, so tags on both would be two sources of
// truth for the same rows.
func lintInheritedTags(provider: String, field: String, entries: [Any]) {
    let objects = entries.compactMap { $0 as? [String: Any] }
    let taggedCategoryKeys = Set(objects.compactMap { entry -> String? in
        guard entry["category"] as? Bool == true, entry["tags"] != nil else { return nil }
        return entry[field] as? String
    })

    for entry in objects where entry["subservice"] as? Bool == true && entry["tags"] != nil {
        guard let key = entry[field] as? String, taggedCategoryKeys.contains(key) else { continue }
        let name = entry["name"] as? String ?? "<unnamed>"
        fail("\(provider).\(name) has \"tags\" but its vendor row is tagged too (sub-services inherit)")
    }
}

func lintTagVocabulary(_ value: Any?) -> Set<String> {
    guard let value else {
        fail("\"\(tagsKey)\" is missing, so no entry's \"tags\" can be valid")
        return []
    }
    guard let vocabulary = value as? [String: Any] else {
        fail("\"\(tagsKey)\" must be an object")
        return []
    }

    var names = Set<String>()
    for (id, body) in vocabulary {
        guard id.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil else {
            fail("\(tagsKey).\(id) must be lowercase letters, digits and hyphens")
            continue
        }
        guard let body = body as? [String: Any],
              let name = body["name"] as? String, !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let symbol = body["symbol"] as? String, !symbol.isEmpty else {
            fail("\(tagsKey).\(id) must be an object with non-empty \"name\" and \"symbol\" strings")
            continue
        }
        if !names.insert(name).inserted {
            fail("\(tagsKey).\(id) reuses the name \"\(name)\"")
        }
        // The app draws nothing for a symbol this macOS doesn't have, so catch typos here.
        if NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil {
            fail("\(tagsKey).\(id) has \"symbol\": \"\(symbol)\", which isn't an SF Symbol on this Mac")
        }
    }
    return Set(vocabulary.keys)
}

func lintRemovedServices(_ value: Any) {
    guard let identifiers = value as? [Any] else {
        fail("\"\(removedServicesKey)\" must be an array")
        return
    }

    for (index, identifier) in identifiers.enumerated() {
        guard let identifier = identifier as? String, !identifier.trimmingCharacters(in: .whitespaces).isEmpty else {
            fail("\(removedServicesKey)[\(index)] must be a non-empty string")
            continue
        }
    }
}

func lintTopLevelKey(_ key: String, value: Any, srcRoot: String) {
    if key == removedServicesKey {
        lintRemovedServices(value)
        return
    }
    if key == tagsKey {
        return // linted up front, see main()
    }

    guard knownProviders.contains(key) else {
        fail("Unknown top-level provider key \"\(key)\" (typo? not declared in ServicesStructure.CodingKeys)")
        return
    }

    guard let entries = value as? [Any] else {
        fail("\"\(key)\" must be an array")
        return
    }

    var seenIdentifiers = Set<String>()
    for (index, entry) in entries.enumerated() {
        lintEntry(provider: key, entry: entry, index: index, seenIdentifiers: &seenIdentifiers)
    }

    lintCategoryKeys(provider: key, entries: entries)

    if key == independentProvider {
        lintIndependentClassCoverage(srcRoot: srcRoot, entries: entries)
    }
}

func main() {
    let srcRoot = envVariable(forKey: "SRCROOT")
    let path = "\(srcRoot)/Resources/services.json"

    guard let data = FileManager.default.contents(atPath: path) else {
        print("error: Could not read \(path)")
        exit(1)
    }

    if let text = String(data: data, encoding: .utf8) {
        warnAboutTrailingCommas(in: text)
    }

    let json: Any
    do {
        json = try JSONSerialization.jsonObject(with: data, options: [])
    } catch {
        print("error: services.json is not valid JSON: \(error.localizedDescription)")
        exit(1)
    }

    guard let root = json as? [String: Any] else {
        print("error: services.json's top level must be an object")
        exit(1)
    }

    knownTags = lintTagVocabulary(root[tagsKey])

    for (key, value) in root {
        lintTopLevelKey(key, value: value, srcRoot: srcRoot)
    }

    // A missing key would otherwise skip the coverage check entirely and silently drop every
    // hand-written service.
    if root[independentProvider] == nil {
        lintIndependentClassCoverage(srcRoot: srcRoot, entries: [])
    }

    if !errors.isEmpty {
        errors.sorted().forEach { print("error: services.json: \($0)") }
        exit(1)
    }

    print("services.json OK.")
}

main()
