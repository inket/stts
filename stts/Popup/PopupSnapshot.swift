//
//  PopupSnapshot.swift
//  stts
//

#if DEBUG
import SwiftUI

/// Renders the popup's designed states to PNGs so the redesign can be checked against the design
/// doc without driving the real menu bar item.
///
/// Debug-only, and entirely opt-in: set `STTS_SNAPSHOT=1` and the app emits every state on launch,
/// then exits. Normal launches never touch this.
///
/// Images go to stdout as base64, one `SNAPSHOT-PNG <name> <base64>` line each, rather than to
/// files: the app is sandboxed, so the only directory it can write to is its own container, which
/// is in turn TCC-protected from other processes.
///
/// Two things the real popup has that these don't: the vibrancy blur (there's no desktop behind an
/// offscreen render, so the panel is painted opaque instead) and the panel's rounded corners and
/// shadow, which come from the native panel rather than this view.
enum PopupSnapshot {
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["STTS_SNAPSHOT"] == "1"
    }

    @MainActor
    static func emit() {
        for appearanceName in [NSAppearance.Name.darkAqua, .aqua] {
            let isDark = appearanceName == .darkAqua
            guard let appearance = NSAppearance(named: appearanceName) else { continue }

            // Both are needed: `colorScheme` drives SwiftUI's own resolution, while the app-wide
            // appearance is what the bridged dynamic `NSColor`s resolve against during rasterization.
            NSApp.appearance = appearance

            appearance.performAsCurrentDrawingAppearance {
                for state in states {
                    let model = PopupViewModel()
                    state.apply(model)
                    render(model: model, named: "\(state.name)-\(isDark ? "dark" : "light")", isDark: isDark)
                }

                renderMenuBar(named: "99-menu-bar-\(isDark ? "dark" : "light")", appearance: appearance)
            }
        }

        NSApp.appearance = nil
    }

    @MainActor
    private static func render(model: PopupViewModel, named name: String, isDark: Bool) {
        let view = PopupContentView(
            viewModel: model,
            onOpenSettings: {},
            onRefresh: {},
            onOpen: { _ in },
            onContentHeightChange: { _ in },
            scrollsContent: false,
            opaqueBackground: true
        )
        .environment(\.colorScheme, isDark ? .dark : .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        func log(_ message: String) {
            FileHandle.standardError.write(Data("SNAPSHOT \(name): \(message)\n".utf8))
        }

        guard let image = renderer.nsImage else { return log("nsImage was nil") }
        guard let tiff = image.tiffRepresentation else { return log("no tiff, size=\(image.size)") }
        guard let bitmap = NSBitmapImageRep(data: tiff) else { return log("no bitmap") }
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return log("no png") }

        FileHandle.standardOutput.write(
            Data("SNAPSHOT-PNG \(name) \(png.base64EncodedString())\n".utf8)
        )
    }

    /// The menu bar item across every status it can show. Rendered through AppKit rather than
    /// `ImageRenderer` because `MenuBarItemView` is an `NSView`.
    @MainActor
    private static func renderMenuBar(named name: String, appearance: NSAppearance) {
        let states: [(status: ServiceStatus, checking: Bool)] = [
            (.good, false), (.minor, false), (.major, false),
            (.maintenance, false), (.undetermined, false), (.good, true)
        ]

        let itemWidth: CGFloat = 30
        let gap: CGFloat = 14
        let height: CGFloat = 24

        let container = NSView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: CGFloat(states.count) * (itemWidth + gap) + gap,
                height: height
            )
        )
        container.appearance = appearance
        container.wantsLayer = true
        container.layer?.backgroundColor = appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.12, alpha: 1).cgColor
            : NSColor(calibratedWhite: 0.96, alpha: 1).cgColor

        for (index, state) in states.enumerated() {
            let item = MenuBarItemView(
                frame: NSRect(
                    x: gap + CGFloat(index) * (itemWidth + gap),
                    y: 0,
                    width: itemWidth,
                    height: height
                )
            )
            item.appearance = appearance
            item.status = state.status
            item.isChecking = state.checking
            container.addSubview(item)
        }

        guard let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) else { return }
        container.cacheDisplay(in: container.bounds, to: rep)

        guard let png = rep.representation(using: .png, properties: [:]) else { return }

        FileHandle.standardOutput.write(
            Data("SNAPSHOT-PNG \(name) \(png.base64EncodedString())\n".utf8)
        )
    }

    // MARK: - Fixtures

    private struct State {
        let name: String
        let apply: @MainActor (PopupViewModel) -> Void
    }

    /// The app's own bundled favicons, so snapshots exercise the real chip rendering rather than
    /// falling back to monograms.
    private static func favicon(_ identifier: String) -> URL? {
        Bundle.main.url(forResource: identifier, withExtension: "png", subdirectory: "Favicons")
    }

    private static func affected(
        _ name: String,
        _ kind: PopupViewModel.Kind,
        _ message: String,
        _ host: String,
        favicon identifier: String? = nil
    ) -> PopupViewModel.AffectedItem {
        PopupViewModel.AffectedItem(
            id: name,
            name: name,
            message: message,
            kind: kind,
            url: URL(string: "https://\(host)")!,
            faviconIdentifier: identifier,
            faviconURL: identifier.flatMap(favicon)
        )
    }

    /// The operational fleet, using real bundled favicons where the app ships one.
    private static let operationalFleet: [(name: String, identifier: String?)] = [
        ("Claude", "statuspage.Claude"),
        ("Cloudflare", "statuspage.Cloudflare"),
        ("Datadog", "statuspage.Datadog"),
        ("DigitalOcean", "statuspage.DigitalOcean"),
        ("Discord", "statuspage.Discord"),
        ("Dropbox", "statuspage.Dropbox"),
        ("Figma", "statuspage.Figma"),
        ("GitLab", "statusiov1.GitLab"),
        ("Linear", "incidentio.Linear"),
        ("Notion", "incidentio.Notion"),
        ("Okta", nil),
        ("OpenAI", "incidentio.OpenAI"),
        ("Rollbar", "incidentio.Rollbar"),
        ("Runway", "betteruptime.Runway"),
        ("Sentry", nil),
        ("Zapier", "incidentio.Zapier")
    ]

    private static func roster(_ count: Int) -> [PopupViewModel.RosterItem] {
        operationalFleet.prefix(count).map { entry in
            PopupViewModel.RosterItem(
                id: entry.name,
                name: entry.name,
                url: URL(string: "https://status.example.com")!,
                faviconIdentifier: entry.identifier,
                faviconURL: entry.identifier.flatMap(favicon)
            )
        }
    }

    private static var states: [State] {
        [
            State(name: "1-major-minor-maintenance") { model in
                model.applySnapshotState(
                    affected: [
                        affected(
                            "OpenAI", .major, "Elevated error rates on the API",
                            "status.openai.com", favicon: "incidentio.OpenAI"
                        ),
                        affected(
                            "Docker", .minor, "Degraded performance on Hub pulls",
                            "status.docker.com", favicon: "statusiov1.Docker"
                        ),
                        affected(
                            "GitHub", .maintenance, "Scheduled maintenance on Actions",
                            "www.githubstatus.com", favicon: "statuspage.GitHub"
                        )
                    ],
                    roster: roster(13),
                    lastUpdated: Date(timeIntervalSinceNow: -1)
                )
            },
            State(name: "2-minor-only") { model in
                model.applySnapshotState(
                    affected: [
                        affected(
                            "Docker", .minor, "Degraded performance on Hub pulls",
                            "status.docker.com", favicon: "statusiov1.Docker"
                        )
                    ],
                    roster: roster(15),
                    lastUpdated: Date(timeIntervalSinceNow: -1)
                )
            },
            State(name: "3-maintenance-only") { model in
                model.applySnapshotState(
                    affected: [
                        affected(
                            "Linear", .maintenance, "Scheduled database upgrade",
                            "status.linear.app", favicon: "incidentio.Linear"
                        )
                    ],
                    roster: roster(15),
                    lastUpdated: Date(timeIntervalSinceNow: -1)
                )
            },
            State(name: "4-all-clear") { model in
                model.applySnapshotState(
                    roster: roster(16),
                    lastUpdated: Date(timeIntervalSinceNow: -1)
                )
            },
            State(name: "5-roster-expanded") { model in
                model.applySnapshotState(
                    affected: [
                        affected(
                            "OpenAI", .major, "Elevated error rates on the API",
                            "status.openai.com", favicon: "incidentio.OpenAI"
                        )
                    ],
                    roster: roster(15),
                    lastUpdated: Date(timeIntervalSinceNow: -1),
                    rosterExpanded: true
                )
            },
            State(name: "6-with-unknowns") { model in
                model.applySnapshotState(
                    affected: [
                        affected(
                            "OpenAI", .major, "Elevated error rates on the API",
                            "status.openai.com", favicon: "incidentio.OpenAI"
                        ),
                        affected("Okta", .unknown, "No answer from the status page", "status.okta.com"),
                        affected(
                            "Beanstalk", .unknown, "Status page couldn't be read",
                            "status.beanstalkapp.com"
                        )
                    ],
                    roster: roster(13),
                    lastUpdated: Date(timeIntervalSinceNow: -1)
                )
            },
            State(name: "7-checking") { model in
                model.applySnapshotState(
                    roster: roster(16),
                    checkState: .checking(completed: 7, total: 16),
                    lastUpdated: Date(timeIntervalSinceNow: -1)
                )
            },
            State(name: "8-no-connection") { model in
                model.applySnapshotState(
                    affected: operationalFleet.prefix(8).map { entry in
                        affected(
                            entry.name, .unknown, "No answer from the status page",
                            "status.example.com", favicon: entry.identifier
                        )
                    },
                    lastSuccessfulUpdate: Date(timeIntervalSinceNow: -11 * 60)
                )
            },
            State(name: "9-no-services") { model in
                model.applySnapshotState()
            }
        ]
    }
}
#endif
