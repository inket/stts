//
//  SettingsView.swift
//  stts
//

import Cocoa
import StartAtLogin

class SettingsView: NSView {
    let settingsHeader = SectionHeaderView(name: "Preferences")
    let startAtLoginCheckbox = NSButton()
    let notifyCheckbox = NSButton()
    let hideGoodStatus = NSButton()

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
        [settingsHeader, startAtLoginCheckbox, notifyCheckbox, hideGoodStatus, servicesHeader, searchField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

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

        hideGoodStatus.setButtonType(.switch)
        hideGoodStatus.title = "Hide good status description"
        hideGoodStatus.font = smallFont
        hideGoodStatus.state = Preferences.shared.hideGoodStatusMessage ? .on : .off
        hideGoodStatus.action = #selector(SettingsView.hideGoodStatusMessage)
        hideGoodStatus.target = self

        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.action = #selector(SettingsView.filterServices)
        searchField.target = self

        NSLayoutConstraint.activate([
            settingsHeader.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            settingsHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            settingsHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            settingsHeader.heightAnchor.constraint(equalToConstant: 16),

            startAtLoginCheckbox.topAnchor.constraint(equalTo: settingsHeader.bottomAnchor, constant: 6),
            startAtLoginCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            startAtLoginCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            startAtLoginCheckbox.heightAnchor.constraint(equalToConstant: 18),

            notifyCheckbox.topAnchor.constraint(equalTo: startAtLoginCheckbox.bottomAnchor, constant: 6),
            notifyCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            notifyCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            notifyCheckbox.heightAnchor.constraint(equalToConstant: 18),

            hideGoodStatus.topAnchor.constraint(equalTo: notifyCheckbox.bottomAnchor, constant: 6),
            hideGoodStatus.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            hideGoodStatus.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hideGoodStatus.heightAnchor.constraint(equalToConstant: 18),

            servicesHeader.topAnchor.constraint(equalTo: hideGoodStatus.bottomAnchor, constant: 10),
            servicesHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            servicesHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            servicesHeader.heightAnchor.constraint(equalToConstant: 16),

            searchField.topAnchor.constraint(equalTo: servicesHeader.bottomAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    @objc private func updateStartAtLogin() {
        StartAtLogin.enabled = (startAtLoginCheckbox.state == .on)
    }

    @objc private func updateNotifyOnStatusChange() {
        Preferences.shared.notifyOnStatusChange = (notifyCheckbox.state == .on)
    }

    @objc private func hideGoodStatusMessage() {
        Preferences.shared.hideGoodStatusMessage = (hideGoodStatus.state == .on)
    }

    @objc private func filterServices() {
        searchCallback?(searchField.stringValue)
    }
}
