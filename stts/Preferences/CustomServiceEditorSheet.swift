//
//  CustomServiceEditorSheet.swift
//  stts
//

import SwiftUI

/// Fields are local state until Add/Save, so Cancel discards the edit.
///
/// Test now sends one real request for the draft as it stands. It's advice, not a gate — Add never
/// waits on it.
struct CustomServiceEditorSheet: View {
    @ObservedObject var model: PreferencesModel
    /// `nil` when adding.
    let original: CustomService?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var urlString: String
    @State private var method: CustomService.Method
    @State private var followsRedirects: Bool
    @State private var requestBody: String
    @State private var requestHeaders: [CustomService.Header]
    @State private var isShowingAdvanced = false
    @State private var interval: Int?
    @State private var rules: [CustomService.Rule]
    @State private var matching: CustomService.Matching
    @State private var testResult: CustomService.CheckResult?
    @State private var isTesting = false
    /// Secrets that were saved but came back empty from the Keychain.
    private let missingSecretIDs: Set<UUID>

    fileprivate static let width: CGFloat = 470
    private static let maxRules = 5
    fileprivate static let footerInset: CGFloat = 10
    fileprivate static let rowHeight: CGFloat = 38
    /// Name/URL/Check every, the Advanced… and Add rule footers, and the rules header.
    private static let baseFormHeight: CGFloat = 300

    init(model: PreferencesModel, service: CustomService?) {
        self.model = model
        self.original = service
        _name = State(initialValue: service?.name ?? "")
        _urlString = State(initialValue: service?.url.absoluteString ?? "")
        _method = State(initialValue: service?.method ?? .get)
        _followsRedirects = State(initialValue: service?.followsRedirects ?? true)
        _requestBody = State(initialValue: service?.requestBody ?? "")
        _requestHeaders = State(initialValue: service?.requestHeaders ?? [])
        _interval = State(initialValue: service?.interval)
        _rules = State(initialValue: service?.rules ?? [CustomService.Rule(kind: .status, value: "200")])
        _matching = State(initialValue: service?.matching ?? .all)
        missingSecretIDs = Set(
            (service?.requestHeaders ?? [])
                .filter { $0.isSecret && $0.value.isEmpty && !$0.name.isEmpty }
                .map(\.id)
        )
    }

