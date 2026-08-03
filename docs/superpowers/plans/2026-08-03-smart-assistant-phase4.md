# Smart Assistant Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second, exercise-appropriate angle check to every one of the 10 existing movement profiles to catch the most common form problem — using body momentum/swing instead of isolating the working joint — and stop counting reps that violate it. Also reduce how often the Smart Assistant speaks: `.goodRep` only on the first, middle, and last rep of a set; corrective feedback always speaks.

**Architecture:** No changes to `AngleCalculator.swift` or `PoseDetectorService.swift` — the secondary check reuses the same 4 joint triangles already tracked (shoulder-elbow-wrist, hip-shoulder-elbow, shoulder-hip-knee, hip-knee-ankle), just in a second role per profile. `RepCounterEngine` gains a generic secondary-check mechanism (two shapes: `.stability`, for isolation exercises where a joint should stay near wherever it started the rep; `.bounded`, for compound exercises where that joint naturally moves as part of correct form, checked against a fixed absolute range instead). A violated check produces a new `.badForm` feedback case and does not increment the rep count, exactly like `.notDeepEnough` today.

**Tech Stack:** Swift, Swift Testing (`@Test`/`#expect`).

**Depends on:** this plan is written against the branch `smart-assistant-phase3` (not `main`) — it needs all 10 movement profiles (`lateralRaise`/`legExtension`/`legCurl` don't exist on `main` yet, since that PR hasn't merged). Branch this plan's work off `smart-assistant-phase3`.

## Global Constraints

- Every one of the 10 existing profiles gets exactly one `secondaryCheck`, per this table (angles reuse the 4 existing triangles; tolerances/ranges are starting estimates to retune on device, same as every other threshold in this project):

  | Profile | Check | Angle | Detects |
  |---|---|---|---|
  | `squat` | `.bounded(150...180` → **50...180**`)` | shoulder-hip-knee | Torso collapses too far forward |
  | `pushUp` | `.bounded(150...180)` | shoulder-hip-knee | Hips sag (broken body line) |
  | `curl` | `.stability(±15°)` | hip-shoulder-elbow | Shoulder swings for momentum |
  | `overheadPress` | `.bounded(150...180)` | shoulder-hip-knee | Pushing with legs/back instead of the shoulder |
  | `hinge` | `.bounded(150...180)` | hip-knee-ankle | Knees bend too much (turns into a squat) |
  | `row` | `.stability(±15°)` | shoulder-hip-knee | Torso rocks back to heave the weight |
  | `tricepsExtension` | `.stability(±15°)` | hip-shoulder-elbow | Shoulder swings for momentum |
  | `lateralRaise` | `.stability(±15°)` | shoulder-hip-knee | Torso sways to help lift the arm |
  | `legExtension` | `.stability(±15°)` | shoulder-hip-knee | Torso moves to help |
  | `legCurl` | `.stability(±15°)` | shoulder-hip-knee | Torso moves to help |

  (Note the `squat` row: the design spec's table says `50°...180°` for squat specifically — a wider allowance than the other `.bounded` checks, since a squat's torso naturally leans forward more than a push-up's or press's does.)
- A rep whose secondary check is violated at any point before the rep completes returns `.badForm` and does **not** increment `repCount` — same behavior class as `.notDeepEnough` today, not `.tooFast` (which still counts).
- `.goodRep` is spoken only when `repCount == 1`, `repCount == max(1, targetReps / 2)`, or `repCount == targetReps`. `.notDeepEnough`, `.tooFast`, and `.badForm` are always spoken, unconditionally.
- Tests use the Swift Testing framework (`@Test`/`#expect`), matching every existing file in `IronPulseTests/`.
- Test runs must pass `-parallel-testing-enabled NO` (limited simulator process headroom on this machine; parallel test cloning causes unrelated "insufficient system resources" failures).
- This phase does not expand exercise coverage beyond the 64 exercises already mapped in `MovementProfileCatalog` — see the design spec for why that's separate, larger work.

---

### Task 1: Secondary-check mechanism in RepCounterEngine + assign one to each of the 10 profiles

