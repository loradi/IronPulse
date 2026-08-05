# Smart Assistant: Audio Pre-Grabado Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la síntesis de voz en vivo del Smart Assistant por clips de audio pre-grabados (generados una vez con ElevenLabs) para las 64 frases × 3 idiomas existentes, con la síntesis en vivo actual como respaldo automático si algún clip no está disponible.

**Architecture:** Las frases pasan de literales Swift a un JSON empaquetado con un `id` estable por frase. Un script de Python (fuera del pipeline de build) genera los clips de audio una sola vez usando ese mismo JSON. `SmartAssistantAudioAnnouncer` intenta reproducir el clip pre-grabado primero; si no existe, cae al mecanismo de TTS en vivo ya existente (fase 3), sin cambios de comportamiento en absoluto en *cuándo* habla el asistente (fase 4).

**Tech Stack:** SwiftUI, AVFoundation (`AVAudioPlayer` + `AVSpeechSynthesizer`), Swift Testing, Python 3 (script de generación, fuera de la app).

## Global Constraints

- Cero cambios en *cuándo* se habla: `SmartAssistantModel.shouldSpeak(for:repCount:targetReps:)` y toda la lógica de `RepCounterEngine` quedan intactas — este plan solo cambia *cómo suena*.
- `isMuted`/`toggleMute()`/`stop()` siguen controlando ambos caminos de reproducción (audio pre-grabado y TTS en vivo) de forma idéntica.
- Los archivos de audio reales (`.mp3`, uno por frase × idioma) **no** se generan como parte de las Tasks 1-4 de este plan — necesitan la API key de ElevenLabs del humano, que se corre por separado (el controller del SDD la corre una vez que el humano la proporcione como variable de entorno). Hasta que eso pase, **cada frase cae al TTS en vivo actual — cero regresión** respecto al comportamiento de hoy.
- Formato de audio: `.mp3` (no `.m4a` como decía el spec original — la API de ElevenLabs devuelve MP3 directamente; `AVAudioPlayer` reproduce ambos formatos de forma idéntica, así que es un detalle de implementación sin impacto de producto).
- Tests usan Swift Testing (`@Test`/`#expect`), igual que todos los archivos existentes en `IronPulseTests/`.
- Los test runs deben pasar `-parallel-testing-enabled NO`.
- El proyecto usa `PBXFileSystemSynchronizedRootGroup` para toda la carpeta `IronPulse/` — cualquier archivo nuevo bajo `IronPulse/Resources/` se empaqueta automáticamente sin tocar el `.pbxproj` (mismo mecanismo que ya usa `ExercisesSeed.json`, y confirmado que los recursos se aplanan a la raíz del bundle — por eso `Bundle.main.url(forResource:withExtension:)` se usa sin `subdirectory:`).

---

### Task 1: `LocalizedString` gana `id`, `FeedbackPhrases.json`, `FeedbackPhraseBank` carga desde JSON

**Files:**
- Modify: `IronPulse/Services/ExerciseDatabaseSeeder.swift`
- Create: `IronPulse/Resources/FeedbackPhrases.json`
- Modify: `IronPulse/Services/FeedbackPhraseBank.swift`
- Modify: `IronPulse/Views/Workouts/SmartAssistantModel.swift`
- Test: `IronPulseTests/FeedbackPhraseBankTests.swift`

**Interfaces:**
- Produces: `LocalizedString.id: String` (default `""` en el init de conveniencia, decodificado como opcional-con-default desde JSON); `FeedbackPhraseBank.randomPhrase(for feedback: FormFeedback) -> LocalizedString` (cambia de firma: ya no recibe `language:`, ya no devuelve `String`).
- Consumes (Task 2 depende de esto): el nuevo tipo de retorno de `randomPhrase`.

- [ ] **Step 1: Write the failing tests**

