import CoreGraphics
import CoreVideo
import Foundation

/// Owns the real counting pipeline for the Smart Assistant: receives
/// camera frames from a `CameraSessionController`, runs
/// `PoseDetectorService` off the main actor (Vision inference is
/// synchronous and should not block UI), then hops back to the main
/// actor to feed the detected angle into a `RepCounterEngine` and
/// publish the result to the view.
@Observable
@MainActor
final class SmartAssistantModel {
    let cameraController = CameraSessionController()
    let audioAnnouncer = SmartAssistantAudioAnnouncer()
    let targetReps: Int

    private(set) var repCount = 0
    private(set) var feedbackMessage: String?
    private(set) var personVisible = true

    private let engine: RepCounterEngine?
    private let movementProfile: MovementProfile?
    private(set) var didFinish = false
    private let onComplete: (Int) -> Void

    // Touched only from `processFrame`, which `CameraSessionController`
    // always invokes serially on its single `sessionQueue` (the sample
    // buffer delegate is registered on that one serial queue) — never
    // read or written from `handleDetectedJoints` or any other
    // main-actor code. That single-queue confinement is what makes an
    // unsynchronized `nonisolated(unsafe)` Int safe here; it is not
    // shared cross-thread the way `CameraSessionController.cameraPosition`
    // was.
    @ObservationIgnored
    nonisolated(unsafe) private var frameCounter = 0

    /// Process only every Nth frame — Vision inference is too
    /// expensive to run at full camera frame rate.
    private let frameSkip = 3

    // Consecutive frames with no detected primary-angle joints. Only
    // flips `personVisible` to false after several misses in a row so a
    // single bad frame doesn't strobe the "adjust your framing" banner
    // on and off — at the current throttle rate (every 3rd camera
    // frame, ~10 processed frames/sec off a ~30fps feed) this threshold
    // is roughly 1 second of sustained misses.
    private var missedDetectionCount = 0
    private let missedDetectionThreshold = 10

    init(exerciseID: String, targetReps: Int, onComplete: @escaping (Int) -> Void) {
        self.targetReps = targetReps
        self.onComplete = onComplete
        let profile = MovementProfileCatalog.profile(forExerciseID: exerciseID)
        self.movementProfile = profile
        self.engine = profile.map(RepCounterEngine.init(profile:))

        cameraController.onFrame = { [weak self] pixelBuffer in
            self?.processFrame(pixelBuffer)
        }
    }

    func start() {
        cameraController.start()
        _ = audioAnnouncer.resolvedVoice(for: .current)
    }

    func finish() {
        guard !didFinish else { return }
        didFinish = true
        cameraController.stop()
        onComplete(repCount)
    }

    // Called from CameraSessionController's background session queue —
    // deliberately not main-actor-isolated so it can run there without
    // hopping first. The frame-skip gate is checked here, before Vision
    // inference runs, so skipped frames never pay for `detectJoints` —
    // not just after the fact. Only the final state update jumps to
    // the main actor.
    nonisolated private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        frameCounter += 1
        guard frameCounter % frameSkip == 0 else { return }

        let joints = PoseDetectorService.detectJoints(in: pixelBuffer)
        Task { @MainActor in
            self.handleDetectedJoints(joints)
        }
    }

    private func handleDetectedJoints(_ joints: [BodyJoint: CGPoint]) {
        guard !didFinish else { return }

        guard let profile = movementProfile, let engine else { return }

        guard let angle = Self.primaryAngle(joints: joints, profile: profile) else {
            missedDetectionCount += 1
            if missedDetectionCount >= missedDetectionThreshold {
                personVisible = false
            }
            return
        }
        missedDetectionCount = 0
        personVisible = true

        let secondaryAngle = Self.secondaryAngle(joints: joints, profile: profile)
        guard let feedback = engine.update(angle: angle, secondaryAngle: secondaryAngle) else { return }

        repCount = engine.repCount
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback)
        feedbackMessage = phrase.text(for: language)
        if Self.shouldSpeak(for: feedback, repCount: repCount, targetReps: targetReps) {
            audioAnnouncer.speak(phrase, language: language)
        }

        if repCount >= targetReps {
            finish()
        }
    }

    nonisolated static func primaryAngle(joints: [BodyJoint: CGPoint], profile: MovementProfile) -> Double? {
        angle(for: profile.primaryAngle, joints: joints)
    }

    nonisolated static func secondaryAngle(joints: [BodyJoint: CGPoint], profile: MovementProfile) -> Double? {
        guard let secondaryCheck = profile.secondaryCheck else { return nil }
        return angle(for: secondaryCheck.angle, joints: joints)
    }

    nonisolated private static func angle(for jointAngle: JointAngle, joints: [BodyJoint: CGPoint]) -> Double? {
        guard let proximal = joints[jointAngle.proximal],
              let vertex = joints[jointAngle.vertex],
              let distal = joints[jointAngle.distal] else { return nil }
        return AngleCalculator.angle(at: vertex, from: proximal, to: distal)
    }

    /// `.goodRep` is only spoken on the first, middle, and last rep of
    /// the set - the rest still update the on-screen banner, just not
    /// the audio, so a long set doesn't narrate every single rep.
    /// Corrective feedback (`.notDeepEnough`/`.tooFast`/`.badForm`)
    /// always speaks: those matter most exactly when they happen, not
    /// on a milestone schedule.
    nonisolated static func shouldSpeak(for feedback: FormFeedback, repCount: Int, targetReps: Int) -> Bool {
        guard feedback == .goodRep else { return true }
        let midpoint = max(1, targetReps / 2)
        return repCount == 1 || repCount == midpoint || repCount == targetReps
    }
}
