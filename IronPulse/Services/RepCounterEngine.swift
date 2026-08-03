import Foundation

/// Feedback classification for one tracked repetition or attempt. The
/// view layer owns the localized copy shown for each case.
enum FormFeedback: Equatable {
    case goodRep
    case notDeepEnough
    case tooFast
    case badForm
}

/// Counts repetitions from a stream of joint angles using a
/// `MovementProfile`. Pure logic, zero AVFoundation/Vision dependency
/// — fully unit testable by feeding synthetic angle sequences.
///
/// A rep is counted every time the tracked angle moves from
/// `downRange` into `upRange` — that is always the concentric-
/// completion point for every profile in `MovementProfileCatalog`,
/// regardless of which range the exercise happens to start in (see
/// `MovementProfile`'s documentation for why "down"/"up" are
/// exercise-relative, not literal body position).
final class RepCounterEngine {
    private enum Phase: Equatable {
        case unknown
        case down
        case up
    }

    let profile: MovementProfile
    private(set) var repCount: Int = 0

    private var phase: Phase = .unknown
    private var phaseEnteredAt: Date?
    private var previousDistanceToDown: Double?
    private var reportedNearMissThisAttempt = false

    private let minimumRepDuration: TimeInterval = 0.4
    /// How close (in degrees) the angle must get to `downRange` while
    /// attempting a rep, without actually entering it, before a
    /// reversal counts as a "not deep enough" attempt instead of
    /// being ignored as noise near the resting position.
    private let nearMissToleranceDegrees: Double = 15

    // Captured when a "down" phase attempt begins - only meaningful
    // for `.stability` secondary checks, which measure drift from
    // wherever the joint happened to be at the start of THIS attempt,
    // not a fixed absolute angle.
    private var secondaryBaseline: Double?
    // Set the moment the secondary check is violated during a "down"
    // attempt, checked (and reset) only at the down->up completion
    // point - mirrors how `reportedNearMissThisAttempt` is scoped to
    // one attempt.
    private var secondaryViolatedThisAttempt = false

    init(profile: MovementProfile) {
        self.profile = profile
    }

    @discardableResult
    func update(angle: Double, secondaryAngle: Double? = nil, now: Date = Date()) -> FormFeedback? {
        let isDown = profile.downRange.contains(angle)
        let isUp = profile.upRange.contains(angle)

        switch phase {
        case .unknown:
            if isDown {
                enterDown(now: now, secondaryAngle: secondaryAngle)
            } else if isUp {
                enterUp(now: now)
            }
            return nil

        case .down:
            trackSecondary(secondaryAngle)
            guard isUp else { return nil }
            if secondaryViolatedThisAttempt {
                enterUp(now: now)
                return .badForm
            }
            let feedback = repCompletionFeedback(now: now)
            repCount += 1
            enterUp(now: now)
            return feedback

        case .up:
            if isDown {
                enterDown(now: now, secondaryAngle: secondaryAngle)
                return nil
            }
            return checkNearMiss(angle: angle)
        }
    }

    private func enterDown(now: Date, secondaryAngle: Double?) {
        phase = .down
        phaseEnteredAt = now
        previousDistanceToDown = nil
        reportedNearMissThisAttempt = false
        secondaryBaseline = secondaryAngle
        secondaryViolatedThisAttempt = false
        // A `.bounded` check must also validate this very first frame's
        // absolute angle (unlike `.stability`, where this frame only
        // establishes the baseline and can't yet have drifted from it).
        trackSecondary(secondaryAngle)
    }

    private func enterUp(now: Date) {
        phase = .up
        phaseEnteredAt = now
        previousDistanceToDown = nil
        reportedNearMissThisAttempt = false
    }

    /// Called on every `update()` while in the "down" phase, before
    /// the down->up completion check - so a violation anywhere during
    /// the attempt (not just at the final frame) gets caught.
    private func trackSecondary(_ secondaryAngle: Double?) {
        guard let secondaryAngle, let check = profile.secondaryCheck else { return }
        switch check {
        case .stability(_, let toleranceDegrees):
            guard let baseline = secondaryBaseline else { return }
            if abs(secondaryAngle - baseline) > toleranceDegrees {
                secondaryViolatedThisAttempt = true
            }
        case .bounded(_, let allowedRange):
            if !allowedRange.contains(secondaryAngle) {
                secondaryViolatedThisAttempt = true
            }
        }
    }

    private func repCompletionFeedback(now: Date) -> FormFeedback {
        if let phaseEnteredAt, now.timeIntervalSince(phaseEnteredAt) < minimumRepDuration {
            return .tooFast
        }
        return .goodRep
    }

    /// Detects an attempted rep that reversed direction before
    /// reaching `downRange`: the angle got within tolerance of it,
    /// then started moving away again. Fires at most once per
    /// attempt.
    private func checkNearMiss(angle: Double) -> FormFeedback? {
        let distance = distanceToRange(angle, profile.downRange)
        defer { previousDistanceToDown = distance }

        guard let previousDistance = previousDistanceToDown else { return nil }

        if !reportedNearMissThisAttempt,
           previousDistance <= nearMissToleranceDegrees,
           distance > previousDistance {
            reportedNearMissThisAttempt = true
            return .notDeepEnough
        }

        return nil
    }

    private func distanceToRange(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        if range.contains(value) { return 0 }
        return Swift.min(abs(value - range.lowerBound), abs(value - range.upperBound))
    }
}