Reemplazar `IronPulseTests/FeedbackPhraseBankTests.swift` completo con:

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

    @Test func badFormBankHasExactlySixteenPhrases() {
        #expect(FeedbackPhraseBank.badFormPhrases.count == 16)
    }

    @Test func randomPhraseAlwaysComesFromTheMatchingBank() {
        for _ in 0..<50 {
            let phrase = FeedbackPhraseBank.randomPhrase(for: .goodRep)
            #expect(FeedbackPhraseBank.goodRepPhrases.contains { $0.id == phrase.id })
        }
    }

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

    @Test func everyPhraseHasANonEmptyUniqueIDWithinItsBank() {
        let banks = [
            FeedbackPhraseBank.goodRepPhrases,
            FeedbackPhraseBank.notDeepEnoughPhrases,
            FeedbackPhraseBank.tooFastPhrases,
            FeedbackPhraseBank.badFormPhrases,
        ]
        for bank in banks {
            let ids = bank.map(\.id)
            #expect(ids.allSatisfy { !$0.isEmpty })
            #expect(Set(ids).count == ids.count)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/FeedbackPhraseBankTests`
Expected: FAIL (`randomPhrase(for:)` sin `language:` no existe todavía, `.id` no existe en `LocalizedString`)

- [ ] **Step 3: Add `id` to `LocalizedString`**

En `IronPulse/Services/ExerciseDatabaseSeeder.swift`, encontrar:

```swift
struct LocalizedString: Codable {
    let es: String
    let en: String
    let fr: String
}
```

Reemplazar con:

```swift
struct LocalizedString: Codable {
    let es: String
    let en: String
    let fr: String
    /// Identificador estable usado para buscar el clip de audio
    /// pre-grabado de esta frase (`<id>_<idioma>.mp3`) en
    /// `SmartAssistantAudioAnnouncer`. Vacío para los `LocalizedString`
    /// que no lo necesitan (nombres/instrucciones de ejercicios en
    /// `ExercisesSeed.json`, que es anterior a este campo y nunca lo trae).
    let id: String

    init(es: String, en: String, fr: String, id: String = "") {
        self.es = es
        self.en = en
        self.fr = fr
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case es, en, fr, id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        es = try container.decode(String.self, forKey: .es)
        en = try container.decode(String.self, forKey: .en)
        fr = try container.decode(String.self, forKey: .fr)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
    }
}
```

(El `init(from:)` manual es necesario porque `ExercisesSeed.json` no trae la clave `"id"` — sin este init personalizado, el decode automático de `Codable` fallaría en tiempo de ejecución por la clave faltante.)

- [ ] **Step 4: Create `FeedbackPhrases.json`**

Crear `IronPulse/Resources/FeedbackPhrases.json` con este contenido exacto (transcrito 1:1 desde las frases que ya existían en `FeedbackPhraseBank.swift` — no rephrasear ni "mejorar" ningún texto):

```json
{
  "goodRep": [
    { "id": "goodRep_01", "es": "¡Bien hecho!", "en": "Well done!", "fr": "Bien joué !" },
    { "id": "goodRep_02", "es": "Excelente repetición", "en": "Excellent rep", "fr": "Excellente répétition" },
    { "id": "goodRep_03", "es": "Así se hace", "en": "That's how it's done", "fr": "C'est comme ça qu'il faut faire" },
    { "id": "goodRep_04", "es": "Perfecta ejecución", "en": "Perfect execution", "fr": "Exécution parfaite" },
    { "id": "goodRep_05", "es": "Sigue así", "en": "Keep it up", "fr": "Continue comme ça" },
    { "id": "goodRep_06", "es": "Gran repetición", "en": "Great rep", "fr": "Superbe répétition" },
    { "id": "goodRep_07", "es": "Eso es, muy bien", "en": "That's it, well done", "fr": "Voilà, très bien" },
    { "id": "goodRep_08", "es": "Forma impecable", "en": "Flawless form", "fr": "Forme impeccable" },
    { "id": "goodRep_09", "es": "Rango completo, excelente", "en": "Full range, excellent", "fr": "Amplitude complète, excellent" },
    { "id": "goodRep_10", "es": "Lo estás haciendo muy bien", "en": "You're doing great", "fr": "Tu t'en sors très bien" },
    { "id": "goodRep_11", "es": "Repetición perfecta", "en": "Perfect rep", "fr": "Répétition parfaite" },
    { "id": "goodRep_12", "es": "Buen control del movimiento", "en": "Good control of the movement", "fr": "Bon contrôle du mouvement" },
    { "id": "goodRep_13", "es": "Vas muy bien", "en": "You're doing well", "fr": "Tu es sur la bonne voie" },
    { "id": "goodRep_14", "es": "Fuerza y técnica, así", "en": "Strength and technique, just like that", "fr": "Force et technique, comme ça" },
    { "id": "goodRep_15", "es": "Esa es la técnica correcta", "en": "That's the right technique", "fr": "C'est la bonne technique" },
    { "id": "goodRep_16", "es": "Excelente esfuerzo", "en": "Excellent effort", "fr": "Excellent effort" },
    { "id": "goodRep_17", "es": "Movimiento limpio", "en": "Clean movement", "fr": "Mouvement propre" },
    { "id": "goodRep_18", "es": "Bien controlado", "en": "Well controlled", "fr": "Bien contrôlé" },
    { "id": "goodRep_19", "es": "Sigues progresando", "en": "You're making progress", "fr": "Tu progresses" },
    { "id": "goodRep_20", "es": "Esa repetición cuenta", "en": "That rep counts", "fr": "Cette répétition compte" }
  ],
  "notDeepEnough": [
    { "id": "notDeepEnough_01", "es": "No completaste el rango de movimiento", "en": "You didn't complete the full range of motion", "fr": "Tu n'as pas fait toute l'amplitude" },
    { "id": "notDeepEnough_02", "es": "Lleva el movimiento un poco más lejos", "en": "Take the movement a little further", "fr": "Va un peu plus loin dans le mouvement" },
    { "id": "notDeepEnough_03", "es": "Completa el movimiento en su totalidad", "en": "Complete the movement in full", "fr": "Effectue le mouvement en entier" },
    { "id": "notDeepEnough_04", "es": "No llegaste al ángulo correcto", "en": "You didn't reach the right angle", "fr": "Tu n'as pas atteint le bon angle" },
    { "id": "notDeepEnough_05", "es": "Completa el movimiento hasta el final", "en": "Finish the movement all the way", "fr": "Termine le mouvement jusqu'au bout" },
    { "id": "notDeepEnough_06", "es": "Un poco más de alcance", "en": "A bit more range", "fr": "Un peu plus d'étendue" },
    { "id": "notDeepEnough_07", "es": "Casi, pero falta rango", "en": "Almost, but you need more range", "fr": "Presque, mais il manque de l'amplitude" },
    { "id": "notDeepEnough_08", "es": "Extiende completamente la articulación", "en": "Fully extend the joint", "fr": "Étends complètement l'articulation" },
    { "id": "notDeepEnough_09", "es": "No te quedes a medio camino", "en": "Don't stop halfway", "fr": "Ne t'arrête pas à mi-chemin" },
    { "id": "notDeepEnough_10", "es": "Completa más el movimiento para activar el músculo", "en": "Complete more of the movement to fully engage the muscle", "fr": "Termine davantage le mouvement pour bien engager le muscle" },
    { "id": "notDeepEnough_11", "es": "Tu postura necesita más rango", "en": "Your posture needs more range", "fr": "Ta posture a besoin de plus d'amplitude" },
    { "id": "notDeepEnough_12", "es": "Repite con mayor amplitud", "en": "Repeat with more amplitude", "fr": "Répète avec plus d'amplitude" },
    { "id": "notDeepEnough_13", "es": "No se ve el rango completo", "en": "I can't see the full range", "fr": "Je ne vois pas toute l'amplitude" },
    { "id": "notDeepEnough_14", "es": "Ajusta el ángulo del movimiento", "en": "Adjust the angle of the movement", "fr": "Ajuste l'angle du mouvement" },
    { "id": "notDeepEnough_15", "es": "Falta llegar al punto final", "en": "You need to reach the end point", "fr": "Il manque d'atteindre le point final" },
    { "id": "notDeepEnough_16", "es": "Lleva el movimiento más al límite", "en": "Push the movement further", "fr": "Pousse le mouvement plus loin" },
    { "id": "notDeepEnough_17", "es": "Tu rango de movimiento es corto", "en": "Your range of motion is short", "fr": "Ton amplitude de mouvement est courte" },
    { "id": "notDeepEnough_18", "es": "Lleva la articulación al límite", "en": "Take the joint to its limit", "fr": "Amène l'articulation à sa limite" },
    { "id": "notDeepEnough_19", "es": "Necesitas más extensión", "en": "You need more extension", "fr": "Tu as besoin de plus d'extension" },
    { "id": "notDeepEnough_20", "es": "Esa repetición no cuenta, falta rango", "en": "That rep doesn't count, not enough range", "fr": "Cette répétition ne compte pas, pas assez d'amplitude" }
  ],
  "tooFast": [
    { "id": "tooFast_01", "es": "Vas muy rápido, controla el movimiento", "en": "You're going too fast, control the movement", "fr": "Tu vas trop vite, contrôle le mouvement" },
    { "id": "tooFast_02", "es": "Más lento, controla el descenso", "en": "Slow down, control the descent", "fr": "Plus lentement, contrôle la descente" },
    { "id": "tooFast_03", "es": "Baja el ritmo", "en": "Slow the pace down", "fr": "Ralentis le rythme" },
    { "id": "tooFast_04", "es": "Controla la fase negativa", "en": "Control the negative phase", "fr": "Contrôle la phase négative" },
    { "id": "tooFast_05", "es": "Hazlo con más control", "en": "Do it with more control", "fr": "Fais-le avec plus de contrôle" },
    { "id": "tooFast_06", "es": "Menos velocidad, más técnica", "en": "Less speed, more technique", "fr": "Moins de vitesse, plus de technique" },
    { "id": "tooFast_07", "es": "Frena un poco el movimiento", "en": "Slow the movement down a bit", "fr": "Ralentis un peu le mouvement" },
    { "id": "tooFast_08", "es": "Tómate tu tiempo en cada repetición", "en": "Take your time on each rep", "fr": "Prends ton temps sur chaque répétition" }
  ],
  "badForm": [
    { "id": "badForm_01", "es": "No uses impulso, controla el movimiento", "en": "Don't use momentum, control the movement", "fr": "N'utilise pas l'élan, contrôle le mouvement" },
    { "id": "badForm_02", "es": "Mantén el cuerpo quieto", "en": "Keep your body still", "fr": "Garde le corps immobile" },
    { "id": "badForm_03", "es": "Evita balancear el peso", "en": "Avoid swinging the weight", "fr": "Évite de balancer le poids" },
    { "id": "badForm_04", "es": "Aísla el músculo, no balancees el cuerpo", "en": "Isolate the muscle, don't swing your body", "fr": "Isole le muscle, ne balance pas ton corps" },
    { "id": "badForm_05", "es": "Controla el movimiento sin ayudarte con el cuerpo", "en": "Control the movement without using body momentum", "fr": "Contrôle le mouvement sans utiliser l'élan du corps" },
    { "id": "badForm_06", "es": "Menos impulso, más control", "en": "Less momentum, more control", "fr": "Moins d'élan, plus de contrôle" },
    { "id": "badForm_07", "es": "Esa repetición no cuenta, usaste impulso", "en": "That rep doesn't count, you used momentum", "fr": "Cette répétition ne compte pas, tu as utilisé l'élan" },
    { "id": "badForm_08", "es": "Mantén la postura estable", "en": "Keep your posture stable", "fr": "Garde une posture stable" },
    { "id": "badForm_09", "es": "No balancees el torso", "en": "Don't sway your torso", "fr": "Ne balance pas ton torse" },
    { "id": "badForm_10", "es": "Concéntrate en el músculo, no en el impulso", "en": "Focus on the muscle, not the momentum", "fr": "Concentre-toi sur le muscle, pas sur l'élan" },
    { "id": "badForm_11", "es": "Evita ayudarte con el cuerpo", "en": "Avoid using your body to help", "fr": "Évite de t'aider avec le corps" },
    { "id": "badForm_12", "es": "Controla mejor la forma", "en": "Control your form better", "fr": "Contrôle mieux ta forme" },
    { "id": "badForm_13", "es": "El cuerpo debe quedarse quieto en este movimiento", "en": "Your body should stay still during this movement", "fr": "Ton corps doit rester immobile pendant ce mouvement" },
    { "id": "badForm_14", "es": "Repite sin balancear", "en": "Repeat without swinging", "fr": "Répète sans balancer" },
    { "id": "badForm_15", "es": "Mantén el control durante toda la repetición", "en": "Keep control throughout the whole rep", "fr": "Garde le contrôle pendant toute la répétition" },
    { "id": "badForm_16", "es": "Reduce el balanceo para que cuente", "en": "Reduce the swinging so it counts", "fr": "Réduis le balancement pour qu'elle compte" }
  ]
}
```

- [ ] **Step 5: Replace `FeedbackPhraseBank.swift`**

Reemplazar el archivo completo con:

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
/// feedback, loaded once from the bundled `FeedbackPhrases.json` (see
/// `scripts/generate_smart_assistant_audio.py` for how each phrase's
/// pre-recorded audio clip is generated from this same content). A
/// fresh random phrase is chosen per completed rep so the same line
/// doesn't repeat every time. `.notDeepEnough` and `.tooFast` get
/// separate banks instead of one shared "corrective" pool: mixing them
/// would let a range-of-motion problem get announced as a speed
/// problem, since the two conditions are detected independently by
/// `RepCounterEngine` and are not interchangeable advice.
enum FeedbackPhraseBank {
    private struct PhraseBankDTO: Codable {
        let goodRep: [LocalizedString]
        let notDeepEnough: [LocalizedString]
        let tooFast: [LocalizedString]
        let badForm: [LocalizedString]
    }

    private static let bank: PhraseBankDTO = loadBank()

    private static func loadBank() -> PhraseBankDTO {
        guard let url = Bundle.main.url(forResource: "FeedbackPhrases", withExtension: "json") else {
            assertionFailure("FeedbackPhrases.json missing from bundle")
            return PhraseBankDTO(goodRep: [], notDeepEnough: [], tooFast: [], badForm: [])
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PhraseBankDTO.self, from: data)
        } catch {
            assertionFailure("Failed to load FeedbackPhrases.json: \(error)")
            return PhraseBankDTO(goodRep: [], notDeepEnough: [], tooFast: [], badForm: [])
        }
    }

    static let goodRepPhrases: [LocalizedString] = bank.goodRep
    static let notDeepEnoughPhrases: [LocalizedString] = bank.notDeepEnough
    static let tooFastPhrases: [LocalizedString] = bank.tooFast
    static let badFormPhrases: [LocalizedString] = bank.badForm

    static func randomPhrase(for feedback: FormFeedback) -> LocalizedString {
        let bank = phrases(for: feedback)
        return bank.randomElement() ?? LocalizedString(es: "", en: "", fr: "")
    }

    private static func phrases(for feedback: FormFeedback) -> [LocalizedString] {
        switch feedback {
        case .goodRep: return goodRepPhrases
        case .notDeepEnough: return notDeepEnoughPhrases
        case .tooFast: return tooFastPhrases
        case .badForm: return badFormPhrases
        }
    }
}
```

- [ ] **Step 6: Update the call site in `SmartAssistantModel.swift`**

Encontrar (alrededor de la línea 109-115):

```swift
        repCount = engine.repCount
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback, language: language)
        feedbackMessage = phrase
        if Self.shouldSpeak(for: feedback, repCount: repCount, targetReps: targetReps) {
            audioAnnouncer.speak(phrase, language: language)
        }
