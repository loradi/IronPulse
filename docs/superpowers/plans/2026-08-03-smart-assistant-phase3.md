# Smart Assistant Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the Smart Assistant's exercise coverage from 24 to 73 exercises (of 146 in the catalog), and make the spoken feedback sound less robotic by picking the best-quality installed system voice and tuning its rate/pitch.

**Architecture:** No changes to `RepCounterEngine`, `AngleCalculator`, or `PoseDetectorService`. Adds 3 new `MovementProfile`s to `MovementProfileCatalog`, all reusing joint triangles already tracked by existing profiles, plus 49 new exercise-ID-to-profile mappings. Separately, extends `SmartAssistantAudioAnnouncer` with a testable best-quality-voice picker (cached per language) and tuned `AVSpeechUtterance` rate/pitch — no new files, no new AVFoundation surface area beyond what's already there.

**Tech Stack:** Swift, AVFoundation (`AVSpeechSynthesisVoice`, `AVSpeechSynthesisVoiceQuality`), Swift Testing (`@Test`/`#expect`).

## Global Constraints

- All 49 new exercise IDs in this plan were verified against `IronPulse/Resources/ExercisesSeed.json` (each one confirmed to exist, and confirmed not already present in the existing 24-exercise catalog) — never invent an ID during implementation; if one seems to be missing, stop and check the JSON file directly.
- `lateralRaise` reuses the exact triangle already used by `overheadPress`: `JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow)`. Ranges: `downRange: 10...25`, `upRange: 75...95`.
- `legExtension` and `legCurl` reuse the exact triangle already used by `squat`/`hinge`'s knee: `JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle)`. `legExtension`: `downRange: 80...100`, `upRange: 160...180`. `legCurl`: `downRange: 160...180`, `upRange: 70...90`.
- No changes to `AngleCalculator.swift` or `PoseDetectorService.swift` in this plan — all 3 new profiles are pure data reusing existing tracked joints.
- Audio: pick the best-quality (`.premium` > `.enhanced` > `.default`) installed `AVSpeechSynthesisVoice` matching the current language, falling back to `AVSpeechSynthesisVoice(language:)` if none better is installed. Cache the resolved voice per `AppLanguage` so `AVSpeechSynthesisVoice.speechVoices()` (a full scan of every voice installed on the device) isn't repeated on every spoken phrase.
- `AVSpeechUtterance.rate` is tuned to `0.47` and `.pitchMultiplier` to `0.92` (both `Float`), replacing the untouched defaults (`AVSpeechUtteranceDefaultSpeechRate` ≈ 0.5, pitch `1.0`).
- The voice-picking logic must be unit-testable without depending on which real voices happen to be installed on the test-running machine/simulator — extract it as a small generic function operating on a `SpeechVoiceCandidate` protocol (implemented by `AVSpeechSynthesisVoice` and, in tests, by a fake struct), not a method that calls `AVSpeechSynthesisVoice.speechVoices()` directly.
- Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`), matching every existing file in `IronPulseTests/` — not XCTest.
- Test runs must pass `-parallel-testing-enabled NO` (this environment has limited simulator process headroom; parallel test cloning causes "insufficient system resources" failures unrelated to code correctness).

---

### Task 1: Expand the exercise catalog (3 new profiles + 49 exercises)

**Files:**
- Modify: `IronPulse/Services/MovementProfile.swift`
- Modify: `IronPulseTests/MovementProfileCatalogTests.swift`

**Interfaces:**
- Consumes: `JointAngle`, `MovementProfile`, `BodyJoint` (all already defined in `MovementProfile.swift`).
- Produces: 3 new private profiles (`lateralRaise`, `legExtension`, `legCurl`) and an expanded `profiles` dictionary (24 → 73 entries) — no public API changes, `MovementProfileCatalog.profile(forExerciseID:)`'s signature is untouched.

- [ ] **Step 1: Write the failing test**

Replace the entire contents of `IronPulseTests/MovementProfileCatalogTests.swift` with:

```swift
import Foundation
import Testing
@testable import IronPulse

