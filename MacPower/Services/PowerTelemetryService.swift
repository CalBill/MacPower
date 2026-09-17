import Foundation
import IOKit
import IOKit.ps

struct BatteryReading: Equatable, Sendable {
    var hasBattery: Bool
    var percent: Double
    var isCharging: Bool
    var externalConnected: Bool
    var fullyCharged: Bool
    var adapterCeilingWatts: Double
    var adapterInWatts: Double
    var systemLoadWatts: Double
    var batteryWatts: Double
    var remainingCapacityWh: Double
    var missingCapacityWh: Double
    var systemTimeToEmptyMinutes: Int?
    var systemTimeToFullMinutes: Int?
    var instantAmperageMilli: Int
}

enum BatteryReader: Sendable {
    static func read() -> BatteryReading? {
        readSmartBattery() ?? readPowerSources()
    }

    private static func readSmartBattery() -> BatteryReading? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let nsProps = propsRef?.takeRetainedValue() as? [String: Any]
        else {
            return nil
        }

        let hasBattery = bool(nsProps["BatteryInstalled"]) ?? true
        let external = bool(nsProps["ExternalConnected"]) ?? false
        let isCharging = bool(nsProps["IsCharging"]) ?? chargerIsCharging(nsProps)
        let fullyCharged = bool(nsProps["FullyCharged"]) ?? false
        let percent = double(nsProps["CurrentCapacity"]) ?? 0
        let voltageMilli = double(nsProps["Voltage"]) ?? 0
        let instantAmperage = signedMilliAmps(nsProps["InstantAmperage"]) ?? signedMilliAmps(nsProps["Amperage"]) ?? 0

        let adapter = nsProps["AdapterDetails"] as? [String: Any]
        let adapterCeiling = double(adapter?["Watts"]) ?? 0

        let telemetry = nsProps["PowerTelemetryData"] as? [String: Any]
        let systemLoad = milliwattsToWatts(telemetry?["SystemLoad"])
        let systemPowerIn = milliwattsToWatts(telemetry?["SystemPowerIn"])
        let telemetryBattery = milliwattsToWatts(telemetry?["BatteryPower"])

        let viWatts = (Double(instantAmperage) * voltageMilli) / 1_000_000
        let batteryWatts = telemetryBattery ?? viWatts
        let adapterIn = systemPowerIn ?? max(0, abs(viWatts) + max(0, systemLoad ?? 0))
        let load: Double
        if let systemLoad {
            load = systemLoad
        } else if isCharging {
            load = max(0, adapterIn - max(0, batteryWatts))
        } else {
            load = abs(min(0, batteryWatts))
        }

        let batteryData = nsProps["BatteryData"] as? [String: Any]
        let remainingMilliAh = double(batteryData?["RemainingCapacity"])
            ?? double(nsProps["AppleRawCurrentCapacity"])
            ?? 0
        let fullMilliAh = double(batteryData?["FullChargeCapacity"])
            ?? double(nsProps["AppleRawMaxCapacity"])
            ?? 0
        let remainingWh = TimeEstimateService.wattHours(
            milliAmpHours: remainingMilliAh,
            voltageMilli: voltageMilli,
            preferNominal: isCharging || external
        )
        let fullWh = TimeEstimateService.wattHours(
            milliAmpHours: fullMilliAh,
            voltageMilli: voltageMilli,
            preferNominal: true
        )
        let missingWh = max(0, fullWh - remainingWh)

        var timeToEmpty = sanitized(int(nsProps["AvgTimeToEmpty"]))
        var timeToFull = sanitized(int(nsProps["AvgTimeToFull"]))
            ?? sanitized(isCharging ? int(nsProps["TimeRemaining"]) : nil)
        if !isCharging, timeToEmpty == nil {
            timeToEmpty = sanitized(int(nsProps["TimeRemaining"]))
        }
        if let iops = iopsTimes() {
            if timeToEmpty == nil { timeToEmpty = iops.empty }
            if timeToFull == nil { timeToFull = iops.full }
        }

