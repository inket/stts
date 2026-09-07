//
//  PopupViewController.swift
//  stts
//

import Cocoa
import MBPopup
import SwiftUI

/// Owns the popup's content: hosts the SwiftUI hierarchy, drives status refreshes, and keeps the
/// panel sized to its content.
///
/// Replaces the previous `NSTableView`-per-service layout. The popup is now a fixed header, a
/// scrolling middle section, and a fixed bottom bar (see `PopupContentView`), capped at
/// `PopupLayout.maxHeight` — content past that scrolls internally instead of growing the panel.
@MainActor
class PopupViewController: NSObject {
    let contentView = NSView(
        frame: CGRect(x: 0, y: 0, width: PopupLayout.contentWidth, height: PopupLayout.maxHeight)
    )

    private let viewModel: PopupViewModel
    private var hostingView: NSHostingView<PopupContentView>?

    private let serviceLoader: ServiceLoader
    private let preferences: Preferences
    private let preferencesWindow: PreferencesWindow

    /// Services paired with the definitions they were built from — the definition is what knows
    /// where a service's favicon lives.
    private var servicePairs: [(definition: ServiceDefinition, service: BaseService)] = []

    var services: [BaseService] { servicePairs.map(\.service) }

    @Atomic var servicesBeingUpdated = Set<BaseService>()

    private var lastUpdated: Date?
    private var lastSuccessfulUpdate: Date?

    /// Last height handed to the panel, so repeated preference callbacks with an unchanged value
    /// don't trigger redundant (and visibly animated) resizes.
    private var lastAppliedHeight: CGFloat?

    /// Worst status across every service, for the menu bar tick.
    var aggregateStatus: ServiceStatus { viewModel.aggregateStatus }

    var isChecking: Bool { viewModel.checkState.isChecking }

    /// The crown band's colour, which the popup's arrow is also tinted with.
    var crownColor: NSColor { PopupCrownHeaderView.color(for: viewModel) }

    var updateCallback: (() -> Void)?

    /// Fired whenever the displayed state changes, so the menu bar tick can follow along — including
    /// mid-check, which a completion callback alone would miss.
    var onStateChange: (() -> Void)?

    init(serviceLoader: ServiceLoader, preferences: Preferences, preferencesWindow: PreferencesWindow) {
        self.serviceLoader = serviceLoader
        self.preferences = preferences
        self.preferencesWindow = preferencesWindow
        self.viewModel = PopupViewModel()

        super.init()

        reloadServicesList()
    }

