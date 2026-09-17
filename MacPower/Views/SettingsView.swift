import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        form
            .environment(\.locale, appState.settings.resolvedLocale)
            .id(appState.settings.language)
            .onChange(of: appState.settings.language) { _, _ in
                appState.refreshLocalizedChrome()
            }
    }

    private var form: some View {
        Form {
            Section("settings.section.icon") {
                Picker("settings.icon.style", selection: $appState.settings.iconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(LocalizedStringKey(style.localizationKey)).tag(style)
                    }
                }
                Toggle("settings.icon.chargeGlyphs", isOn: $appState.settings.showChargeGlyphs)
            }

            Section("settings.section.appearance") {
                Picker("settings.palette", selection: $appState.settings.palette) {
                    ForEach(ThemePalette.allCases) { palette in
                        Text(LocalizedStringKey(palette.localizationKey)).tag(palette)
                    }
                }
                Toggle("settings.lowBatteryTint", isOn: $appState.settings.lowBatteryTintEnabled)
                Toggle("settings.popover.arrow", isOn: $appState.settings.showPopoverArrow)
                    .onChange(of: appState.settings.showPopoverArrow) { _, _ in
                        appState.onPopoverChromeChange?()
                    }
            }

            Section {
                Picker("settings.motion.style", selection: $appState.settings.motionStyle) {
                    ForEach(EnergyMotionStyle.allCases) { style in
                        Text(LocalizedStringKey(style.localizationKey)).tag(style)
                    }
                }
                Picker("settings.motion.frameRate", selection: $appState.settings.motionFrameRate) {
                    ForEach(EnergyMotionFrameRate.allCases) { rate in
                        Text(rate.title).tag(rate)
                    }
                }
                .disabled(appState.settings.motionStyle == .off)
                Toggle("settings.motion.pulseIcons", isOn: $appState.settings.pulseFlowIcons)
            } header: {
                Text("settings.section.motion")
            }

            Section("settings.section.general") {
                Picker(selection: $appState.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(title(for: language)).tag(language)
                    }
                } label: {
                    Text("settings.language") + Text("（文/A）")
                }
                Toggle("settings.launchAtLogin", isOn: launchAtLoginBinding)
            }

            Section {
                Button("settings.quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: true, vertical: true)
        .navigationTitle("settings.title")
    }

    private func title(for language: AppLanguage) -> String {
        if language == .system {
            return Localization.string("settings.language.system", language: appState.settings.language)
        }
        return language.nativeName
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginEnabled },
            set: { appState.setLaunchAtLogin($0) }
        )
    }
}