**Files:**
- Modify: `IronPulse/Services/MovementProfile.swift`
- Modify: `IronPulse/Services/RepCounterEngine.swift`
- Modify: `IronPulseTests/RepCounterEngineTests.swift`
- Modify: `IronPulseTests/MovementProfileCatalogTests.swift`

**Interfaces:**
- Consumes: `JointAngle`, `BodyJoint` (already defined).
- Produces: `SecondaryCheck` enum (`.stability(angle:toleranceDegrees:)` / `.bounded(angle:allowedRange:)`, both cases carrying a `JointAngle` plus their own parameter), `MovementProfile.secondaryCheck: SecondaryCheck?` (defaults to `nil` via a custom initializer, so no other file needs to change just because this field exists), `FormFeedback.badForm` (new case), `RepCounterEngine.update(angle:secondaryAngle:now:)` (adds an optional `secondaryAngle` parameter, defaulting to `nil`, so every existing call site keeps compiling unchanged unless it wants to opt in).

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `IronPulseTests/RepCounterEngineTests.swift` with:

```swift
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
        _ = engine.update(angle: 85, secondaryAngle: 160, now: base.addingTimeInterval(0.2)) // depth, torso within 150...180
        let feedback = engine.update(angle: 170, secondaryAngle: 178, now: base.addingTimeInterval(0.5))
        #expect(engine.repCount == 1)
        #expect(feedback == .goodRep)
    }

    @Test func boundedCheckOutsideRangeReturnsBadFormAndDoesNotCount() {
        let engine = RepCounterEngine(profile: boundedProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 175, now: base)
        _ = engine.update(angle: 85, secondaryAngle: 120, now: base.addingTimeInterval(0.2)) // torso collapses below 150
        let feedback = engine.update(angle: 170, secondaryAngle: 178, now: base.addingTimeInterval(0.5))
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
}
```

Also append these 10 tests to the END of `IronPulseTests/MovementProfileCatalogTests.swift` (inside the existing `MovementProfileCatalogTests` struct, after its last test — do not remove or modify any existing test in that file):

```swift
    @Test func squatHasABoundedTorsoCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_048_sentadilla_trasera_con_barra")!
        #expect(profile.secondaryCheck == .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 50...180
        ))
    }

    @Test func pushUpHasABoundedTorsoCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_021_flexiones_pecho")!
        #expect(profile.secondaryCheck == .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        ))
    }

    @Test func curlHasAShoulderStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_098_curl_barra_recta")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        ))
    }

    @Test func overheadPressHasABoundedTorsoCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_078_press_militar_barra")!
        #expect(profile.secondaryCheck == .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        ))
    }

    @Test func hingeHasABoundedKneeCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_031_peso_muerto_convencional")!
        #expect(profile.secondaryCheck == .bounded(
            angle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            allowedRange: 150...180
        ))
    }

    @Test func rowHasATorsoStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_027_remo_sentado_polea")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        ))
    }

    @Test func tricepsExtensionHasAShoulderStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_117_pushdown_polea_cuerda")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        ))
    }

    @Test func lateralRaiseHasATorsoStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_085_elevaciones_laterales_mancuernas")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        ))
    }

    @Test func legExtensionHasATorsoStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_054_extension_de_piernas_en_maquina")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        ))
    }

    @Test func legCurlHasATorsoStabilityCheck() {
        let profile = MovementProfileCatalog.profile(forExerciseID: "ex_056_curl_femoral_sentado")!
        #expect(profile.secondaryCheck == .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        ))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/RepCounterEngineTests -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: FAIL (build error — `secondaryCheck`, `SecondaryCheck`, `.badForm`, and `update(angle:secondaryAngle:now:)` don't exist yet)

- [ ] **Step 3: Implement the secondary-check mechanism**

Replace the entire contents of `IronPulse/Services/MovementProfile.swift` with:

```swift
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

