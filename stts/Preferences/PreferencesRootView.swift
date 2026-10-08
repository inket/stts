//
//  PreferencesRootView.swift
//  stts
//

import PreferencesWindow
import SwiftUI

/// Built out of stock SwiftUI — `NavigationSplitView`, `Form`, `Toggle`, `Picker` — which brings
/// keyboard focus, accessibility, the system accent, Increase Contrast, and appearance changes for
/// free, and rules out a whole class of custom-drawing bug along with it.
///
/// The sidebar is the one exception to "stock SwiftUI": it's the `PreferencesWindow` framework's
/// `PreferencesSidebarView`, a real `NSOutlineView` — see that type's header comment for why
/// `List` couldn't do the job. Everything app-specific about it — the four panes, their icons and
/// tint, the Services badge count — stays here, wired up through `PreferencesModel.Pane`'s
/// `PreferencesSidebarItem` conformance at the bottom of `PreferencesModel.swift`.
struct PreferencesRootView: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        NavigationSplitView {
            PreferencesSidebarView(
                items: PreferencesModel.Pane.allCases,
                selection: $model.selectedPane,
                accentColor: nil,
                badge: { pane in
                    switch pane {
                    case .services: return model.enabledCount
                    case .customServices: return model.customServices.count
                    case .general, .about: return 0
                    }
                }
            )
            // `NavigationSplitView` adds a sidebar-toggle button automatically; this sidebar is
            // never meant to collapse. The modifier has to be on the sidebar *column's* content —
            // on the split view itself it was ignored (the button still showed on macOS 26).
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) {
                Text(Self.versionString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            // Outermost on purpose. With this *inside* the `.toolbar(removing:)` above, the split
            // view stopped honouring it and opened the column at ~144pt; the width has to be the
            // last thing the column's root view says about itself.
            .modifier(SidebarColumnWidth())
        } detail: {
            detail
                .navigationTitle(model.selectedPane.title)
                // An invisible item so the toolbar is never *empty*: a unified toolbar with no
                // items collapses to title-bar height, and with the sidebar toggle gone the
                // panes without a search field (General, Custom services, About) were doing
                // exactly that while Services stayed full height — the window jumped between
                // the two on every pane switch.
                //
                // On macOS 26 every toolbar item sits on its own glass capsule, so even a clear
                // 1×1 item showed up as a sliver of capsule edge at the trailing end — hence the
                // hidden shared background there. Earlier systems draw no chrome per item.
                .toolbar {
                    if #available(macOS 26, *) {
                        ToolbarItem(placement: .automatic) { toolbarPlaceholder }
                            .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .automatic) { toolbarPlaceholder }
                    }
                }
                // The window's own titlebar text is hidden (`PreferencesWindowController` sets
                // `titleVisibility = .hidden`) in favour of this: a toolbar item merges into the
                // same title-bar row next to the traffic lights, the way Mail's or Notes' window
                // does, rather than the taller two-row "big title" a visible native title would
                // add above a *second* toolbar.
        }
        // No `.tint()`: controls, focus rings and both sidebars' selection pills follow the
        // user's own system accent, like any other settings window. `PreferencesLayout.accent`
        // (the app's green) is kept for content that *means* stts — the Monitoring glyph, the
        // "Every change" label — not for chrome.
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedPane {
        case .general:
            GeneralPreferencesView(model: model)
        case .services:
            ServicesPreferencesView(model: model)
        case .customServices:
            CustomServicesPreferencesView(model: model)
        case .about:
            AboutPreferencesView(model: model)
        }
    }

    private var toolbarPlaceholder: some View {
        Color.clear.frame(width: 1, height: 1)
            .accessibilityHidden(true)
    }

    /// The sidebar column's width from `PreferencesLayout`: one fixed value, or a draggable
    /// range, depending on `isSidebarResizable`.
    private struct SidebarColumnWidth: ViewModifier {
        func body(content: Content) -> some View {
            if PreferencesLayout.isSidebarResizable {
                content.navigationSplitViewColumnWidth(
                    min: PreferencesLayout.sidebarWidthRange.lowerBound,
                    ideal: PreferencesLayout.sidebarWidth,
                    max: PreferencesLayout.sidebarWidthRange.upperBound
                )
            } else {
                content.navigationSplitViewColumnWidth(PreferencesLayout.sidebarWidth)
            }
        }
    }

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "stts \(short) (\(build))"
    }
}