    func setup() {
        let rootView = PopupContentView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] in self?.preferencesWindow.show() },
            onRefresh: { [weak self] in self?.requestRefresh() },
            onOpen: { url in NSWorkspace.shared.open(url) },
            onContentHeightChange: { [weak self] height in self?.contentHeightChanged(height) }
        )

        // The panel is a vibrancy material with the panel colour laid over it, so the desktop tints
        // through. The blur has to come from AppKit — SwiftUI's own materials are system-defined
        // and wouldn't take the design's specific tint.
        let vibrancyView = NSVisualEffectView()
        vibrancyView.material = .popover
        vibrancyView.blendingMode = .behindWindow
        vibrancyView.state = .active
        vibrancyView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(vibrancyView)

        let hostingView = NSHostingView(rootView: rootView)
        // The popup's container view pins the content view to its edges and the panel's size comes
        // from `resizePopup`, so the hosting view must not also impose a size of its own.
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            vibrancyView.topAnchor.constraint(equalTo: contentView.topAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        self.hostingView = hostingView

        refreshViewModel()
    }

    func willOpenPopup() {
        viewModel.prepareForOpen()
        refreshViewModel()

        // `prepareForOpen()` collapses the roster, so the panel is very likely the wrong height for
        // what's about to be shown. MBPopup positions the panel from its current size right after
        // this returns, so the new height has to be in before then — otherwise the popup opens at
        // the size it closed at and visibly snaps. Safe to apply synchronously here, unlike from
        // `contentHeightChanged` — this is an AppKit callback, not the middle of a SwiftUI layout.
        hostingView?.layoutSubtreeIfNeeded()
        if let lastAppliedHeight { applyPanelHeight(lastAppliedHeight) }

        if let lastUpdated, Date().timeIntervalSince(lastUpdated) > 60 {
            requestRefresh()
        }
    }

    func reloadServicesList() {
        servicePairs = serviceLoader.servicesWithDefinitions(for: preferences.selectedServices)
        refreshViewModel()
    }

    func updateServices(updateCallback: @escaping () -> Void) {
        servicesBeingUpdated = Set<BaseService>()

        guard !services.isEmpty else {
            lastUpdated = Date()
            refreshViewModel()

            self.updateCallback?()
            self.updateCallback = nil

            return
        }

        self.updateCallback = updateCallback

        let servicesToUpdate = Set<BaseService>(services)
        servicesBeingUpdated = servicesToUpdate

        refreshViewModel()

        Task { [weak self] in
            await withTaskGroup(of: Void.self) { [weak self] group in
                for service in servicesToUpdate {
                    group.addTask { [weak self] in
                        await service.updateStatusAutomaticallyHandlingErrors()
                        await self?.updatedStatus(for: service)
                    }
                }
            }
        }
    }

    private func updatedStatus(for service: BaseService) async {
        servicesBeingUpdated.remove(service)

        if servicesBeingUpdated.isEmpty {
            let now = Date()
            lastUpdated = now

            // Only counts as successful if something actually reported. A pass where every service
            // came back `.undetermined` is what the "No connection" state is for, and it needs the
            // *previous* successful time to stay put.
            if services.contains(where: { $0.status != .undetermined }) {
                lastSuccessfulUpdate = now
            }
        }

        refreshViewModel()

        if servicesBeingUpdated.isEmpty {
            updateCallback?()
            updateCallback = nil
        }
    }

    private func requestRefresh() {
        (NSApp.delegate as? AppDelegate)?.updateServices()
    }

    private func refreshViewModel() {
        viewModel.update(
            services: servicePairs.map { (definition: $0.definition, service: $0.service) },
            servicesBeingUpdated: servicesBeingUpdated,
            lastUpdated: lastUpdated,
            lastSuccessfulUpdate: lastSuccessfulUpdate
        )

        onStateChange?()
    }

    private func contentHeightChanged(_ height: CGFloat) {
        let clamped = min(max(height, 0), PopupLayout.maxHeight)

        // SwiftUI re-reports the same height on unrelated re-layouts; resizing the panel to a height
        // it already has is wasted work.
        if let lastAppliedHeight, abs(lastAppliedHeight - clamped) < 0.5 { return }
        lastAppliedHeight = clamped

        // This arrives from inside SwiftUI's own layout pass (it's an `onPreferenceChange`), and
        // resizing the window from in there leaves the panel's content view at the size the pass
        // already committed to: the window shrinks to its 498pt ceiling while its content view stays
        // 544pt, so the content sits 46pt too tall inside it and the top of the crown is clipped
        // away above the panel. Applied on the next turn of the run loop, once that pass has ended.
        DispatchQueue.main.async { [weak self] in
            self?.applyPanelHeight(clamped)
        }
    }

    /// Resizes the panel to `contentHeight`, keeping its top edge — the one touching the menu bar —
    /// exactly where it is, so the popup only ever grows and shrinks downwards.
    ///
    /// Deliberately *not* `MBPopupController.resizePopup`, which does the same arithmetic but applies
    /// it with an animated `setFrame`. That call blocks in a nested run loop, which lets the next
    /// height report re-enter and compute its own frame from a half-resized panel, after which the
    /// outer animation finishes to its own now-stale target.
    private func applyPanelHeight(_ contentHeight: CGFloat) {
        guard let popupController = (NSApp.delegate as? AppDelegate)?.popupController else { return }

        let panel = popupController.panel
        let inset = popupController.contentInset

        var frame = panel.frame
        let top = frame.maxY
        frame.size.width = PopupLayout.contentWidth + inset * 2
        // SwiftUI measures in fractions of a point (443.556…), and AppKit rounds a window frame to
        // whole points behind your back — rounding the origin down and the height up. Asking for a
        // whole number to begin with keeps the top edge exactly where it was put, instead of landing
        // half a point off and reading as a 1px twitch on each expand.
        frame.size.height = (contentHeight + popupController.arrowSize.height + inset * 2).rounded(.up)
        frame.origin.y = top - frame.size.height

        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)

        // AppKit resizes the panel's content view along with the window, except when the window is
        // resized out from under a layout pass that is already running — which is how the 544pt
        // content view inside a 498pt panel was caught. Everything below it (MBPopup's container,
        // this controller's content view, the hosting view) is pinned to that view, so a stale size
        // there is a stale size for the whole popup. Cheap to assert rather than assume.
        let contentSize = panel.contentRect(forFrameRect: panel.frame).size
        if popupController.backgroundView.frame.size != contentSize {
            popupController.backgroundView.setFrameSize(contentSize)
        }
    }
}
