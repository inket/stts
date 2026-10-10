//
//  PreferencesSidebarView.swift
//  PreferencesWindow
//

import AppKit
import SwiftUI

/// One row in a `PreferencesSidebarView`.
public protocol PreferencesSidebarItem: Hashable {
    var sidebarTitle: String { get }
    /// A template image, so the tile can tint it. An image rather than an SF Symbol name so the
    /// caller can supply its own artwork — see stts's `PreferencesGlyph` for why it does.
    var sidebarIcon: NSImage { get }
    var sidebarTint: Color { get }
}

/// A titled run of rows in a `PreferencesSidebarView`. A `nil` title is an untitled block — no
/// header row, just the items — which is how a list's leading rows sit above its first header.
public struct PreferencesSidebarSection<Item: PreferencesSidebarItem>: Equatable {
    public var title: String?
    public var items: [Item]

    public init(title: String? = nil, items: [Item]) {
        self.title = title
        self.items = items
    }
}

/// How a row shows its icon.
public enum PreferencesSidebarIconStyle {
    /// A 20pt rounded square filled with `sidebarTint`, the glyph in white on top — System
    /// Settings' own treatment for its top-level list.
    case tile
    /// The bare glyph, tinted `sidebarTint` (white when selected) beside the title — a Finder- or
    /// Mail-style source list, for a secondary list that shouldn't compete with the main one.
    case glyph
}

/// A macOS-style preferences sidebar, backed by a real `NSOutlineView` instead of SwiftUI's `List`.
///
/// `List`'s `.sidebar` style gives live row-selection tracking (highlight follows the pointer while
/// held, commits on release) but hardcodes its pill to the system accent; `.plain` with a
/// hand-drawn pill gets the colour back but loses the tracking, since `NavigationLink`'s tap is a
/// single click-then-release unit. This gets both by using the real component and only overriding
/// how it draws.
public struct PreferencesSidebarView<Item: PreferencesSidebarItem>: NSViewRepresentable {
    private let sections: [PreferencesSidebarSection<Item>]
    private let selection: Binding<Item>
    private let accentColor: Color?
    private let iconStyle: PreferencesSidebarIconStyle
    private let badge: (Item) -> Int
    private let badgeTint: (Item) -> Color?

    /// - Parameters:
    ///   - accentColor: The selection pill's fill, or `nil` for the system accent colour — the
    ///     one the user picked in System Settings, i.e. what `List`'s own `.sidebar` style draws.
    ///   - badge: A trailing count for the row; 0 hides it.
    ///   - badgeTint: The count's colour, or `nil` for the secondary label colour. Ignored while
    ///     the row is selected, where the count is white like the title.
    public init(
        sections: [PreferencesSidebarSection<Item>],
        selection: Binding<Item>,
        accentColor: Color?,
        iconStyle: PreferencesSidebarIconStyle = .tile,
        badge: @escaping (Item) -> Int = { _ in 0 },
        badgeTint: @escaping (Item) -> Color? = { _ in nil }
    ) {
        self.sections = sections
        self.selection = selection
        self.accentColor = accentColor
        self.iconStyle = iconStyle
        self.badge = badge
        self.badgeTint = badgeTint
    }

