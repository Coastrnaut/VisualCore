// SettingsView — feature 190 T-U04-011 (FR-U04-050 to FR-U04-053; research R4, R6; data-model sections 1, 4, 5).
// The settings route: the shared reduce-motion and reduce-flashing section, the quality override, the reset of
// one experience's data and of all data (each asks first) and the privacy statement.
import SwiftUI
import VisualCoreExperience
import VisualCoreSimulation
import VisualCoreUI

/// The settings form.
struct SettingsView: View {
    let model: AppModel
    @State private var system = SystemAccessibilityObserver()
    @State private var pending: PendingReset?
    @State private var confirmed: ResetPlan?

    /// A reset that waits for its confirmation.
    struct PendingReset: Identifiable {
        let plan: ResetPlan
        let question: String
        var id: String {
            switch plan {
            case .experience(let id): id.rawValue
            case .all: "all"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                RouteBackRow(title: AppStrings.text(.navDone), identifier: ShellID.navDone) { model.go(.catalog) }
            }
            AccessibilitySettingsSection(preferences: accessibility, system: system.current,
                                         identifierPrefix: ShellID.settingsPrefix)
            qualitySection
            dataSection
            Section(AppStrings.text(.settingsPrivacyHeader)) {
                Text(AppStrings.text(.settingsPrivacy))
                    .font(.body)
                    .accessibilityIdentifier(ShellID.settingsPrivacy)
            }
            #if DEBUG
            Section(AppStrings.text(.settingsDiagnosticsHeader)) {
                Text(verbatim: model.diagnostics.text)
                    .font(.footnote)
                    .accessibilityIdentifier(ShellID.diagnostics)
            }
            #endif
        }
        .headerProminence(.increased)
        .routeRoot(ShellID.routeSettings)
        .navigationTitle(AppStrings.text(.settingsTitle))
        .navigationBarBackButtonHidden(true)
        .onAppear { model.refreshDataNamespaces() }
        .sheet(item: $pending, onDismiss: carryOut) { request in
            ResetConfirmationView(question: request.question) {
                confirmed = request.plan
                pending = nil
            } onCancel: {
                confirmed = nil
                pending = nil
            }
        }
    }

    /// Runs the confirmed reset once the confirmation is gone, so that no presentation is in the way when a
    /// reset of all data brings the welcome back.
    private func carryOut() {
        guard let plan = confirmed else { return }
        confirmed = nil
        model.reset(plan)
    }

    // MARK: Accessibility choices

    /// The two stored choices as the value the shared section edits.
    private var accessibility: Binding<AccessibilityPreferences> {
        Binding(get: {
            AccessibilityPreferences(reduceMotion: Self.shared(model.preferences.reduceMotion),
                                     reduceFlashing: Self.shared(model.preferences.reduceFlashing))
        }, set: { value in
            model.setAccessibility(reduceMotion: Self.stored(value.reduceMotion),
                                   reduceFlashing: Self.stored(value.reduceFlashing))
        })
    }

    /// The choice type the preferences store (module VisualCoreExperience).
    typealias StoredChoice = VisualCoreExperience.AccessibilityChoice
    /// The choice type the shared settings section edits (module VisualCoreSimulation); same three cases.
    typealias SharedChoice = VisualCoreSimulation.AccessibilityChoice

    /// The shell's choice as the choice of the shared settings section.
    nonisolated static func shared(_ choice: StoredChoice) -> SharedChoice {
        switch choice {
        case .system: .system
        case .on: .on
        case .off: .off
        }
    }

    /// The choice of the shared settings section as the shell's choice.
    nonisolated static func stored(_ choice: SharedChoice) -> StoredChoice {
        switch choice {
        case .system: .system
        case .on: .on
        case .off: .off
        }
    }

    // MARK: Quality

    /// The picker's tag for automatic; the tiers are their own numbers.
    private static let automatic = -1

    private var quality: Binding<Int> {
        Binding(get: { model.preferences.qualityOverride ?? Self.automatic },
                set: { model.setQualityOverride($0 == Self.automatic ? nil : $0) })
    }

    private func qualityTitle(_ tag: Int) -> String {
        tag == Self.automatic ? AppStrings.text(.settingsQualityAutomatic) : String(tag)
    }

    private var qualitySection: some View {
        Section(AppStrings.text(.settingsQualityHeader)) {
            Picker(AppStrings.text(.settingsQuality), selection: quality) {
                Text(qualityTitle(Self.automatic)).tag(Self.automatic)
                ForEach(Array(ShellPreferences.qualityRange), id: \.self) { tier in
                    Text(qualityTitle(tier)).tag(tier)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(ShellID.settingsQuality)
            .accessibilityValue(Text(qualityTitle(quality.wrappedValue)))
            Text(AppStrings.text(.settingsQualityNote))
                .font(.footnote)
        }
    }

    // MARK: Reset

    private var dataSection: some View {
        Section(AppStrings.text(.settingsDataHeader)) {
            ForEach(model.dataNamespaces.compactMap(ExperienceID.init(rawValue:)), id: \.self) { id in
                let name = model.descriptor(for: id)?.title ?? id.rawValue
                resetButton(AppStrings.text(.settingsResetOne, name),
                            identifier: ShellID.settingsResetPrefix + id.rawValue,
                            request: PendingReset(plan: .experience(id),
                                                  question: AppStrings.text(.settingsResetOneQuestion, name)))
            }
            resetButton(AppStrings.text(.settingsResetAll), identifier: ShellID.settingsResetAll,
                        request: PendingReset(plan: .all, question: AppStrings.text(.settingsResetAllQuestion)))
        }
    }

    private func resetButton(_ title: String, identifier: String, request: PendingReset) -> some View {
        Button {
            pending = request
        } label: {
            // The warning is carried by the symbol and the confirmation that follows, not by a red text colour, which
            // does not reach the contrast the accessibility audit asks for on a grouped background.
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(uiColor: .label))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier(identifier)
    }
}

/// The confirmation of a reset: the question, the warning and the two answers.
struct ResetConfirmationView: View {
    let question: String
    let onConfirm: @MainActor () -> Void
    let onCancel: @MainActor () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(question)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(AppStrings.text(.settingsResetWarning))
                    .font(.body)
                Button(role: .destructive, action: onConfirm) {
                    Text(AppStrings.text(.settingsResetConfirm))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(ShellID.settingsResetConfirm)
                Button(action: onCancel) {
                    Text(AppStrings.text(.settingsResetCancel))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(ShellID.settingsResetCancel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .presentationDetents([.medium, .large])
    }
}
