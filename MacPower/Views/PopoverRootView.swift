import SwiftUI

struct PopoverRootView: View {
    @Bindable var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { timeline in
            let theme = AppTheme.resolved(palette: appState.settings.palette, colorScheme: colorScheme)
            let phase = timeline.date.timeIntervalSinceReferenceDate / 4.6
            content(theme: theme, phase: phase)
        }
        .padding(14)
        .frame(width: 348)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func content(theme: AppTheme, phase: Double) -> some View {
        if !appState.snapshot.hasBattery {
            Text("error.needsBattery")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header(theme: theme, phase: phase)
                TimeEstimateRow(snapshot: appState.snapshot)
                EnergyFlowView(snapshot: appState.snapshot, theme: theme, phase: phase)
            }
        }
    }

    private func header(theme: AppTheme, phase: Double) -> some View {
        HStack(alignment: .center, spacing: 8) {
            BatteryBarView(
                percent: appState.snapshot.percent,
                fill: theme.batteryFill(
                    percent: appState.snapshot.percent,
                    mode: appState.snapshot.flowMode,
                    lowBatteryTintEnabled: appState.settings.lowBatteryTintEnabled
                ),
                sheenPhase: phase
            )
            Button {
                appState.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .frame(width: FlowRibbon.nodeDiameter, height: FlowRibbon.nodeDiameter)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .help(String(localized: "settings.title"))
        }
        .frame(height: FlowRibbon.nodeDiameter)
    }
}