```

Reemplazar con (nota: `audioAnnouncer.speak` todavía recibe un `String` aquí — Task 2 la cambia a recibir el `LocalizedString` completo; este paso es intencionalmente un puente para que el proyecto compile con Task 1 sola):

```swift
        repCount = engine.repCount
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback)
        feedbackMessage = phrase.text(for: language)
        if Self.shouldSpeak(for: feedback, repCount: repCount, targetReps: targetReps) {
            audioAnnouncer.speak(phrase.text(for: language), language: language)
        }
```

- [ ] **Step 7: Run tests to verify they pass, then build**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/FeedbackPhraseBankTests`
Expected: PASS

Then: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **` (confirma que `SmartAssistantModel.swift` sigue compilando con el puente del Step 6)

- [ ] **Step 8: Commit**

```bash
git add IronPulse/Services/ExerciseDatabaseSeeder.swift IronPulse/Resources/FeedbackPhrases.json IronPulse/Services/FeedbackPhraseBank.swift IronPulse/Views/Workouts/SmartAssistantModel.swift IronPulseTests/FeedbackPhraseBankTests.swift
git commit -m "Mover FeedbackPhraseBank a datos JSON con id estable por frase"
```

---

### Task 2: `SmartAssistantAudioAnnouncer` reproduce audio pre-grabado con respaldo a TTS

**Files:**
- Modify: `IronPulse/Services/SmartAssistantAudioAnnouncer.swift`
- Modify: `IronPulse/Views/Workouts/SmartAssistantModel.swift`
- Test: `IronPulseTests/SmartAssistantAudioAnnouncerTests.swift`

**Interfaces:**
- Consumes: `LocalizedString` (con `id`, de Task 1).
- Produces: `SmartAssistantAudioAnnouncer.speak(_ phrase: LocalizedString, language: AppLanguage)` (cambia de firma: primer parámetro pasa de `String` a `LocalizedString`); `SmartAssistantAudioAnnouncer.audioURL(for:language:bundle:) -> URL?` (nueva, estática, testeable).

- [ ] **Step 1: Write the failing tests**

En `IronPulseTests/SmartAssistantAudioAnnouncerTests.swift`, agregar (al final del `struct`, antes del `}` de cierre):

```swift

    @Test func audioURLIsNilWhenPhraseIDIsEmpty() {
        let phrase = LocalizedString(es: "x", en: "x", fr: "x")
        #expect(SmartAssistantAudioAnnouncer.audioURL(for: phrase, language: .spanish) == nil)
    }

    @Test func audioURLIsNilWhenNoBundledClipMatchesTheID() {
        let phrase = LocalizedString(es: "x", en: "x", fr: "x", id: "does_not_exist_yet")
        #expect(SmartAssistantAudioAnnouncer.audioURL(for: phrase, language: .spanish) == nil)
    }
