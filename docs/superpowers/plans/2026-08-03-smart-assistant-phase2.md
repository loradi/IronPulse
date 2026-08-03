# Smart Assistant Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Smart Assistant's on-screen feedback legible from a distance, add spoken motivational/corrective feedback with 48 curated phrases in 3 languages, and expand exercise coverage from 8 to 24 exercises by reusing the existing rep-counting engine.

**Architecture:** No changes to the counting engine (`RepCounterEngine`, `AngleCalculator`, `PoseDetectorService`) or the camera pipeline. Adds one pure-data service (`FeedbackPhraseBank`) for randomized localized phrases, one small AVFoundation wrapper (`SmartAssistantAudioAnnouncer`) for text-to-speech + mute persistence, wires both into the existing `SmartAssistantModel`/`SmartAssistantSheet`, and expands `MovementProfileCatalog`'s exercise-ID-to-profile mapping (plus 2 new profiles that reuse an already-tracked joint triangle).

**Tech Stack:** Swift, SwiftUI, AVFoundation (`AVSpeechSynthesizer`, `AVAudioSession`), Swift Testing (`@Test`/`#expect`).

## Global Constraints

- Feedback text font in `SmartAssistantSheet`: `.wwCaption` (13pt) → `.wwHeadline` (24pt), for both the "no person detected" banner and the `FormFeedback` banner.
- Phrase banks: exactly 20 `.goodRep`, exactly 20 `.notDeepEnough`, exactly 8 `.tooFast` phrases, each with `es`/`en`/`fr` text — reuse the existing `LocalizedString` struct (`IronPulse/Services/ExerciseDatabaseSeeder.swift:4`), do not define a new struct.
- Audio: `AVSpeechSynthesizer`, voice picked via `AVSpeechSynthesisVoice(language:)` using a new `AppLanguage.speechLanguageCode` computed property (`es-ES`/`en-US`/`fr-FR`). `AVAudioSession` category `.playback` with `.mixWithOthers` so music/podcasts aren't interrupted. A new phrase cancels any in-flight utterance (`stopSpeaking(at: .immediate)`) — the latest feedback always wins over a stale one still being spoken.
- Mute toggle: persisted via an injectable `UserDefaults` (default `.standard`), key `smart_assistant.audio_muted`, default `false`.
- All exercise IDs referenced in this plan were verified against `IronPulse/Resources/ExercisesSeed.json` — never invent an ID during implementation; if one seems to be missing, stop and check the JSON file directly.
- `row` and `tricepsExtension` reuse the exact same joint triangle already tracked by `pushUp`/`curl` (`JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist)`) — no changes to `AngleCalculator.swift` or `PoseDetectorService.swift` in this plan.
- Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`), matching every existing file in `IronPulseTests/` — not XCTest.
- All user-facing strings route through `AppLanguage.current` (never the OS locale directly), matching the rest of the app's i18n architecture.

---

### Task 1: FeedbackPhraseBank

**Files:**
- Create: `IronPulse/Services/FeedbackPhraseBank.swift`
- Test: `IronPulseTests/FeedbackPhraseBankTests.swift`

**Interfaces:**
- Consumes: `FormFeedback` (`IronPulse/Services/RepCounterEngine.swift:5`, cases `.goodRep`/`.notDeepEnough`/`.tooFast`), `LocalizedString` (`IronPulse/Services/ExerciseDatabaseSeeder.swift:4`, fields `es`/`en`/`fr`), `AppLanguage` (`IronPulse/Models/AppLanguage.swift`, cases `.spanish`/`.english`/`.french`, `CaseIterable`).
- Produces: `FeedbackPhraseBank.randomPhrase(for feedback: FormFeedback, language: AppLanguage) -> String`, used by Task 3. Also `LocalizedString.text(for language: AppLanguage) -> String`, a small extension used by Task 1's own tests and available to any future caller.

- [ ] **Step 1: Write the failing tests**

Create `IronPulseTests/FeedbackPhraseBankTests.swift`:

```swift
import Foundation
import Testing
@testable import IronPulse

