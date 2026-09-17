import SwiftUI

struct TimeEstimateRow: View {
    var snapshot: PowerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !snapshot.externalConnected {
                labeledRow(
                    title: String(localized: "estimate.runtime"),
                    value: runtimeText
                )
            }
            if snapshot.externalConnected {
                labeledRow(
                    title: String(localized: "estimate.full"),
                    value: fullText
                )
            }
        }
        .font(.callout)
    }

    private var runtimeText: String {
        guard let minutes = snapshot.timeToEmptyMinutes else {
            return String(localized: "estimate.calculating")
        }
        return String(localized: "estimate.about \(DurationFormatter.string(minutes: minutes))")
    }

    private var fullText: String {
        guard snapshot.isCharging, let minutes = snapshot.timeToFullMinutes else {
            return "—"
        }
        return String(localized: "estimate.about \(DurationFormatter.string(minutes: minutes))")
    }

    private func labeledRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

enum DurationFormatter {
    static func string(minutes: Int) -> String {
        let hours = minutes / 60
        let remain = minutes % 60
        if hours > 0 && remain > 0 {
            return String(localized: "duration.hoursMinutes \(hours) \(remain)")
        }
        if hours > 0 {
            return String(localized: "duration.hours \(hours)")
        }
        return String(localized: "duration.minutes \(remain)")
    }
}