```

(No hay test para "el archivo existe y se encuentra" porque los `.mp3` reales todavía no existen en el bundle en este punto del plan — ver Global Constraints. Ese camino se verifica manualmente en dispositivo una vez que el script de Task 3 se corra de verdad.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/SmartAssistantAudioAnnouncerTests`
Expected: FAIL (`audioURL` no existe todavía)

- [ ] **Step 3: Replace `SmartAssistantAudioAnnouncer.swift`**

Reemplazar el archivo completo con:

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

/// Speaks the Smart Assistant's feedback phrases aloud. Primary path:
/// plays a pre-recorded, human-quality audio clip bundled with the app
/// (one per phrase × language, generated once offline by
/// `scripts/generate_smart_assistant_audio.py`) — this is what makes
/// every user hear a natural voice regardless of what TTS voices their
/// device happens to have installed. Falls back to live system TTS
/// (the original fase 3 mechanism, tuned rate/pitch and best-available
/// installed voice) only when no bundled clip exists for a phrase — a
/// phrase added without regenerating its audio, or one with no `id`.
/// Configured with `.mixWithOthers` so it doesn't interrupt music or
/// podcasts playing during a workout.
@Observable
final class SmartAssistantAudioAnnouncer {
    private static let mutedDefaultsKey = "smart_assistant.audio_muted"
    private static let speechRate: Float = 0.47
    private static let speechPitch: Float = 0.92

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
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

