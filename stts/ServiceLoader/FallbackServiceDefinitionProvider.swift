//
//  FallbackServiceDefinitionProvider.swift
//  stts
//

import Foundation

/// Wraps two providers so `primary`'s data, when non-empty, is used *exclusively* — `fallback`'s
/// data is not merged in alongside it. `fallback` only kicks in when `primary` has nothing to offer
/// (not yet fetched, or a decode failure).
///
/// This is deliberately a whole-sale swap rather than a per-identifier merge: `ServiceLoader`
/// unions identifiers across all of its providers, so a plain union of `primary`/`fallback` would
/// let a service `primary` no longer lists still leak back in from `fallback` — see
/// `RemoteServiceDefinitionProvider`, where that would mean a service removed from the
/// remote-fetched services.json still showing up because the older bundled copy still has it.
final class FallbackServiceDefinitionProvider: ServiceDefinitionProvider {
    private let primary: ServiceDefinitionProvider
    private let fallback: ServiceDefinitionProvider

    init(primary: ServiceDefinitionProvider, fallback: ServiceDefinitionProvider) {
        self.primary = primary
        self.fallback = fallback
    }

    func definedServices() throws -> [ServiceDefinition]? {
        if let primaryDefinitions = try primary.definedServices(), !primaryDefinitions.isEmpty {
            return primaryDefinitions
        }
        return try fallback.definedServices()
    }

    /// Only the currently-active source's removals apply — mixing `primary`'s removals in while
    /// `fallback` is actually driving the catalog (or vice versa) could prune a user's preference
    /// for a service the active source never even mentioned removing.
    var removedIdentifiers: Set<String> {
        if let primaryDefinitions = try? primary.definedServices(), !primaryDefinitions.isEmpty {
            return primary.removedIdentifiers
        }
        return fallback.removedIdentifiers
    }

    /// The active source's vocabulary, for the same reason as `removedIdentifiers`: it's the one
    /// its own entries' tags were written against.
    var tags: [ServiceTag] {
        if let primaryDefinitions = try? primary.definedServices(), !primaryDefinitions.isEmpty {
            return primary.tags
        }
        return fallback.tags
    }

    func reload() {
        primary.reload()
        fallback.reload()
    }
}