/// A secondary constraint checked alongside `MovementProfile.primaryAngle`,
/// to catch the most common form problem: using body momentum/swing
/// instead of isolating the working joint. Two shapes cover the two
/// broad categories of exercise:
///
/// - `.stability`: for isolation exercises, where a joint (typically
///   the shoulder or torso) should stay put while only the primary
///   joint moves. Measured relative to wherever that joint happened to
///   be when the rep attempt started (there's no single "correct"
///   absolute angle here — only "however you started, don't drift far
///   from it").
/// - `.bounded`: for compound exercises, where that same joint is
///   *supposed* to move as a natural part of correct form (a squat's
///   torso leans forward, a hinge's torso tips over) — so instead of a
///   per-rep baseline, it's checked against one fixed absolute range
///   for the whole rep attempt.
enum SecondaryCheck: Equatable {
    case stability(angle: JointAngle, toleranceDegrees: Double)
    case bounded(angle: JointAngle, allowedRange: ClosedRange<Double>)

    var angle: JointAngle {
        switch self {
        case .stability(let angle, _): return angle
        case .bounded(let angle, _): return angle
        }
    }
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
    let secondaryCheck: SecondaryCheck?

    init(
        primaryAngle: JointAngle,
        downRange: ClosedRange<Double>,
        upRange: ClosedRange<Double>,
        secondaryCheck: SecondaryCheck? = nil
    ) {
        self.primaryAngle = primaryAngle
        self.downRange = downRange
        self.upRange = upRange
        self.secondaryCheck = secondaryCheck
    }
}

/// The curated set of exercises the Smart Assistant supports (see the
/// phase 3 design spec for why these 64 and not the full 146-exercise
/// catalog). Angle thresholds below are a reasonable starting point
/// based on standard range-of-motion references for each movement —
/// expect to retune them against real Vision output on a physical
/// device during verification, per the design spec.
enum MovementProfileCatalog {
    static func profile(forExerciseID id: String) -> MovementProfile? {
        profiles[id]
    }

    private static let profiles: [String: MovementProfile] = [
        "ex_048_sentadilla_trasera_con_barra": squat,
        "ex_060_sentadilla_goblet_con_mancuerna": squat,
        "ex_057_sentadilla_bulgara_con_mancuernas": squat,
        "ex_049_sentadilla_frontal_con_barra": squat,
        "ex_062_sentadilla_hack_en_maquina": squat,
        "ex_063_sentadilla_en_maquina_smith": squat,
        "ex_058_sentadilla_sissy": squat,
        "ex_076_sentadilla_sumo_con_mancuerna": squat,
        "ex_021_flexiones_pecho": pushUp,
        "ex_020_fondos_banco": pushUp,
        "ex_019_fondos_paralelas": pushUp,
        "ex_022_flexiones_inclinadas": pushUp,
        "ex_015_press_pecho_maquina": pushUp,
        "ex_123_flexiones_diamante": pushUp,
        "ex_124_fondos_maquina": pushUp,
        "ex_098_curl_barra_recta": curl,
        "ex_100_curl_alterno_mancuernas": curl,
        "ex_101_curl_martillo_mancuernas": curl,
        "ex_104_curl_concentrado": curl,
        "ex_099_curl_barra_z": curl,
        "ex_102_curl_predicador_barra_z": curl,
        "ex_103_curl_predicador_maquina": curl,
        "ex_105_curl_polea_baja": curl,
        "ex_106_curl_inclinado_mancuernas": curl,
        "ex_108_curl_drag": curl,
        "ex_109_curl_martillo_cuerda_polea": curl,
        "ex_110_curl_agarre_cerrado": curl,
        "ex_111_curl_zottman": curl,
        "ex_112_curl_polea_alta": curl,
        "ex_113_curl_inverso_barra": curl,
        "ex_114_curl_maquina": curl,
        "ex_078_press_militar_barra": overheadPress,
        "ex_079_press_militar_sentado_barra": overheadPress,
        "ex_080_press_hombros_mancuernas": overheadPress,
        "ex_081_press_arnold": overheadPress,
        "ex_082_press_hombros_sentado_mancuernas": overheadPress,
        "ex_083_press_hombros_maquina": overheadPress,
        "ex_084_press_hombros_polea": overheadPress,
        "ex_031_peso_muerto_convencional": hinge,
        "ex_051_peso_muerto_rumano_con_barra": hinge,
        "ex_052_peso_muerto_rumano_con_mancuernas": hinge,
        "ex_032_peso_muerto_rumano": hinge,
        "ex_043_peso_muerto_sumo": hinge,
        "ex_064_peso_muerto_sumo_con_barra": hinge,
        "ex_027_remo_sentado_polea": row,
        "ex_028_jalon_pecho_agarre_ancho": row,
        "ex_023_dominadas_pronadas": row,
        "ex_024_dominadas_supinadas": row,
        "ex_025_dominadas_asistidas_banda": row,
        "ex_029_jalon_pecho_agarre_cerrado": row,
        "ex_033_remo_posterior_polea_cuerda": row,
        "ex_045_face_pull_polea": row,
        "ex_046_remo_arrodillado_polea_alta": row,
        "ex_093_remo_menton_barra": row,
        "ex_094_remo_menton_mancuernas": row,
        "ex_117_pushdown_polea_cuerda": tricepsExtension,
        "ex_118_pushdown_polea_barra_recta": tricepsExtension,
        "ex_120_extension_mancuernas_dos_manos_sobre_cabeza": tricepsExtension,
        "ex_128_extension_polea_cuerda_tras_nuca": tricepsExtension,
        "ex_133_extension_triceps_maquina": tricepsExtension,
        "ex_085_elevaciones_laterales_mancuernas": lateralRaise,
        "ex_087_elevaciones_frontales_mancuernas": lateralRaise,
        "ex_054_extension_de_piernas_en_maquina": legExtension,
        "ex_056_curl_femoral_sentado": legCurl,
    ]