    /// Whether either playback path is currently speaking — lets
    /// callers (e.g. the dismiss-timing logic in
    /// `SmartAssistantSheet`) wait for real completion instead of
    /// guessing a fixed delay.
    var isSpeaking: Bool { synthesizer.isSpeaking || (audioPlayer?.isPlaying ?? false) }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isMuted = userDefaults.bool(forKey: Self.mutedDefaultsKey)
    }

    /// Cancels any utterance/clip still playing before starting the
    /// new one — the latest feedback always wins over a stale one
    /// that hasn't finished yet (reps can complete faster than a
    /// phrase takes to play).
    func speak(_ phrase: LocalizedString, language: AppLanguage) {
        guard !isMuted else { return }
        if !hasConfiguredAudioSession {
            hasConfiguredAudioSession = true
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        }
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()

        if let url = Self.audioURL(for: phrase, language: language),
           let player = try? AVAudioPlayer(contentsOf: url) {
            audioPlayer = player
            player.play()
            return
        }

        let utterance = Self.makeUtterance(phrase.text(for: language), voice: resolvedVoice(for: language))
        synthesizer.speak(utterance)
    }

    /// Immediately silences any utterance/clip currently playing.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
    }

    func toggleMute() {
        isMuted.toggle()
    }

    /// The bundled URL for `phrase`'s pre-recorded clip in `language`,
    /// or `nil` if `phrase.id` is empty or no matching `.mp3` is
    /// bundled — either case triggers the live-TTS fallback in `speak`.
    static func audioURL(for phrase: LocalizedString, language: AppLanguage, bundle: Bundle = .main) -> URL? {
        guard !phrase.id.isEmpty else { return nil }
        return bundle.url(forResource: "\(phrase.id)_\(language.rawValue)", withExtension: "mp3")
    }

    /// Picks the best-quality installed voice for `language`, caching
    /// the result so `AVSpeechSynthesisVoice.speechVoices()` - a full
    /// scan of every voice installed on the device - isn't repeated on
    /// every spoken phrase. Only used by the live-TTS fallback path.
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

