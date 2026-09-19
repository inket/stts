//
//  PopupViewModel.swift
//  stts
//

import SwiftUI

/// Display state for the popup, derived from the live `BaseService` list.
///
/// The services themselves carry a flat `ServiceStatus`; the design splits them into two groups —
/// everything needing attention (including services that couldn't be reached) in one list, and
/// everything operational collapsed into a single roster row — so that bucketing lives here rather
/// than being re-derived by each view.
@MainActor
final class PopupViewModel: ObservableObject {
    // MARK: - Item types

    /// Why a service appears in the affected list. Drives its corner dot's colour and its place in
    /// the sort order.
    enum Kind {
        case major
        case minor
        case maintenance
        /// Couldn't be determined — grey, and explicitly *not* "down".
        case unknown

        var dotColor: NSColor {
            switch self {
            case .major: return PopupLayout.Colors.dotMajor
            case .minor: return PopupLayout.Colors.dotMinor
            case .maintenance: return PopupLayout.Colors.dotMaintenance
            case .unknown: return PopupLayout.Colors.dotUnknown
            }
        }

        /// Whether this counts toward the crown's "N services affected". Unknown doesn't — nothing
        /// was actually reported broken.
        var isIncident: Bool { self != .unknown }
    }

    /// Presentation form of `UndeterminedReason`, used as an unknown row's message.
    enum UnknownReason {
        case noAnswer
        case unreadable

        init(_ reason: UndeterminedReason?) {
            switch reason {
            case .noAnswer, .none: self = .noAnswer
            case .unreadable: self = .unreadable
            }
        }

        var message: String {
            switch self {
            case .noAnswer: return "No answer from the status page"
            case .unreadable: return "Status page couldn't be read"
            }
        }
    }

    struct AffectedItem: Identifiable {
        let id: String
        let name: String
        let message: String
        let kind: Kind
        let url: URL

        /// `ServiceDefinition.globalIdentifier`, used to look up and cache the service's favicon.
        var faviconIdentifier: String?
        var faviconURL: URL?

        var dotColor: NSColor { kind.dotColor }

