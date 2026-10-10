//
//  Firebase.swift
//  stts
//

import Foundation

typealias FirebaseService = BaseFirebaseService & RequiredServiceProperties & RequiredFirebaseProperties

protocol RequiredFirebaseProperties: FirebaseStatusDashboardStoreService {
    var name: String { get }
    var dashboardName: String { get }
}

extension RequiredFirebaseProperties {
    var dashboardName: String {
        let prefix = "Firebase "

        guard let prefixRange = name.range(of: prefix), prefixRange.lowerBound.utf16Offset(in: name) == 0 else {
            return name
        }

        return name.replacingCharacters(in: prefixRange, with: "")
    }
}

class BaseFirebaseService: BaseIndependentService {
    private static var store = FirebaseStatusDashboardStore(url: FirebaseServiceDefinition.commonURL)

    override func updateStatus() async throws {
        guard let realSelf = self as? FirebaseService else {
            fatalError("BaseFirebaseService should not be used directly.")
        }

        statusDescription = try await BaseFirebaseService.store.updatedStatus(for: realSelf)
    }
}

class FirebaseServiceDefinition: CodableServiceDefinition, ServiceDefinition {
    static let commonURL = URL(string: "https://status.firebase.google.com")!

    enum ExtraKeys: String, CodingKey {
        case id
        case name
        case url
        case oldNames = "old_names"
    }

    let id: String
    let providerIdentifier = "firebase"

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ExtraKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let url = try container.decodeIfPresent(URL.self, forKey: .url) ?? Self.commonURL
        let oldNames = try container.decodeIfPresent(Set<String>.self, forKey: .oldNames)
        let tags = try CodableServiceDefinition.decodeTags(from: decoder)

        super.init(name: name, url: url, isCategory: nil, isSubService: true, oldNames: oldNames, tags: tags)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: ExtraKeys.self)
        try container.encode(id, forKey: .id)
    }

    func build() -> BaseService? {
        FirebaseSubService(self)
    }
}

final class FirebaseSubService: FirebaseService, SubService {
    let name: String
    let url: URL
    let dashboardName: String

    init(_ definition: FirebaseServiceDefinition) {
        name = definition.name
        url = definition.url
        dashboardName = definition.id
        super.init()
    }

    required init() {
        fatalError("FirebaseSubService must be initialized with a definition")
    }
}