struct MovementProfileCatalogTests {
    private static let curatedIDs = [
        // squat (8)
        "ex_048_sentadilla_trasera_con_barra",
        "ex_060_sentadilla_goblet_con_mancuerna",
        "ex_057_sentadilla_bulgara_con_mancuernas",
        "ex_049_sentadilla_frontal_con_barra",
        "ex_062_sentadilla_hack_en_maquina",
        "ex_063_sentadilla_en_maquina_smith",
        "ex_058_sentadilla_sissy",
        "ex_076_sentadilla_sumo_con_mancuerna",
        // pushUp (8)
        "ex_021_flexiones_pecho",
        "ex_020_fondos_banco",
        "ex_019_fondos_paralelas",
        "ex_022_flexiones_inclinadas",
        "ex_015_press_pecho_maquina",
        "ex_016_press_pecho_polea_de_pie",
        "ex_123_flexiones_diamante",
        "ex_124_fondos_maquina",
        // curl (18)
        "ex_098_curl_barra_recta",
        "ex_100_curl_alterno_mancuernas",
        "ex_101_curl_martillo_mancuernas",
        "ex_104_curl_concentrado",
        "ex_099_curl_barra_z",
        "ex_102_curl_predicador_barra_z",
        "ex_103_curl_predicador_maquina",
        "ex_105_curl_polea_baja",
        "ex_106_curl_inclinado_mancuernas",
        "ex_107_curl_arana",
        "ex_108_curl_drag",
        "ex_109_curl_martillo_cuerda_polea",
        "ex_110_curl_agarre_cerrado",
        "ex_111_curl_zottman",
        "ex_112_curl_polea_alta",
        "ex_113_curl_inverso_barra",
        "ex_114_curl_maquina",
        "ex_115_curl_cruzado_martillo",
        // overheadPress (7)
        "ex_078_press_militar_barra",
        "ex_079_press_militar_sentado_barra",
        "ex_080_press_hombros_mancuernas",
        "ex_081_press_arnold",
        "ex_082_press_hombros_sentado_mancuernas",
        "ex_083_press_hombros_maquina",
        "ex_084_press_hombros_polea",
        // hinge (6)
        "ex_031_peso_muerto_convencional",
        "ex_051_peso_muerto_rumano_con_barra",
        "ex_052_peso_muerto_rumano_con_mancuernas",
        "ex_032_peso_muerto_rumano",
        "ex_043_peso_muerto_sumo",
        "ex_064_peso_muerto_sumo_con_barra",
        // row (12)
        "ex_027_remo_sentado_polea",
        "ex_028_jalon_pecho_agarre_ancho",
        "ex_023_dominadas_pronadas",
        "ex_024_dominadas_supinadas",
        "ex_025_dominadas_asistidas_banda",
        "ex_029_jalon_pecho_agarre_cerrado",
        "ex_033_remo_posterior_polea_cuerda",
        "ex_044_remo_alto_maquina_palanca",
        "ex_045_face_pull_polea",
        "ex_046_remo_arrodillado_polea_alta",
        "ex_093_remo_menton_barra",
        "ex_094_remo_menton_mancuernas",
        // tricepsExtension (8)
        "ex_117_pushdown_polea_cuerda",
        "ex_118_pushdown_polea_barra_recta",
        "ex_120_extension_mancuernas_dos_manos_sobre_cabeza",
        "ex_125_extension_polea_una_mano",
        "ex_126_press_frances_mancuernas",
        "ex_127_extension_mancuerna_una_mano_sobre_cabeza",
        "ex_128_extension_polea_cuerda_tras_nuca",
        "ex_133_extension_triceps_maquina",
        // lateralRaise (4, new profile)
        "ex_085_elevaciones_laterales_mancuernas",
        "ex_086_elevaciones_laterales_polea",
        "ex_087_elevaciones_frontales_mancuernas",
        "ex_088_elevaciones_frontales_polea",
        // legExtension (1, new profile)
        "ex_054_extension_de_piernas_en_maquina",
        // legCurl (1, new profile)
        "ex_056_curl_femoral_sentado",
    ]

    @Test func unknownExerciseHasNoProfile() {
        #expect(MovementProfileCatalog.profile(forExerciseID: "not_a_real_exercise") == nil)
    }

