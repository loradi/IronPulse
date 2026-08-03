# Smart Exercise Assistant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a camera-based "Smart Exercise Assistant" to the guided workout session — live pose detection that counts reps and gives real-time form feedback for a curated set of exercises, replacing manual rep entry when the user opts in.

**Architecture:** Three layers, built in three stages per the approved design spec: (1) pure rep-counting logic with zero framework dependencies, fully unit tested; (2) `AVFoundation` live camera capture wired to a mock counter; (3) `Vision` (`VNDetectHumanBodyPoseRequest`) replacing the mock with real joint-angle tracking. Each stage is independently reviewable and the UI contract never changes between stages.

**Tech Stack:** SwiftUI, AVFoundation, Vision framework — no new external dependencies (matches this project's zero-dependency policy).

**Spec:** `docs/superpowers/specs/2026-08-02-smart-exercise-assistant-design.md` — read this first for the full rationale behind every decision below.

## Global Constraints

- Work happens entirely on branch `smart-exercise-assistant` (already created, spec already committed there). Nothing lands on `main` until the user decides to merge the finished feature.
- All new code — type names, function names, variable names, comments — is written in English. This is a deliberate departure from the rest of this codebase (which has Spanish comments); it applies only to files created or substantially modified by this plan.
- Every user-visible string goes through `String(localized: "<key>", defaultValue: "<spanish text>", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)` — the exact pattern already used everywhere else in this project. The Spanish text is the `defaultValue` (matches the project's `sourceLanguage: "es"`); `en`/`fr` translations are added to `IronPulse/Localizable.xcstrings` in the same commit that introduces the string. No exceptions, no strings left only in Spanish.
- No video frame, image, or pose observation is ever written to disk, cached, or transmitted anywhere. Every frame is processed and discarded immediately. This is a hard privacy constraint from the spec, not a performance suggestion.
- The assistant's entry point is visible only when `setPhase == .runningSet` in `GuidedWorkoutView` AND `MovementProfileCatalog.profile(forExerciseID:)` returns non-nil for the active exercise. If unsupported, the button simply does not appear — no "unsupported" messaging.
- No "Force (Watt)" or any other force/power metric anywhere in this feature — it is not derivable honestly from camera-only pose detection.
- Finishing a set from the assistant only auto-completes it (`finishSet`) when `GuidedSessionFlow.canCompleteSet(weightKg:repsCompleted:)` is already `true` (weight was already entered before opening the assistant). Otherwise only `repsCompleted` is updated and the existing "Finish set" button (already gated on the same check) is left for the user.
- Pure logic (`AngleCalculator`, `RepCounterEngine`, `MovementProfileCatalog`) has zero `import AVFoundation` / `import Vision`. It must be fully testable by feeding synthetic numbers, with no camera or hardware involved.

---

### Task 1: Pure Rep-Counting Core

**Files:**
- Create: `IronPulse/Services/MovementProfile.swift`
- Create: `IronPulse/Services/AngleCalculator.swift`
- Create: `IronPulse/Services/RepCounterEngine.swift`
- Test: `IronPulseTests/MovementProfileCatalogTests.swift`
- Test: `IronPulseTests/AngleCalculatorTests.swift`
- Test: `IronPulseTests/RepCounterEngineTests.swift`

**Interfaces:**
- Produces: `BodyJoint` (enum), `JointAngle` (struct), `MovementProfile` (struct), `MovementProfileCatalog.profile(forExerciseID: String) -> MovementProfile?`, `AngleCalculator.angle(at:from:to:) -> Double`, `FormFeedback` (enum: `.goodRep`, `.notDeepEnough`, `.tooFast`), `RepCounterEngine` (class: `init(profile:)`, `repCount: Int`, `func update(angle: Double, now: Date = Date()) -> FormFeedback?`).
- Consumes: nothing — this task has no dependencies on the rest of the plan.

- [ ] **Step 1: Write the failing tests for `AngleCalculator`**

```swift
// IronPulseTests/AngleCalculatorTests.swift
import Foundation
import Testing
@testable import IronPulse

struct AngleCalculatorTests {
    @Test func rightAngleMeasuresNinetyDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let a = CGPoint(x: 1, y: 0)
        let b = CGPoint(x: 0, y: 1)
        #expect(abs(AngleCalculator.angle(at: vertex, from: a, to: b) - 90) < 0.001)
    }

    @Test func straightLineMeasuresOneHundredEightyDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let a = CGPoint(x: -1, y: 0)
        let b = CGPoint(x: 1, y: 0)
        #expect(abs(AngleCalculator.angle(at: vertex, from: a, to: b) - 180) < 0.001)
    }

    @Test func sameDirectionMeasuresZeroDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let a = CGPoint(x: 1, y: 0)
        let b = CGPoint(x: 2, y: 0)
        #expect(abs(AngleCalculator.angle(at: vertex, from: a, to: b)) < 0.001)
    }

    @Test func degenerateSamePointReturnsZeroInsteadOfCrashing() {
        let point = CGPoint(x: 5, y: 5)
        #expect(AngleCalculator.angle(at: point, from: point, to: point) == 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/AngleCalculatorTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: FAIL — `AngleCalculator` does not exist yet.

- [ ] **Step 3: Implement `AngleCalculator`**

```swift
// IronPulse/Services/AngleCalculator.swift
import CoreGraphics
import Foundation

/// Pure 2D geometry: the interior angle in degrees formed at `vertex`
/// between the rays to `a` and `b`. No framework dependency beyond
/// CoreGraphics - takes plain points so it is testable without Vision
/// or a camera.
enum AngleCalculator {
    static func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let vectorA = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let vectorB = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)

        let dot = vectorA.dx * vectorB.dx + vectorA.dy * vectorB.dy
        let magnitudeA = (vectorA.dx * vectorA.dx + vectorA.dy * vectorA.dy).squareRoot()
        let magnitudeB = (vectorB.dx * vectorB.dx + vectorB.dy * vectorB.dy).squareRoot()

        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }

        let cosTheta = max(-1, min(1, dot / (magnitudeA * magnitudeB)))
        return acos(cosTheta) * 180 / .pi
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/AngleCalculatorTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Write the failing tests for `MovementProfileCatalog`**

```swift
// IronPulseTests/MovementProfileCatalogTests.swift
import Foundation
import Testing
@testable import IronPulse

struct MovementProfileCatalogTests {
    @Test func unknownExerciseHasNoProfile() {
        #expect(MovementProfileCatalog.profile(forExerciseID: "not_a_real_exercise") == nil)
    }

    @Test func everyCuratedExerciseHasAProfile() {
        let curatedIDs = [
            "ex_048_sentadilla_trasera_con_barra",
            "ex_060_sentadilla_goblet_con_mancuerna",
            "ex_057_sentadilla_bulgara_con_mancuernas",
            "ex_021_flexiones_pecho",
            "ex_020_fondos_banco",
            "ex_098_curl_barra_recta",
            "ex_078_press_militar_barra",
            "ex_031_peso_muerto_convencional",
        ]
        for id in curatedIDs {
            #expect(MovementProfileCatalog.profile(forExerciseID: id) != nil, "Missing profile for \(id)")
        }
    }

    @Test func squatAndCurlProfilesHaveNonOverlappingDownAndUpRanges() {
        let curl = MovementProfileCatalog.profile(forExerciseID: "ex_098_curl_barra_recta")!
        #expect(!curl.downRange.overlaps(curl.upRange))
    }
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/MovementProfileCatalogTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: FAIL — `MovementProfile` / `MovementProfileCatalog` do not exist yet.

- [ ] **Step 7: Implement `MovementProfile.swift`**

```swift
// IronPulse/Services/MovementProfile.swift
import Foundation

/// Body joints tracked for rep counting, independent of Vision's own
/// joint naming so the counting logic has no framework dependency and
/// can be unit tested without a camera. `PoseDetectorService` (added
/// in a later task) is the only place that maps Vision's joint names
/// onto this enum.
enum BodyJoint: String, Codable, Equatable, Hashable {
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

/// A joint angle to track: the interior angle formed at `vertex`
/// between the rays to `proximal` and `distal` — e.g. the knee angle
/// is the angle at the knee between the hip and the ankle.
struct JointAngle: Equatable {
    let proximal: BodyJoint
    let vertex: BodyJoint
    let distal: BodyJoint
}

/// Per-exercise configuration for the rep counter: which angle to
/// track and which ranges count as the two extremes of one
/// repetition. Every exercise gets its own independent profile —
/// nothing is shared between exercises beyond the `RepCounterEngine`
/// that interprets them. `downRange`/`upRange` are exercise-relative
/// labels, not literal body position: for a squat "up" is standing
/// (the peak angle), for a curl "up" is the top of the curl (the
/// trough angle). See `RepCounterEngine` for how a rep is counted.
struct MovementProfile: Equatable {
    let primaryAngle: JointAngle
    let downRange: ClosedRange<Double>
    let upRange: ClosedRange<Double>
}

/// The curated set of exercises the Smart Assistant supports (see the
/// design spec for why these eight and not the full 146-exercise
/// catalog). Angle thresholds below are a reasonable starting point
/// based on standard range-of-motion references for each movement —
/// expect to retune them against real Vision output on a physical
/// device during Task 4's verification, per the design spec.
enum MovementProfileCatalog {
    static func profile(forExerciseID id: String) -> MovementProfile? {
        profiles[id]
    }

    private static let profiles: [String: MovementProfile] = [
        "ex_048_sentadilla_trasera_con_barra": squat,
        "ex_060_sentadilla_goblet_con_mancuerna": squat,
        "ex_057_sentadilla_bulgara_con_mancuernas": squat,
        "ex_021_flexiones_pecho": pushUp,
        "ex_020_fondos_banco": pushUp,
        "ex_098_curl_barra_recta": curl,
        "ex_078_press_militar_barra": overheadPress,
        "ex_031_peso_muerto_convencional": hinge,
    ]

    // Knee angle (hip-knee-ankle): ~85 degrees at the bottom of a
    // working-depth squat, ~170 degrees standing tall.
    private static let squat = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 70...100,
        upRange: 160...180
    )

    // Elbow angle (shoulder-elbow-wrist): ~85 degrees at the bottom
    // of a push-up, ~170 degrees at full lockout.
    private static let pushUp = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...100,
        upRange: 155...180
    )

    // Elbow angle: ~165 degrees hanging extended (the curl's "down"),
    // ~45 degrees at peak contraction (the curl's "up").
    private static let curl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 150...180,
        upRange: 30...60
    )

    // Shoulder angle (hip-shoulder-elbow): ~35 degrees racked at the
    // shoulder, ~165 degrees with the arm locked out overhead.
    private static let overheadPress = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 20...50,
        upRange: 150...180
    )

    // Hip angle (shoulder-hip-knee): ~80 degrees bent over at the
    // bottom of a deadlift, ~170 degrees standing tall at lockout.
    private static let hinge = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
        downRange: 60...100,
        upRange: 160...180
    )
}
```

Note (final cross-task review, 2026-08-02): a tenth/lunge profile
(`ex_053_zancadas_caminando_con_mancuernas`, walking lunge, per-limb
tracking) was originally planned here but cut before shipping — it was
set up in the catalog and asserted by a test, but per-limb tracking was
never actually implemented anywhere in `RepCounterEngine` or
`SmartAssistantModel`, so it would have silently miscounted reps. Removed
rather than shipped broken; may return later as real per-limb tracking
work.

- [ ] **Step 8: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/MovementProfileCatalogTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 9: Write the failing tests for `RepCounterEngine`**

```swift
// IronPulseTests/RepCounterEngineTests.swift
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
        var lastFeedback: FormFeedback?
        _ = engine.update(angle: 170, now: base) // standing
        for angle in [150.0, 120.0, 105.0, 110.0, 130.0, 170.0] {
            t += 0.2
            lastFeedback = engine.update(angle: angle, now: base.addingTimeInterval(t))
        }
        #expect(engine.repCount == 0)
        #expect(lastFeedback == .notDeepEnough)
    }
}
```

- [ ] **Step 10: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/RepCounterEngineTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: FAIL — `RepCounterEngine` does not exist yet.

- [ ] **Step 11: Implement `RepCounterEngine`**

```swift
// IronPulse/Services/RepCounterEngine.swift
import Foundation

