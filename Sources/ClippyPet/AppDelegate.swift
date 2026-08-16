import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private enum DefaultsKey {
        static let positionX = "ClippyPositionX"
        static let positionY = "ClippyPositionY"
    }

    private let renderScale: CGFloat = 1
    private var panel: PetPanel?
    private var petView: PetView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try launchPet()
        } catch {
            let message = "ClippyPet failed to start: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        petView?.animator.stop()
        if let origin = panel?.frame.origin {
            savePosition(origin)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        keepPanelOnScreen()
    }

    func windowDidMove(_ notification: Notification) {
        guard let origin = panel?.frame.origin else { return }
        savePosition(origin)
    }

    private func launchPet() throws {
        guard let atlasURL = Bundle.main.url(forResource: "map", withExtension: "png") else {
            throw SpriteAtlasError.unreadableImage
        }

        let atlas = try SpriteAtlas(url: atlasURL)
        let size = NSSize(
            width: CGFloat(AnimationCatalog.frameWidth) * renderScale,
            height: CGFloat(AnimationCatalog.frameHeight) * renderScale
        )
        let initialOrigin = restoredPosition(for: size) ?? defaultPosition(for: size)
        let contentRect = NSRect(origin: initialOrigin, size: size)
        let newPanel = PetPanel(contentRect: contentRect)
        let newPetView = PetView(
            frame: NSRect(origin: .zero, size: size),
            atlas: atlas
        )

        newPanel.delegate = self
        newPanel.contentView = newPetView
        newPanel.orderFrontRegardless()

        panel = newPanel
        petView = newPetView

        if CommandLine.arguments.contains("--smoke-test") {
            runSmokeTest(initialOrigin: newPanel.frame.origin, atlas: atlas)
        } else {
            newPetView.animator.start()
        }
    }

    private func runSmokeTest(initialOrigin: NSPoint, atlas: SpriteAtlas) {
        guard let panel, let petView else {
            NSApp.terminate(nil)
            return
        }

        petView.animator.play(named: "Wave")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let currentOrigin = panel.frame.origin
            let report: [String: Any] = [
                "animationCount": AnimationCatalog.animations.count,
                "automaticDelaySeconds": SpriteAnimator.automaticAnimationDelay,
                "atlasHeight": atlas.pixelHeight,
                "atlasWidth": atlas.pixelWidth,
                "frameAdvanceCount": petView.animator.frameAdvanceCount,
                "frameCount": AnimationCatalog.frameCount,
                "hasShadow": panel.hasShadow,
                "isBorderless": panel.styleMask.contains(.borderless),
                "isMovable": panel.isMovable,
                "isNonactivating": panel.styleMask.contains(.nonactivatingPanel),
                "isOpaque": panel.isOpaque,
                "maximumAnimationDurationSeconds": SpriteAnimator.maximumAnimationDuration,
                "maximumFrameAdvances": SpriteAnimator.maximumFrameAdvances,
                "playableAnimationCount": AnimationCatalog.playableAnimations.count,
                "routeCount": AnimationCatalog.routeCount,
                "routeValidationErrorCount": AnimationCatalog.routeValidationErrors().count,
                "stationary": abs(currentOrigin.x - initialOrigin.x) < 0.001 &&
                    abs(currentOrigin.y - initialOrigin.y) < 0.001,
                "uniqueAnimationNameCount": Set(
                    AnimationCatalog.animations.map(\.name)
                ).count,
                "windowLevel": panel.level.rawValue
            ]

            if let data = try? JSONSerialization.data(
                withJSONObject: report,
                options: [.sortedKeys]
            ) {
                let arguments = CommandLine.arguments
                if let outputIndex = arguments.firstIndex(of: "--smoke-output"),
                   arguments.indices.contains(outputIndex + 1) {
                    try? data.write(
                        to: URL(fileURLWithPath: arguments[outputIndex + 1]),
                        options: .atomic
                    )
                } else {
                    FileHandle.standardOutput.write(data)
                    FileHandle.standardOutput.write(Data("\n".utf8))
                }

                if let snapshotIndex = arguments.firstIndex(of: "--snapshot-output"),
                   arguments.indices.contains(snapshotIndex + 1) {
                    self.writeSnapshot(
                        of: petView,
                        to: URL(fileURLWithPath: arguments[snapshotIndex + 1])
                    )
                }
            }
            NSApp.terminate(nil)
        }
    }

    private func restoredPosition(for size: NSSize) -> NSPoint? {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: DefaultsKey.positionX) != nil,
            defaults.object(forKey: DefaultsKey.positionY) != nil
        else {
            return nil
        }

        let point = NSPoint(
            x: defaults.double(forKey: DefaultsKey.positionX),
            y: defaults.double(forKey: DefaultsKey.positionY)
        )
        let candidate = NSRect(origin: point, size: size)
        let visibleOnScreen = NSScreen.screens.contains { screen in
            let intersection = screen.visibleFrame.intersection(candidate)
            return intersection.width >= 32 && intersection.height >= 32
        }
        return visibleOnScreen ? point : nil
    }

    private func defaultPosition(for size: NSSize) -> NSPoint {
        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(
            x: visibleFrame.maxX - size.width - 24,
            y: visibleFrame.minY + 24
        )
    }

    private func savePosition(_ origin: NSPoint) {
        let defaults = UserDefaults.standard
        defaults.set(Double(origin.x), forKey: DefaultsKey.positionX)
        defaults.set(Double(origin.y), forKey: DefaultsKey.positionY)
    }

    private func keepPanelOnScreen() {
        guard let panel else { return }
        let currentFrame = panel.frame
        guard !NSScreen.screens.contains(where: {
            $0.visibleFrame.intersection(currentFrame).width >= 32 &&
                $0.visibleFrame.intersection(currentFrame).height >= 32
        }) else {
            return
        }

        let destination = defaultPosition(for: currentFrame.size)
        panel.setFrameOrigin(destination)
        savePosition(destination)
    }

    private func writeSnapshot(of view: NSView, to url: URL) {
        guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return
        }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let png = representation.representation(using: .png, properties: [:]) else {
            return
        }
        try? png.write(to: url, options: .atomic)
    }
}
