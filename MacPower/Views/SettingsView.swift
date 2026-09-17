import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        Form {
            Section(String(localized: "settings.section.icon")) {
                Picker(String(localized: "settings.icon.style"), selection: $appState.settings.iconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(LocalizedStringKey(style.localizationKey)).tag(style)
                    }
                }
                Toggle(String(localized: "settings.icon.chargeGlyphs"), isOn: $appState.settings.showChargeGlyphs)
            }

            Section(String(localized: "settings.section.appearance")) {
                Picker(String(localized: "settings.palette"), selection: $appState.settings.palette) {
                    ForEach(ThemePalette.allCases) { palette in
                        Text(LocalizedStringKey(palette.localizationKey)).tag(palette)
                    }
                }
                Toggle(String(localized: "settings.lowBatteryTint"), isOn: $appState.settings.lowBatteryTintEnabled)
            }

            Section(String(localized: "settings.section.general")) {
                Toggle(String(localized: "settings.launchAtLogin"), isOn: launchAtLoginBinding)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
        .navigationTitle(String(localized: "settings.title"))
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.launchAtLoginEnabled },
            set: { appState.setLaunchAtLogin($0) }
        )
    }
}