/// Feedback classification for one tracked repetition or attempt. The
/// view layer owns the localized copy shown for each case.
enum FormFeedback: Equatable {
    case goodRep
    case notDeepEnough
    case tooFast
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

    init(profile: MovementProfile) {
        self.profile = profile
    }

    @discardableResult
    func update(angle: Double, now: Date = Date()) -> FormFeedback? {
        let isDown = profile.downRange.contains(angle)
        let isUp = profile.upRange.contains(angle)

        switch phase {
        case .unknown:
            if isDown {
                enterDown(now: now)
            } else if isUp {
                enterUp(now: now)
            }
            return nil

        case .down:
            guard isUp else { return nil }
            let feedback = repCompletionFeedback(now: now)
            repCount += 1
            enterUp(now: now)
            return feedback

        case .up:
            if isDown {
                enterDown(now: now)
                return nil
            }
            return checkNearMiss(angle: angle)
        }
    }

    private func enterDown(now: Date) {
        phase = .down
        phaseEnteredAt = now
        previousDistanceToDown = nil
        reportedNearMissThisAttempt = false
    }

    private func enterUp(now: Date) {
        phase = .up
        phaseEnteredAt = now
        previousDistanceToDown = nil
        reportedNearMissThisAttempt = false
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
```

- [ ] **Step 12: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/RepCounterEngineTests -only-testing:IronPulseTests/AngleCalculatorTests -only-testing:IronPulseTests/MovementProfileCatalogTests 2>&1 | grep -E "\*\* TEST|Test case.*failed"`
Expected: `** TEST SUCCEEDED **`, all cases passing.

- [ ] **Step 13: Run the full existing suite to confirm no regressions**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests 2>&1 | grep -E "\*\* TEST|Test case.*failed"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 14: Commit**

```bash
git add IronPulse/Services/MovementProfile.swift IronPulse/Services/AngleCalculator.swift IronPulse/Services/RepCounterEngine.swift IronPulseTests/MovementProfileCatalogTests.swift IronPulseTests/AngleCalculatorTests.swift IronPulseTests/RepCounterEngineTests.swift
git commit -m "Add pure rep-counting core for the Smart Exercise Assistant"
```

---

### Task 2: Assistant UI Shell with Mock Counting (Stage 1)

**Files:**
- Create: `IronPulse/Views/Workouts/SmartAssistantSheet.swift`
- Modify: `IronPulse/Views/Workouts/GuidedWorkoutView.swift`
- Modify: `IronPulse/Localizable.xcstrings`

**Interfaces:**
- Consumes: `MovementProfileCatalog.profile(forExerciseID:)` from Task 1 (to decide whether the button shows).
- Produces: `SmartAssistantSheet(exerciseName: String, targetReps: Int, onFinish: (Int) -> Void)` — this exact signature does not change in Tasks 3 or 4, only its internals do.

This task has no new pure logic (it is view wiring around already-tested code), so there is no TDD test-first step here — verify by building and checking in the simulator per Step 4.

- [ ] **Step 1: Add the new localized strings**

Add these keys to `IronPulse/Localizable.xcstrings`, following the exact structure of existing `guided_session.*` entries (see `guided_session.done` for the pattern) — `es`/`en`/`fr`, all `"state": "translated"`:

| Key | es | en | fr |
|---|---|---|---|
| `guided_session.smart_assistant` | Asistente inteligente | Smart assistant | Assistant intelligent |
| `smart_assistant.finish_set` | Finalizar set | Finish set | Terminer la série |
| `smart_assistant.feedback.good_rep` | Buena repetición | Good rep | Bonne répétition |
| `smart_assistant.feedback.not_deep_enough` | No llegaste al rango completo | Not a full range of motion | Amplitude de mouvement incomplète |
| `smart_assistant.feedback.too_fast` | Bajá el ritmo | Slow down | Ralentis le rythme |

- [ ] **Step 2: Create `SmartAssistantSheet` with mock counting**

```swift
// IronPulse/Views/Workouts/SmartAssistantSheet.swift
import SwiftUI

/// Stage-1 UI shell for the Smart Exercise Assistant: the full
/// overlay (exercise name, rep counter, feedback banner, Finish Set
/// button) driven by a mock, self-incrementing counter so the whole
/// flow is reviewable before any camera code exists. A later task
/// swaps the black background for a live camera preview, and another
/// swaps this mock timer for real Vision-based tracking — this
/// view's `onFinish` contract does not change across either swap.
struct SmartAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let targetReps: Int
    let onFinish: (Int) -> Void

    @State private var repCount = 0
    @State private var feedbackMessage: String?
    @State private var mockCountingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(exerciseName)
                    .font(.wwHeadline)
                    .foregroundStyle(.white)
                    .padding(.top, 60)

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.wwCaption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ironAccent.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.ironAccent)
                }

                Spacer()

                Text("\(repCount) / \(targetReps)")
                    .font(.wwDisplay)
                    .foregroundStyle(Color.ironAccent)

                Spacer()

                Button(finishSetLabel, action: finish)
                    .buttonStyle(PrimarySportButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
        .onAppear(perform: startMockCounting)
        .onDisappear { mockCountingTask?.cancel() }
    }

    private func startMockCounting() {
        mockCountingTask = Task { @MainActor in
            while !Task.isCancelled, repCount < targetReps {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                repCount += 1
                feedbackMessage = goodRepLabel
                if repCount >= targetReps {
                    finish()
                }
            }
        }
    }

    private func finish() {
        mockCountingTask?.cancel()
        onFinish(repCount)
        dismiss()
    }

    private var finishSetLabel: String {
        String(localized: "smart_assistant.finish_set", defaultValue: "Finalizar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var goodRepLabel: String {
        String(localized: "smart_assistant.feedback.good_rep", defaultValue: "Buena repeticion", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
}
```

- [ ] **Step 3: Wire the button and sheet into `GuidedWorkoutView`**

Add a new `@State` property alongside the existing ones (near `isShowingExerciseInfo`):

```swift
@State private var isShowingSmartAssistant = false
```

In the `.runningSet` case of `controls(for:)`, add the button between the elapsed-time label and the "Finish set" button:

```swift
case .runningSet:
    VStack(spacing: 8) {
        Text(elapsedLabel(elapsedSetSeconds)).font(.wwHeadline).foregroundStyle(Color.ironAccent)

        if currentExercise.flatMap({ MovementProfileCatalog.profile(forExerciseID: $0.id) }) != nil {
            Button {
                isShowingSmartAssistant = true
            } label: {
                Label(smartAssistantLabel, systemImage: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
            .tint(Color.ironAccent)
        }

        Button(finishSetLabel) {
            finishSet(set)
        }
        .buttonStyle(PrimarySportButtonStyle())
        .disabled(!GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted))
    }
```

Add the `fullScreenCover` modifier alongside the existing `.sheet(isPresented: $isShowingExerciseInfo)` modifier:

```swift
.fullScreenCover(isPresented: $isShowingSmartAssistant) {
    if let set = activeSet, let exercise = currentExercise {
        SmartAssistantSheet(
            exerciseName: exercise.name,
            targetReps: set.targetRepsMax,
            onFinish: { count in
                handleSmartAssistantFinish(set: set, repCount: count)
            }
        )
    }
}
```

Add the handler and label near the other private functions/labels:

```swift
private func handleSmartAssistantFinish(set: SetLog, repCount: Int) {
    set.repsCompleted = repCount
    try? modelContext.save()
    if GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted) {
        finishSet(set)
    }
}

private var smartAssistantLabel: String {
    String(localized: "guided_session.smart_assistant", defaultValue: "Asistente inteligente", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
}
```

- [ ] **Step 4: Build and verify in the simulator**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`

Install and launch on the simulator, start a session, tap "Start set" on one of the eight curated exercises (e.g. any squat variant), confirm the "Asistente inteligente" button appears and does NOT appear for an unsupported exercise (e.g. any cable/machine exercise). Open it, confirm the mock counter increments every 2 seconds up to the target and auto-closes, confirm the manual "Finalizar set" button also works and returns the count reached so far.

- [ ] **Step 5: Run the full existing suite to confirm no regressions**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests 2>&1 | grep -E "\*\* TEST|Test case.*failed"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Views/Workouts/SmartAssistantSheet.swift IronPulse/Views/Workouts/GuidedWorkoutView.swift IronPulse/Localizable.xcstrings
git commit -m "Add Smart Assistant UI shell with mock rep counting"
```

---

### Task 3: Live Camera Feed (Stage 2)

**Files:**
- Create: `IronPulse/Components/CameraSessionController.swift`
- Create: `IronPulse/Components/CameraPreviewView.swift`
- Modify: `IronPulse/Views/Workouts/SmartAssistantSheet.swift`
- Modify: `IronPulse.xcodeproj/project.pbxproj`
- Modify: `IronPulse/Localizable.xcstrings`

**Interfaces:**
- Produces: `CameraSessionController` (`@Observable`, owns `AVCaptureSession`, exposes `authorizationState`, `cameraPosition`, `start()`, `stop()`, `toggleCamera()`, `onFrame: ((CVPixelBuffer) -> Void)?`), `CameraPreviewView(session: AVCaptureSession)`.
- Consumes: nothing new from earlier tasks — `onFrame` is left unused by this task (Task 4 wires it to Vision). The mock counting from Task 2 stays as the counting driver; only the visual background becomes a real camera feed.

This task's new logic is UIKit/AVFoundation bridging and hardware session management — not unit-testable. Verify with Step 5 (build) and Step 6 (manual device check, camera does not work in the Simulator).

- [ ] **Step 1: Update the camera permission description**

The existing `NSCameraUsageDescription` only mentions the profile photo. Update it in all six configurations in `IronPulse.xcodeproj/project.pbxproj`:

```bash
sed -i '' 's/INFOPLIST_KEY_NSCameraUsageDescription = "Watt + Weight usa la camara para tomar tu foto de perfil.";/INFOPLIST_KEY_NSCameraUsageDescription = "Watt + Weight usa la camara para tomar tu foto de perfil y, si lo activas, para el Asistente Inteligente que detecta tu postura durante un set. El video nunca se graba ni se envia a ningun lado.";/g' IronPulse.xcodeproj/project.pbxproj
grep -n "NSCameraUsageDescription" IronPulse.xcodeproj/project.pbxproj
```

Expected: 6 matching lines with the new text.

- [ ] **Step 2: Add the new localized strings**

Add to `IronPulse/Localizable.xcstrings`:

| Key | es | en | fr |
|---|---|---|---|
| `smart_assistant.camera_permission_denied` | Watt + Weight necesita acceso a la cámara para el Asistente Inteligente. | Watt + Weight needs camera access for the Smart Assistant. | Watt + Weight a besoin d'accéder à la caméra pour l'Assistant Intelligent. |
| `smart_assistant.open_settings` | Abrir Ajustes | Open Settings | Ouvrir les Réglages |
| `smart_assistant.toggle_camera` | Cambiar cámara | Switch camera | Changer de caméra |

- [ ] **Step 3: Implement `CameraSessionController`**

```swift
// IronPulse/Components/CameraSessionController.swift
import AVFoundation
import Foundation

/// Owns the AVCaptureSession for the Smart Assistant's live camera
/// feed. Frames reach `onFrame` and are never written to disk, cached,
/// or kept beyond the caller's own processing of that single call —
/// see the design spec's "no video/frame storage" constraint.
@Observable
final class CameraSessionController: NSObject {
    enum AuthorizationState {
        case notDetermined
        case authorized
        case denied
    }

    enum CameraPosition {
        case front
        case back
    }

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var cameraPosition: CameraPosition = .back

    let session = AVCaptureSession()
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.BERNU.WattWeight.camera-session")
    private var currentInput: AVCaptureDeviceInput?

    func requestAuthorizationIfNeeded() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationState = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorizationState = granted ? .authorized : .denied
        default:
            authorizationState = .denied
        }
    }

    func start() {
        guard authorizationState == .authorized else { return }
        sessionQueue.async { [weak self] in
            self?.configureSessionIfNeeded()
            self?.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func toggleCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        sessionQueue.async { [weak self] in
            self?.reconfigureInput()
        }
    }

    private func configureSessionIfNeeded() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .medium
        reconfigureInput()

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    private func reconfigureInput() {
        session.beginConfiguration()
        if let currentInput {
            session.removeInput(currentInput)
        }

        let position: AVCaptureDevice.Position = cameraPosition == .back ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        session.commitConfiguration()
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
```

- [ ] **Step 4: Implement `CameraPreviewView`**

```swift
// IronPulse/Components/CameraPreviewView.swift
import AVFoundation
import SwiftUI

/// Thin UIKit bridge for the live camera preview layer. No logic of
/// its own — session lifecycle lives entirely in
/// `CameraSessionController`.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
```

- [ ] **Step 5: Wire the camera into `SmartAssistantSheet`**

Replace the `Color.black.ignoresSafeArea()` background and add permission handling and the toggle button. The mock counting logic from Task 2 is unchanged — only the background and permission flow change:

```swift
// Replace the existing background + add these properties/views to SmartAssistantSheet

@State private var cameraController = CameraSessionController()

var body: some View {
    ZStack {
        switch cameraController.authorizationState {
        case .authorized:
            CameraPreviewView(session: cameraController.session)
                .ignoresSafeArea()
        case .denied:
            Color.black.ignoresSafeArea()
            permissionDeniedOverlay
        case .notDetermined:
            Color.black.ignoresSafeArea()
        }

        VStack(spacing: 24) {
            HStack {
                Text(exerciseName)
                    .font(.wwHeadline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    cameraController.toggleCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(toggleCameraLabel)
            }
            .padding(.top, 60)
            .padding(.horizontal)

            // ... feedback banner, counter, Finish Set button unchanged from Task 2 ...
        }
    }
    .task {
        await cameraController.requestAuthorizationIfNeeded()
        if cameraController.authorizationState == .authorized {
            cameraController.start()
        }
    }
    .onAppear(perform: startMockCounting)
    .onDisappear {
        mockCountingTask?.cancel()
        cameraController.stop()
    }
}

private var permissionDeniedOverlay: some View {
    VStack(spacing: 16) {
        Text(permissionDeniedLabel)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        Button(openSettingsLabel) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        .buttonStyle(.bordered)
        .tint(Color.ironAccent)
    }
}

private var permissionDeniedLabel: String {
    String(localized: "smart_assistant.camera_permission_denied", defaultValue: "Watt + Weight necesita acceso a la camara para el Asistente Inteligente.", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
}

private var openSettingsLabel: String {
    String(localized: "smart_assistant.open_settings", defaultValue: "Abrir Ajustes", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
}

private var toggleCameraLabel: String {
    String(localized: "smart_assistant.toggle_camera", defaultValue: "Cambiar camara", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
}
```

Apply this by editing the actual file (the snippet above shows what changes; integrate it into the full `SmartAssistantSheet` body from Task 2 rather than replacing the whole file blindly — the feedback banner, rep counter, and Finish Set button from Task 2 stay exactly as they were, just now on top of a live camera background instead of solid black).

- [ ] **Step 6: Build and verify**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`

The Simulator has no camera, so `authorizationState` will report `.authorized` (Simulator auto-grants) but `CameraPreviewView` will show a black/empty feed — that is expected and not a bug. **This step needs verification on a physical device** by the user: confirm the permission prompt appears with the updated description, confirm denying it shows the Settings link and that link works, confirm granting it shows a real live preview, confirm the front/back toggle switches cameras.

- [ ] **Step 7: Run the full existing suite to confirm no regressions**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests 2>&1 | grep -E "\*\* TEST|Test case.*failed"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add IronPulse/Components/CameraSessionController.swift IronPulse/Components/CameraPreviewView.swift IronPulse/Views/Workouts/SmartAssistantSheet.swift IronPulse.xcodeproj/project.pbxproj IronPulse/Localizable.xcstrings
git commit -m "Add live camera feed to the Smart Assistant (Stage 2)"
```

---

### Task 4: Vision Pose Detection and Real Rep Counting (Stage 3)

**Files:**
- Create: `IronPulse/Services/PoseDetectorService.swift`
- Create: `IronPulse/Views/Workouts/SmartAssistantModel.swift`
- Modify: `IronPulse/Views/Workouts/SmartAssistantSheet.swift`
- Test: `IronPulseTests/PoseDetectorServiceTests.swift`
- Modify: `IronPulse/Localizable.xcstrings`

**Interfaces:**
- Consumes: `BodyJoint`, `MovementProfile`, `MovementProfileCatalog`, `AngleCalculator`, `RepCounterEngine`, `FormFeedback` from Task 1; `CameraSessionController.onFrame` from Task 3.
- Produces: `PoseDetectorService.detectJoints(in: CVPixelBuffer) -> [BodyJoint: CGPoint]`, `SmartAssistantModel` (the real counting driver, replacing Task 2's mock timer).

- [ ] **Step 1: Add the new localized string**

Add to `IronPulse/Localizable.xcstrings`:

| Key | es | en | fr |
|---|---|---|---|
| `smart_assistant.no_person_detected` | No te vemos bien, ajustá el encuadre | We can't see you clearly, adjust the framing | On ne vous voit pas bien, ajustez le cadrage |

- [ ] **Step 2: Write the failing test for the joint-angle lookup logic**

The Vision request itself cannot be unit tested (needs a real camera frame), but the pure "given detected joints and a profile, compute the angle" logic can be, since it is just dictionary lookups plus the already-tested `AngleCalculator`:

```swift
// IronPulseTests/PoseDetectorServiceTests.swift
import CoreGraphics
import Foundation
import Testing
@testable import IronPulse

struct PoseDetectorServiceTests {
    @Test func primaryAngleReturnsNilWhenAJointIsMissing() {
        let profile = MovementProfile(
            primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            downRange: 70...100,
            upRange: 160...180
        )
        let incompleteJoints: [BodyJoint: CGPoint] = [
            .leftHip: CGPoint(x: 0, y: 0),
            .leftKnee: CGPoint(x: 0, y: 1),
            // .leftAnkle missing
        ]
        #expect(SmartAssistantModel.primaryAngle(joints: incompleteJoints, profile: profile) == nil)
    }

    @Test func primaryAngleComputesFromDetectedJoints() {
        let profile = MovementProfile(
            primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            downRange: 70...100,
            upRange: 160...180
        )
        let joints: [BodyJoint: CGPoint] = [
            .leftHip: CGPoint(x: 1, y: 0),
            .leftKnee: CGPoint(x: 0, y: 0),
            .leftAnkle: CGPoint(x: 0, y: 1),
        ]
        let angle = SmartAssistantModel.primaryAngle(joints: joints, profile: profile)
        #expect(angle != nil)
        #expect(abs(angle! - 90) < 0.001)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/PoseDetectorServiceTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: FAIL — `SmartAssistantModel` does not exist yet.

- [ ] **Step 4: Implement `PoseDetectorService`**

```swift
// IronPulse/Services/PoseDetectorService.swift
import CoreVideo
import Foundation
import Vision

/// Wraps `VNDetectHumanBodyPoseRequest` and translates Vision's own
/// joint naming into this app's `BodyJoint` enum, so the counting
/// logic (`RepCounterEngine`, `AngleCalculator`) never imports Vision
/// and stays unit-testable without a camera. This is the ONLY file in
/// the feature that talks to Vision directly.
enum PoseDetectorService {
    static func detectJoints(in pixelBuffer: CVPixelBuffer) -> [BodyJoint: CGPoint] {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return [:]
        }

        guard let observation = request.results?.first,
              let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return [:]
        }

        var joints: [BodyJoint: CGPoint] = [:]
        for (visionName, ourJoint) in jointMapping {
            guard let point = recognizedPoints[visionName], point.confidence > 0.3 else { continue }
            joints[ourJoint] = point.location
        }
        return joints
    }

    private static let jointMapping: [VNHumanBodyPoseObservation.JointName: BodyJoint] = [
        .leftShoulder: .leftShoulder,
        .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow,
        .rightElbow: .rightElbow,
        .leftWrist: .leftWrist,
        .rightWrist: .rightWrist,
        .leftHip: .leftHip,
        .rightHip: .rightHip,
        .leftKnee: .leftKnee,
        .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle,
        .rightAnkle: .rightAnkle,
    ]
}
```

- [ ] **Step 5: Implement `SmartAssistantModel`**

```swift
// IronPulse/Views/Workouts/SmartAssistantModel.swift
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
    private var frameCounter = 0
    private var didFinish = false
    private let onComplete: (Int) -> Void