- [ ] **Step 4: Update the call site in `SmartAssistantModel.swift`**

Encontrar (el puente de Task 1, Step 6):

```swift
        repCount = engine.repCount
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback)
        feedbackMessage = phrase.text(for: language)
        if Self.shouldSpeak(for: feedback, repCount: repCount, targetReps: targetReps) {
            audioAnnouncer.speak(phrase.text(for: language), language: language)
        }
```

Reemplazar con:

```swift
        repCount = engine.repCount
        let language = AppLanguage.current
        let phrase = FeedbackPhraseBank.randomPhrase(for: feedback)
        feedbackMessage = phrase.text(for: language)
        if Self.shouldSpeak(for: feedback, repCount: repCount, targetReps: targetReps) {
            audioAnnouncer.speak(phrase, language: language)
        }
```

- [ ] **Step 5: Run tests to verify they pass, then run the full suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/SmartAssistantAudioAnnouncerTests`
Expected: PASS

Then: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Services/SmartAssistantAudioAnnouncer.swift IronPulse/Views/Workouts/SmartAssistantModel.swift IronPulseTests/SmartAssistantAudioAnnouncerTests.swift
git commit -m "SmartAssistantAudioAnnouncer reproduce audio pre-grabado con respaldo a TTS en vivo"
```

