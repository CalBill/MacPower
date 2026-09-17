#if DEBUG
import AppKit
import SwiftUI

/// One-shot README shots. Launch with `--readme-gallery`, then the process quits.
@MainActor
enum ReadmeAssetCapture {
    static func startIfNeeded() -> Bool {
        guard CommandLine.arguments.contains("--readme-gallery") else { return false }
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .aqua)
        ProcessInfo.processInfo.disableAutomaticTermination("readme-gallery")
        Task { await exportAll() }
        return true
    }

    private static func exportAll() async {
        let output = outputDirectory()
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let anchor = NSWindow(
            contentRect: NSRect(x: 24, y: 24, width: 2, height: 2),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        anchor.isOpaque = true
        anchor.backgroundColor = .windowBackgroundColor
        anchor.level = .floating
        anchor.hasShadow = false
        anchor.orderFrontRegardless()

        let state = AppState()
        state.telemetry.stop()
        state.metricsService.stop()
        state.telemetry.onChange = nil
        state.metricsService.onChange = nil
        state.settings.language = .simplifiedChinese
        state.settings.motionStyle = .particles
        state.settings.pulseFlowIcons = false
        state.metrics = SystemSnapshot(cpuPercent: 19, gpuPercent: 31, memoryPercent: 67)
        state.isPopoverOpen = true

        let hosting = NSHostingController(
            rootView: PopoverRootView(appState: state)
                .environment(\.colorScheme, .light)
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.appearance = NSAppearance(named: .aqua)
        popover.contentViewController = hosting
        if popover.responds(to: NSSelectorFromString("setShouldHideAnchor:")) {
            popover.setValue(true, forKey: "shouldHideAnchor")
        }

        let shots: [(String, EnergyFlowMode)] = [
            ("flow-adapter-hold", .adapterHold),
            ("flow-underpowered", .underpowered),
            ("flow-charging", .charging)
        ]
        for (name, mode) in shots {
            state.snapshot = .readme(mode)
            popover.show(
                relativeTo: anchor.contentView!.bounds,
                of: anchor.contentView!,
                preferredEdge: .maxY
            )
            try? await Task.sleep(for: .milliseconds(700))
            if let window = hosting.view.window {
                window.displayIfNeeded()
                let dest = output.appendingPathComponent("\(name).png")
                capture(window: window, to: dest)
                trimOpaqueContent(at: dest)
            }
        }

        state.isPopoverOpen = false
        state.settings.motionStyle = .off
        popover.close()
        anchor.close()
        NSApp.terminate(nil)
    }

    private static func outputDirectory() -> URL {
        if let flag = CommandLine.arguments.first(where: { $0.hasPrefix("--readme-output=") }) {
            return URL(fileURLWithPath: String(flag.dropFirst("--readme-output=".count)), isDirectory: true)
        }
        return URL(fileURLWithPath: "/Users/wangshaoyan/Code/MacPower/docs/readme", isDirectory: true)
    }

    private static func capture(window: NSWindow, to url: URL) {
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-l", String(window.windowNumber), "-o", "-x", url.path]
        try? capture.run()
        capture.waitUntilExit()
    }

    private static func trimOpaqueContent(at url: URL) {
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let lum = color.redComponent * 0.3 + color.greenComponent * 0.59 + color.blueComponent * 0.11
                if lum > 0.22 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        let cropW = maxX - minX + 1
        let cropH = maxY - minY + 1
        guard cropW > 8, cropH > 8,
              let cropped = rep.cgImage?.cropping(to: CGRect(x: minX, y: minY, width: cropW, height: cropH))
        else { return }
        let out = NSBitmapImageRep(cgImage: cropped)
        if let png = out.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
    }
}

private extension PowerSnapshot {
    static func readme(_ mode: EnergyFlowMode) -> PowerSnapshot {
        switch mode {
        case .discharging:
            PowerSnapshot(
                hasBattery: true,
                percent: 95,
                isCharging: false,
                externalConnected: false,
                fullyCharged: false,
                adapterCeilingWatts: 0,
                adapterInWatts: 0,
                systemLoadWatts: 23.8,
                batteryWatts: -23.8,
                remainingCapacityWh: 70,
                missingCapacityWh: 4,
                systemTimeToEmptyMinutes: 156,
                systemTimeToFullMinutes: nil,
                timeToEmptyMinutes: 156,
                timeToFullMinutes: nil,
                flowMode: .discharging
            )
        case .adapterHold:
            PowerSnapshot(
                hasBattery: true,
                percent: 100,
                isCharging: false,
                externalConnected: true,
                fullyCharged: true,
                adapterCeilingWatts: 70,
                adapterInWatts: 12.4,
                systemLoadWatts: 12.4,
                batteryWatts: 0,
                remainingCapacityWh: 74,
                missingCapacityWh: 0,
                systemTimeToEmptyMinutes: nil,
                systemTimeToFullMinutes: nil,
                timeToEmptyMinutes: nil,
                timeToFullMinutes: nil,
                flowMode: .adapterHold
            )
        case .underpowered:
            PowerSnapshot(
                hasBattery: true,
                percent: 64,
                isCharging: false,
                externalConnected: true,
                fullyCharged: false,
                adapterCeilingWatts: 30,
                adapterInWatts: 18.0,
                systemLoadWatts: 28.5,
                batteryWatts: -10.5,
                remainingCapacityWh: 48,
                missingCapacityWh: 26,
                systemTimeToEmptyMinutes: nil,
                systemTimeToFullMinutes: nil,
                timeToEmptyMinutes: nil,
                timeToFullMinutes: nil,
                flowMode: .underpowered
            )
        case .charging:
            PowerSnapshot(
                hasBattery: true,
                percent: 42,
                isCharging: true,
                externalConnected: true,
                fullyCharged: false,
                adapterCeilingWatts: 70,
                adapterInWatts: 48.0,
                systemLoadWatts: 22.0,
                batteryWatts: 26.0,
                remainingCapacityWh: 31,
                missingCapacityWh: 43,
                systemTimeToEmptyMinutes: nil,
                systemTimeToFullMinutes: 95,
                timeToEmptyMinutes: nil,
                timeToFullMinutes: 95,
                flowMode: .charging
            )
        }
    }
}
#endif