        /// `message` with its newlines swapped for U+2028 LINE SEPARATOR, which is what the row
        /// actually renders.
        ///
        /// Providers return one line per open incident, and each stays on its own line here. The
        /// swap is what gets an ellipsis drawn when there are more of them than the row shows:
        /// U+000A ends a *paragraph*, and SwiftUI only marks a truncation when the last visible line
        /// is itself cut short — a limit landing on a paragraph break just stops, dropping the
        /// remaining incidents silently. U+2028 breaks the line without ending the paragraph, so the
        /// whole message is one paragraph that happens to break where the provider broke it, and any
        /// overflow is marked.
        var displayMessage: String {
            message
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: "\u{2028}")
        }
    }

    struct RosterItem: Identifiable {
        let id: String
        let name: String
        let url: URL
        var faviconIdentifier: String?
        var faviconURL: URL?
    }

    /// Whether a refresh is in flight, and how far along it is.
    enum CheckState: Equatable {
        case idle
        case checking(completed: Int, total: Int)

        var isChecking: Bool {
            if case .checking = self { return true }
            return false
        }
    }

    // MARK: - Published state

    /// Everything needing attention — incidents first (major → minor → maintenance), then services
    /// that couldn't be determined. One list, because the design renders them as one group.
    @Published private(set) var affected: [AffectedItem] = []
    @Published private(set) var roster: [RosterItem] = []
    @Published private(set) var checkState: CheckState = .idle
    @Published private(set) var lastUpdated: Date?

    /// When at least one service last reported an actual status.
    ///
    /// Distinct from `lastUpdated`, which advances even when every request failed. The
    /// "No connection" state reports this instead, so it doesn't claim to have "checked" a moment
    /// ago when what actually happened is that nothing answered.
    @Published private(set) var lastSuccessfulUpdate: Date?

    /// Deliberately *not* persisted, and reset on every open: the design says collapsed is the
    /// default every time, since the roster is the least urgent thing in the panel.
    @Published var rosterExpanded = false

    /// One of six phrases, picked once per popup *open* — not per refresh, or the copy would
    /// flicker while it's being read.
    @Published private(set) var allClearHeadline: String = allClearHeadlines.randomElement()!

    init() {}

    /// Called when the popup is about to appear: re-roll the headline and collapse the roster.
    func prepareForOpen() {
        allClearHeadline = Self.allClearHeadlines.randomElement()!
        rosterExpanded = false
    }

    private static let allClearHeadlines = [
        "All clear", "All green", "All good", "All systems go", "Looking good"
    ]

    // MARK: - Derived state

    /// No services are enabled at all — distinct from "every service failed to answer".
    var hasNoSelectedServices: Bool {
        affected.isEmpty && roster.isEmpty
    }

    /// Every enabled service failed to report. The design replaces the whole verdict with a
    /// "No connection" state in this case rather than claiming everything is unknown.
    var isFullyUnreachable: Bool {
        !affected.isEmpty && affected.allSatisfy { $0.kind == .unknown } && roster.isEmpty
    }

    /// Nothing wrong, nothing unknown — every enabled service reported operational.
    var isAllClear: Bool {
        affected.isEmpty && !roster.isEmpty
    }

    /// Whether the header renders as the design's colour band, vs. the plain text verdict carried
    /// over from the earlier design.
    ///
    /// The plain verdict remains for the states the design doesn't cover — "no connection" and "no
    /// services selected" — and for one case it leaves genuinely ambiguous: some services unknown
    /// but none actually reporting a problem. The all-clear subtitle asserts "ALL N REPORTING NO
    /// ISSUES", which wouldn't be true with unknowns in the mix, and there's no colour in the
    /// palette for "mostly fine, a few unreachable".
    var usesCrownHeader: Bool {
        !hasNoSelectedServices && !isFullyUnreachable && (affectedCount > 0 || isAllClear)
    }

    /// What the crown counts: services actually reporting a problem. Unknowns are listed and
    /// appear in the legend, but don't inflate this.
    var affectedCount: Int { affected.filter { $0.kind.isIncident }.count }
    var unknownCount: Int { affected.filter { $0.kind == .unknown }.count }
    var operationalCount: Int { roster.count }
    var totalCount: Int { affected.count + roster.count }

    var majorCount: Int { affected.filter { $0.kind == .major }.count }
    var minorCount: Int { affected.filter { $0.kind == .minor }.count }
    var maintenanceCount: Int { affected.filter { $0.kind == .maintenance }.count }

    /// The worst incident's kind, i.e. what sets the crown band's colour. `nil` when there are no
    /// incidents (the all-clear case, which uses green regardless).
    var worstIncidentKind: Kind? {
        // `affected` is already sorted major → minor → maintenance → unknown.
        affected.first { $0.kind.isIncident }?.kind
    }

    /// Single worst state across every service, for the menu bar tick.
    ///
    /// Unknown ranks below maintenance deliberately: grey means "couldn't be determined", which is
    /// less alarming than a reported problem, and it must not read as "down".
    var aggregateStatus: ServiceStatus {
        if majorCount > 0 { return .major }
        if minorCount > 0 { return .minor }
        if maintenanceCount > 0 { return .maintenance }
        if unknownCount > 0 { return .undetermined }

        return .good
    }

    // MARK: - Updating

    /// Rebuilds every bucket from the current service list. Sort order is major → minor →
    /// maintenance → unknown → operational, alphabetical within each group.
    func update(
        services: [(definition: ServiceDefinition?, service: BaseService)],
        servicesBeingUpdated: Set<BaseService>,
        lastUpdated: Date?,
        lastSuccessfulUpdate: Date?
    ) {
        var affected: [AffectedItem] = []
        var roster: [RosterItem] = []

        for (definition, baseService) in services {
            guard let service = baseService as? Service else { continue }

            switch baseService.status {
            case .major, .minor, .maintenance:
                affected.append(
                    AffectedItem(
                        id: service.name,
                        name: service.name,
                        message: baseService.message,
                        kind: Self.kind(for: baseService.status),
                        url: service.url,
                        faviconIdentifier: definition?.globalIdentifier,
                        faviconURL: definition?.faviconURL
                    )
                )
            case .undetermined:
                // A service that hasn't finished its first check isn't "unknown", it's pending —
                // listing it as a failure would make every cold launch look like an outage. The
                // header's progress bar is what covers this window.
                guard baseService.hasBeenChecked else { continue }

                affected.append(
                    AffectedItem(
                        id: service.name,
                        name: service.name,
                        message: UnknownReason(baseService.undeterminedReason).message,
                        kind: .unknown,
                        url: service.url,
                        faviconIdentifier: definition?.globalIdentifier,
                        faviconURL: definition?.faviconURL
                    )
                )
            case .good, .notice:
                // `.notice` is informational rather than degraded — the design has no separate
                // treatment for it.
                roster.append(
                    RosterItem(
                        id: service.name,
                        name: service.name,
                        url: service.url,
                        faviconIdentifier: definition?.globalIdentifier,
                        faviconURL: definition?.faviconURL
                    )
                )
            }
        }

        self.affected = affected.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return Self.rank(lhs.kind) < Self.rank(rhs.kind)
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        self.roster = roster.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        if servicesBeingUpdated.isEmpty {
            checkState = .idle
        } else {
            checkState = .checking(
                completed: services.count - servicesBeingUpdated.count,
                total: services.count
            )
        }

        self.lastUpdated = lastUpdated
        self.lastSuccessfulUpdate = lastSuccessfulUpdate
    }

    private static func kind(for status: ServiceStatus) -> Kind {
        switch status {
        case .major: return .major
        case .maintenance: return .maintenance
        case .undetermined: return .unknown
        default: return .minor
        }
    }

    private static func rank(_ kind: Kind) -> Int {
        switch kind {
        case .major: return 0
        case .minor: return 1
        case .maintenance: return 2
        case .unknown: return 3
        }
    }

    #if DEBUG
    /// Forces the model into a specific state for snapshot rendering (see `PopupSnapshot`), without
    /// needing real services in those states. Lives here because the published properties are
    /// `private(set)`.
    func applySnapshotState(
        affected: [AffectedItem] = [],
        roster: [RosterItem] = [],
        checkState: CheckState = .idle,
        lastUpdated: Date? = nil,
        lastSuccessfulUpdate: Date? = nil,
        rosterExpanded: Bool = false,
        allClearHeadline: String? = nil
    ) {
        self.affected = affected
        self.roster = roster
        self.checkState = checkState
        self.lastUpdated = lastUpdated
        self.lastSuccessfulUpdate = lastSuccessfulUpdate
        self.rosterExpanded = rosterExpanded
        // Deterministic by default — a snapshot that changed its headline every run would be
        // useless for eyeballing a diff.
        self.allClearHeadline = allClearHeadline ?? Self.allClearHeadlines[2]
    }
    #endif
}