    @Test func everyCuratedExerciseHasAProfile() {
        for id in Self.curatedIDs {
            #expect(MovementProfileCatalog.profile(forExerciseID: id) != nil, "Missing profile for \(id)")
        }
    }

    @Test func curatedListHasExactlySeventyThreeExercises() {
        #expect(Self.curatedIDs.count == 73)
    }

    @Test func everyCuratedProfileHasNonOverlappingDownAndUpRanges() {
        for id in Self.curatedIDs {
            let profile = MovementProfileCatalog.profile(forExerciseID: id)!
            #expect(!profile.downRange.overlaps(profile.upRange), "\(id) has overlapping down/up ranges")
        }
    }

    @Test func rowAndTricepsExtensionShareCurlsJointTriangleButHaveDifferentRanges() {
        let row = MovementProfileCatalog.profile(forExerciseID: "ex_027_remo_sentado_polea")!
        let tricepsExtension = MovementProfileCatalog.profile(forExerciseID: "ex_117_pushdown_polea_cuerda")!
        let sharedTriangle = JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist)

        #expect(row.primaryAngle == sharedTriangle)
        #expect(tricepsExtension.primaryAngle == sharedTriangle)
        #expect(row.downRange != tricepsExtension.downRange)
    }

    @Test func everyCuratedIDExistsInTheRealExerciseCatalog() throws {
        let url = try #require(Bundle.main.url(forResource: "ExercisesSeed", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let realIDs = Set(try JSONDecoder().decode([ExerciseSeedDTO].self, from: data).map(\.id))
        for id in Self.curatedIDs {
            #expect(realIDs.contains(id), "\(id) is not a real exercise ID in ExercisesSeed.json")
        }
    }

    @Test func lateralRaiseSharesOverheadPressJointTriangleButHasAShorterRange() {
        let lateralRaise = MovementProfileCatalog.profile(forExerciseID: "ex_085_elevaciones_laterales_mancuernas")!
        let overheadPress = MovementProfileCatalog.profile(forExerciseID: "ex_078_press_militar_barra")!
        let sharedTriangle = JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow)

        #expect(lateralRaise.primaryAngle == sharedTriangle)
        #expect(overheadPress.primaryAngle == sharedTriangle)
        #expect(lateralRaise.upRange.upperBound < overheadPress.upRange.upperBound)
    }

    @Test func legExtensionAndLegCurlShareSquatsJointTriangleAndTrackOppositeDirections() {
        let legExtension = MovementProfileCatalog.profile(forExerciseID: "ex_054_extension_de_piernas_en_maquina")!
        let legCurl = MovementProfileCatalog.profile(forExerciseID: "ex_056_curl_femoral_sentado")!
        let sharedTriangle = JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle)

        #expect(legExtension.primaryAngle == sharedTriangle)
        #expect(legCurl.primaryAngle == sharedTriangle)
        // Both ranges represent "leg extended straight" as the opposite end of their own motion.
        #expect(legExtension.upRange.overlaps(legCurl.downRange))
        // Both ranges represent "leg bent" as the opposite end of their own motion.
        #expect(legExtension.downRange.overlaps(legCurl.upRange))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: FAIL (the 49 new IDs and the 3 new profiles don't exist in the catalog yet)

- [ ] **Step 3: Add the 3 new profiles and expand the catalog dictionary**

In `IronPulse/Services/MovementProfile.swift`, replace the entire `profiles` dictionary:

