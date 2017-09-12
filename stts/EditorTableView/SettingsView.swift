//
//  SettingsView.swift
//  stts
//

import Cocoa
import SnapKit
import StartAtLogin

class SettingsView: NSView {
    let settingsHeader = SectionHeaderView(name: "Preferences")
    let startAtLoginCheckbox = NSButton()
    let notifyCheckbox = NSButton()

    let servicesHeader = SectionHeaderView(name: "Services")
    let searchField = NSSearchField()

    var searchCallback: ((String) -> Void)?

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(frame: .zero)
        setup()
    }

    func setup() {
        addSubview(settingsHeader)
        addSubview(startAtLoginCheckbox)
        addSubview(notifyCheckbox)
        addSubview(servicesHeader)
        addSubview(searchField)

        let smallFont = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))

        startAtLoginCheckbox.setButtonType(.switch)
        startAtLoginCheckbox.title = "Start at Login"
        startAtLoginCheckbox.font = smallFont
        startAtLoginCheckbox.state = StartAtLogin.enabled ? .on : .off
        startAtLoginCheckbox.action = #selector(SettingsView.updateStartAtLogin)
        startAtLoginCheckbox.target = self

        notifyCheckbox.setButtonType(.switch)
        notifyCheckbox.title = "Notify when a status changes"
        notifyCheckbox.font = smallFont
        notifyCheckbox.state = Preferences.shared.notifyOnStatusChange ? .on : .off
        notifyCheckbox.action = #selector(SettingsView.updateNotifyOnStatusChange)
        notifyCheckbox.target = self

        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.action = #selector(SettingsView.filterServices)
        searchField.target = self

        settingsHeader.snp.makeConstraints { make in
            make.top.left.equalTo(6)
            make.right.equalTo(-6)
            make.height.equalTo(16)
        }

        startAtLoginCheckbox.snp.makeConstraints { make in
            make.top.equalTo(settingsHeader.snp.bottom).offset(6)
            make.left.equalTo(14)
            make.right.equalTo(-14)
            make.height.equalTo(18)
        }

        notifyCheckbox.snp.makeConstraints { make in
            make.top.equalTo(startAtLoginCheckbox.snp.bottom).offset(6)
            make.left.equalTo(14)
            make.right.equalTo(-14).priority(200)
            make.height.equalTo(18)
        }

        servicesHeader.snp.makeConstraints { make in
            make.top.equalTo(notifyCheckbox.snp.bottom).offset(10)
            make.left.equalTo(6)
            make.right.equalTo(-6)
            make.height.equalTo(16)
        }

        searchField.snp.makeConstraints { make in
            make.top.equalTo(servicesHeader.snp.bottom).offset(6)
            make.left.equalTo(12)
            make.right.equalTo(-12)
            make.height.equalTo(22)
        }
    }

    @objc private func updateStartAtLogin() {
        StartAtLogin.enabled = (startAtLoginCheckbox.state == .on)
    }

    @objc private func updateNotifyOnStatusChange() {
        Preferences.shared.notifyOnStatusChange = (notifyCheckbox.state == .on)
    }

    @objc private func filterServices() {
        searchCallback?(searchField.stringValue)
    }
}