---

### Task 3: Script de generación de audio (ElevenLabs, una sola vez)

**Files:**
- Create: `scripts/generate_smart_assistant_audio.py`

**Interfaces:** ninguna (herramienta externa a la app, no se importa desde Swift).

- [ ] **Step 1: Create the script**

Crear `scripts/generate_smart_assistant_audio.py` con este contenido exacto:

```python
#!/usr/bin/env python3
"""One-time script: generates a pre-recorded .mp3 audio clip for every
phrase x language combination in IronPulse/Resources/FeedbackPhrases.json,
using the ElevenLabs text-to-speech API, and saves them to
IronPulse/Resources/SmartAssistantAudio/<id>_<language>.mp3.

Run again only if phrases are added/changed in FeedbackPhrases.json --
this is NOT part of the Xcode build, it's a manual asset-generation step.

Requires:
    ELEVENLABS_API_KEY          - your ElevenLabs API key (required)
    ELEVENLABS_VOICE_ID_ES      - voice ID to use for Spanish
    ELEVENLABS_VOICE_ID_EN      - voice ID to use for English
    ELEVENLABS_VOICE_ID_FR      - voice ID to use for French

If any ELEVENLABS_VOICE_ID_* is missing, the script queries
/v1/voices, prints every available premade voice with its metadata,
and exits so you can pick real, currently-available voice IDs rather
than relying on hardcoded names that might not exist on your account.

Usage:
    export ELEVENLABS_API_KEY=...
    export ELEVENLABS_VOICE_ID_ES=...
    export ELEVENLABS_VOICE_ID_EN=...
    export ELEVENLABS_VOICE_ID_FR=...
    python3 scripts/generate_smart_assistant_audio.py [--dry-run]
"""
import json
import os
import sys
import urllib.error
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHRASES_PATH = os.path.join(REPO_ROOT, "IronPulse", "Resources", "FeedbackPhrases.json")
OUTPUT_DIR = os.path.join(REPO_ROOT, "IronPulse", "Resources", "SmartAssistantAudio")
API_BASE = "https://api.elevenlabs.io/v1"

LANGUAGES = ("es", "en", "fr")
VOICE_ID_ENV_VARS = {
    "es": "ELEVENLABS_VOICE_ID_ES",
    "en": "ELEVENLABS_VOICE_ID_EN",
    "fr": "ELEVENLABS_VOICE_ID_FR",
}


def load_jobs():
    with open(PHRASES_PATH, encoding="utf-8") as f:
        bank = json.load(f)
    jobs = []
    for phrases in bank.values():
        for phrase in phrases:
            for lang in LANGUAGES:
                jobs.append((phrase["id"], lang, phrase[lang]))
    return jobs


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        print("ERROR: set the ELEVENLABS_API_KEY environment variable first.", file=sys.stderr)
        sys.exit(1)
    return key


def list_voices(key: str) -> list:
    req = urllib.request.Request(f"{API_BASE}/voices", headers={"xi-api-key": key})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["voices"]


def resolve_voice_ids(key: str) -> dict:
    resolved = {}
    missing = []
    for lang, env_name in VOICE_ID_ENV_VARS.items():
        voice_id = os.environ.get(env_name)
        if voice_id:
            resolved[lang] = voice_id
        else:
            missing.append(lang)

    if missing:
        print(f"Missing voice ID env var(s) for: {', '.join(missing)}")
        print("Available premade voices on this account:")
        for v in list_voices(key):
            print(f"  {v['voice_id']}  {v.get('name')}  labels={v.get('labels', {})}")
        print("\nSet the corresponding ELEVENLABS_VOICE_ID_<LANG> env var(s) and re-run.")
        sys.exit(1)

    return resolved


def generate_clip(key: str, voice_id: str, text: str, out_path: str) -> None:
    url = f"{API_BASE}/text-to-speech/{voice_id}"
    body = json.dumps({
        "text": text,
        "model_id": "eleven_multilingual_v2",
    }).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST", headers={
        "xi-api-key": key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    })
    with urllib.request.urlopen(req) as resp:
        audio = resp.read()
    with open(out_path, "wb") as f:
        f.write(audio)


def main() -> None:
    jobs = load_jobs()
    print(f"{len(jobs)} clips to generate.")

    if "--dry-run" in sys.argv:
        # Self-check: confirms the JSON parses and every job has
        # non-empty id/text before touching the network at all.
        assert len(jobs) > 0, "no phrases found in FeedbackPhrases.json"
        for phrase_id, lang, text in jobs:
            assert phrase_id, "found a phrase with an empty id"
            assert text.strip(), f"empty {lang} text for {phrase_id}"
        for phrase_id, lang, text in jobs[:5]:
            print(f"  [dry-run] {phrase_id}_{lang}.mp3 <- \"{text}\"")
        print("Dry run OK - no API calls made, no files written.")
        return

    key = api_key()
    voice_ids = resolve_voice_ids(key)
    for lang, voice_id in voice_ids.items():
        print(f"Using voice for '{lang}': {voice_id}")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    failures = []
    for i, (phrase_id, lang, text) in enumerate(jobs, start=1):
        out_path = os.path.join(OUTPUT_DIR, f"{phrase_id}_{lang}.mp3")
        if os.path.exists(out_path):
            print(f"[{i}/{len(jobs)}] skip (exists): {phrase_id}_{lang}.mp3")
            continue
        try:
            generate_clip(key, voice_ids[lang], text, out_path)
            print(f"[{i}/{len(jobs)}] wrote {phrase_id}_{lang}.mp3")
        except urllib.error.HTTPError as e:
            failures.append(f"{phrase_id}_{lang}.mp3: {e.code} {e.read().decode(errors='replace')}")
            print(f"[{i}/{len(jobs)}] FAILED {phrase_id}_{lang}.mp3: {e.code}", file=sys.stderr)

    print(f"Done. {len(jobs) - len(failures)}/{len(jobs)} succeeded.")
    if failures:
        print("Failures:", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Verify the self-check (no API key needed)**

Run: `python3 scripts/generate_smart_assistant_audio.py --dry-run`
Expected: prints "192 clips to generate.", 5 sample lines, and "Dry run OK - no API calls made, no files written." with exit code 0. No `IronPulse/Resources/SmartAssistantAudio/` directory is created by this step.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_smart_assistant_audio.py
git commit -m "Agrega script de generacion de audio pre-grabado (ElevenLabs, una sola vez)"
```

