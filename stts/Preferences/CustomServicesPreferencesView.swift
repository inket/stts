//
//  CustomServicesPreferencesView.swift
//  stts
//

import SwiftUI

/// Custom services: the design doc's fourth sidebar pane, added to the shell now so the pane
/// exists to navigate to — content (the empty state, the editor sheet, the URL-testing service
/// model) is a separate piece of work. See `Scripts/settings_redesign_plan.md`.
struct CustomServicesPreferencesView: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        Color.clear
    }
}
