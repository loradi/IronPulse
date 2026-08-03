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

    private let stabilityProfile = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 150...180,
        upRange: 30...60,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        )
    )

    private let boundedProfile = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 70...100,
        upRange: 160...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        )
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

    @Test func stabilityCheckWithinToleranceStillCountsAsGoodRep() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        _ = engine.update(angle: 155, secondaryAngle: 45, now: base.addingTimeInterval(0.2)) // drift of 5, within 15
        let feedback = engine.update(angle: 45, secondaryAngle: 42, now: base.addingTimeInterval(0.5))
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func stabilityCheckExceedingToleranceReturnsBadFormAndDoesNotCount() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        _ = engine.update(angle: 155, secondaryAngle: 65, now: base.addingTimeInterval(0.2)) // drift of 25, exceeds 15
        let feedback = engine.update(angle: 45, secondaryAngle: 42, now: base.addingTimeInterval(0.5))
        #expect(engine.repCount == 0)
        #expect(feedback == .badForm)
    }

    @Test func boundedCheckWithinRangeStillCountsAsGoodRep() {
        let engine = RepCounterEngine(profile: boundedProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 175, now: base) // standing, torso upright
        _ = engine.update(angle: 85, secondaryAngle: 160, now: base.addingTimeInterval(1)) // depth, torso within 150...180
        let feedback = engine.update(angle: 170, secondaryAngle: 178, now: base.addingTimeInterval(2))
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func boundedCheckOutsideRangeReturnsBadFormAndDoesNotCount() {
        let engine = RepCounterEngine(profile: boundedProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 175, now: base)
        _ = engine.update(angle: 85, secondaryAngle: 120, now: base.addingTimeInterval(1)) // torso collapses below 150
        let feedback = engine.update(angle: 170, secondaryAngle: 178, now: base.addingTimeInterval(2))
        #expect(engine.repCount == 0)
        #expect(feedback == .badForm)
    }

    @Test func profilesWithoutASecondaryCheckIgnoreSecondaryAngleEntirely() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 0, now: base)
        _ = engine.update(angle: 85, secondaryAngle: 999, now: base.addingTimeInterval(1))
        let feedback = engine.update(angle: 170, secondaryAngle: -500, now: base.addingTimeInterval(2))
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func badFormTakesPriorityOverTooFastWhenBothApply() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        // Drift of 25 exceeds the 15 tolerance AND the rep completes
        // in 0.1s, under `minimumRepDuration` (0.4s) - both conditions
        // apply, and `.badForm` must win: reporting `.tooFast` instead
        // would incorrectly imply the rep counted.
        let feedback = engine.update(angle: 45, secondaryAngle: 65, now: base.addingTimeInterval(0.1))
        #expect(feedback == .badForm)
        #expect(engine.repCount == 0)
    }

    @Test func badFormRepDoesNotLeakStateIntoASubsequentCleanRep() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        let badFormFeedback = engine.update(angle: 45, secondaryAngle: 65, now: base.addingTimeInterval(0.5)) // drift of 25, violates
        #expect(badFormFeedback == .badForm)
        #expect(engine.repCount == 0)

        // Immediately followed by a clean down->up cycle on the same
        // engine instance - `enterDown` must reset the secondary-check
        // state, since it's only otherwise reset on `enterUp`.
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base.addingTimeInterval(1)) // re-enters down, new baseline = 40
        let goodFeedback = engine.update(angle: 45, secondaryAngle: 42, now: base.addingTimeInterval(1.5)) // drift of 2, within tolerance
        #expect(goodFeedback == .goodRep)
        #expect(engine.repCount == 1)
    }

    @Test func nilSecondaryAngleMidRepOnAProfileWithACheckDoesNotForceAViolationOrResetTheBaseline() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        _ = engine.update(angle: 155, secondaryAngle: nil, now: base.addingTimeInterval(0.2)) // joint briefly occluded mid-rep
        let feedback = engine.update(angle: 45, secondaryAngle: 42, now: base.addingTimeInterval(0.5)) // drift of 2 from the original baseline, within tolerance
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func stabilityBaselineIsCapturedOnTheFirstFrameWhereSecondaryAngleIsAvailableAfterOcclusionOnEntry() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: nil, now: base) // enters down, but the joint is occluded on this exact frame
        _ = engine.update(angle: 155, secondaryAngle: 40, now: base.addingTimeInterval(0.2)) // joint visible now - baseline captured here as 40
        let feedback = engine.update(angle: 45, secondaryAngle: 42, now: base.addingTimeInterval(0.5)) // drift of 2 from the captured baseline, within tolerance
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }
}
