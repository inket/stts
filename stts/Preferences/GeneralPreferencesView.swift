//
//  GeneralPreferencesView.swift
//  stts
//

import ServiceManagement
import SwiftUI

/// A plain `Form` with `.formStyle(.grouped)` — which is what System Settings itself is built from,
/// so the cards, insets, separators and row heights come out right without any of them being
/// specified here.
struct GeneralPreferencesView: View {
    @ObservedObject var model: PreferencesModel

    @State private var appearance: AppearancePreference
    @State private var launchAtLogin: Bool
    @State private var refreshInterval: Int
    @State private var granularity: NotificationGranularity

    init(model: PreferencesModel) {
        self.model = model
        _appearance = State(initialValue: model.preferences.appearancePreference)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        _refreshInterval = State(initialValue: model.preferences.refreshInterval)
        _granularity = State(initialValue: model.preferences.notificationGranularity)
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases, id: \.self) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                .onChange(of: appearance) { _, newValue in
                    model.preferences.appearancePreference = newValue
                    // Applied app-wide rather than to this window alone: the popup is drawn from
                    // the same palette and would otherwise disagree about the appearance.
                    NSApp.appearance = newValue.appearance
                }
            }

            Section("Startup") {
                Toggle("Launch stts at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
            }

            Section("Status updates") {
                Picker("Check every", selection: $refreshInterval) {
                    ForEach(Preferences.refreshIntervalOptions, id: \.self) { seconds in
                        Text(Self.intervalTitle(seconds)).tag(seconds)
                    }
                }
                .onChange(of: refreshInterval) { _, newValue in
                    model.preferences.refreshInterval = newValue
                    model.onRefreshIntervalChange?(newValue)
                }

                Picker(selection: $granularity) {
                    ForEach(NotificationGranularity.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Text("Notify me about")
                    Text("Individual services can override this in Services.")
                }
                .onChange(of: granularity) { _, newValue in
                    model.preferences.notificationGranularity = newValue
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private static func intervalTitle(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    /// Registers the app itself as a login item.
    ///
    /// `SMAppService.mainApp` rather than the `StartAtLogin` framework in the Cartfile: that
    /// framework installs a separate helper app the way login items worked before macOS 13, and
    /// its Carthage-built module was compiled by a Swift version this build can't import anyway.
    /// Nothing in the app had ever called it.
    private func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            debugPrint("Could not change the login item: \(error)")
        }

        // Registration can fail, or be overridden in System Settings, so the switch is put back
        // where the system actually left it rather than where it was clicked.
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