    /// A single untitled section — the window's own pane list.
    public init(
        items: [Item],
        selection: Binding<Item>,
        accentColor: Color?,
        badge: @escaping (Item) -> Int = { _ in 0 }
    ) {
        self.init(
            sections: [PreferencesSidebarSection(items: items)],
            selection: selection,
            accentColor: accentColor,
            badge: badge
        )
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 0
        outlineView.style = .plain
        // `.regular`, not `.none`: `.none` skips calling `drawSelection(in:)` at all, override
        // included. `RowView` below replaces what `.regular` would draw.
        outlineView.selectionHighlightStyle = .regular
        outlineView.backgroundColor = .clear
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.allowsEmptySelection = false
        outlineView.allowsMultipleSelection = false
        // Section headers are group items so AppKit treats them as headers (no selection, no
        // hover), but they shouldn't pin to the top while scrolling — they're labels, not
        // navigation.
        outlineView.floatsGroupRows = false
        outlineView.dataSource = context.coordinator
        outlineView.delegate = context.coordinator

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Item"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        // Auto-hidden, so a list that fits (the pane list) never shows one.
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        context.coordinator.outlineView = outlineView
        context.coordinator.expandAllSections()
        context.coordinator.refreshBadgesIfNeeded()
        context.coordinator.sync(to: selection.wrappedValue)

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // The single column starts at NSTableColumn's ~100pt default and only grows on an actual
        // resize event, not on makeNSView's initial zero-sized frame — re-fit here, once real
        // geometry exists, or the trailing badge looks unaligned.
        context.coordinator.outlineView?.sizeLastColumnToFit()
        context.coordinator.sections = sections
        context.coordinator.selection = selection
        context.coordinator.accentColor = accentColor
        context.coordinator.badge = badge
        context.coordinator.badgeTint = badgeTint
        context.coordinator.refreshBadgesIfNeeded()
        context.coordinator.sync(to: selection.wrappedValue)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            sections: sections,
            selection: selection,
            accentColor: accentColor,
            iconStyle: iconStyle,
            badge: badge,
            badgeTint: badgeTint
        )
    }

    @MainActor
    public final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        /// What the outline view holds: a section's header, or one of the caller's items. Headers
        /// are keyed by title, which is unique within a list by construction (two sections with
        /// the same name would be one section).
        enum Node: Hashable {
            case header(String)
            case item(Item)
        }

        var sections: [PreferencesSidebarSection<Item>] {
            didSet {
                guard sections != oldValue, let outlineView else { return }
                isReloading = true
                outlineView.reloadData()
                expandAllSections()
                isReloading = false
                lastBadges = nil // the rows changed under the cached values
            }
        }
        var selection: Binding<Item>
        var accentColor: Color?
        let iconStyle: PreferencesSidebarIconStyle
        var badge: (Item) -> Int
        var badgeTint: (Item) -> Color?
        weak var outlineView: NSOutlineView?

        /// Every item in display order, headers excluded — the flat list the caller passed before
        /// sections existed. What `refreshBadgesIfNeeded` diffs against.
        private var items: [Item] { sections.flatMap(\.items) }

        /// Every row in display order, headers included, mirroring the outline view once all its
        /// sections are expanded (they always are — see `expandAllSections`). Row numbers come
        /// from here rather than `NSOutlineView.row(forItem:)`, which would have to find a
        /// boxed Swift value by `isEqual:`; keeping the mapping explicit means no reliance on how
        /// `Any` bridging hashes an enum.
        private var rows: [Node] {
            sections.flatMap { section -> [Node] in
                let items = section.items.map(Node.item)
                guard let title = section.title else { return items }
                return [.header(title)] + items
            }
        }

        private func row(for item: Item) -> Int? {
            rows.firstIndex(of: .item(item))
        }

        private var rowHeight: CGFloat {
            switch iconStyle {
            case .tile: return 28
            case .glyph: return 26
            }
        }

        /// The item a click just selected, while its write to `selection` is still in-flight on
        /// `DispatchQueue.main.async` (see `outlineViewSelectionDidChange`). `updateNSView` — and so
        /// `sync(to:)` — can run before that write lands, still carrying the pre-click value; while
        /// this is set, `sync(to:)` holds off rather than selecting the stale value back over the
        /// row the user just clicked.
        private var pendingItem: Item?

        /// The badge values last reflected on screen. `reloadData()` resets `NSOutlineView`'s
        /// selection, and with `allowsEmptySelection = false` AppKit auto-selects row 0 as a fix-up —
        /// silently overriding whatever was just clicked. Reloading only when a badge actually
        /// changed avoids that almost entirely; `refreshBadgesIfNeeded()` also re-asserts the
        /// selection across the reload as a second line of defence.
        private var lastBadges: [Int]?

        /// Set for the duration of `refreshBadgesIfNeeded()`'s reload-and-reselect, since
        /// `reloadData()`'s row-0 auto-select fires `outlineViewSelectionDidChange` synchronously —
        /// a real, if spurious, intermediate selection change that `pendingItem` doesn't cover.
        /// This flag makes that delegate callback ignore it and the subsequent reselect.
        private var isReloading = false

        init(
            sections: [PreferencesSidebarSection<Item>],
            selection: Binding<Item>,
            accentColor: Color?,
            iconStyle: PreferencesSidebarIconStyle,
            badge: @escaping (Item) -> Int,
            badgeTint: @escaping (Item) -> Color?
        ) {
            self.sections = sections
            self.selection = selection
            self.accentColor = accentColor
            self.iconStyle = iconStyle
            self.badge = badge
            self.badgeTint = badgeTint
        }

        /// Sections are always open — they're headings, not disclosure groups — so the outline
        /// view's rows always match `rows`. `reloadData()` collapses everything, so this runs
        /// after every reload.
        func expandAllSections() {
            outlineView?.expandItem(nil, expandChildren: true)
        }

        func refreshBadgesIfNeeded() {
            let current = items.map(badge)
            guard current != lastBadges, let outlineView else { return }
            lastBadges = current

            let selectedRow = outlineView.selectedRow
            isReloading = true
            outlineView.reloadData()
            expandAllSections()
            if selectedRow >= 0 {
                outlineView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            }
            isReloading = false
        }

        func sync(to item: Item) {
            if let pendingItem {
                if pendingItem == item { self.pendingItem = nil } // the deferred write landed
                return
            }

            guard
                let outlineView,
                let index = row(for: item),
                outlineView.selectedRow != index
            else { return }

            outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }

        private func section(titled title: String) -> PreferencesSidebarSection<Item>? {
            sections.first { $0.title == title }
        }

        // MARK: NSOutlineViewDataSource

        public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            switch item as? Node {
            case .none:
                return sections.reduce(0) { $0 + ($1.title == nil ? $1.items.count : 1) }
            case .header(let title):
                return section(titled: title)?.items.count ?? 0
            case .item:
                return 0
            }
        }

        public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            if case .header = item as? Node { return true }
            return false
        }

        public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            switch item as? Node {
            case .none:
                let roots = sections.flatMap { section -> [Node] in
                    section.title.map { [.header($0)] } ?? section.items.map(Node.item)
                }
                return roots[index]
            case .header(let title):
                guard let section = section(titled: title) else { preconditionFailure("unknown section \(title)") }
                return Node.item(section.items[index])
            case .item:
                preconditionFailure("items have no children")
            }
        }

        // MARK: NSOutlineViewDelegate

        public func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
            if case .header = item as? Node { return true }
            return false
        }

        public func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
            false
        }

        public func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
            if case .header = item as? Node { return PreferencesSidebarHeaderCell.height }
            return rowHeight
        }

        public func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            if case .item = item as? Node { return true }
            return false
        }

        public func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
            if case .header = item as? Node { return nil } // a stock, unselectable row
            return PreferencesSidebarRowView(accentColor: accentColor)
        }

        public func outlineView(
            _ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any
        ) -> NSView? {
            switch item as? Node {
            case .header(let title):
                let id = NSUserInterfaceItemIdentifier("PreferencesSidebarHeaderCell")
                let cell = outlineView.makeView(withIdentifier: id, owner: self) as? PreferencesSidebarHeaderCell
                    ?? PreferencesSidebarHeaderCell(identifier: id)
                cell.configure(title: title)
                return cell
            case .item(let item):
                let identifier = NSUserInterfaceItemIdentifier("PreferencesSidebarRowCell")
                let cell = (outlineView.makeView(withIdentifier: identifier, owner: self) as? PreferencesSidebarRowCell)
                    ?? PreferencesSidebarRowCell(identifier: identifier, iconStyle: iconStyle)
                cell.configure(
                    title: item.sidebarTitle,
                    icon: item.sidebarIcon,
                    tint: NSColor(item.sidebarTint),
                    badge: badge(item),
                    badgeTint: badgeTint(item).map(NSColor.init)
                )
                return cell
            case .none:
                return nil
            }
        }

        public func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !isReloading else { return }
            guard
                let outlineView,
                case .item(let item)? = outlineView.item(atRow: outlineView.selectedRow) as? Node,
                item != selection.wrappedValue
            else { return }

            pendingItem = item

            // Dispatched, not direct: `NSHostingView` can run this delegate callback nested inside
            // its own update cycle, so writing straight through `selection` here still hits SwiftUI's
            // "Publishing changes from within view updates" hazard. Safe to defer since the pill
            // itself (`NSTableRowView.isSelected`) is already updated synchronously by mouse
            // tracking; `pendingItem` covers the gap until this write lands.
            let selection = self.selection
            DispatchQueue.main.async { selection.wrappedValue = item }
        }
    }
}