    private var isEditing: Bool { original != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isEditing ? "Edit custom service" : "New custom service")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 18)

            form

            if let testResult {
                CheckResultChip(result: testResult)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            buttons
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .frame(width: Self.width)
        .sheet(isPresented: $isShowingAdvanced) {
            AdvancedRequestSheet(
                method: $method,
                followsRedirects: $followsRedirects,
                requestBody: $requestBody,
                requestHeaders: $requestHeaders,
                missingSecretIDs: missingSecretIDs
            )
        }
    }

    private var form: some View {
        Form {
            Section {
                TextField("Name", text: $name, prompt: Text("Required"))
                // `verbatim:` — as a string literal it's Markdown, and the URL came out as a link.
                TextField("URL", text: $urlString, prompt: Text(verbatim: "https://example.com/health"))
                Picker("Check every", selection: $interval) {
                    ForEach(CustomService.intervalOptions, id: \.self) { seconds in
                        Text(CustomService.intervalTitle(seconds)).tag(seconds)
                    }
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("Advanced…") { isShowingAdvanced = true }
                }
                .padding(.trailing, -Self.footerInset)
            }

            Section {
                ForEach(rules) { rule in
                    RuleRow(
                        rule: binding(for: rule, in: $rules),
                        kinds: availableKinds(for: rule),
                        note: note(for: rule),
                        canRemove: rules.count > 1
                    ) {
                        rules.removeAll { $0.id == rule.id }
                    }
                }
            } header: {
                HStack(spacing: 4) {
                    Text("Healthy when")
                    if rules.count > 1 {
                        PlainMenuPicker(
                            "Rules that must pass",
                            selection: $matching,
                            options: CustomService.Matching.allCases,
                            title: \.title
                        )
                        Text("of these rules pass")
                    }
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("Add rule", systemImage: "plus", action: addRule)
                        .disabled(rules.count >= Self.maxRules)
                }
                // A grouped `Form` insets footer content like row content; this puts the button's
                // edge on the card's instead.
                .padding(.trailing, -Self.footerInset)
            }
        }
        .formStyle(.grouped)
        .frame(height: formHeight)
        .animation(.default, value: rules.map(\.id))
    }

    /// A grouped `Form` scrolls, so it has no height of its own to offer a sheet. This grows it a
    /// row per rule (rules with small print are taller) and lets it scroll past the cap.
    private var formHeight: CGFloat {
        let rules = rules.reduce(CGFloat(0)) { total, rule in
            total + (rule.kind.note == nil ? 38 : 54)
        }
        return min(Self.baseFormHeight + rules, 560)
    }

    /// The kind's own small print, or why the rule can't work with the chosen method.
    private func note(for rule: CustomService.Rule) -> RuleRow.Note? {
        if rule.kind.readsBody, !method.hasResponseBody {
            return RuleRow.Note(text: "HEAD responses have no body; use GET or POST", isWarning: true)
        }
        return rule.kind.note.map { RuleRow.Note(text: $0, isWarning: false) }
    }

    /// A non-repeatable kind is only offered to the rule that already has it, or to every rule
    /// while none does.
    private func availableKinds(for rule: CustomService.Rule) -> [CustomService.Rule.Kind] {
        let takenElsewhere = Set(rules.filter { $0.id != rule.id }.map(\.kind))
        return CustomService.Rule.Kind.allCases.filter { $0.isRepeatable || !takenElsewhere.contains($0) }
    }

    /// The first kind not already used, so a second rule doesn't start as a duplicate of the first.
    private func addRule() {
        let used = Set(rules.map(\.kind))
        let kind = CustomService.Rule.Kind.allCases.first { !used.contains($0) } ?? .contains
        rules.append(CustomService.Rule(kind: kind, value: ""))
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            if isEditing {
                Button("Delete", role: .destructive, action: delete)
            }

            Button("Test now", action: test)
                .disabled(draft == nil || isTesting)

            if isTesting {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button(isEditing ? "Save" : "Add service", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(draft == nil)
        }
    }

    // MARK: - Validation

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// An http(s) URL with a host; anything else can't be requested.
    private var validURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else { return nil }
        return url
    }

    /// The service as the fields describe it, or `nil` while they don't describe a valid one.
    private var draft: CustomService? {
        let rules = rules.map(\.normalized)
        guard
            !trimmedName.isEmpty,
            let url = validURL,
            rules.allSatisfy(\.isValid),
            !hasDuplicateUniqueKind(rules),
            url.scheme?.lowercased() == "https" || !rules.contains(where: { $0.kind == .certificate }),
            method.hasResponseBody || !rules.contains(where: \.kind.readsBody),
            requestHeaders.map(\.trimmed).filter({ !$0.isEmpty }).allSatisfy(\.hasValidName),
            !hasDuplicateSecretName
        else { return nil }

        let requestBody = method.sendsBody ? requestBody : ""
        let requestHeaders = requestHeaders.map(\.trimmed).filter { !$0.isEmpty }

        return CustomService(
            id: original?.id ?? UUID(),
            name: trimmedName,
            url: url,
            method: method,
            followsRedirects: followsRedirects,
            requestBody: requestBody,
            requestHeaders: requestHeaders,
            interval: interval,
            rules: rules,
            matching: matching
        )
    }

    /// A secret's Keychain item is keyed by its header name, so two secrets can't share one.
    private var hasDuplicateSecretName: Bool {
        let names = requestHeaders.filter(\.isSecret).map { $0.trimmed.name.lowercased() }
        return Set(names).count != names.count
    }

    private func test() {
        guard let draft else { return }
        isTesting = true
        Task {
            testResult = await model.testCustomService(draft)
            isTesting = false
        }
    }

    private func hasDuplicateUniqueKind(_ rules: [CustomService.Rule]) -> Bool {
        let unique = rules.map(\.kind).filter { !$0.isRepeatable }
        return Set(unique).count != unique.count
    }

    private func delete() {
        if let original { model.deleteCustomService(original) }
        dismiss()
    }

    private func save() {
        guard let draft else { return }
        if isEditing {
            model.updateCustomService(draft)
        } else {
            model.addCustomService(draft)
        }
        dismiss()
    }
}

