#if DEBUG
import AppKit
import SwiftUI

/// One-shot README shots. Launch with `--readme-gallery`, then the process quits.
@MainActor
enum ReadmeAssetCapture {
    private struct Shot {
        var name: String
        var mode: EnergyFlowMode
        var motion: EnergyMotionStyle
        var tint: PopoverTintPreset
    }

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
            contentRect: NSRect(x: 40, y: 40, width: 4, height: 4),
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
        state.settings.pulseFlowIcons = false
        state.settings.showStatusRings = true
        state.settings.showEnergyFlow = true
        state.settings.showPopoverArrow = false
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

        let shots: [Shot] = [
            .init(name: "flow-discharging", mode: .discharging, motion: .particles, tint: .semantic),
            .init(name: "flow-adapter-hold", mode: .adapterHold, motion: .particles, tint: .semantic),
            .init(name: "flow-underpowered", mode: .underpowered, motion: .particles, tint: .semantic),
            .init(name: "flow-charging", mode: .charging, motion: .particles, tint: .semantic),
            .init(name: "flow-charging-filaments", mode: .charging, motion: .filaments, tint: .semantic),
            .init(name: "flow-charging-off", mode: .charging, motion: .off, tint: .semantic),
            .init(name: "flow-charging-highContrast", mode: .charging, motion: .particles, tint: .highContrast),
            .init(name: "flow-charging-glide", mode: .charging, motion: .sheen, tint: .glide),
            .init(name: "flow-discharging-smooth", mode: .discharging, motion: .filamentsSolid, tint: .smooth),
            .init(name: "flow-adapter-hold-gradient", mode: .adapterHold, motion: .particlesWhite, tint: .gradient)
        ]

        for shot in shots {
            state.settings.motionStyle = shot.motion
            state.settings.applyRingTintPreset(shot.tint)
            state.settings.applyFlowTintPreset(shot.tint)
            state.snapshot = .readme(shot.mode)
            popover.show(
                relativeTo: anchor.contentView!.bounds,
                of: anchor.contentView!,
                preferredEdge: .maxY
            )
            try? await Task.sleep(for: .milliseconds(shot.motion == .off ? 500 : 1_050))
            hosting.view.layoutSubtreeIfNeeded()
            hosting.view.window?.displayIfNeeded()
            let dest = output.appendingPathComponent("\(shot.name).png")
            if captureView(hosting.view, to: dest) {
                trimOpaqueContent(at: dest)
                print("wrote \(dest.lastPathComponent)")
            } else {
                print("failed \(shot.name)")
            }
        }

        state.isPopoverOpen = false
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

    @discardableResult
    private static func captureView(_ view: NSView, to url: URL) -> Bool {
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return false }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try png.write(to: url)
            return true
        } catch {
            return false
        }
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
                // Keep glass / colored content; drop near-black empty canvas.
                if lum > 0.08 || color.alphaComponent < 0.95 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        let pad = 6
        minX = max(0, minX - pad)
        minY = max(0, minY - pad)
        maxX = min(width - 1, maxX + pad)
        maxY = min(height - 1, maxY + pad)
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
