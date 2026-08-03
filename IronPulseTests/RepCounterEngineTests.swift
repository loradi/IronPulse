import Foundation
import Testing
@testable import IronPulse

struct RepCounterEngineTests {
    private let squatLikeProfile = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 70...100,
        upRange: 160...180
    )

    private let curlLikeProfile = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 150...180,
        upRange: 30...60
    )

    @Test func countsOneRepOnFullDownToUpCycleStartingUp() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        _ = engine.update(angle: 170, now: base) // starts standing (up)
        _ = engine.update(angle: 85, now: base.addingTimeInterval(1)) // goes to bottom (down)
        let feedback = engine.update(angle: 170, now: base.addingTimeInterval(2)) // back up
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func countsOneRepOnFullDownToUpCycleStartingDown() {
        // Curl starts in its "down" range (arm extended) rather than "up".
        let engine = RepCounterEngine(profile: curlLikeProfile)
        let base = Date()
        _ = engine.update(angle: 170, now: base) // starts extended (down)
        let feedback = engine.update(angle: 45, now: base.addingTimeInterval(1)) // curls up
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func doesNotCountGoingUpToDownAlone() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        _ = engine.update(angle: 170, now: base)
        _ = engine.update(angle: 85, now: base.addingTimeInterval(1))
        #expect(engine.repCount == 0)
    }

    @Test func countsMultipleFullCycles() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        var t = 0.0
        for _ in 0..<3 {
            _ = engine.update(angle: 170, now: base.addingTimeInterval(t)); t += 1
            _ = engine.update(angle: 85, now: base.addingTimeInterval(t)); t += 1
            _ = engine.update(angle: 170, now: base.addingTimeInterval(t)); t += 1
        }
        #expect(engine.repCount == 3)
    }

    @Test func flagsRepCompletedFasterThanMinimumDurationAsTooFast() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        _ = engine.update(angle: 170, now: base)
        _ = engine.update(angle: 85, now: base.addingTimeInterval(0.05))
        let feedback = engine.update(angle: 170, now: base.addingTimeInterval(0.1))
        #expect(engine.repCount == 1)
        #expect(feedback == .tooFast)
    }

    @Test func flagsNearMissAttemptWithoutCountingARep() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        var t = 0.0
        var notDeepEnoughFeedback: FormFeedback?
        _ = engine.update(angle: 170, now: base) // standing
        for angle in [150.0, 120.0, 105.0, 110.0, 130.0, 170.0] {
            t += 0.2
            let feedback = engine.update(angle: angle, now: base.addingTimeInterval(t))
            if feedback == .notDeepEnough {
                notDeepEnoughFeedback = feedback
            }
        }
        #expect(engine.repCount == 0)
        #expect(notDeepEnoughFeedback == .notDeepEnough)
    }
}