/// Draws the sidebar's selection pill in the caller's accent color (or the system one, when the
/// caller passes `nil`), instead of what `NSOutlineView`'s built-in `.sourceList` highlight style
/// would draw. Row-selection *tracking* (press, live drag between rows, commit or cancel on
/// release) is untouched: that's `NSTableView`'s own mouse handling, and overriding only
/// `drawSelection(in:)` doesn't affect it.
private final class PreferencesSidebarRowView: NSTableRowView {
    private let accentColor: Color?

    init(accentColor: Color?) {
        self.accentColor = accentColor
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard isSelected else { return }

        let pillRect = bounds.insetBy(dx: 10, dy: 0)
        // `NSBezierPath(roundedRect:)` only does circular corners; borrowing SwiftUI's shape gets
        // the same continuous curve the icon tile's `CALayer.cornerCurve = .continuous` uses.
        let cgPath = RoundedRectangle(cornerRadius: 7, style: .continuous).path(in: pillRect).cgPath
        let path = NSBezierPath(cgPath: cgPath)
        // Unemphasized (window not key, or the outline view not first responder) goes gray the
        // way every system source list does, rather than a faded accent.
        let color: NSColor = isEmphasized
            ? accentColor.map(NSColor.init) ?? .controlAccentColor
            : .unemphasizedSelectedContentBackgroundColor
        color.setFill()
        path.fill()
    }
}