    // Knee angle (hip-knee-ankle): ~85 degrees at the bottom of a
    // working-depth squat, ~170 degrees standing tall. Secondary
    // check: torso (shoulder-hip-knee) shouldn't collapse forward past
    // ~50 degrees — a squat's torso naturally leans forward some, more
    // than the other `.bounded` checks below allow, so this one gets a
    // wider range.
    private static let squat = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 70...100,
        upRange: 160...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 50...180
        )
    )

    // Elbow angle (shoulder-elbow-wrist): ~85 degrees at the bottom
    // of a push-up, ~170 degrees at full lockout. Secondary check:
    // torso (shoulder-hip-knee) stays close to a straight line -
    // sagging hips would drop this well below 150.
    private static let pushUp = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...100,
        upRange: 155...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        )
    )

    // Elbow angle: ~165 degrees hanging extended (the curl's "down"),
    // ~45 degrees at peak contraction (the curl's "up"). Secondary
    // check: shoulder (hip-shoulder-elbow) should stay near wherever
    // it started the rep - swinging it to help curl the weight is the
    // most common curl cheat.
    private static let curl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 150...180,
        upRange: 30...60,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        )
    )

    // Shoulder angle (hip-shoulder-elbow): ~35 degrees racked at the
    // shoulder, ~165 degrees with the arm locked out overhead.
    // Secondary check: torso (shoulder-hip-knee) stays upright -
    // leaning back to "push press" with the legs/back would drop this
    // below 150.
    private static let overheadPress = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 20...50,
        upRange: 150...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            allowedRange: 150...180
        )
    )

    // Hip angle (shoulder-hip-knee): ~80 degrees bent over at the
    // bottom of a deadlift, ~170 degrees standing tall at lockout.
    // Secondary check: knee (hip-knee-ankle) stays relatively straight
    // - bending it too much turns the hinge into a squat.
    private static let hinge = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
        downRange: 60...100,
        upRange: 160...180,
        secondaryCheck: .bounded(
            angle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            allowedRange: 150...180
        )
    )

    // Elbow angle (shoulder-elbow-wrist): ~170 degrees extended
    // reaching for the weight (the row's "down"), ~60-85 degrees
    // pulled to the torso (the row's "up") — the opposite direction
    // from pushUp's elbow angle on the same joint triangle. Secondary
    // check: torso (shoulder-hip-knee) stays near wherever it started
    // - rocking back to heave the weight is the most common row cheat.
    private static let row = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 155...180,
        upRange: 60...85,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Elbow angle (shoulder-elbow-wrist): ~70-95 degrees at the rack
    // position (the extension's "down"), ~160-180 degrees at full
    // lockout (the extension's "up") — the same joint triangle as
    // curl, opposite direction. Secondary check: shoulder
    // (hip-shoulder-elbow) stays near wherever it started, same
    // swing-for-momentum concern as curl.
    private static let tricepsExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...95,
        upRange: 160...180,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
            toleranceDegrees: 15
        )
    )

    // Shoulder angle (hip-shoulder-elbow) - same triangle as
    // overheadPress, with a shorter range: ~0-25 degrees with the arm
    // at the side (the raise's "down" — the floor is 0, not ~10, since
    // the arm hanging naturally at rest can sit flush against the
    // torso), ~75-95 degrees at shoulder height (the raise's "up") -
    // stops well short of overheadPress's overhead lockout. Covers
    // both lateral and front raises: from a front-facing camera the
    // two produce a very similar change in this angle even though the
    // arm moves in a different plane (out to the side vs. forward) -
    // the tracked angle doesn't distinguish which plane, so one
    // profile serves both. Secondary check: torso (shoulder-hip-knee)
    // stays near wherever it started - swaying to help lift the arm is
    // the most common raise cheat.
    private static let lateralRaise = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 0...25,
        upRange: 75...95,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Knee angle (hip-knee-ankle) - same triangle as squat, seated
    // machine motion: ~80-100 degrees with the leg bent under the seat
    // (the extension's "down"), ~160-180 degrees with the leg extended
    // straight out (the extension's "up"). Secondary check: torso
    // (shoulder-hip-knee) stays near wherever it started - it should
    // stay put in a seated machine.
    private static let legExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 80...100,
        upRange: 160...180,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )

    // Knee angle (hip-knee-ankle) - same triangle as legExtension,
    // opposite direction: ~160-180 degrees with the leg extended (the
    // curl's "down"), ~70-90 degrees curled under the seat (the
    // curl's "up"). Secondary check: same torso-stability concern as
    // legExtension.
    private static let legCurl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 160...180,
        upRange: 70...90,
        secondaryCheck: .stability(
            angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
            toleranceDegrees: 15
        )
    )
}
```

Replace the entire contents of `IronPulse/Services/RepCounterEngine.swift` with:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/RepCounterEngineTests -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/MovementProfile.swift IronPulse/Services/RepCounterEngine.swift IronPulseTests/RepCounterEngineTests.swift IronPulseTests/MovementProfileCatalogTests.swift
git commit -m "Add secondary form-check mechanism to RepCounterEngine, assign one to each of the 10 movement profiles"
```