---

### Task 4: Verificación completa

**Files:** ninguno (solo verificación)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`, incluyendo todos los tests nuevos/cambiados de Tasks 1-2 más todos los preexistentes.

- [ ] **Step 2: Build para dispositivo real**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Nota de verificación manual y próximo paso (fuera de este plan)**

Documentar en el reporte (no en código):
- En este punto, ningún `.mp3` real existe todavía — cada frase sigue cayendo al TTS en vivo (fase 3), exactamente como hoy. Esto es intencional (ver Global Constraints) y significa que el comportamiento en dispositivo no cambia todavía con solo Tasks 1-4 mergeadas.
- El siguiente paso, **fuera del alcance de este plan** (lo hace el controller directamente, no un subagente, porque necesita la API key personal del humano): correr `scripts/generate_smart_assistant_audio.py` de verdad con `ELEVENLABS_API_KEY`/`ELEVENLABS_VOICE_ID_ES`/`ELEVENLABS_VOICE_ID_EN`/`ELEVENLABS_VOICE_ID_FR` seteadas, revisar los 192 archivos `.mp3` resultantes, y confirmar en dispositivo real que: (a) el asistente reproduce el audio pre-grabado en vez de cualquier TTS, (b) el volumen es consistente entre frases, (c) el `.mixWithOthers` sigue sin interrumpir música/podcasts, (d) el mute sigue silenciando ambos caminos.
