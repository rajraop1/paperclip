import Foundation

final class SpriteAnimator {
    static let automaticAnimationDelay: TimeInterval = 2
    static let maximumAnimationDuration: TimeInterval = 20
    static let maximumFrameAdvances = 2_000

    private let onFrame: (SpriteFrame) -> Void
    private var reduceMotion: Bool
    private var timer: Timer?
    private var lastAnimationName = "RestPose"
    private var currentAnimation: SpriteAnimation?
    private var currentFrameIndex = 0
    private var currentAnimationAdvanceCount = 0
    private var animationStartedAt: TimeInterval = 0
    private var exitAfter: TimeInterval = .infinity
    private var exitRequested = false

    private(set) var frameAdvanceCount = 0

    init(reduceMotion: Bool, onFrame: @escaping (SpriteFrame) -> Void) {
        self.reduceMotion = reduceMotion
        self.onFrame = onFrame
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        stop()
        onFrame(.rest)
        schedule(after: Self.automaticAnimationDelay) { animator in
            animator.playRandomNow()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentAnimation = nil
        currentFrameIndex = 0
        currentAnimationAdvanceCount = 0
        exitRequested = false
    }

    func updateReduceMotion(_ enabled: Bool) {
        guard enabled != reduceMotion else { return }
        reduceMotion = enabled

        if enabled {
            stop()
            onFrame(.rest)
            schedule(after: Self.automaticAnimationDelay) { animator in
                animator.playRandomNow()
            }
        }
    }

    func playRandomNow() {
        let pool: [SpriteAnimation]
        if reduceMotion {
            let quietNames = Set([
                "LookRight", "LookLeft", "LookUp", "LookDown",
                "IdleEyeBrowRaise", "IdleFingerTap"
            ])
            pool = AnimationCatalog.playableAnimations.filter { quietNames.contains($0.name) }
        } else {
            pool = AnimationCatalog.playableAnimations
        }

        guard !pool.isEmpty else {
            onFrame(.rest)
            return
        }

        let candidates = pool.filter { $0.name != lastAnimationName }
        let chosen = candidates.randomElement() ?? pool[0]
        play(chosen)
    }

    func play(named name: String) {
        guard let animation = AnimationCatalog.animation(named: name) else { return }
        play(animation)
    }

    private func play(_ animation: SpriteAnimation) {
        timer?.invalidate()
        lastAnimationName = animation.name
        currentAnimation = animation
        currentFrameIndex = 0
        currentAnimationAdvanceCount = 0
        animationStartedAt = ProcessInfo.processInfo.systemUptime
        exitRequested = false

        let hasWeightedBranches = AnimationCatalog.routes[animation.name]?.values.contains {
            !$0.branches.isEmpty
        } ?? false
        if hasWeightedBranches {
            let linearDuration = animation.frames.reduce(0) { $0 + $1.duration }
            exitAfter = max(3, min(10, linearDuration * 0.65))
        } else {
            exitAfter = .infinity
        }
        advance()
    }

    private func advance() {
        guard let animation = currentAnimation else { return }

        let elapsed = ProcessInfo.processInfo.systemUptime - animationStartedAt
        guard currentFrameIndex < animation.frames.count,
              currentAnimationAdvanceCount < Self.maximumFrameAdvances,
              elapsed < Self.maximumAnimationDuration else {
            finishCurrentAnimation()
            return
        }

        if elapsed >= exitAfter {
            exitRequested = true
        }

        let displayedFrameIndex = currentFrameIndex
        let frame = animation.frames[displayedFrameIndex]
        currentFrameIndex = nextFrameIndex(
            after: displayedFrameIndex,
            in: animation
        )
        currentAnimationAdvanceCount += 1
        frameAdvanceCount += 1
        onFrame(frame)
        let remainingDuration = max(
            0.000_001,
            Self.maximumAnimationDuration - elapsed
        )
        schedule(after: min(frame.duration, remainingDuration)) { animator in
            animator.advance()
        }
    }

    private func nextFrameIndex(
        after frameIndex: Int,
        in animation: SpriteAnimation
    ) -> Int {
        let sequentialFrameIndex = frameIndex + 1
        guard let route = AnimationCatalog.route(
            forAnimation: animation.name,
            frameIndex: frameIndex
        ) else {
            return sequentialFrameIndex
        }

        if exitRequested, let exitBranch = route.exitBranch {
            return exitBranch
        }
        guard !exitRequested, !route.branches.isEmpty else {
            return sequentialFrameIndex
        }

        let roll = Int.random(in: 0..<100)
        var cumulativeWeight = 0
        for branch in route.branches {
            cumulativeWeight += branch.weight
            if roll < cumulativeWeight {
                return branch.frameIndex
            }
        }
        return sequentialFrameIndex
    }

    private func finishCurrentAnimation() {
        currentAnimation = nil
        currentFrameIndex = 0
        currentAnimationAdvanceCount = 0
        exitRequested = false
        onFrame(.rest)

        schedule(after: Self.automaticAnimationDelay) { animator in
            animator.playRandomNow()
        }
    }

    private func schedule(
        after interval: TimeInterval,
        action: @escaping (SpriteAnimator) -> Void
    ) {
        timer?.invalidate()
        let nextTimer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.timer = nil
            action(self)
        }
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }
}
