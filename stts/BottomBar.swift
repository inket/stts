//
//  BottomBar.swift
//  stts
//

import Cocoa
import DateHelper

enum BottomBarStatus {
    case undetermined
    case updating
    case updated(Date)
}

class BottomBar: NSView {
    let settingsButton = NSButton()
    let reloadButton = NSButton()
    let doneButton = NSButton()
    let aboutButton = NSButton()
    let quitButton = NSButton()
    let backButton = NSButton()
    let statusField = NSTextField()
    let separator = ServiceTableRowView()

    var status: BottomBarStatus = .undetermined {
        didSet {
            updateStatusText()
        }
    }

    var reloadServicesCallback: () -> Void = {}
    var openSettingsCallback: () -> Void = {}
    var closeSettingsCallback: () -> Void = {}
    var backCallback: () -> Void = {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        [
            separator,
            settingsButton, reloadButton, statusField, // Main view buttons
            doneButton, aboutButton, quitButton, // Editor view buttons
            backButton // Category view buttons
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let gearIcon = GearIcon()
        gearIcon.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addSubview(gearIcon)

        let refreshIcon = RefreshIcon()
        refreshIcon.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.addSubview(refreshIcon)

        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),

            settingsButton.heightAnchor.constraint(equalToConstant: 30),
            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            settingsButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            gearIcon.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            gearIcon.centerXAnchor.constraint(equalTo: settingsButton.centerXAnchor),
            gearIcon.heightAnchor.constraint(equalToConstant: 22),
            gearIcon.widthAnchor.constraint(equalToConstant: 22),

            reloadButton.heightAnchor.constraint(equalToConstant: 30),
            reloadButton.widthAnchor.constraint(equalToConstant: 30),
            reloadButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            reloadButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            refreshIcon.centerYAnchor.constraint(equalTo: reloadButton.centerYAnchor),
            refreshIcon.centerXAnchor.constraint(equalTo: reloadButton.centerXAnchor),
            refreshIcon.heightAnchor.constraint(equalToConstant: 18),
            refreshIcon.widthAnchor.constraint(equalToConstant: 18),

            statusField.leadingAnchor.constraint(equalTo: settingsButton.trailingAnchor),
            statusField.trailingAnchor.constraint(equalTo: reloadButton.leadingAnchor),
            statusField.centerYAnchor.constraint(equalTo: centerYAnchor),

            doneButton.widthAnchor.constraint(equalToConstant: 60),
            doneButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),

            aboutButton.widthAnchor.constraint(equalToConstant: 56),
            aboutButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            aboutButton.leadingAnchor.constraint(equalTo: quitButton.trailingAnchor, constant: 6),

