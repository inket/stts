//
//  BottomBar.swift
//  stts
//

import Cocoa
import SnapKit
import SwiftDate

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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        addSubview(separator)
        addSubview(settingsButton)
        addSubview(reloadButton)
        addSubview(statusField)
        addSubview(doneButton)
        addSubview(aboutButton)
        addSubview(quitButton)

        let gearIcon = GearIcon()
        settingsButton.addSubview(gearIcon)

        let refreshIcon = RefreshIcon()
        reloadButton.addSubview(refreshIcon)

        separator.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.left.top.right.equalTo(0)
        }

        settingsButton.snp.makeConstraints { make in
            make.height.width.equalTo(30)
            make.bottom.left.equalTo(0)
        }

        gearIcon.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }

        reloadButton.snp.makeConstraints { make in
            make.height.width.equalTo(30)
            make.bottom.right.equalTo(0)
        }

        refreshIcon.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        statusField.snp.makeConstraints { make in
            make.left.equalTo(settingsButton.snp.right)
            make.right.equalTo(reloadButton.snp.left)
            make.centerY.equalToSuperview()
        }

        doneButton.snp.makeConstraints { make in
            make.width.equalTo(60)
            make.centerY.equalToSuperview()
            make.right.equalTo(-3)
        }

        aboutButton.snp.makeConstraints { make in
            make.width.equalTo(56)
            make.centerY.equalToSuperview()
            make.left.equalTo(quitButton.snp.right).offset(6)
        }

        quitButton.snp.makeConstraints { make in
            make.width.equalTo(46)
            make.centerY.equalToSuperview()
            make.left.equalTo(3)
        }

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
        let italicFont = NSFontManager.shared().font(withFamily: font.fontName,
                                                     traits: NSFontTraitMask.italicFontMask,
                                                     weight: 5,
                                                     size: 10)
        statusField.font = italicFont
        statusField.textColor = NSColor(calibratedWhite: 0, alpha: 0.6)
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
        aboutButton.target = NSApp
        aboutButton.action = #selector(NSApplication.orderFrontStandardAboutPanel(_:))

        quitButton.title = "Quit"
        quitButton.bezelStyle = .regularSquare
        quitButton.controlSize = .regular
        quitButton.isHidden = true
        quitButton.target = NSApp
        quitButton.action = #selector(NSApplication.terminate(_:))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateStatusText() {
        switch status {
        case .undetermined: statusField.stringValue = ""
        case .updating: statusField.stringValue = "Updating…"
        case .updated(let date):
            if let (colloquial, _) = try? date.colloquialSinceNow() {
                statusField.stringValue = "Updated \(colloquial)"
            } else {
                statusField.stringValue = "Updated"
            }
        }
    }

    func reloadServices() {
        reloadServicesCallback()
    }

    func openSettings() {
        settingsButton.isHidden = true
        statusField.isHidden = true
        reloadButton.isHidden = true

        doneButton.isHidden = false
        aboutButton.isHidden = false
        quitButton.isHidden = false

        openSettingsCallback()
    }

    func closeSettings() {
        settingsButton.isHidden = false
        statusField.isHidden = false
        reloadButton.isHidden = false

        doneButton.isHidden = true
        aboutButton.isHidden = true
        quitButton.isHidden = true

        closeSettingsCallback()
    }
}