```swift
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
        "ex_016_press_pecho_polea_de_pie": pushUp,
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
        "ex_107_curl_arana": curl,
        "ex_108_curl_drag": curl,
        "ex_109_curl_martillo_cuerda_polea": curl,
        "ex_110_curl_agarre_cerrado": curl,
        "ex_111_curl_zottman": curl,
        "ex_112_curl_polea_alta": curl,
        "ex_113_curl_inverso_barra": curl,
        "ex_114_curl_maquina": curl,
        "ex_115_curl_cruzado_martillo": curl,
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
        "ex_044_remo_alto_maquina_palanca": row,
        "ex_045_face_pull_polea": row,
        "ex_046_remo_arrodillado_polea_alta": row,
        "ex_093_remo_menton_barra": row,
        "ex_094_remo_menton_mancuernas": row,
        "ex_117_pushdown_polea_cuerda": tricepsExtension,
        "ex_118_pushdown_polea_barra_recta": tricepsExtension,
        "ex_120_extension_mancuernas_dos_manos_sobre_cabeza": tricepsExtension,
        "ex_125_extension_polea_una_mano": tricepsExtension,
        "ex_126_press_frances_mancuernas": tricepsExtension,
        "ex_127_extension_mancuerna_una_mano_sobre_cabeza": tricepsExtension,
        "ex_128_extension_polea_cuerda_tras_nuca": tricepsExtension,
        "ex_133_extension_triceps_maquina": tricepsExtension,
        "ex_085_elevaciones_laterales_mancuernas": lateralRaise,
        "ex_086_elevaciones_laterales_polea": lateralRaise,
        "ex_087_elevaciones_frontales_mancuernas": lateralRaise,
        "ex_088_elevaciones_frontales_polea": lateralRaise,
        "ex_054_extension_de_piernas_en_maquina": legExtension,
        "ex_056_curl_femoral_sentado": legCurl,
    ]
```

Then add these 3 new profiles at the end of the file, after `tricepsExtension`'s definition (before the enum's closing `}`):

```swift
    // Shoulder angle (hip-shoulder-elbow) - same triangle as
    // overheadPress, with a shorter range: ~10-25 degrees with the arm
    // at the side (the raise's "down"), ~75-95 degrees at shoulder
    // height (the raise's "up") - stops well short of overheadPress's
    // overhead lockout. Covers both lateral and front raises: from a
    // front-facing camera the two produce a very similar change in
    // this angle even though the arm moves in a different plane (out
    // to the side vs. forward) - the tracked angle doesn't distinguish
    // which plane, so one profile serves both.
    private static let lateralRaise = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
        downRange: 10...25,
        upRange: 75...95
    )

    // Knee angle (hip-knee-ankle) - same triangle as squat, seated
    // machine motion: ~80-100 degrees with the leg bent under the seat
    // (the extension's "down"), ~160-180 degrees with the leg extended
    // straight out (the extension's "up").
    private static let legExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 80...100,
        upRange: 160...180
    )

    // Knee angle (hip-knee-ankle) - same triangle as legExtension,
    // opposite direction: ~160-180 degrees with the leg extended (the
    // curl's "down"), ~70-90 degrees curled under the seat (the
    // curl's "up").
    private static let legCurl = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
        downRange: 160...180,
        upRange: 70...90
    )
```

Also update the doc comment above `MovementProfileCatalog` (currently says "these 24"):

Replace:
```swift
/// The curated set of exercises the Smart Assistant supports (see the
/// design spec for why these 24 and not the full 146-exercise
/// catalog). Angle thresholds below are a reasonable starting point
/// based on standard range-of-motion references for each movement —
/// expect to retune them against real Vision output on a physical
/// device during verification, per the design spec.
```
with:
```swift
/// The curated set of exercises the Smart Assistant supports (see the
/// phase 3 design spec for why these 73 and not the full 146-exercise
/// catalog). Angle thresholds below are a reasonable starting point
/// based on standard range-of-motion references for each movement —
/// expect to retune them against real Vision output on a physical
/// device during verification, per the design spec.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/MovementProfile.swift IronPulseTests/MovementProfileCatalogTests.swift
git commit -m "Expand Smart Assistant exercise catalog from 24 to 73 exercises (add lateralRaise, legExtension, legCurl)"
```

---

### Task 2: More natural audio (best-quality voice + tuned rate/pitch)

**Files:**
- Modify: `IronPulse/Services/SmartAssistantAudioAnnouncer.swift`
- Modify: `IronPulseTests/SmartAssistantAudioAnnouncerTests.swift`