/// Writes straight through to the editor's state, so there's nothing to commit here — the editor's
/// Cancel still discards these changes with the rest.
private struct AdvancedRequestSheet: View {
    @Binding var method: CustomService.Method
    @Binding var followsRedirects: Bool
    @Binding var requestBody: String
    @Binding var requestHeaders: [CustomService.Header]
    let missingSecretIDs: Set<UUID>

    @Environment(\.dismiss) private var dismiss

    private static let bodyEditorHeight: CGFloat = 80
    private static let headerRowHeight: CGFloat = 64
    /// Follow redirects/Method, the Headers section header and the Add header footer.
    private static let baseFormHeight: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Advanced")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 18)

            form

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: CustomServiceEditorSheet.width)
    }

    private var form: some View {
        Form {
            Section {
                Toggle("Follow redirects", isOn: $followsRedirects)
                Picker("Method", selection: $method) {
                    ForEach(CustomService.Method.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                if method.sendsBody {
                    bodyEditor
                }
            }

            Section {
                if requestHeaders.isEmpty {
                    Text("No headers")
                        .foregroundStyle(.secondary)
                }
                ForEach(requestHeaders) { header in
                    HeaderRow(
                        header: binding(for: header, in: $requestHeaders),
                        isMissingFromKeychain: header.isMissingFromKeychain(missingAtOpen: missingSecretIDs)
                    ) {
                        requestHeaders.removeAll { $0.id == header.id }
                    }
                }
            } header: {
                Text("Headers")
            } footer: {
                HStack {
                    Text("Secret headers are stored in the system keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add header", systemImage: "plus") {
                        requestHeaders.append(CustomService.Header(name: "", value: ""))
                    }
                }
                .padding(.trailing, -CustomServiceEditorSheet.footerInset)
            }
        }
        .formStyle(.grouped)
        .frame(height: formHeight)
        .animation(.default, value: requestHeaders.map(\.id))
        .animation(.default, value: method.sendsBody)
    }

    /// A two-line row per header (fields, then Secret), "No headers" when there are none, and the
    /// body editor for POST.
    private var formHeight: CGFloat {
        let rowHeight = CustomServiceEditorSheet.rowHeight
        var height = Self.baseFormHeight
        height += requestHeaders.isEmpty ? rowHeight : CGFloat(requestHeaders.count) * Self.headerRowHeight
        if method.sendsBody { height += Self.bodyEditorHeight + 40 }
        return min(height, 520)
    }

    /// A `TextEditor` rather than a vertical-axis `TextField`: in the latter, Return triggers the
    /// sheet's default button instead of starting a new line.
    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Body")
            TextEditor(text: $requestBody)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                .scrollContentBackground(.hidden)
                // `TextEditor` has no prompt; the offset matches the text view's line fragment
                // padding so the placeholder sits where typing starts.
                .overlay(alignment: .topLeading) {
                    if requestBody.isEmpty {
                        Text("Request body")
                            .font(.body.monospaced())
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .padding(4)
                .frame(height: Self.bodyEditorHeight)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
                .accessibilityLabel("Body")
        }
    }
}

private extension CustomService.Header {
    /// `missingAtOpen` is fixed when the editor opens, so a header marked secret there, not yet
    /// given a value, isn't mistaken for one.
    func isMissingFromKeychain(missingAtOpen: Set<UUID>) -> Bool {
        missingAtOpen.contains(id) && isSecret && value.isEmpty
    }
}

/// A row's binding, found by id rather than position. `ForEach($array)` hands out bindings by
/// index, and after a removal a row on its way out — or a field committing its edit — still writes
/// through one past the end of the array: "Index out of range". Once the item is gone, reads fall
/// back to its last value and writes are dropped.
private func binding<Item: Identifiable>(for item: Item, in items: Binding<[Item]>) -> Binding<Item> {
    Binding(
        get: { items.wrappedValue.first { $0.id == item.id } ?? item },
        set: { newValue in
            guard let index = items.wrappedValue.firstIndex(where: { $0.id == item.id }) else { return }
            items.wrappedValue[index] = newValue
        }
    )
}

private struct HeaderRow: View {
    @Binding var header: CustomService.Header
    let isMissingFromKeychain: Bool
    let onRemove: () -> Void

    private static let spacing: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            fields
            secretToggle
        }
    }

    private var fields: some View {
        HStack(spacing: Self.spacing) {
            TextField("Name", text: $header.name, prompt: Text(verbatim: "Content-Type"))
                .labelsHidden()
                .font(.body.monospaced())
                .foregroundStyle(header.name.isEmpty || header.trimmed.hasValidName ? .primary : warningColor)
                .frame(width: 140)
            Group {
                if header.isSecret {
                    SecureField("Value", text: $header.value, prompt: Text(verbatim: "Value"))
                } else {
                    TextField("Value", text: $header.value, prompt: Text(verbatim: "application/json"))
                }
            }
            .labelsHidden()
            .font(.body.monospaced())
            .multilineTextAlignment(.trailing)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Remove this header")
            .accessibilityLabel("Remove header")
        }
    }

    private var secretToggle: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.spacing) {
            Toggle("Secret", isOn: $header.isSecret)
                .toggleStyle(.checkbox)
                .help("Keep the value in the Keychain instead of the services file")

            Spacer(minLength: 0)

            if isMissingFromKeychain {
                Text("Not found in the system keychain. Please provide the value.")
                    .font(.caption)
                    .foregroundStyle(warningColor)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var warningColor: Color { PopupLayout.Colors.dotMinor.swiftUI }
}

private struct RuleRow: View {
    @Binding var rule: CustomService.Rule
    struct Note {
        let text: String
        let isWarning: Bool
    }

    let kinds: [CustomService.Rule.Kind]
    let note: Note?
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            controls

            // Under the whole row rather than just the kind menu, so a long note doesn't squeeze
            // the value field.
            if let note {
                Text(note.text)
                    .font(.caption)
                    .foregroundStyle(note.isWarning ? PopupLayout.Colors.dotMinor.swiftUI : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var controls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            PlainMenuPicker(
                "Rule",
                selection: $rule.kind,
                options: kinds,
                title: \.title
            )

            TextField("Value", text: $rule.value, prompt: Text(verbatim: rule.kind.prompt))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                // Filtered after the fact rather than in a custom binding: a binding that rejects a
                // keystroke leaves the value unchanged, so SwiftUI never refreshes the field and
                // the rejected character stays on screen.
                .onChange(of: rule.value) { _, newValue in
                    let filtered = rule.kind.filtered(newValue)
                    if filtered != newValue { rule.value = filtered }
                }
                .onChange(of: rule.kind) { _, newKind in
                    rule.value = newKind.filtered(rule.value)
                }

            if let unit = rule.kind.unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove this rule")
                .accessibilityLabel("Remove rule")
            }
        }
    }
}

/// A picker drawn as its current value plus a chevron, with no bezel. A bare `Picker`'s bezel insets
/// its title, which then sat out of line with the form's labels.
private struct PlainMenuPicker<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [Value]
    let title: (Value) -> String

    init(_ label: String, selection: Binding<Value>, options: [Value], title: @escaping (Value) -> String) {
        self.label = label
        _selection = selection
        self.options = options
        self.title = title
    }

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(title(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 4) {
                Text(title(selection))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(label)
    }
}

struct CheckResultChip: View {
    let result: CustomService.CheckResult

    var body: some View {
        HStack(spacing: 10) {
            Text(verdictTitle)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(result.color.swiftUI)
            Text(result.verdict == .noAnswer ? result.detail : "\(result.label) · \(result.detail)")
                .font(.caption.monospaced())
                .foregroundStyle(
                    result.isMissingSecret
                        ? AnyShapeStyle(PopupLayout.Colors.dotMinor.swiftUI)
                        : AnyShapeStyle(.secondary)
                )
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            result.color.swiftUI.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
    }

    private var verdictTitle: String {
        switch result.verdict {
        case .healthy: return "HEALTHY"
        case .failed: return "FAILED"
        case .noAnswer: return "NO ANSWER"
        }
    }
}