        return BatteryReading(
            hasBattery: hasBattery,
            percent: min(100, max(0, percent)),
            isCharging: isCharging,
            externalConnected: external,
            fullyCharged: fullyCharged,
            adapterCeilingWatts: adapterCeiling,
            adapterInWatts: adapterIn,
            systemLoadWatts: load,
            batteryWatts: batteryWatts,
            remainingCapacityWh: remainingWh,
            missingCapacityWh: missingWh,
            systemTimeToEmptyMinutes: timeToEmpty,
            systemTimeToFullMinutes: timeToFull,
            instantAmperageMilli: instantAmperage
        )
    }

    private static func readPowerSources() -> BatteryReading? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let type = desc[kIOPSTypeKey] as? String
            guard type == kIOPSInternalBatteryType else { continue }

            let percent = double(desc[kIOPSCurrentCapacityKey]) ?? 0
            let isCharging = bool(desc[kIOPSIsChargingKey]) ?? false
            let state = desc[kIOPSPowerSourceStateKey] as? String
            let external = state == kIOPSACPowerValue
            let timeToEmpty = sanitized(int(desc[kIOPSTimeToEmptyKey]))
            let timeToFull = sanitized(int(desc[kIOPSTimeToFullChargeKey]))

            return BatteryReading(
                hasBattery: true,
                percent: percent,
                isCharging: isCharging,
                externalConnected: external,
                fullyCharged: percent >= 99.5 && external && !isCharging,
                adapterCeilingWatts: 0,
                adapterInWatts: 0,
                systemLoadWatts: 0,
                batteryWatts: 0,
                remainingCapacityWh: 0,
                missingCapacityWh: 0,
                systemTimeToEmptyMinutes: timeToEmpty,
                systemTimeToFullMinutes: timeToFull,
                instantAmperageMilli: isCharging ? 1 : (external ? 0 : -1)
            )
        }
        return nil
    }

    private static func iopsTimes() -> (empty: Int?, full: Int?)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }
        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }
            return (
                empty: sanitized(int(desc[kIOPSTimeToEmptyKey])),
                full: sanitized(int(desc[kIOPSTimeToFullChargeKey]))
            )
        }
        return nil
    }

    private static func milliwattsToWatts(_ value: Any?) -> Double? {
        guard let milli = signedMilli(value) else { return nil }
        if abs(milli) > 250 {
            return milli / 1000
        }
        return milli
    }

    private static func signedMilli(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber else { return nil }
        let uint = number.uint64Value
        if uint > UInt64(Int64.max) {
            return Double(Int64(bitPattern: uint))
        }
        return number.doubleValue
    }

    private static func signedMilliAmps(_ value: Any?) -> Int? {
        guard let milli = signedMilli(value) else { return nil }
        return Int(milli.rounded())
    }

    private static func sanitized(_ value: Int?) -> Int? {
        TimeEstimateService.sanitizedSystemMinutes(value)
    }

    private static func chargerIsCharging(_ props: [String: Any]) -> Bool {
        let charger = props["ChargerData"] as? [String: Any]
        return bool(charger?["IsCharging"]) ?? false
    }

    private static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber: number.boolValue
        case let flag as Bool: flag
        default: nil
        }
    }

    private static func int(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private static func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

@MainActor
final class PowerTelemetryService {
    private var liveTimer: Timer?
    private var idleTimer: Timer?
    private var powerSourceLoop: CFRunLoopSource?
    private var smoothed: PowerSnapshot?
    private var estimateLoadWatts: Double?
    private var popoverOpen = false

    var onChange: ((PowerSnapshot) -> Void)?

    func start() {
        refresh(smooth: false)
        listenForPowerSourceChanges()
        scheduleIdleTimer()
    }

    func setPopoverOpen(_ open: Bool) {
        popoverOpen = open
        liveTimer?.invalidate()
        liveTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil

        if open {
            refresh(smooth: true)
            liveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh(smooth: true)
                }
            }
            liveTimer?.tolerance = 0.1
        } else {
            scheduleIdleTimer()
        }
    }

    func stop() {
        liveTimer?.invalidate()
        idleTimer?.invalidate()
        liveTimer = nil
        idleTimer = nil
        if let powerSourceLoop {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceLoop, .defaultMode)
            self.powerSourceLoop = nil
        }
    }

    private func scheduleIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(smooth: true)
            }
        }
        idleTimer?.tolerance = 2
    }

    private func listenForPowerSourceChanges() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let service = Unmanaged<PowerTelemetryService>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                service.refresh(smooth: false)
            }
        }, context)?.takeRetainedValue() else {
            return
        }
        powerSourceLoop = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func refresh(smooth: Bool) {
        guard let reading = BatteryReader.read() else {
            onChange?(.empty)
            return
        }

        let mode = EnergyFlowMode.derive(
            hasBattery: reading.hasBattery,
            externalConnected: reading.externalConnected,
            isCharging: reading.isCharging,
            instantAmperageMilli: reading.instantAmperageMilli,
            batteryWatts: reading.batteryWatts
        )

        var snapshot = PowerSnapshot(
            hasBattery: reading.hasBattery,
            percent: reading.percent,
            isCharging: reading.isCharging,
            externalConnected: reading.externalConnected,
            fullyCharged: reading.fullyCharged,
            adapterCeilingWatts: reading.adapterCeilingWatts,
            adapterInWatts: reading.adapterInWatts,
            systemLoadWatts: reading.systemLoadWatts,
            batteryWatts: reading.batteryWatts,
            remainingCapacityWh: reading.remainingCapacityWh,
            missingCapacityWh: reading.missingCapacityWh,
            systemTimeToEmptyMinutes: reading.systemTimeToEmptyMinutes,
            systemTimeToFullMinutes: reading.systemTimeToFullMinutes,
            timeToEmptyMinutes: nil,
            timeToFullMinutes: nil,
            flowMode: mode
        )

        let instantEstimateLoad = max(snapshot.systemLoadWatts, snapshot.dischargeWatts)
        if let previousEstimate = estimateLoadWatts, smooth {
            estimateLoadWatts = ema(previousEstimate, instantEstimateLoad, alpha: 0.06)
        } else {
            estimateLoadWatts = instantEstimateLoad
        }

        snapshot.timeToFullMinutes = TimeEstimateService.timeToFullMinutes(
            isCharging: snapshot.isCharging,
            systemMinutes: snapshot.systemTimeToFullMinutes,
            missingCapacityWh: snapshot.missingCapacityWh,
            chargeWatts: snapshot.chargeWatts
        )
        snapshot.timeToEmptyMinutes = TimeEstimateService.timeToEmptyMinutes(
            isOnBattery: !snapshot.externalConnected || snapshot.flowMode == .discharging || snapshot.flowMode == .underpowered,
            systemMinutes: snapshot.systemTimeToEmptyMinutes,
            remainingCapacityWh: snapshot.remainingCapacityWh,
            averageLoadWatts: estimateLoadWatts ?? instantEstimateLoad
        )

        smoothed = snapshot
        onChange?(snapshot)
    }

    private func ema(_ previous: Double, _ next: Double, alpha: Double) -> Double {
        previous * (1 - alpha) + next * alpha
    }
}
