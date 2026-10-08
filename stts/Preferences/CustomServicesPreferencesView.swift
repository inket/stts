//
//  CustomServicesPreferencesView.swift
//  stts
//

import SwiftUI
import UniformTypeIdentifiers

/// Built from the popup's grouped-list pieces rather than a `List`, for the same reason as the
/// Services pane — see `ServicesPreferencesView`.
struct CustomServicesPreferencesView: View {
    @ObservedObject var model: PreferencesModel

    @State private var editor: EditorTarget?
    @State private var alert: AlertMessage?

    var body: some View {
        Group {
            if model.customServices.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = .new
                } label: {
                    Label("Add a service", systemImage: "plus")
                }
                .help("Add a custom service")
            }
        }
        .sheet(item: $editor) { target in
            CustomServiceEditorSheet(model: model, service: target.service)
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            importFile(at: url)
            return true
        }
        .alert(item: $alert) { message in
            Alert(title: Text(message.title), message: message.detail.map(Text.init))
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Image(nsImage: PreferencesGlyph.customServices.image(size: 18))
                .renderingMode(.template)
                .foregroundStyle(.tertiary)
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.quaternary)
                )

            Text("Monitor anything with a URL")
                .font(.title3.weight(.semibold))
                .padding(.top, 14)

            Text(
                "Your internal dashboard, a vendor without a status page, a health endpoint: " +
                "stts can keep an eye on them too."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 330)
            .padding(.top, 7)

            Button("Add a service") { editor = .new }
                .buttonStyle(.borderedProminent)
                .padding(.top, 18)

            Button("or import a set you exported earlier", action: showImportPanel)
                .buttonStyle(.link)
                .font(.caption)
                .padding(.top, 12)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - The list

    private var list: some View {
        ScrollView {
            PopupGroupBox(topMargin: 0) {
                let services = Array(model.customServices.enumerated())
                ForEach(services, id: \.element.id) { index, service in
                    if index > 0 {
                        PopupRowSeparator()
                    }
                    CustomServiceRow(
                        model: model,
                        service: service,
                        onEdit: { editor = .edit(service) },
                        onDelete: { model.deleteCustomService(service) }
                    )
                }
            }
            .padding(.top, PopupLayout.Group.topMargin)
            .padding(.bottom, PopupLayout.Group.bottomMargin)
            .animation(.default, value: model.customServices.map(\.id))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
    }

    private var footer: some View {
        let count = model.customServices.count

        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Text(count == 1 ? "1 custom service" : "\(count) custom services")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Import…", action: showImportPanel)
                Button("Export…", action: showExportPanel)
            }
            .font(.caption)
            .buttonStyle(.link)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
        }
        .background(.bar)
    }

    // MARK: - Import / export

    private func showImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a file of custom services exported from stts."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(at: url)
    }

    private func importFile(at url: URL) {
        do {
            let summary = try model.importCustomServices(Data(contentsOf: url))
            alert = AlertMessage(summary)
        } catch {
            alert = AlertMessage(
                title: "Couldn't import “\(url.lastPathComponent)”",
                detail: "It isn't a custom services file exported from stts."
            )
        }
    }

    private func showExportPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "stts custom services.json"
        panel.message = "Secret header values are included in the file as plain text."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try model.exportCustomServices().write(to: url, options: .atomic)
        } catch {
            alert = AlertMessage(title: "Couldn't export custom services", detail: error.localizedDescription)
        }
    }

    private struct AlertMessage: Identifiable {
        let id = UUID()
        var title: String
        var detail: String?

        init(title: String, detail: String?) {
            self.title = title
            self.detail = detail
        }

        init(_ summary: CustomServiceStore.ImportSummary) {
            let imported = summary.addedIDs.count + summary.replacedIDs.count
            title = imported == 1 ? "Imported 1 custom service" : "Imported \(imported) custom services"

            var lines: [String] = []
            if !summary.replacedIDs.isEmpty {
                lines.append(summary.replacedIDs.count == 1
                    ? "1 replaced a service you already had."
                    : "\(summary.replacedIDs.count) replaced services you already had.")
            }
            if summary.skippedCount > 0 {
                lines.append(summary.skippedCount == 1
                    ? "1 was skipped: it needs a newer version of stts, or couldn't be read."
                    : "\(summary.skippedCount) were skipped: they need a newer version of stts, or couldn't be read.")
            }
            detail = lines.isEmpty ? nil : lines.joined(separator: " ")
        }
    }

    // MARK: - Editor

    private enum EditorTarget: Identifiable {
        case new
        case edit(CustomService)

        var id: String {
            switch self {
            case .new: return "new"
            case let .edit(service): return service.id.uuidString
            }
        }

        var service: CustomService? {
            switch self {
            case .new: return nil
            case let .edit(service): return service
            }
        }
    }
}