**Interfaces:**
- Consumes: `AppLanguage.speechLanguageCode` (already exists).
- Produces: `SmartAssistantAudioAnnouncer.resolvedVoice(for:) -> AVSpeechSynthesisVoice?`, `SmartAssistantAudioAnnouncer.bestVoice(among:language:)` (static, generic over `SpeechVoiceCandidate`), `SmartAssistantAudioAnnouncer.makeUtterance(_:voice:) -> AVSpeechUtterance` (static) — all `internal` (not `private`) so tests in a separate file can call them via `@testable import`. `speak(_:language:)`'s existing public signature is unchanged.

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `IronPulseTests/SmartAssistantAudioAnnouncerTests.swift` with:

```swift
import AVFoundation
import Foundation
import Testing
@testable import IronPulse

struct SmartAssistantAudioAnnouncerTests {
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "SmartAssistantAudioAnnouncerTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test func mutedDefaultsToFalseWhenNothingStored() {
        let announcer = SmartAssistantAudioAnnouncer(userDefaults: makeIsolatedDefaults())
        #expect(announcer.isMuted == false)
    }

    @Test func toggleMutePersistsAcrossInstancesSharingTheSameDefaults() {
        let defaults = makeIsolatedDefaults()
        let first = SmartAssistantAudioAnnouncer(userDefaults: defaults)
        first.toggleMute()
        #expect(first.isMuted == true)

        let second = SmartAssistantAudioAnnouncer(userDefaults: defaults)
        #expect(second.isMuted == true)
    }

    private struct FakeVoiceCandidate: SpeechVoiceCandidate {
        let language: String
        let quality: AVSpeechSynthesisVoiceQuality
    }

    @Test func bestVoicePicksThePremiumVoiceOverEnhancedAndDefault() {
        let candidates = [
            FakeVoiceCandidate(language: "es-ES", quality: .default),
            FakeVoiceCandidate(language: "es-ES", quality: .premium),
            FakeVoiceCandidate(language: "es-ES", quality: .enhanced),
            FakeVoiceCandidate(language: "en-US", quality: .premium),
        ]
        let best = SmartAssistantAudioAnnouncer.bestVoice(among: candidates, language: "es-ES")
        #expect(best?.quality == .premium)
    }

    @Test func bestVoiceIgnoresCandidatesForOtherLanguages() {
        let candidates = [FakeVoiceCandidate(language: "fr-FR", quality: .premium)]
        let best = SmartAssistantAudioAnnouncer.bestVoice(among: candidates, language: "es-ES")
        #expect(best == nil)
    }

    @Test func makeUtteranceUsesTheTunedRateAndPitch() {
        let utterance = SmartAssistantAudioAnnouncer.makeUtterance("hola", voice: nil)
        #expect(utterance.rate == 0.47)
        #expect(utterance.pitchMultiplier == 0.92)
    }

    @Test func resolvedVoiceCachesTheSameInstanceForRepeatedCallsWithTheSameLanguage() {
        let announcer = SmartAssistantAudioAnnouncer(userDefaults: makeIsolatedDefaults())
        let first = announcer.resolvedVoice(for: .spanish)
        let second = announcer.resolvedVoice(for: .spanish)
        #expect(first === second)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/SmartAssistantAudioAnnouncerTests`