/// A section's heading: a small uppercase secondary label, the way Finder and Mail head their
/// source-list groups, with room above it so it reads as the start of something new.
private final class PreferencesSidebarHeaderCell: NSTableCellView {
    static let height: CGFloat = 30

    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = .tertiaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Same leading inset as a row's content; pinned to the bottom rather than centred so the
        // extra height sits *above* the label as a gap from the previous section.
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    convenience init(identifier: NSUserInterfaceItemIdentifier) {
        self.init(frame: .zero)
        self.identifier = identifier
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.stringValue = title.uppercased()
    }
}

/// A sidebar row's content: an icon (tile or bare glyph), title, and trailing count.
private final class PreferencesSidebarRowCell: NSTableCellView {
    private let iconStyle: PreferencesSidebarIconStyle
    private let tileView = PreferencesSidebarTileView()
    private let glyphView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")

    private var glyphTint: NSColor = .secondaryLabelColor
    private var badgeTint: NSColor?

    init(identifier: NSUserInterfaceItemIdentifier, iconStyle: PreferencesSidebarIconStyle) {
        self.iconStyle = iconStyle
        super.init(frame: .zero)
        self.identifier = identifier
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        badgeLabel.font = .systemFont(ofSize: 13)
        badgeLabel.alignment = .right
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)

        // `.centerY` on the outer stack box-centers each view, which leaves title and badge (different
        // font sizes) on visibly different lines — nesting them in their own `.firstBaseline` stack
        // fixes that. `.fill`, not the default `.gravityAreas`, so the hugging priorities below are
        // actually honored: the title grows to take the slack, pushing the badge to the trailing edge.
        let textRow = NSStackView(views: [titleLabel, badgeLabel])
        textRow.orientation = .horizontal
        textRow.distribution = .fill
        textRow.alignment = .firstBaseline
        textRow.spacing = 8
        textRow.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // A fixed-width image view rather than an inline `NSTextAttachment`: each symbol has its
        // own advance width, which would leave titles starting at different x positions.
        glyphView.imageScaling = .scaleProportionallyDown
        glyphView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        glyphView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glyphView.widthAnchor.constraint(equalToConstant: 16),
            glyphView.heightAnchor.constraint(equalToConstant: 16)
        ])

        let iconView: NSView
        switch iconStyle {
        case .tile: iconView = tileView
        case .glyph: iconView = glyphView
        }
        let stack = NSStackView(views: [iconView, textRow])
        stack.orientation = .horizontal
        stack.distribution = .fill
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        // 10pt is the pill's own inset (`PreferencesSidebarRowView.drawSelection`); content needs
        // its own padding inside that. Trailing gets a little more so the badge doesn't crowd the
        // pill's rounded corner.
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateAppearance()
    }

    func configure(title: String, icon: NSImage, tint: NSColor, badge: Int, badgeTint: NSColor?) {
        switch iconStyle {
        case .tile:
            tileView.configure(icon: icon, tint: tint)
        case .glyph:
            glyphView.image = icon
            glyphTint = tint
        }
        self.badgeTint = badgeTint
        titleLabel.stringValue = title
        badgeLabel.stringValue = badge > 0 ? "\(badge)" : ""
        badgeLabel.isHidden = badge == 0
        updateAppearance()
    }

    // The standard hook for a custom cell to react to selection, since AppKit's built-in
    // text/image recoloring only applies to a cell's designated textField/imageView.
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { updateAppearance() }
    }

    private func updateAppearance() {
        let isSelected = backgroundStyle == .emphasized
        titleLabel.textColor = isSelected ? .white : .labelColor
        badgeLabel.textColor = isSelected ? NSColor.white.withAlphaComponent(0.85) : (badgeTint ?? .secondaryLabelColor)
        glyphView.contentTintColor = isSelected ? .white : glyphTint
    }
}

/// A tinted rounded-square icon tile with a white glyph on top. The tile is fixed at 20×20; the
/// glyph inside it is plain default-centred `NSImageView` layout, no per-symbol adjustment.
private final class PreferencesSidebarTileView: NSView {
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 20),
            heightAnchor.constraint(equalToConstant: 20),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 12),
            imageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: NSImage, tint: NSColor) {
        layer?.backgroundColor = tint.cgColor
        imageView.image = icon
    }
}