// MARK: - Rows

/// Unlike a Services row this one *is* a button — clicking it opens the editor — so it keeps the
/// popup's hover highlight.
private struct CustomServiceRow: View {
    @ObservedObject var model: PreferencesModel
    let service: CustomService
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var lastResult: CustomService.CheckResult? { model.customResults[service.id] }

    var body: some View {
        HStack(spacing: PopupLayout.ServiceRow.contentGap) {
            PopupFaviconChipWithDot(
                identifier: nil,
                faviconURL: nil,
                initial: service.name.first.map(String.init) ?? "?",
                dotColor: lastResult?.color ?? PopupLayout.Colors.dotUnknown
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(service.name)
                        .font(PopupLayout.Fonts.serviceName.swiftUI.weight(.semibold))
                        .foregroundStyle(PopupLayout.Colors.serviceName.swiftUI)
                        .lineLimit(1)

                    if let result = lastResult {
                        Text(result.label)
                            .font(.caption.monospaced())
                            .foregroundStyle(result.color.swiftUI)
                    }
                }

                // The method only when it isn't the default, curl-style.
                Text(service.method == .get ? service.url.absoluteString : "\(service.method.rawValue) \(service.url.absoluteString)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Rules and meta share a line while they fit; several rules push the meta below.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 5) {
                        rulesSummary
                        Text("·")
                            .foregroundStyle(.quaternary)
                        checkDetail
                    }
                    .lineLimit(1)

                    VStack(alignment: .leading, spacing: 3) {
                        rulesSummary
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        checkDetail
                            .lineLimit(1)
                    }
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if model.isCustomServiceEnabled(service) {
                NotificationOverrideMenu(
                    serviceName: service.name,
                    override: model.customServiceNotificationBinding(for: service),
                    inherited: model.preferences.notificationGranularity
                )
            }

            Toggle("", isOn: model.customServiceEnabledBinding(for: service))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(PopupLayout.ServiceRow.padding)
        .background(isHovering ? PopupLayout.Colors.groupBackgroundHover.swiftUI : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button("Edit…", action: onEdit)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(service.name)
        .accessibilityAction(named: "Edit", onEdit)
    }

    private var rulesSummary: some View {
        Text(service.rulesSummary)
            .foregroundStyle(.secondary)
    }

    /// Re-rendered every 30 seconds so "Checked 2 minutes ago" keeps up.
    private var checkDetail: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Group {
                if let result = lastResult {
                    let when = result.date.formatted(.relative(presentation: .named, unitsStyle: .wide))
                    let detail = Text(result.detail).foregroundStyle(
                        result.isMissingSecret
                            ? AnyShapeStyle(PopupLayout.Colors.dotMinor.swiftUI)
                            : AnyShapeStyle(.tertiary)
                    )
                    Text("Checked \(context.date.timeIntervalSince(result.date) < 60 ? "just now" : when) · \(detail)")
                } else if model.isCustomServiceEnabled(service) {
                    Text("Not checked yet")
                } else {
                    Text("Off")
                }
            }
            .foregroundStyle(.tertiary)
        }
    }
}
