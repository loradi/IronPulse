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

        guard let feedback = engine.update(angle: angle) else { return }

        repCount = engine.repCount
        feedbackMessage = Self.message(for: feedback)

        if repCount >= targetReps {
            finish()
        }
    }

    nonisolated static func primaryAngle(joints: [BodyJoint: CGPoint], profile: MovementProfile) -> Double? {
        let spec = profile.primaryAngle
        guard let proximal = joints[spec.proximal],
              let vertex = joints[spec.vertex],
              let distal = joints[spec.distal] else { return nil }
        return AngleCalculator.angle(at: vertex, from: proximal, to: distal)
    }

    private static func message(for feedback: FormFeedback) -> String {
        switch feedback {
        case .goodRep:
            return String(localized: "smart_assistant.feedback.good_rep", defaultValue: "Buena repeticion", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .notDeepEnough:
            return String(localized: "smart_assistant.feedback.not_deep_enough", defaultValue: "No llegaste al rango completo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .tooFast:
            return String(localized: "smart_assistant.feedback.too_fast", defaultValue: "Baja el ritmo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }
}
