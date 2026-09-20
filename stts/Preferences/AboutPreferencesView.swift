//
//  AboutPreferencesView.swift
//  stts
//

import SwiftUI

/// About: the app's own icon and type, a line saying what it's actually doing, and a way to report
/// an issue.
///
/// "Monitoring 12 of 543 status pages. Definitions last updated 2 days ago." answers, in the one
/// screen people open when something seems wrong, whether the catalogue is current — which matters
/// because `services.json` is fetched rather than shipped (see `RemoteServicesUpdater`).
struct AboutPreferencesView: View {
    @ObservedObject var model: PreferencesModel

    private static let issuesURL = URL(string: "https://github.com/inket/stts/issues")!

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)

            Text("stts")
                .font(.title2.weight(.semibold))
                .padding(.top, 14)

            Text(Self.versionString)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Text(summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 14)

            Divider()
                .frame(width: 240)
                .padding(.vertical, 22)

            Button("Report an issue") { open(Self.issuesURL) }

            Text(
                "Status data belongs to the respective services. All trademarks, logos, and "
                + "favicons are the property of their respective owners. Activity glyph (app icon) "
                + "by Gregor Črešnar from the Noun Project."
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var summary: String {
        var text = "Monitoring \(model.enabledCount) of \(model.totalServiceCount) status pages."

        if let updated = model.definitionsUpdated {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            text += " Definitions last updated \(formatter.localizedString(for: updated, relativeTo: Date()))."
        }

        return text
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
