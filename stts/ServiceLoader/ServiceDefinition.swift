//
//  ServiceDefinition.swift
//  stts
//

import Foundation

protocol ServiceDefinition: CodableServiceDefinition {
    /// Identifier of the provider of the status page (e.g. statuspage, statuspal, cachet, instatus, etc.)
    /// For use in local storage.
    var providerIdentifier: String { get }

    /// Identifier for this service for use in local storage.
    /// This is how it was stored before switching to JSON definitions
    var legacyIdentifiers: Set<String> { get }

    /// Identifier for this service for use in local storage.
    var globalIdentifier: String { get }

    /// Builds the service object from the definition.
    func build() -> BaseService?

    /// Whether this build can actually run this service. False only for a definition whose
    /// behaviour isn't compiled into this app — see `IndependentServiceDefinition.isSupported`.
    /// Unsupported definitions are dropped by `ServiceLoader`, so nothing downstream sees them.
    var isSupported: Bool { get }

    /// Shared grouping value between a category row (`isCategory == true`) and its subservices
    /// (`isSubService == true`) within the same provider, so Preferences can group them by data
    /// instead of Swift type. nil for providers still using `ServiceCategory.subServiceSuperclass`
    /// (a single fixed category per provider, which never needs a second data-driven group).
    var categoryKey: String? { get }
}

// Repo this app ships from — used only as a last-resort favicon source below, hardcoded since
// there's no other way for the app to know its own repo.
private let faviconRepoRawBaseURL = "https://cdn.jsdelivr.net/gh/inket/stts@master/Resources/Favicons"

extension ServiceDefinition {
    var categoryKey: String? { nil }

    /// `name` with a trailing " (All)" removed, for the expandable category header — the row that
    /// actually toggles every subservice at once keeps the full "(All)" name.
    var categoryDisplayName: String {
        name.hasSuffix(" (All)") ? String(name.dropLast(" (All)".count)) : name
    }

    var isSupported: Bool { true }

    var globalIdentifier: String { "\(providerIdentifier).\(alphanumericName)" }

    /// The service's favicon. Checks the app bundle first — see `Scripts/generators/Sources/
    /// UpdateServicesJSON/FaviconDownloader.swift` for how `Resources/Favicons/*.png` gets
    /// populated — falling back to fetching the same filename from this repo on GitHub (via
    /// jsdelivr) as a last resort, in case a favicon was added/fixed there after this copy of the
    /// app was built. That fallback is a *URL construction only* — it's never verified to resolve,
    /// so the caller must handle a load failure the same as it would a missing local icon.
    /// `nil` only for a service with no `services.json` entry at all (a hand-written `independent`
    /// class) — every JSON-defined service gets at least the remote-fallback candidate.
    var faviconURL: URL? {
        if let url = bundledFaviconURL(filename: "\(providerIdentifier).\(alphanumericName)") {
            return url
        }
        // A rename or a provider reassignment (e.g. a remote services.json update moving a service
        // from one provider to another) makes the current filename stale until the next app
        // update ships the correspondingly-renamed bundled file — try the identifiers this service
        // used to be known under too, the same data `old_names` already exists to carry.
        for legacyIdentifier in legacyIdentifiers {
            if let url = bundledFaviconURL(filename: legacyIdentifier) {
                return url
            }
        }
        // A handful of products within a shared-page provider (e.g. Salesforce's Heroku/Tableau/
        // Mulesoft) have their own distinct real-world branding, so they get their own shared icon
        // instead of the provider's generic one — see FaviconDownloader.officialWebsiteByProduct.
        if let categoryKey {
            let sanitized = String(categoryKey.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
            if let url = bundledFaviconURL(filename: "\(providerIdentifier).\(sanitized)") {
                return url
            }
        }
        // Providers whose entries all share one status page (Azure, AWS, Adobe, ...) get a single
        // shared icon at "<providerIdentifier>.png" instead of a byte-identical copy per entry.
        if let url = bundledFaviconURL(filename: providerIdentifier) {
            return url
        }

        return URL(string: "\(faviconRepoRawBaseURL)/\(providerIdentifier).\(alphanumericName).png")
    }

    private func bundledFaviconURL(filename: String) -> URL? {
        Bundle.main.url(forResource: filename, withExtension: "png", subdirectory: "Favicons")
    }

    func eq(_ other: ServiceDefinition) -> Bool {
        globalIdentifier == other.globalIdentifier
    }
}

let ServiceDefinitionSortByName: (ServiceDefinition, ServiceDefinition) -> Bool = { a, b in
    a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
}

class CodableServiceDefinition: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case isCategory = "category"
        case isSubService = "subservice"
        case oldNames = "old_names"
    }

    let name: String
    let url: URL
    let isCategory: Bool?
    let isSubService: Bool?
    let oldNames: Set<String>?

    private(set) lazy var legacyIdentifiers = oldNames ?? .init()

    var alphanumericName: String {
        String(name.unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    init(name: String, url: URL, isCategory: Bool?, isSubService: Bool?, oldNames: Set<String>? = nil) {
        assert(type(of: self) != CodableServiceDefinition.self)

        self.oldNames = oldNames
        self.name = name
        self.isCategory = isCategory
        self.isSubService = isSubService
        self.url = url
    }

    required init(from decoder: Decoder) throws {
        assert(type(of: self) != CodableServiceDefinition.self)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.url = try container.decode(URL.self, forKey: .url)
        self.isCategory = try container.decodeIfPresent(Bool.self, forKey: .isCategory)
        self.isSubService = try container.decodeIfPresent(Bool.self, forKey: .isSubService)
        self.oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.url, forKey: .url)
        try container.encodeIfPresent(self.isCategory, forKey: .isCategory)
        try container.encodeIfPresent(self.isSubService, forKey: .isSubService)
        try container.encodeIfPresent(self.oldNames, forKey: .oldNames)
    }
}
