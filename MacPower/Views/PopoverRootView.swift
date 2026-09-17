import SwiftUI

struct PopoverRootView: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if appState.isPopoverOpen {
                let theme = AppTheme.resolved(palette: appState.settings.palette, colorScheme: colorScheme)
                content(theme: theme)
                    .padding(14)
                    .frame(width: 420)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Keep the hosting graph mounted, but never build glass / TimelineView
                // while the menu extra is idle. Interactive Liquid Glass in a hidden
                // NSPopover was burning CPU and UAFing NSViewFocusProxy ~2s after launch.
                Color.clear.frame(width: 420, height: 1)
            }
        }
        .environment(\.locale, appState.settings.resolvedLocale)
        .id(appState.settings.language)
    }

    @ViewBuilder
    private func content(theme: AppTheme) -> some View {
        if !appState.snapshot.hasBattery {
            Text(Localization.string("error.needsBattery", language: appState.settings.language))
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header(theme: theme)
                TimeEstimateRow(snapshot: appState.snapshot, language: appState.settings.language)
                EnergyFlowView(
                    snapshot: appState.snapshot,
                    theme: theme,
                    isAnimating: appState.isPopoverOpen,
                    motion: appState.settings.motionStyle,
                    motionFrameRate: appState.settings.motionFrameRate,
                    pulseFlowIcons: appState.settings.pulseFlowIcons,
                    language: appState.settings.language
                )
            }
        }
    }

    private func header(theme: AppTheme) -> some View {
        let language = appState.settings.language
        let battery = Int(appState.snapshot.percent.rounded())
        let cpu = Int(appState.metrics.cpuPercent.rounded())
        let gpu = Int(appState.metrics.gpuPercent.rounded())
        let memory = Int(appState.metrics.memoryPercent.rounded())
        return HStack(alignment: .top, spacing: 8) {
            StatusRingView(
                percent: appState.snapshot.percent,
                color: theme.batteryLevelFill(percent: appState.snapshot.percent),
                caption: Localization.string("ring.caption.battery %lld", language: language, Int64(battery)),
                accessibilityName: Localization.string("ring.battery", language: language),
                systemImage: "laptopcomputer"
            )
            StatusRingView(
                percent: appState.metrics.cpuPercent,
                color: theme.loadFill(percent: appState.metrics.cpuPercent),
                caption: Localization.string("ring.caption.cpu %lld", language: language, Int64(cpu)),
                accessibilityName: Localization.string("ring.cpu", language: language),
                systemImage: "cpu.fill"
            )
            StatusRingView(
                percent: appState.metrics.gpuPercent,
                color: theme.loadFill(percent: appState.metrics.gpuPercent),
                caption: Localization.string("ring.caption.gpu %lld", language: language, Int64(gpu)),
                accessibilityName: Localization.string("ring.gpu", language: language),
                assetImage: "GPUMark"
            )
            StatusRingView(
                percent: appState.metrics.memoryPercent,
                color: theme.loadFill(percent: appState.metrics.memoryPercent),
                caption: Localization.string("ring.caption.memory %lld", language: language, Int64(memory)),
                accessibilityName: Localization.string("ring.memory", language: language),
                systemImage: "memorychip.fill"
            )
            settingsButton
        }
    }

    private var settingsButton: some View {
        let language = appState.settings.language
        return Button {
            appState.openSettings()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 58, height: 58)
                    .glassEffect(.regular.interactive(), in: .circle)
                Text(Localization.string("settings.title", language: language))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .autoFittingCaption(minimumScale: 0.55)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .help(Localization.string("settings.title", language: language))
        .accessibilityLabel(Localization.string("settings.title", language: language))
    }
}