struct FeedbackPhraseBankTests {
    @Test func goodRepBankHasExactlyTwentyPhrases() {
        #expect(FeedbackPhraseBank.goodRepPhrases.count == 20)
    }

    @Test func notDeepEnoughBankHasExactlyTwentyPhrases() {
        #expect(FeedbackPhraseBank.notDeepEnoughPhrases.count == 20)
    }

    @Test func tooFastBankHasExactlyEightPhrases() {
        #expect(FeedbackPhraseBank.tooFastPhrases.count == 8)
    }

    @Test func randomPhraseAlwaysComesFromTheMatchingBank() {
        for _ in 0..<50 {
            let phrase = FeedbackPhraseBank.randomPhrase(for: .goodRep, language: .spanish)
            #expect(FeedbackPhraseBank.goodRepPhrases.contains { $0.es == phrase })
        }
    }

    @Test func everyPhraseHasNonEmptyTextInAllThreeLanguages() {
        let allPhrases = FeedbackPhraseBank.goodRepPhrases
            + FeedbackPhraseBank.notDeepEnoughPhrases
            + FeedbackPhraseBank.tooFastPhrases
        for phrase in allPhrases {
            for language in AppLanguage.allCases {
                #expect(!phrase.text(for: language).isEmpty)
            }
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/FeedbackPhraseBankTests`
Expected: FAIL (build error — `FeedbackPhraseBank` doesn't exist yet)

- [ ] **Step 3: Implement `FeedbackPhraseBank`**

Create `IronPulse/Services/FeedbackPhraseBank.swift`:

```swift
import Foundation

extension LocalizedString {
    func text(for language: AppLanguage) -> String {
        switch language {
        case .spanish: return es
        case .english: return en
        case .french: return fr
        }
    }
}

/// Curated phrase banks for the Smart Assistant's spoken/on-screen
/// feedback. A fresh random phrase is chosen per completed rep so the
/// same line doesn't repeat every time. `.notDeepEnough` and
/// `.tooFast` get separate banks instead of one shared "corrective"
/// pool: mixing them would let a range-of-motion problem get
/// announced as a speed problem, since the two conditions are
/// detected independently by `RepCounterEngine` and are not
/// interchangeable advice.
enum FeedbackPhraseBank {
    static func randomPhrase(for feedback: FormFeedback, language: AppLanguage) -> String {
        let bank = phrases(for: feedback)
        let phrase = bank.randomElement() ?? bank[0]
        return phrase.text(for: language)
    }

    private static func phrases(for feedback: FormFeedback) -> [LocalizedString] {
        switch feedback {
        case .goodRep: return goodRepPhrases
        case .notDeepEnough: return notDeepEnoughPhrases
        case .tooFast: return tooFastPhrases
        }
    }

    static let goodRepPhrases: [LocalizedString] = [
        LocalizedString(es: "¡Bien hecho!", en: "Well done!", fr: "Bien joué !"),
        LocalizedString(es: "Excelente repetición", en: "Excellent rep", fr: "Excellente répétition"),
        LocalizedString(es: "Así se hace", en: "That's how it's done", fr: "C'est comme ça qu'il faut faire"),
        LocalizedString(es: "Perfecta ejecución", en: "Perfect execution", fr: "Exécution parfaite"),
        LocalizedString(es: "Sigue así", en: "Keep it up", fr: "Continue comme ça"),
        LocalizedString(es: "Gran repetición", en: "Great rep", fr: "Superbe répétition"),
        LocalizedString(es: "Eso es, muy bien", en: "That's it, well done", fr: "Voilà, très bien"),
        LocalizedString(es: "Forma impecable", en: "Flawless form", fr: "Forme impeccable"),
        LocalizedString(es: "Rango completo, excelente", en: "Full range, excellent", fr: "Amplitude complète, excellent"),
        LocalizedString(es: "Lo estás haciendo muy bien", en: "You're doing great", fr: "Tu t'en sors très bien"),
        LocalizedString(es: "Repetición perfecta", en: "Perfect rep", fr: "Répétition parfaite"),
        LocalizedString(es: "Buen control del movimiento", en: "Good control of the movement", fr: "Bon contrôle du mouvement"),
        LocalizedString(es: "Vas muy bien", en: "You're doing well", fr: "Tu es sur la bonne voie"),
        LocalizedString(es: "Fuerza y técnica, así", en: "Strength and technique, just like that", fr: "Force et technique, comme ça"),
        LocalizedString(es: "Esa es la técnica correcta", en: "That's the right technique", fr: "C'est la bonne technique"),
        LocalizedString(es: "Excelente esfuerzo", en: "Excellent effort", fr: "Excellent effort"),
        LocalizedString(es: "Movimiento limpio", en: "Clean movement", fr: "Mouvement propre"),
        LocalizedString(es: "Bien controlado", en: "Well controlled", fr: "Bien contrôlé"),
        LocalizedString(es: "Sigues progresando", en: "You're making progress", fr: "Tu progresses"),
        LocalizedString(es: "Esa repetición cuenta", en: "That rep counts", fr: "Cette répétition compte"),
    ]

    static let notDeepEnoughPhrases: [LocalizedString] = [
        LocalizedString(es: "No completaste el rango de movimiento", en: "You didn't complete the full range of motion", fr: "Tu n'as pas fait toute l'amplitude"),
        LocalizedString(es: "Baja un poco más", en: "Go a little lower", fr: "Descends un peu plus"),
        LocalizedString(es: "Estira el brazo por completo", en: "Fully extend your arm", fr: "Étends complètement le bras"),
        LocalizedString(es: "No llegaste al ángulo correcto", en: "You didn't reach the right angle", fr: "Tu n'as pas atteint le bon angle"),
        LocalizedString(es: "Completa el movimiento hasta el final", en: "Finish the movement all the way", fr: "Termine le mouvement jusqu'au bout"),
        LocalizedString(es: "Un poco más de profundidad", en: "A bit more depth", fr: "Un peu plus de profondeur"),
        LocalizedString(es: "Casi, pero falta rango", en: "Almost, but you need more range", fr: "Presque, mais il manque de l'amplitude"),
        LocalizedString(es: "Extiende completamente la articulación", en: "Fully extend the joint", fr: "Étends complètement l'articulation"),
        LocalizedString(es: "No te quedes a medio camino", en: "Don't stop halfway", fr: "Ne t'arrête pas à mi-chemin"),
        LocalizedString(es: "Baja más para activar el músculo", en: "Go lower to fully engage the muscle", fr: "Descends plus bas pour bien engager le muscle"),
        LocalizedString(es: "Tu postura necesita más rango", en: "Your posture needs more range", fr: "Ta posture a besoin de plus d'amplitude"),
        LocalizedString(es: "Repite con mayor amplitud", en: "Repeat with more amplitude", fr: "Répète avec plus d'amplitude"),
        LocalizedString(es: "No se ve el rango completo", en: "I can't see the full range", fr: "Je ne vois pas toute l'amplitude"),
        LocalizedString(es: "Ajusta el ángulo del brazo", en: "Adjust your arm angle", fr: "Ajuste l'angle de ton bras"),
        LocalizedString(es: "Falta llegar al punto final", en: "You need to reach the end point", fr: "Il manque d'atteindre le point final"),
        LocalizedString(es: "Profundiza más el movimiento", en: "Go deeper into the movement", fr: "Approfondis davantage le mouvement"),
        LocalizedString(es: "Tu rango de movimiento es corto", en: "Your range of motion is short", fr: "Ton amplitude de mouvement est courte"),
        LocalizedString(es: "Lleva la articulación al límite", en: "Take the joint to its limit", fr: "Amène l'articulation à sa limite"),
        LocalizedString(es: "Necesitas más extensión", en: "You need more extension", fr: "Tu as besoin de plus d'extension"),
        LocalizedString(es: "Esa repetición no cuenta, falta rango", en: "That rep doesn't count, not enough range", fr: "Cette répétition ne compte pas, pas assez d'amplitude"),
    ]

    static let tooFastPhrases: [LocalizedString] = [
        LocalizedString(es: "Vas muy rápido, controla el movimiento", en: "You're going too fast, control the movement", fr: "Tu vas trop vite, contrôle le mouvement"),
        LocalizedString(es: "Más lento, controla el descenso", en: "Slow down, control the descent", fr: "Plus lentement, contrôle la descente"),
        LocalizedString(es: "Baja el ritmo", en: "Slow the pace down", fr: "Ralentis le rythme"),
        LocalizedString(es: "Controla la fase negativa", en: "Control the negative phase", fr: "Contrôle la phase négative"),
        LocalizedString(es: "Hazlo con más control", en: "Do it with more control", fr: "Fais-le avec plus de contrôle"),
        LocalizedString(es: "Menos velocidad, más técnica", en: "Less speed, more technique", fr: "Moins de vitesse, plus de technique"),
        LocalizedString(es: "Frena un poco el movimiento", en: "Slow the movement down a bit", fr: "Ralentis un peu le mouvement"),
        LocalizedString(es: "Tómate tu tiempo en cada repetición", en: "Take your time on each rep", fr: "Prends ton temps sur chaque répétition"),
    ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/FeedbackPhraseBankTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/FeedbackPhraseBank.swift IronPulseTests/FeedbackPhraseBankTests.swift
git commit -m "Add FeedbackPhraseBank: 48 curated motivational/corrective phrases in 3 languages"
```

---

### Task 2: SmartAssistantAudioAnnouncer

**Files:**
- Modify: `IronPulse/Models/AppLanguage.swift`
- Create: `IronPulse/Services/SmartAssistantAudioAnnouncer.swift`
- Test: `IronPulseTests/SmartAssistantAudioAnnouncerTests.swift`

**Interfaces:**
- Consumes: `AppLanguage` (adds `speechLanguageCode`).
- Produces: `SmartAssistantAudioAnnouncer` — `@Observable final class` with `init(userDefaults: UserDefaults = .standard)`, `var isMuted: Bool`, `func speak(_ text: String, language: AppLanguage)`, `func toggleMute()`. Used by Task 3.

- [ ] **Step 1: Write the failing tests**

Create `IronPulseTests/SmartAssistantAudioAnnouncerTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/SmartAssistantAudioAnnouncerTests`
Expected: FAIL (build error — `SmartAssistantAudioAnnouncer` doesn't exist yet)

- [ ] **Step 3: Add `speechLanguageCode` to `AppLanguage`**

In `IronPulse/Models/AppLanguage.swift`, add this computed property to the `AppLanguage` enum (alongside `displayName`):

```swift
    var speechLanguageCode: String {
        switch self {
        case .spanish: return "es-ES"
        case .english: return "en-US"
        case .french: return "fr-FR"
        }
    }
```

- [ ] **Step 4: Implement `SmartAssistantAudioAnnouncer`**

Create `IronPulse/Services/SmartAssistantAudioAnnouncer.swift`:

```swift
import AVFoundation
import Foundation

/// Speaks the Smart Assistant's feedback phrases aloud via the
/// system's text-to-speech voice, in the app's currently selected
/// language. Configured with `.mixWithOthers` so it doesn't
/// interrupt music or podcasts playing during a workout.
@Observable
final class SmartAssistantAudioAnnouncer {
    private static let mutedDefaultsKey = "smart_assistant.audio_muted"

    private let synthesizer = AVSpeechSynthesizer()
    private let userDefaults: UserDefaults

    var isMuted: Bool {
        didSet {
            userDefaults.set(isMuted, forKey: Self.mutedDefaultsKey)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isMuted = userDefaults.bool(forKey: Self.mutedDefaultsKey)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    }

    /// Cancels any utterance still being spoken before starting the
    /// new one — the latest feedback always wins over a stale one
    /// that hasn't finished yet (reps can complete faster than a
    /// sentence takes to say).
    func speak(_ text: String, language: AppLanguage) {
        guard !isMuted else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechLanguageCode)
        synthesizer.speak(utterance)
    }

    func toggleMute() {
        isMuted.toggle()
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/SmartAssistantAudioAnnouncerTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Models/AppLanguage.swift IronPulse/Services/SmartAssistantAudioAnnouncer.swift IronPulseTests/SmartAssistantAudioAnnouncerTests.swift
git commit -m "Add SmartAssistantAudioAnnouncer: TTS feedback with persisted mute toggle"
```

---

### Task 3: Wire phrase bank + audio into SmartAssistantModel and SmartAssistantSheet

**Files:**
- Modify: `IronPulse/Views/Workouts/SmartAssistantModel.swift`
- Modify: `IronPulse/Views/Workouts/SmartAssistantSheet.swift`
- Modify: `IronPulse/Localizable.xcstrings`

**Interfaces:**
- Consumes: `FeedbackPhraseBank.randomPhrase(for:language:)` (Task 1), `SmartAssistantAudioAnnouncer` (Task 2).
- Produces: `SmartAssistantModel.audioAnnouncer` (public `let`, read by `SmartAssistantSheet` for the mute button).

This task has no new unit-testable logic of its own (it wires two already-tested services into an `@Observable @MainActor` model and a SwiftUI view) — its steps are direct edits, verified by the existing test suite still passing and by running the app.

- [ ] **Step 1: Add the audio announcer property to `SmartAssistantModel`**

In `IronPulse/Views/Workouts/SmartAssistantModel.swift`, add a stored property next to `cameraController`:

```swift
    let cameraController = CameraSessionController()
    let audioAnnouncer = SmartAssistantAudioAnnouncer()
```

- [ ] **Step 2: Replace the fixed-message lookup with the phrase bank + speech**

In the same file, replace this block inside `handleDetectedJoints(_:)`:

```swift
        guard let feedback = engine.update(angle: angle) else { return }

        repCount = engine.repCount
        feedbackMessage = Self.message(for: feedback)

        if repCount >= targetReps {
            finish()
        }
```

with:

```swift
        guard let feedback = engine.update(angle: angle) else { return }

        repCount = engine.repCount
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback, language: language)
        feedbackMessage = phrase
        audioAnnouncer.speak(phrase, language: language)

        if repCount >= targetReps {
            finish()
        }
```

- [ ] **Step 3: Delete the now-unused `message(for:)` static function**

Remove this entire method from `SmartAssistantModel.swift` (it's fully replaced by `FeedbackPhraseBank`):

```swift
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
```

- [ ] **Step 4: Bump the feedback text size and add the mute button in `SmartAssistantSheet`**

In `IronPulse/Views/Workouts/SmartAssistantSheet.swift`, replace this block:

```swift
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
```

with:

```swift
                HStack {
                    Text(exerciseName)
                        .font(.wwHeadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        model.audioAnnouncer.toggleMute()
                    } label: {
                        Image(systemName: model.audioAnnouncer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(toggleAudioLabel)
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
                        .font(.wwHeadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.3), in: Capsule())
                        .foregroundStyle(.white)
                } else if let feedbackMessage = model.feedbackMessage {
                    Text(feedbackMessage)
                        .font(.wwHeadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.ironAccent.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.ironAccent)
                }
```

- [ ] **Step 5: Add the `toggleAudioLabel` computed property**

In the same file, add this alongside `toggleCameraLabel`:

```swift
    private var toggleAudioLabel: String {
        String(localized: "smart_assistant.toggle_audio", defaultValue: "Cambiar audio", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
```

- [ ] **Step 6: Update `Localizable.xcstrings`**

The 3 old fixed-feedback keys are now unused (replaced by `FeedbackPhraseBank`) — remove them and add the one new key for the mute button's accessibility label. In `IronPulse/Localizable.xcstrings`, replace this block:

```json
    "smart_assistant.feedback.good_rep" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Good rep"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Buena repetición"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bonne répétition"
          }
        }
      }
    },
    "smart_assistant.feedback.not_deep_enough" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Not a full range of motion"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "No llegaste al rango completo"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Amplitude de mouvement incomplète"
          }
        }
      }
    },
    "smart_assistant.feedback.too_fast" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Slow down"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bajá el ritmo"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ralentis le rythme"
          }
        }
      }
    },
