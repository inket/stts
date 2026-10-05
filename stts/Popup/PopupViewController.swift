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
/// The popup is a fixed header, a scrolling middle section, and a fixed bottom bar (see
/// `PopupContentView`), capped at `PopupLayout.maxHeight` — content past that scrolls internally
/// instead of growing the panel.
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

    /// Every service paired with the identifier its per-service preferences are keyed by. The
    /// service itself doesn't know its identifier — only the definition it was built from does.
    var identifiedServices: [(identifier: String, service: BaseService)] {
        servicePairs.map { ($0.definition.globalIdentifier, $0.service) }
    }

    var servicesBeingUpdated = Set<BaseService>()

    private var lastUpdated: Date?
    private var lastSuccessfulUpdate: Date?

    /// Last height handed to the panel, so repeated preference callbacks with an unchanged value
    /// don't trigger redundant (and visibly animated) resizes.
    private var lastAppliedHeight: CGFloat?

    /// Worst status across every service, for the menu bar tick.
    var aggregateStatus: ServiceStatus { viewModel.aggregateStatus }

    var isChecking: Bool { viewModel.checkState.isChecking }

    /// The popup arrow's tint: the crown band's colour when the band is shown, so it appears to
    /// continue up into the menu bar, and the panel colour otherwise.
    var arrowColor: NSColor {
        viewModel.usesCrownHeader ? PopupCrownHeaderView.color(for: viewModel) : PopupLayout.Colors.panelSolid
    }

    /// Set for the duration of a full check (`updateServices(updateCallback:)`) and nil otherwise.
    /// A partial check (`updateServices(only:)`) never sets it, which is how the two are told
    /// apart when the last in-flight service reports back.
    private var updateCallback: (() -> Void)?

    /// Fired whenever the displayed state changes, so the menu bar tick can follow along — including
    /// mid-check, which a completion callback alone would miss.
    var onStateChange: (() -> Void)?

    init(serviceLoader: ServiceLoader, preferences: Preferences, preferencesWindow: PreferencesWindow) {
        self.serviceLoader = serviceLoader
        self.preferences = preferences
        self.preferencesWindow = preferencesWindow
        self.viewModel = PopupViewModel()

        super.init()

        rebuildServicesList()
    }

    func setup() {
        let rootView = PopupContentView(
            viewModel: viewModel,
            onOpenSettings: { [weak self] in self?.preferencesWindow.show() },
            onSelectServices: { [weak self] in self?.preferencesWindow.showServices() },
            onRefresh: { [weak self] in self?.requestRefresh() },
            onOpen: { url in NSWorkspace.shared.open(url) },
            onContentHeightChange: { [weak self] height in self?.contentHeightChanged(height) }
        )

        // The blur has to come from AppKit — SwiftUI's own materials are system-defined and
        // wouldn't take a custom tint.
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

        // MBPopup positions the panel from its current size right after this returns, so the new
        // height (roster just collapsed) has to be applied before then, or the popup opens at the
        // size it closed at and visibly snaps. Safe synchronously here, unlike from
        // `contentHeightChanged` — this is an AppKit callback, not mid SwiftUI layout.
        hostingView?.layoutSubtreeIfNeeded()
        if let lastAppliedHeight { applyPanelHeight(lastAppliedHeight) }

        if let lastUpdated, Date().timeIntervalSince(lastUpdated) > 60 {
            requestRefresh()
        }
    }

    /// Syncs the list with the enabled set. Services that stay enabled keep their `BaseService`
    /// (and its status); only newly enabled ones are built, and those are returned so the caller
    /// can fetch just them.
    func reloadServicesList() -> [BaseService] {
        let existing = Dictionary(
            servicePairs.map { ($0.definition.globalIdentifier, $0.service) }
        ) { first, _ in first }
        let definitions = preferences.selectedServices
        let newPairs = serviceLoader.servicesWithDefinitions(
            for: definitions.filter { existing[$0.globalIdentifier] == nil }
        )
        let new = Dictionary(newPairs.map { ($0.definition.globalIdentifier, $0.service) }) { first, _ in first }

        setServicePairs(definitions.compactMap { definition in
            (existing[definition.globalIdentifier] ?? new[definition.globalIdentifier]).map { (definition, $0) }
        })
        return newPairs.map(\.service)
    }

    /// Throws every `BaseService` away and builds the enabled set from scratch — for when the
    /// definitions themselves changed. The result starts at `.undetermined`, so follow it with a
    /// full `updateServices`.
    func rebuildServicesList() {
        setServicePairs(serviceLoader.servicesWithDefinitions(for: preferences.selectedServices))
    }

    private func setServicePairs(_ pairs: [(definition: ServiceDefinition, service: BaseService)]) {
        servicePairs = pairs
        // A service disabled mid-check shouldn't keep the "checking" state alive.
        servicesBeingUpdated.formIntersection(services)
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
        startUpdating(Set(services))
    }

    /// Checks only the given services, on top of whatever is already in flight. Used after
    /// enabling a service so the rest aren't re-fetched.
    func updateServices(only servicesToUpdate: [BaseService]) {
        let subset = Set(servicesToUpdate).intersection(services).subtracting(servicesBeingUpdated)
        guard !subset.isEmpty else { return }
        startUpdating(subset)
    }

    private func startUpdating(_ servicesToUpdate: Set<BaseService>) {
        servicesBeingUpdated.formUnion(servicesToUpdate)
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

        // Only a full check moves the timestamps; a partial one has nothing to say about them.
        if servicesBeingUpdated.isEmpty, updateCallback != nil {
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

        // This arrives from inside SwiftUI's own layout pass (`onPreferenceChange`); resizing the
        // window from in there leaves the panel's content view at the size that pass already
        // committed to, clipping content. Deferred to the next run loop turn instead.
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
        // AppKit rounds a window frame to whole points behind your back (origin down, height up) —
        // rounding here keeps the top edge exactly where it was put instead of twitching a pixel.
        frame.size.height = (contentHeight + popupController.arrowSize.height + inset * 2).rounded(.up)
        frame.origin.y = top - frame.size.height

        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: true)

        // AppKit resizes the panel's content view along with the window, except when the window is
        // resized out from under a layout pass that's already running. Everything below it is
        // pinned to that view, so a stale size there is a stale size for the whole popup — cheap to
        // assert rather than assume.
        let contentSize = panel.contentRect(forFrameRect: panel.frame).size
        if popupController.backgroundView.frame.size != contentSize {
            popupController.backgroundView.setFrameSize(contentSize)
        }
    }
}
