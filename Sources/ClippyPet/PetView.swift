import AppKit
import QuartzCore

final class PetView: NSView {
    private let atlas: SpriteAtlas
    private let spriteLayer = CALayer()
    private var accessibilityObserver: NSObjectProtocol?

    private(set) var renderedFrameCount = 0

    lazy var animator = SpriteAnimator(
        reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    ) { [weak self] frame in
        self?.show(frame)
    }

    init(frame frameRect: NSRect, atlas: SpriteAtlas) {
        self.atlas = atlas
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        spriteLayer.contents = atlas.image
        spriteLayer.contentsGravity = .resize
        spriteLayer.magnificationFilter = .nearest
        spriteLayer.minificationFilter = .nearest
        spriteLayer.backgroundColor = NSColor.clear.cgColor
        spriteLayer.masksToBounds = true
        layer?.addSublayer(spriteLayer)

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Clippy")
        setAccessibilityHelp(
            "Click for another animation. Drag to reposition. Right-click for options."
        )
        show(.rest)

        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.animator.updateReduceMotion(
                NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
        }
    }

    deinit {
        if let accessibilityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.frame = bounds
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount >= 2, event.modifierFlags.contains(.option) {
            NSApp.terminate(nil)
            return
        }

        animator.playRandomNow()
        guard let window else { return }
        window.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let changeItem = NSMenuItem(
            title: "Change Animation",
            action: #selector(changeAnimation),
            keyEquivalent: ""
        )
        changeItem.target = self
        changeItem.isEnabled = true
        menu.addItem(changeItem)

        let closeItem = NSMenuItem(
            title: "Close Clippy",
            action: #selector(closeClippy),
            keyEquivalent: ""
        )
        closeItem.target = self
        closeItem.isEnabled = true
        menu.addItem(closeItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func changeAnimation() {
        animator.playRandomNow()
    }

    @objc private func closeClippy() {
        NSApp.terminate(nil)
    }

    func show(_ frame: SpriteFrame) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.contentsRect = atlas.contentsRect(for: frame)
        CATransaction.commit()
        renderedFrameCount += 1
    }

    private func updateContentsScale() {
        spriteLayer.contentsScale = window?.backingScaleFactor ?? 2
    }
}