    /// Process only every Nth frame — Vision inference is too
    /// expensive to run at full camera frame rate.
    private let frameSkip = 3

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
    // hopping first. Vision inference itself happens on that queue;
    // only the final state update jumps to the main actor.
    nonisolated private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        let joints = PoseDetectorService.detectJoints(in: pixelBuffer)
        Task { @MainActor in
            self.handleDetectedJoints(joints)
        }
    }

    private func handleDetectedJoints(_ joints: [BodyJoint: CGPoint]) {
        guard !didFinish else { return }

        frameCounter += 1
        guard frameCounter % frameSkip == 0 else { return }

        guard let profile = movementProfile, let engine else { return }

        guard let angle = Self.primaryAngle(joints: joints, profile: profile) else {
            personVisible = false
            return
        }
        personVisible = true

        guard let feedback = engine.update(angle: angle) else { return }

        repCount = engine.repCount
        feedbackMessage = Self.message(for: feedback)

        if repCount >= targetReps {
            finish()
        }
    }

    static func primaryAngle(joints: [BodyJoint: CGPoint], profile: MovementProfile) -> Double? {
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
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/PoseDetectorServiceTests 2>&1 | grep -E "\*\* TEST|error:"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Replace the mock counter in `SmartAssistantSheet` with `SmartAssistantModel`**

Add an `exerciseID: String` parameter alongside the existing `exerciseName` (the id is needed to look up the profile; the name stays for display), remove the Task-2 mock-counting `@State`/`startMockCounting()`/local `repCount`/`feedbackMessage`, and drive the view from `SmartAssistantModel` instead:

```swift
// SmartAssistantSheet's new shape after this task
struct SmartAssistantSheet: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseID: String
    let exerciseName: String
    let targetReps: Int
    let onFinish: (Int) -> Void

    @State private var model: SmartAssistantModel

    init(exerciseID: String, exerciseName: String, targetReps: Int, onFinish: @escaping (Int) -> Void) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.targetReps = targetReps
        self.onFinish = onFinish
        _model = State(initialValue: SmartAssistantModel(
            exerciseID: exerciseID,
            targetReps: targetReps,
            onComplete: onFinish
        ))
    }

    var body: some View {
        ZStack {
            switch model.cameraController.authorizationState {
            case .authorized:
                CameraPreviewView(session: model.cameraController.session)
                    .ignoresSafeArea()
            case .denied:
                Color.black.ignoresSafeArea()
                permissionDeniedOverlay
            case .notDetermined:
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 24) {
                HStack {
                    Text(exerciseName)
                        .font(.wwHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        model.cameraController.toggleCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(toggleCameraLabel)
                }
                .padding(.top, 60)
                .padding(.horizontal)

                if !model.personVisible {
                    Text(noPersonLabel)
                        .font(.wwCaption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.3), in: Capsule())
                        .foregroundStyle(.white)
                } else if let feedbackMessage = model.feedbackMessage {
                    Text(feedbackMessage)
                        .font(.wwCaption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ironAccent.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.ironAccent)
                }

                Spacer()

                Text("\(model.repCount) / \(targetReps)")
                    .font(.wwDisplay)
                    .foregroundStyle(Color.ironAccent)

                Spacer()

                Button(finishSetLabel) {
                    model.finish()
                    dismiss()
                }
                .buttonStyle(PrimarySportButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .task {
            await model.cameraController.requestAuthorizationIfNeeded()
            if model.cameraController.authorizationState == .authorized {
                model.start()
            }
        }
    }

    private var noPersonLabel: String {
        String(localized: "smart_assistant.no_person_detected", defaultValue: "No te vemos bien, ajusta el encuadre", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    // finishSetLabel, permissionDeniedOverlay, permissionDeniedLabel,
    // openSettingsLabel, toggleCameraLabel unchanged from Task 3.
}
```

Update the call site in `GuidedWorkoutView`'s `fullScreenCover` (added in Task 2) to pass the new `exerciseID` parameter:

```swift
.fullScreenCover(isPresented: $isShowingSmartAssistant) {
    if let set = activeSet, let exercise = currentExercise {
        SmartAssistantSheet(
            exerciseID: exercise.id,
            exerciseName: exercise.name,
            targetReps: set.targetRepsMax,
            onFinish: { count in
                handleSmartAssistantFinish(set: set, repCount: count)
            }
        )
    }
}
```

Note the `finish()` on `SmartAssistantModel` already calls `onComplete` (which is `onFinish`), so the closure passed to `Button(finishSetLabel)` must not call `onFinish` a second time — only `model.finish()` and `dismiss()`, matching the code above.

- [ ] **Step 8: Build and verify**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`

**This task's core feature — real pose detection — needs verification on a physical device** by the user: open the assistant on a curated exercise with the phone propped up, perform a few real repetitions, confirm the counter increments on genuine full-range reps, confirm the "not deep enough" / "slow down" feedback appears for a deliberately shallow or too-fast rep, confirm auto-close at the target rep count, confirm the manual "Finalizar set" button still works at any point.

- [ ] **Step 9: Run the full existing suite to confirm no regressions**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests 2>&1 | grep -E "\*\* TEST|Test case.*failed"`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 10: Commit**

```bash
git add IronPulse/Services/PoseDetectorService.swift IronPulse/Views/Workouts/SmartAssistantModel.swift IronPulse/Views/Workouts/SmartAssistantSheet.swift IronPulse/Views/Workouts/GuidedWorkoutView.swift IronPulseTests/PoseDetectorServiceTests.swift IronPulse/Localizable.xcstrings
git commit -m "Wire real Vision pose detection into the Smart Assistant (Stage 3)"
```

---

### Task 5: Full Verification

**Files:** none — this task only runs checks.

- [ ] **Step 1: Run the full unit test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests 2>&1 | grep -E "\*\* TEST|Test case.*failed"`
Expected: `** TEST SUCCEEDED **`, zero failures.

- [ ] **Step 2: Build for both Simulator and a physical device destination**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`

The device build itself can be verified with `xcodebuild build -destination 'generic/platform=iOS'` (compiles without needing a connected device); actually running it on a physical iPhone is the user's own step, not something the controller can do in this environment.

- [ ] **Step 3: Full manual walkthrough on the user's physical device**

This is the one task in this plan the controller cannot execute or verify directly — Vision pose detection needs a real camera and does not run meaningfully on the Simulator or on synthetic test data. The user should walk through, in order:

1. Start a guided session, reach a curated exercise, tap "Start set" — confirm the Smart Assistant button appears only for curated exercises.
2. Open the assistant, confirm the camera permission prompt shows the updated description mentioning the assistant (not just the profile photo).
3. Deny permission once (can be reset via Settings → Watt + Weight → re-triggering, or reinstalling) — confirm the denied state shows the message and "Open Settings" link, and that link actually opens Settings.
4. Grant permission, confirm a live camera preview appears, confirm the front/back toggle works.
5. Perform real repetitions of a curated exercise (e.g. bodyweight squats) with the phone propped up — confirm the counter increments on genuine full-range reps, confirm a deliberately shallow rep triggers the "not deep enough" feedback, confirm a very fast rep triggers "slow down".
6. Let the counter reach the set's target reps — confirm the assistant auto-closes and the reps carry over into the set.
7. Open the assistant again and tap "Finalizar set" manually partway through — confirm it closes immediately with the count reached so far.
8. With the assistant-provided rep count and a weight already typed in beforehand, confirm the set auto-completes (starts rest) exactly as the existing "Finish set" button would. With weight still at 0, confirm the set does NOT auto-complete and the existing "Finish set" button stays disabled until weight is entered.

- [ ] **Step 4: Report back**

Report which of Step 3's checks passed, and any threshold values from `MovementProfileCatalog` that need retuning based on real results (per Task 1's note that these are a starting point, not final calibration).