```

with:

```json
    "smart_assistant.toggle_audio" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Toggle audio"
          }
        },
        "es" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Cambiar audio"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Changer l'audio"
          }
        }
      }
    },
```

(This is a straight text replacement inside the `"strings"` object — the surrounding JSON structure doesn't otherwise change.)

- [ ] **Step 7: Build and run the existing test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests`
Expected: PASS (this task doesn't add new tests, but must not break Task 1/2's tests or any existing one — the `SmartAssistantModel`/`SmartAssistantSheet` files aren't unit tested directly, so a full-suite pass plus a successful build is the bar here)

- [ ] **Step 8: Commit**

```bash
git add IronPulse/Views/Workouts/SmartAssistantModel.swift IronPulse/Views/Workouts/SmartAssistantSheet.swift IronPulse/Localizable.xcstrings
git commit -m "Wire FeedbackPhraseBank and SmartAssistantAudioAnnouncer into the assistant UI, bump feedback text size"
```

---

### Task 4: Expand the exercise catalog (13 more exercises on existing profiles + 2 new profiles)

**Files:**
- Modify: `IronPulse/Services/MovementProfile.swift`
- Modify: `IronPulseTests/MovementProfileCatalogTests.swift`

**Interfaces:**
- Consumes: `JointAngle`, `MovementProfile`, `BodyJoint` (all already defined in `MovementProfile.swift`).
- Produces: 2 new private profiles (`row`, `tricepsExtension`) and an expanded `profiles` dictionary — no public API changes, `MovementProfileCatalog.profile(forExerciseID:)`'s signature is untouched.

- [ ] **Step 1: Write the failing test**

In `IronPulseTests/MovementProfileCatalogTests.swift`, replace the entire file with:

```swift
import Foundation
import Testing
@testable import IronPulse

struct MovementProfileCatalogTests {
    private static let curatedIDs = [
        "ex_048_sentadilla_trasera_con_barra",
        "ex_060_sentadilla_goblet_con_mancuerna",
        "ex_057_sentadilla_bulgara_con_mancuernas",
        "ex_049_sentadilla_frontal_con_barra",
        "ex_062_sentadilla_hack_en_maquina",
        "ex_063_sentadilla_en_maquina_smith",
        "ex_021_flexiones_pecho",
        "ex_020_fondos_banco",
        "ex_019_fondos_paralelas",
        "ex_022_flexiones_inclinadas",
        "ex_098_curl_barra_recta",
        "ex_100_curl_alterno_mancuernas",
        "ex_101_curl_martillo_mancuernas",
        "ex_104_curl_concentrado",
        "ex_078_press_militar_barra",
        "ex_079_press_militar_sentado_barra",
        "ex_080_press_hombros_mancuernas",
        "ex_081_press_arnold",
        "ex_031_peso_muerto_convencional",
        "ex_051_peso_muerto_rumano_con_barra",
        "ex_052_peso_muerto_rumano_con_mancuernas",
        "ex_027_remo_sentado_polea",
        "ex_028_jalon_pecho_agarre_ancho",
        "ex_117_pushdown_polea_cuerda",
    ]

    @Test func unknownExerciseHasNoProfile() {
        #expect(MovementProfileCatalog.profile(forExerciseID: "not_a_real_exercise") == nil)
    }

    @Test func everyCuratedExerciseHasAProfile() {
        for id in Self.curatedIDs {
            #expect(MovementProfileCatalog.profile(forExerciseID: id) != nil, "Missing profile for \(id)")
        }
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
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: FAIL (new IDs and `row`/`tricepsExtension` don't exist in the catalog yet)

- [ ] **Step 3: Add the 2 new profiles and expand the catalog dictionary**

In `IronPulse/Services/MovementProfile.swift`, replace this block:

```swift
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
```

with:

```swift
    private static let profiles: [String: MovementProfile] = [
        "ex_048_sentadilla_trasera_con_barra": squat,
        "ex_060_sentadilla_goblet_con_mancuerna": squat,
        "ex_057_sentadilla_bulgara_con_mancuernas": squat,
        "ex_049_sentadilla_frontal_con_barra": squat,
        "ex_062_sentadilla_hack_en_maquina": squat,
        "ex_063_sentadilla_en_maquina_smith": squat,
        "ex_021_flexiones_pecho": pushUp,
        "ex_020_fondos_banco": pushUp,
        "ex_019_fondos_paralelas": pushUp,
        "ex_022_flexiones_inclinadas": pushUp,
        "ex_098_curl_barra_recta": curl,
        "ex_100_curl_alterno_mancuernas": curl,
        "ex_101_curl_martillo_mancuernas": curl,
        "ex_104_curl_concentrado": curl,
        "ex_078_press_militar_barra": overheadPress,
        "ex_079_press_militar_sentado_barra": overheadPress,
        "ex_080_press_hombros_mancuernas": overheadPress,
        "ex_081_press_arnold": overheadPress,
        "ex_031_peso_muerto_convencional": hinge,
        "ex_051_peso_muerto_rumano_con_barra": hinge,
        "ex_052_peso_muerto_rumano_con_mancuernas": hinge,
        "ex_027_remo_sentado_polea": row,
        "ex_028_jalon_pecho_agarre_ancho": row,
        "ex_117_pushdown_polea_cuerda": tricepsExtension,
    ]
```

Then add these 2 new profiles after the existing `hinge` profile definition (same file):

```swift
    // Elbow angle (shoulder-elbow-wrist): ~170 degrees extended
    // reaching for the weight (the row's "down"), ~60-85 degrees
    // pulled to the torso (the row's "up") — the opposite direction
    // from pushUp's elbow angle on the same joint triangle.
    private static let row = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 155...180,
        upRange: 60...85
    )

    // Elbow angle (shoulder-elbow-wrist): ~70-95 degrees at the rack
    // position (the extension's "down"), ~160-180 degrees at full
    // lockout (the extension's "up") — the same joint triangle as
    // curl, opposite direction.
    private static let tricepsExtension = MovementProfile(
        primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist),
        downRange: 70...95,
        upRange: 160...180
    )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests/MovementProfileCatalogTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/MovementProfile.swift IronPulseTests/MovementProfileCatalogTests.swift
git commit -m "Expand Smart Assistant exercise catalog from 8 to 24 exercises (add row, tricepsExtension)"
```

---

### Task 5: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`, including all of Task 1-4's new tests plus every pre-existing test.

- [ ] **Step 2: Build for a real device target**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual verification note for the human partner**

Document (in the task report, not in code) that the following cannot be verified by an automated test and need a physical device, same caveat as phase 1:
- The mute button actually silences `AVSpeechSynthesizer` and that toggling it back on resumes speech.
- Spoken phrases audibly match the on-screen text and don't overlap/garble when reps happen in quick succession.
- Audio doesn't interrupt music/podcasts already playing (`.mixWithOthers` behaves as expected).
- The bigger feedback text is actually legible at arm's-length/propped-phone distance.
- At least one of the 3 newly-added exercise categories (a new `squat`/`pushUp`/`curl`/`overheadPress`/`hinge` variant, plus `row` and `tricepsExtension`) tracks reps correctly with real Vision output — the angle ranges for `row`/`tricepsExtension` in particular are starting estimates, per the design spec.