Expected: FAIL (build error — `SpeechVoiceCandidate`, `bestVoice`, `makeUtterance`, `resolvedVoice` don't exist yet)

- [ ] **Step 3: Implement the voice-quality picker and rate/pitch tuning**

Replace the entire contents of `IronPulse/Services/SmartAssistantAudioAnnouncer.swift` with:

```swift
import AVFoundation
import Foundation

/// A source of speech-voice metadata that `bestVoice(among:language:)`
/// can rank by quality. `AVSpeechSynthesisVoice` conforms below; tests
/// use a fake struct instead, so the ranking logic can be verified
/// without depending on which real voices happen to be installed on
/// the machine running the tests.
protocol SpeechVoiceCandidate {
    var language: String { get }
    var quality: AVSpeechSynthesisVoiceQuality { get }
}

extension AVSpeechSynthesisVoice: SpeechVoiceCandidate {}

/// Speaks the Smart Assistant's feedback phrases aloud via the
/// system's text-to-speech voice, in the app's currently selected
/// language. Picks the best-quality voice installed for that language
/// (falling back to the system default if the user hasn't downloaded
/// an Enhanced/Premium one in Settings > Accessibility > Spoken
/// Content > Voices) and speaks at a tuned rate/pitch, so it sounds
/// less robotic than the untouched system default. Configured with
/// `.mixWithOthers` so it doesn't interrupt music or podcasts playing
/// during a workout.
@Observable
final class SmartAssistantAudioAnnouncer {
    private static let mutedDefaultsKey = "smart_assistant.audio_muted"
    private static let speechRate: Float = 0.47
    private static let speechPitch: Float = 0.92

    private let synthesizer = AVSpeechSynthesizer()
    private let userDefaults: UserDefaults
    private var hasConfiguredAudioSession = false
    private var cachedVoices: [AppLanguage: AVSpeechSynthesisVoice] = [:]

    var isMuted: Bool {
        didSet {
            userDefaults.set(isMuted, forKey: Self.mutedDefaultsKey)
            if isMuted {
                stop()
            }
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isMuted = userDefaults.bool(forKey: Self.mutedDefaultsKey)
    }

    /// Cancels any utterance still being spoken before starting the
    /// new one — the latest feedback always wins over a stale one
    /// that hasn't finished yet (reps can complete faster than a
    /// sentence takes to say).
    func speak(_ text: String, language: AppLanguage) {
        guard !isMuted else { return }
        if !hasConfiguredAudioSession {
            hasConfiguredAudioSession = true
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = Self.makeUtterance(text, voice: resolvedVoice(for: language))
        synthesizer.speak(utterance)
    }

    /// Immediately silences any utterance currently being spoken.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func toggleMute() {
        isMuted.toggle()
    }

    /// Picks the best-quality installed voice for `language`, caching
    /// the result so `AVSpeechSynthesisVoice.speechVoices()` - a full
    /// scan of every voice installed on the device - isn't repeated on
    /// every spoken phrase.
    func resolvedVoice(for language: AppLanguage) -> AVSpeechSynthesisVoice? {
        if let cached = cachedVoices[language] { return cached }
        let code = language.speechLanguageCode
        let voice = Self.bestVoice(among: AVSpeechSynthesisVoice.speechVoices(), language: code)
            ?? AVSpeechSynthesisVoice(language: code)
        cachedVoices[language] = voice
        return voice
    }

    /// Pure ranking logic, generic over `SpeechVoiceCandidate` so it's
    /// testable with fake candidates instead of the real system voice
    /// list. Picks the highest-quality candidate matching `language`
    /// exactly (`.premium` > `.enhanced` > `.default`).
    static func bestVoice<V: SpeechVoiceCandidate>(among candidates: [V], language: String) -> V? {
        candidates
            .filter { $0.language == language }
            .max { $0.quality.rawValue < $1.quality.rawValue }
    }

    static func makeUtterance(_ text: String, voice: AVSpeechSynthesisVoice?) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        return utterance
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/SmartAssistantAudioAnnouncerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/SmartAssistantAudioAnnouncer.swift IronPulseTests/SmartAssistantAudioAnnouncerTests.swift
git commit -m "Pick best-quality installed voice and tune rate/pitch for more natural-sounding Smart Assistant audio"
```

---

### Task 3: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`, including all of Task 1-2's new/changed tests plus every pre-existing test.

- [ ] **Step 2: Build for a real device target**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual verification note for the human partner**

Document (in the task report, not in code) that the following cannot be verified by an automated test and need a physical device:
- At least a few of the newly-covered exercises (one per new profile: a lateral raise, the seated leg extension machine, the seated leg curl machine, a pull-up, a machine chest press) actually track reps correctly with real Vision output — all 3 new profiles' angle ranges are starting estimates, same caveat as every prior phase.
- The picked voice is actually higher quality than before, and the rate/pitch change is a genuine improvement and not overcorrected (too slow/too low) — this is inherently subjective and needs a human ear, not a test.
- Whether the device actually has an Enhanced/Premium voice installed for the profile's language matters here: if none is installed, `resolvedVoice` falls back to the same default voice as before, and the audio will sound unchanged aside from the rate/pitch tuning. Worth checking Settings > Accessibility > Spoken Content > Voices before judging the result.
