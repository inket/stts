//
//  ServicesPreferencesView.swift
//  stts
//

import PreferencesWindow
import SwiftUI

/// Services: a filter column on the left, one list on the right, search scoped to the filter. The
/// filter column is the same `PreferencesSidebarView` the window's own sidebar uses, so the two
/// source lists share one selection pill.
///
/// The catalogue rows are built from the popup's own grouped-list pieces — `PopupGroupBox`,
/// `PopupRowSeparator`, `PopupFaviconChip` — rather than a `List`. A `List` fights this look on
/// macOS: there's no stock style that gives a whole section the popup's single rounded card with
/// hairlines between rows, only per-row insets and system-drawn separators. Reusing the popup's own
/// views instead means the two windows render their lists identically, and any future change to the
/// popup's row style carries over here for free.
///
/// No drill-in (a vendor opens underneath itself, and which vendors are open is remembered), and no
/// Save button — every toggle writes through to `Preferences` and reloads the popup.
struct ServicesPreferencesView: View {
    @ObservedObject var model: PreferencesModel

    private static let filterColumnWidth: CGFloat = 186

    var body: some View {
        HStack(spacing: 0) {
            filterColumn
                .frame(width: Self.filterColumnWidth)
            Divider()
            list
        }
        .searchable(text: $model.searchTerm, placement: .toolbar, prompt: model.searchPrompt)
    }

    // MARK: - The filter column

    private var filterColumn: some View {
        PreferencesSidebarView(
            sections: PreferencesModel.ServicesFilter.sections.map {
                PreferencesSidebarSection(title: $0.title, items: $0.filters)
            },
            selection: $model.servicesFilter,
            accentColor: nil,
            iconStyle: .glyph,
            badge: { model.count(for: $0) },
            // Affected's count is the one number here that's a warning rather than a size.
            badgeTint: { $0 == .affected ? PopupLayout.Colors.dotMinor.swiftUI : nil }
        )
        .padding(.vertical, 8)
    }

    // MARK: - The list

    @ViewBuilder
    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PopupLayout.Group.spacing) {
                if model.isSearching {
                    searchResultsCard
                } else if model.servicesFilter == .all {
                    catalogueCard
                } else {
                    scopedCard
                }
            }
            .padding(.top, PopupLayout.Group.topMargin)
            .padding(.bottom, PopupLayout.Group.bottomMargin)
            // Greedy width, always: with only a one-line empty-state `Text` inside, the scroll
            // view would otherwise shrink to fit it and the `HStack` would centre the leftover,
            // shoving the filter column right of where it sits with rows present.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// `LazyVStack`, not `VStack`: the catalogue runs to ~1,000 entries, and a plain `VStack`
    /// builds and lays out every one of them immediately, whether it's on screen or not. That
    /// alone was constructing hundreds of rows (each decoding a favicon off disk on first use —
    /// see `PopupFaviconLoader`) before a single one was visible. Lazy defers a row to when it's
    /// actually about to scroll into view, the same way `List`'s cells would have.
    private var catalogueCard: some View {
        PopupGroupBox(topMargin: 0) {
            LazyVStack(spacing: 0) {
                let entries = Array(model.topLevelServices.enumerated())
                ForEach(entries, id: \.element.globalIdentifier) { index, definition in
                    if index > 0 {
                        PopupRowSeparator()
                    }

                    if definition.isCategory == true {
                        ServiceGroupRows(model: model, definition: definition)
                    } else {
                        ServiceRow(model: model, definition: definition)
                    }
                }
            }
        }
    }

    /// A monitored scope: the flat list of what's in it, each sub-service captioned with its
    /// vendor — the same shape as search results, since both are slices rather than the catalogue.
    @ViewBuilder
    private var scopedCard: some View {
        let filter = model.servicesFilter
        let services = model.services(for: filter)

        if services.isEmpty {
            Text(filter.emptyMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, PopupLayout.Group.horizontalMargin)
        } else {
            // Keyed to the filter so switching scopes swaps the card outright, the way switching
            // to All services does; the card's own animation is only for a row leaving when
            // it's switched off *within* a scope.
            flatCard(services, subtitle: model.vendorSubtitle(for:))
                .id(filter)
        }
    }

    private func flatCard(
        _ services: [ServiceDefinition],
        subtitle: @escaping (ServiceDefinition) -> String?
    ) -> some View {
        PopupGroupBox(topMargin: 0) {
            LazyVStack(spacing: 0) {
                ForEach(Array(services.enumerated()), id: \.element.globalIdentifier) { index, definition in
                    if index > 0 {
                        PopupRowSeparator()
                    }
                    ServiceRow(model: model, definition: definition, subtitle: subtitle(definition))
                }
            }
        }
        .animation(.default, value: services.map(\.globalIdentifier))
    }

    private var searchResultsCard: some View {
        let results = model.searchResults

        return VStack(alignment: .leading, spacing: 8) {
            Text("\(results.count) results")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, PopupLayout.Group.horizontalMargin)

            if results.isEmpty {
                Text("No services match “\(model.searchTerm)”.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, PopupLayout.Group.horizontalMargin)
            } else {
                flatCard(results, subtitle: model.searchSubtitle(for:))
            }
        }
    }
}

// MARK: - Rows

/// A vendor with sub-services, as a header row plus — once expanded — its own togglable entry
/// and each child. Mirrors `PopupRosterView`'s header/rows split: same hover and background
/// rules, just with a per-vendor chevron instead of one collapsed stack.
private struct ServiceGroupRows: View {
    @ObservedObject var model: PreferencesModel
    let definition: ServiceDefinition