---

### Task 2: Add the `.badForm` phrase bank

**Files:**
- Modify: `IronPulse/Services/FeedbackPhraseBank.swift`
- Modify: `IronPulseTests/FeedbackPhraseBankTests.swift`

**Interfaces:**
- Consumes: `FormFeedback.badForm` (added in Task 1).
- Produces: `FeedbackPhraseBank.badFormPhrases: [LocalizedString]` (16 entries), `phrases(for:)` updated to handle `.badForm`.

- [ ] **Step 1: Write the failing tests**

In `IronPulseTests/FeedbackPhraseBankTests.swift`, add this test (alongside the existing ones, inside the `FeedbackPhraseBankTests` struct):

```swift
    @Test func badFormBankHasExactlySixteenPhrases() {
        #expect(FeedbackPhraseBank.badFormPhrases.count == 16)
    }
```

And replace the existing `everyPhraseHasNonEmptyTextInAllThreeLanguages` test with:

```swift
    @Test func everyPhraseHasNonEmptyTextInAllThreeLanguages() {
        let allPhrases = FeedbackPhraseBank.goodRepPhrases
            + FeedbackPhraseBank.notDeepEnoughPhrases
            + FeedbackPhraseBank.tooFastPhrases
            + FeedbackPhraseBank.badFormPhrases
        for phrase in allPhrases {
            for language in AppLanguage.allCases {
                #expect(!phrase.text(for: language).isEmpty)
            }
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/FeedbackPhraseBankTests`
Expected: FAIL (`badFormPhrases` doesn't exist yet)

- [ ] **Step 3: Add the phrase bank**

In `IronPulse/Services/FeedbackPhraseBank.swift`, update the `phrases(for:)` switch:

Find:
```swift
    private static func phrases(for feedback: FormFeedback) -> [LocalizedString] {
        switch feedback {
        case .goodRep: return goodRepPhrases
        case .notDeepEnough: return notDeepEnoughPhrases
        case .tooFast: return tooFastPhrases
        }
    }
```

Replace with:
```swift
    private static func phrases(for feedback: FormFeedback) -> [LocalizedString] {
        switch feedback {
        case .goodRep: return goodRepPhrases
        case .notDeepEnough: return notDeepEnoughPhrases
        case .tooFast: return tooFastPhrases
        case .badForm: return badFormPhrases
        }
    }
```

Then add this new bank at the end of the enum (after `tooFastPhrases`, before the closing `}`):

```swift

    static let badFormPhrases: [LocalizedString] = [
        LocalizedString(es: "No uses impulso, controla el movimiento", en: "Don't use momentum, control the movement", fr: "N'utilise pas l'élan, contrôle le mouvement"),
        LocalizedString(es: "Mantén el cuerpo quieto", en: "Keep your body still", fr: "Garde le corps immobile"),
        LocalizedString(es: "Evita balancear el peso", en: "Avoid swinging the weight", fr: "Évite de balancer le poids"),
        LocalizedString(es: "Aísla el músculo, no balancees el cuerpo", en: "Isolate the muscle, don't swing your body", fr: "Isole le muscle, ne balance pas ton corps"),
        LocalizedString(es: "Controla el movimiento sin ayudarte con el cuerpo", en: "Control the movement without using body momentum", fr: "Contrôle le mouvement sans utiliser l'élan du corps"),
        LocalizedString(es: "Menos impulso, más control", en: "Less momentum, more control", fr: "Moins d'élan, plus de contrôle"),
        LocalizedString(es: "Esa repetición no cuenta, usaste impulso", en: "That rep doesn't count, you used momentum", fr: "Cette répétition ne compte pas, tu as utilisé l'élan"),
        LocalizedString(es: "Mantén la postura estable", en: "Keep your posture stable", fr: "Garde une posture stable"),
        LocalizedString(es: "No balancees el torso", en: "Don't sway your torso", fr: "Ne balance pas ton torse"),
        LocalizedString(es: "Concéntrate en el músculo, no en el impulso", en: "Focus on the muscle, not the momentum", fr: "Concentre-toi sur le muscle, pas sur l'élan"),
        LocalizedString(es: "Evita ayudarte con el cuerpo", en: "Avoid using your body to help", fr: "Évite de t'aider avec le corps"),
        LocalizedString(es: "Controla mejor la forma", en: "Control your form better", fr: "Contrôle mieux ta forme"),
        LocalizedString(es: "El cuerpo debe quedarse quieto en este movimiento", en: "Your body should stay still during this movement", fr: "Ton corps doit rester immobile pendant ce mouvement"),
        LocalizedString(es: "Repite sin balancear", en: "Repeat without swinging", fr: "Répète sans balancer"),
        LocalizedString(es: "Mantén el control durante toda la repetición", en: "Keep control throughout the whole rep", fr: "Garde le contrôle pendant toute la répétition"),
        LocalizedString(es: "Reduce el balanceo para que cuente", en: "Reduce the swinging so it counts", fr: "Réduis le balancement pour qu'elle compte"),
    ]
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/FeedbackPhraseBankTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/FeedbackPhraseBank.swift IronPulseTests/FeedbackPhraseBankTests.swift
git commit -m "Add badForm phrase bank (16 phrases, 3 languages)"
```

---

### Task 3: Wire the secondary angle and audio-frequency pacing into SmartAssistantModel

**Files:**
- Modify: `IronPulse/Views/Workouts/SmartAssistantModel.swift`
- Modify: `IronPulseTests/PoseDetectorServiceTests.swift`

**Interfaces:**
- Consumes: `MovementProfile.secondaryCheck`, `SecondaryCheck.angle`, `RepCounterEngine.update(angle:secondaryAngle:now:)`, `FeedbackPhraseBank.badFormPhrases` (all from Tasks 1-2).
- Produces: `SmartAssistantModel.secondaryAngle(joints:profile:) -> Double?` (static, mirrors the existing `primaryAngle`), `SmartAssistantModel.shouldSpeak(for:repCount:targetReps:) -> Bool` (static, pure — testable without a live model instance).

- [ ] **Step 1: Write the failing tests**

In `IronPulseTests/PoseDetectorServiceTests.swift`, add these tests (alongside the existing ones, inside the `PoseDetectorServiceTests` struct):

```swift
    @Test func shouldSpeakAlwaysReturnsTrueForCorrectiveFeedback() {
        #expect(SmartAssistantModel.shouldSpeak(for: .notDeepEnough, repCount: 3, targetReps: 10))
        #expect(SmartAssistantModel.shouldSpeak(for: .tooFast, repCount: 7, targetReps: 10))
        #expect(SmartAssistantModel.shouldSpeak(for: .badForm, repCount: 5, targetReps: 10))
    }

    @Test func shouldSpeakForGoodRepOnlyOnFirstMiddleAndLastRep() {
        let targetReps = 10
        for repCount in 1...targetReps {
            let expected = (repCount == 1 || repCount == 5 || repCount == targetReps)
            #expect(
                SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: repCount, targetReps: targetReps) == expected,
                "repCount \(repCount)"
            )
        }
    }

    @Test func shouldSpeakHandlesSmallTargetsWithoutCrashing() {
        #expect(SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: 1, targetReps: 1))
        #expect(SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: 1, targetReps: 2))
        #expect(SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: 2, targetReps: 2))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/PoseDetectorServiceTests`
Expected: FAIL (`shouldSpeak` doesn't exist yet)

- [ ] **Step 3: Implement the wiring**

In `IronPulse/Views/Workouts/SmartAssistantModel.swift`, replace this block:

```swift
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
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback, language: language)
        feedbackMessage = phrase
        audioAnnouncer.speak(phrase, language: language)

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
}
```

with:

```swift
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
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback, language: language)
        feedbackMessage = phrase
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
```

- [ ] **Step 4: Run the tests to verify they pass, then run the full suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/PoseDetectorServiceTests`
Expected: PASS

Then run the full suite once: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **` (confirms Tasks 1-3 all still integrate correctly together)

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Views/Workouts/SmartAssistantModel.swift IronPulseTests/PoseDetectorServiceTests.swift
git commit -m "Wire secondary-angle form checking and milestone-based audio pacing into SmartAssistantModel"
```

---

### Task 4: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`, including all of Tasks 1-3's new/changed tests plus every pre-existing test.

- [ ] **Step 2: Build for a real device target**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual verification note for the human partner**

Document (in the task report, not in code) that the following cannot be verified by an automated test and need a physical device:
- Whether the secondary-check tolerances/ranges are actually well-tuned — a genuinely good rep on a real body, with real Vision noise, might get incorrectly flagged as `.badForm` (too strict), or a genuinely swinging rep might not get caught (too loose). These are starting estimates, same caveat as every other angle threshold in this project — expect to retune per profile after testing each one.
- Whether the audio pacing (first/middle/last rep) feels right in practice, or if it needs adjusting (e.g., for short sets it may end up speaking on almost every rep since 1/middle/last collapse together).
- Whether the `.badForm` phrases sound natural spoken aloud via TTS, same as any other phrase bank.
