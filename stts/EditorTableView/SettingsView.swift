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
    let hideServiceDetailsIfAvailableCheckbox = NSButton()
    let allowPopupToStretchAsNeededCheckbox = NSButton()

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
        [
            settingsHeader,
            startAtLoginCheckbox,
            notifyCheckbox,
            hideServiceDetailsIfAvailableCheckbox,
            allowPopupToStretchAsNeededCheckbox,
            servicesHeader,
            searchField
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))

        startAtLoginCheckbox.setButtonType(.switch)
        startAtLoginCheckbox.title = "Start at login"
        startAtLoginCheckbox.font = font
        startAtLoginCheckbox.state = StartAtLogin.enabled ? .on : .off
        startAtLoginCheckbox.action = #selector(SettingsView.updateStartAtLogin)
        startAtLoginCheckbox.target = self

        notifyCheckbox.setButtonType(.switch)
        notifyCheckbox.title = "Notify when a status changes"
        notifyCheckbox.font = font
        notifyCheckbox.state = Preferences.shared.notifyOnStatusChange ? .on : .off
        notifyCheckbox.action = #selector(SettingsView.updateNotifyOnStatusChange)
        notifyCheckbox.target = self

        hideServiceDetailsIfAvailableCheckbox.setButtonType(.switch)
        hideServiceDetailsIfAvailableCheckbox.title = "Hide details of available services"
        hideServiceDetailsIfAvailableCheckbox.font = font
        hideServiceDetailsIfAvailableCheckbox.state = Preferences.shared.hideServiceDetailsIfAvailable ? .on : .off
        hideServiceDetailsIfAvailableCheckbox.action = #selector(SettingsView.updateHideServiceDetailsIfAvailable)
        hideServiceDetailsIfAvailableCheckbox.target = self

        allowPopupToStretchAsNeededCheckbox.setButtonType(.switch)
        allowPopupToStretchAsNeededCheckbox.title = "Allow popup to stretch as needed"
        allowPopupToStretchAsNeededCheckbox.font = font
        allowPopupToStretchAsNeededCheckbox.state = Preferences.shared.allowPopupToStretchAsNeeded ? .on : .off
        allowPopupToStretchAsNeededCheckbox.action = #selector(SettingsView.updateAllowPopupToStretchAsNeeded)
        allowPopupToStretchAsNeededCheckbox.target = self

        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.action = #selector(SettingsView.filterServices)
        searchField.target = self

        NSLayoutConstraint.activate([
            settingsHeader.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            settingsHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            settingsHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            settingsHeader.heightAnchor.constraint(equalToConstant: 20),

            startAtLoginCheckbox.topAnchor.constraint(equalTo: settingsHeader.bottomAnchor, constant: 6),
            startAtLoginCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            startAtLoginCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            startAtLoginCheckbox.heightAnchor.constraint(equalToConstant: 22),

            notifyCheckbox.topAnchor.constraint(equalTo: startAtLoginCheckbox.bottomAnchor, constant: 6),
            notifyCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            notifyCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            notifyCheckbox.heightAnchor.constraint(equalToConstant: 22),

            hideServiceDetailsIfAvailableCheckbox.topAnchor.constraint(
                equalTo: notifyCheckbox.bottomAnchor,
                constant: 6
            ),
            hideServiceDetailsIfAvailableCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            hideServiceDetailsIfAvailableCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            hideServiceDetailsIfAvailableCheckbox.heightAnchor.constraint(equalToConstant: 22),

            allowPopupToStretchAsNeededCheckbox.topAnchor.constraint(
                equalTo: hideServiceDetailsIfAvailableCheckbox.bottomAnchor,
                constant: 6
            ),
            allowPopupToStretchAsNeededCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            allowPopupToStretchAsNeededCheckbox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            allowPopupToStretchAsNeededCheckbox.heightAnchor.constraint(equalToConstant: 22),

            servicesHeader.topAnchor.constraint(
                equalTo: allowPopupToStretchAsNeededCheckbox.bottomAnchor,
                constant: 10
            ),
            servicesHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            servicesHeader.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            servicesHeader.heightAnchor.constraint(equalToConstant: 20),

            searchField.topAnchor.constraint(equalTo: servicesHeader.bottomAnchor, constant: 6),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    @objc private func updateStartAtLogin() {
        StartAtLogin.enabled = startAtLoginCheckbox.state == .on
    }

    @objc private func updateNotifyOnStatusChange() {
        Preferences.shared.notifyOnStatusChange = notifyCheckbox.state == .on
    }

    @objc private func updateHideServiceDetailsIfAvailable() {
        Preferences.shared.hideServiceDetailsIfAvailable = hideServiceDetailsIfAvailableCheckbox.state == .on
    }

    @objc private func updateAllowPopupToStretchAsNeeded() {
        Preferences.shared.allowPopupToStretchAsNeeded = allowPopupToStretchAsNeededCheckbox.state == .on
    }

    @objc private func filterServices() {
        searchCallback?(searchField.stringValue)
    }
}