    @State private var isHoveringHeader = false

    var body: some View {
        let isExpanded = model.isExpanded(definition)
        let children = model.children(of: definition)
        let enabledCount = model.enabledCount(in: definition)

        VStack(spacing: 0) {
            header(isExpanded: isExpanded, childCount: children.count, enabledCount: enabledCount)

            if isExpanded {
                PopupRowSeparator()
                ServiceRow(model: model, definition: definition, subtitle: "All services", isChild: true)

                ForEach(children, id: \.globalIdentifier) { child in
                    PopupRowSeparator()
                    ServiceRow(model: model, definition: child, isChild: true)
                }
            }
        }
    }

    private func header(isExpanded: Bool, childCount: Int, enabledCount: Int) -> some View {
        HStack(spacing: PopupLayout.ServiceRow.contentGap) {
            PopupFaviconChip(
                identifier: definition.globalIdentifier,
                faviconURL: definition.faviconURL,
                initial: definition.name.first.map(String.init) ?? "?"
            )

            Text(definition.categoryDisplayName)
                .font(.body.weight(.semibold))
                .foregroundStyle(PopupLayout.Colors.serviceName.swiftUI)

            Spacer()

            if enabledCount > 0 {
                Text("\(enabledCount) of \(childCount + 1)")
                    .foregroundStyle(PreferencesLayout.accent)
            } else {
                Text("\(childCount + 1) services")
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .font(PopupLayout.Fonts.serviceMessage.swiftUI)
        .padding(PopupLayout.ServiceRow.padding)
        .background(isHoveringHeader ? PopupLayout.Colors.groupBackgroundHover.swiftUI : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHoveringHeader = $0 }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                model.toggleExpansion(of: definition)
            }
        }
    }
}

/// One service: its mark, its name, the notification override once it's being watched, and the
/// switch that starts and stops watching it.
///
/// No row background of any kind — no hover highlight, no "enabled" tint. A macOS list row only
/// paints a hover state when the whole row is a button, and this one isn't (its actions are the
/// switch and the bell; the vendor header *is* a button, so it keeps its hover).
private struct ServiceRow: View {
    @ObservedObject var model: PreferencesModel
    let definition: ServiceDefinition
    var subtitle: String?
    var isChild = false

    /// Nudges a subservice row's content right of its vendor's, so the expanded group reads as a
    /// hierarchy rather than a flat list.
    private static let childIndent: CGFloat = 20

    var body: some View {
        let isEnabled = model.isEnabled(definition)

        HStack(spacing: PopupLayout.ServiceRow.contentGap) {
            PopupFaviconChip(
                identifier: definition.globalIdentifier,
                faviconURL: definition.faviconURL,
                initial: definition.name.first.map(String.init) ?? "?"
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(definition.name)
                    .font(PopupLayout.Fonts.serviceName.swiftUI)
                    .foregroundStyle(PopupLayout.Colors.serviceName.swiftUI)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Only on rows that are actually being watched: an override on a service nothing is
            // monitoring would have nothing to act on.
            if isEnabled {
                NotificationOverrideMenu(model: model, definition: definition)
            }

            Toggle("", isOn: model.enabledBinding(for: definition))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.leading, isChild ? Self.childIndent : 0)
        .padding(PopupLayout.ServiceRow.padding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(definition.name)
    }
}

/// The per-service notification override, as a bell that opens a menu.
private struct NotificationOverrideMenu: View {
    @ObservedObject var model: PreferencesModel
    let definition: ServiceDefinition

    var body: some View {
        let override = model.notificationOverride(for: definition)

        Menu {
            Picker("Notify me about \(definition.name)", selection: binding) {
                Text("Use General setting (\(model.preferences.notificationGranularity.title.lowercased()))")
                    .tag(NotificationGranularity?.none)
                Divider()
                ForEach(NotificationGranularity.allCases, id: \.self) { granularity in
                    Text(granularity.title).tag(NotificationGranularity?.some(granularity))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: symbol(for: override))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint(for: override))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        // `.button` + `.plain`, not `.borderlessButton`: the latter is an `NSPopUpButton`, and
        // SwiftUI hands it the label's image as an `NSImage` that AppKit then paints as a
        // template in its own tint — the weight and colour set above never reach it (an
        // inheriting bell came out in the window's green rather than grey). `.button` keeps
        // the label a SwiftUI view; only the dropdown is AppKit's.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(helpText(for: override))
    }

    private var binding: Binding<NotificationGranularity?> {
        Binding(
            get: { model.notificationOverride(for: definition) },
            set: { model.setNotificationOverride($0, for: definition) }
        )
    }

    private func symbol(for override: NotificationGranularity?) -> String {
        switch override {
        case .never: return "bell.slash"
        case .outagesOnly: return "bell.badge"
        case .everyChange, nil: return "bell"
        }
    }

    /// Grey while inheriting, then the popup's own status hues for an override: green for every
    /// change, amber for outages only, red for never — so a row's bell reads at a glance without
    /// opening the menu.
    private func tint(for override: NotificationGranularity?) -> Color {
        switch override {
        case nil: return Color(nsColor: .tertiaryLabelColor)
        case .everyChange: return PreferencesLayout.accent
        case .outagesOnly: return PopupLayout.Colors.dotMinor.swiftUI
        case .never: return PopupLayout.Colors.dotMajor.swiftUI
        }
    }

    private func helpText(for override: NotificationGranularity?) -> String {
        guard let override else {
            return "Follows the General setting: \(model.preferences.notificationGranularity.title.lowercased())"
        }
        return "Notifications: \(override.title.lowercased())"
    }
}