            quitButton.widthAnchor.constraint(equalToConstant: 46),
            quitButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            quitButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),

            backButton.widthAnchor.constraint(equalToConstant: 46),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3)
        ])

        settingsButton.isBordered = false
        settingsButton.bezelStyle = .regularSquare
        settingsButton.title = ""
        settingsButton.target = self
        settingsButton.action = #selector(BottomBar.openSettings)
        gearIcon.scaleUnitSquare(to: NSSize(width: 0.46, height: 0.46))

        reloadButton.isBordered = false
        reloadButton.bezelStyle = .regularSquare
        reloadButton.title = ""
        reloadButton.target = self
        reloadButton.action = #selector(BottomBar.reloadServices)
        refreshIcon.scaleUnitSquare(to: NSSize(width: 0.38, height: 0.38))

        statusField.isEditable = false
        statusField.isBordered = false
        statusField.isSelectable = false
        let font = NSFont.systemFont(ofSize: 12)
        let italicFont = NSFontManager.shared.font(
            withFamily: font.fontName,
            traits: NSFontTraitMask.italicFontMask,
            weight: 5,
            size: 10
        )

        statusField.font = italicFont
        statusField.textColor = NSColor.secondaryLabelColor
        statusField.maximumNumberOfLines = 1
        statusField.backgroundColor = NSColor.clear
        statusField.alignment = .center
        statusField.cell?.truncatesLastVisibleLine = true

        doneButton.title = "Done"
        doneButton.bezelStyle = .regularSquare
        doneButton.controlSize = .regular
        doneButton.isHidden = true
        doneButton.target = self
        doneButton.action = #selector(BottomBar.closeSettings)

        aboutButton.title = "About"
        aboutButton.bezelStyle = .regularSquare
        aboutButton.controlSize = .regular
        aboutButton.isHidden = true
        aboutButton.target = self
        aboutButton.action = #selector(BottomBar.openAbout)

        quitButton.title = "Quit"
        quitButton.bezelStyle = .regularSquare
        quitButton.controlSize = .regular
        quitButton.isHidden = true
        quitButton.target = NSApp
        quitButton.action = #selector(NSApplication.terminate(_:))

        backButton.title = "Back"
        backButton.bezelStyle = .regularSquare
        backButton.controlSize = .regular
        backButton.isHidden = true
        backButton.target = self
        backButton.action = #selector(BottomBar.back)
    }

    func updateStatusText() {
        switch status {
        case .undetermined: statusField.stringValue = ""
        case .updating: statusField.stringValue = "Updating…"
        case .updated(let date):
            let relativeTime = date.toStringWithRelativeTime()
            statusField.stringValue = "Updated \(relativeTime)"
        }
    }

    func openedCategory(_ category: ServiceCategory?, backCallback: @escaping () -> Void) {
        doneButton.isHidden = false
        aboutButton.isHidden = category != nil
        quitButton.isHidden = category != nil

        backButton.isHidden = category == nil

        self.backCallback = backCallback
    }

    @objc func reloadServices() {
        reloadServicesCallback()
    }

    @objc func openSettings() {
        settingsButton.isHidden = true
        statusField.isHidden = true
        reloadButton.isHidden = true

        doneButton.isHidden = false
        aboutButton.isHidden = false
        quitButton.isHidden = false

        openSettingsCallback()
    }

    @objc func closeSettings() {
        backCallback()

        settingsButton.isHidden = false
        statusField.isHidden = false
        reloadButton.isHidden = false

        doneButton.isHidden = true
        aboutButton.isHidden = true
        quitButton.isHidden = true

        backButton.isHidden = true

        closeSettingsCallback()
    }

    @objc func openAbout() {
        let githubLink = "github.com/inket/stts"
        let contributorsLink = "github.com/inket/stts/graphs/contributors"

        let openSourceNotice = "stts is an open-source project\n\(githubLink)"
        let iconGlyphCredit = "Activity glyph (app icon)\nCreated by Gregor Črešnar from the Noun Project"
        let contributors = "Contributors\n\(contributorsLink)"
        let credits = NSMutableAttributedString(
            string: "\n\(openSourceNotice)\n\n\(iconGlyphCredit)\n\n\(contributors)\n\n"
        )

        let normalFont = NSFont.systemFont(ofSize: 11)
        let boldFont = NSFont.boldSystemFont(ofSize: 11)

        credits.addAttribute(.font, value: normalFont, range: NSRange(location: 0, length: credits.length))
        for word in ["stts", "Activity", "Contributors"] {
            credits.addAttribute(.font, value: boldFont, range: (credits.string as NSString).range(of: word))
        }

        credits.addAttribute(
            .link,
            value: "https://\(githubLink)",
            range: (credits.string as NSString).range(of: githubLink)
        )
        credits.addAttribute(
            .link,
            value: "https://\(contributorsLink)",
            range: (credits.string as NSString).range(of: contributorsLink)
        )

        NSApp.orderFrontStandardAboutPanel(options: [NSApplication.AboutPanelOptionKey(rawValue: "Credits"): credits])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func back() {
        backButton.isHidden = true

        doneButton.isHidden = false
        aboutButton.isHidden = false
        quitButton.isHidden = false

        backCallback()
    }
}
