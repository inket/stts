//
//  PopupFaviconLoader.swift
//  stts
//

import SwiftUI

/// Supplies the small service icons shown on incident cards.
///
/// `ServiceDefinition.faviconURL` already resolves where an icon lives — a PNG bundled in the app
/// when one shipped, otherwise a jsDelivr URL for one added to the repo since. That means a lookup
/// is either a local file read or a network fetch, and the network case is what this caches: once
/// on disk under Application Support, and once in memory for the lifetime of the process.
///
/// Failures are deliberately quiet — a missing icon falls back to the monogram placeholder rather
/// than surfacing an error.
@MainActor
final class PopupFaviconLoader: ObservableObject {
    static let shared = PopupFaviconLoader()

    /// Bumped when an asynchronously fetched icon arrives, so observing views re-render.
    ///
    /// The images themselves live in a plain dictionary rather than an `@Published` one: a locally
    /// available icon is resolved during `body` evaluation, and publishing from there is exactly the
    /// "modifying state during view update" mistake.
    @Published private(set) var generation = 0

    /// Keyed by `ServiceDefinition.globalIdentifier`.
    private var cache: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    /// Identifiers already tried and failed, so a broken icon isn't re-fetched on every redraw.
    private var failed: Set<String> = []

    private let cacheDirectory: URL?

    init(cacheDirectory: URL? = PopupFaviconLoader.defaultCacheDirectory()) {
        self.cacheDirectory = cacheDirectory
    }

    /// The icon for a service.
    ///
    /// Resolves immediately when the icon is bundled with the app or already on disk — which is the
    /// common case, and means no placeholder flash for an icon we already have. Anything that needs
    /// the network returns `nil` now and arrives via `generation`.
    func icon(for identifier: String, url: URL?) -> NSImage? {
        if let icon = cache[identifier] { return icon }

        guard let url, !failed.contains(identifier) else { return nil }

        if let image = locallyAvailableIcon(for: identifier, url: url) {
            cache[identifier] = image
            return image
        }

        // A file URL that didn't resolve above isn't going to resolve later.
        guard !url.isFileURL else {
            failed.insert(identifier)
            return nil
        }

        guard !inFlight.contains(identifier) else { return nil }

        inFlight.insert(identifier)
        Task { await fetch(identifier: identifier, url: url) }

        return nil
    }

    private func locallyAvailableIcon(for identifier: String, url: URL) -> NSImage? {
        if let cached = cachedImage(for: identifier) { return cached }
        guard url.isFileURL else { return nil }

        return NSImage(contentsOf: url)
    }

    private func fetch(identifier: String, url: URL) async {
        defer { inFlight.remove(identifier) }

        do {
            let (data, response) = try await DataLoader.shared.data(from: url)

            guard
                (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                let image = NSImage(data: data)
            else {
                failed.insert(identifier)
                return
            }

            store(data, for: identifier)
            cache[identifier] = image
            generation += 1
        } catch {
            failed.insert(identifier)
        }
    }

    // MARK: - Disk cache

    private func cacheURL(for identifier: String) -> URL? {
        guard let cacheDirectory else { return nil }

        // Identifiers are `provider.AlphanumericName`, so they're already path-safe, but a remote
        // services.json could introduce anything — don't let a name escape the cache directory.
        let safeName = identifier.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )

        return cacheDirectory.appendingPathComponent("\(safeName).png")
    }

    private func cachedImage(for identifier: String) -> NSImage? {
        guard let url = cacheURL(for: identifier), FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    private func store(_ data: Data, for identifier: String) {
        guard let cacheDirectory, let url = cacheURL(for: identifier) else { return }

        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: url)
    }

    nonisolated static func defaultCacheDirectory() -> URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        return applicationSupport
            .appendingPathComponent("stts", isDirectory: true)
            .appendingPathComponent("Favicons", isDirectory: true)
    }
}

/// A service's favicon on a white chip.
///
/// Every icon gets the chip because the shipped favicons are a mixed bag — black marks on
/// transparency, full-colour marks, marks that already carry their own tile — and none of them
/// survive being dropped straight onto the panel. Services with no favicon on disk fall back to a
/// monogram on the same chip.
struct PopupFaviconChip: View {
    let identifier: String?
    let faviconURL: URL?
    let initial: String

    var chipSize: CGFloat = PopupLayout.ServiceRow.chipSize
    var cornerRadius: CGFloat = PopupLayout.ServiceRow.chipCornerRadius
    var faviconSize: CGFloat = PopupLayout.ServiceRow.faviconSize

    @ObservedObject private var loader = PopupFaviconLoader.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return Group {
            if let identifier, let image = loader.icon(for: identifier, url: faviconURL) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: faviconSize, height: faviconSize)
            } else {
                Text(initial.uppercased())
                    .font(PopupLayout.Fonts.faviconMonogram.swiftUI)
                    .foregroundColor(PopupLayout.Colors.serviceName.swiftUI)
            }
        }
        .frame(width: chipSize, height: chipSize)
        .background(chipBackground)
        .clipShape(shape)
        .overlay(shape.strokeBorder(PopupLayout.Colors.chipRing.swiftUI, lineWidth: PopupLayout.hairlineWidth))
    }

    /// A real favicon gets the white chip; a monogram gets a translucent one instead, so a missing
    /// icon doesn't read as a blank white tile.
    @ViewBuilder
    private var chipBackground: some View {
        if identifier != nil, loader.icon(for: identifier!, url: faviconURL) != nil {
            PopupLayout.Colors.chipBackground.swiftUI
        } else {
            PopupLayout.Colors.chipMonogramBackground.swiftUI
        }
    }
}

/// A favicon chip with a severity dot notched into its bottom-trailing corner. The dot carries a
/// ring in the group's blended colour so it stays legible against the chip while blending into the
/// cell rather than reading as a drawn border.
struct PopupFaviconChipWithDot: View {
    let identifier: String?
    let faviconURL: URL?
    let initial: String
    let dotColor: NSColor

    var body: some View {
        PopupFaviconChip(identifier: identifier, faviconURL: faviconURL, initial: initial)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(dotColor.swiftUI)
                    .frame(width: PopupLayout.ServiceRow.dotSize, height: PopupLayout.ServiceRow.dotSize)
                    // Ring drawn as a larger circle behind the dot rather than a strokeBorder on it —
                    // the latter antialiases the ring and fill separately at the same radius, letting
                    // the dot's colour bleed past the ring at the seam.
                    .background(
                        Circle()
                            .fill(PopupLayout.Colors.chipRing.swiftUI)
                            .padding(-PopupLayout.ServiceRow.dotRingWidth)
                    )
                    .offset(
                        x: PopupLayout.ServiceRow.dotOffset,
                        y: PopupLayout.ServiceRow.dotOffset
                    )
            }
    }
}
