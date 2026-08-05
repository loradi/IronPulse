# Smart Assistant: Audio Pre-Grabado (Reemplazo de TTS en Vivo)

## Contexto

Feedback de uso real: la voz del Smart Assistant (fase 3, síntesis en vivo con `AVSpeechSynthesizer`) sigue sonando robótica. Root-cause investigado en esta sesión: `AVSpeechSynthesizer` solo suena natural si el dispositivo tiene una voz "Enhanced"/"Premium" descargada manualmente en Ajustes — un activo del sistema operativo que Apple no permite empaquetar dentro de una app. Mientras la app dependa de síntesis en vivo del sistema, la calidad de voz siempre va a depender de una configuración manual que la mayoría de usuarios nunca toca.

La salida real: las frases que dice el asistente son un conjunto fijo y cerrado — 64 frases (20 `goodRep`, 20 `notDeepEnough`, 8 `tooFast`, 16 `badForm`) × 3 idiomas = 192 combinaciones. Como no cambian en runtime, se pueden generar **una sola vez** con un servicio de TTS de alta calidad (ElevenLabs, plan gratuito — 192 frases usan ~7,700 caracteres, dentro del límite gratuito de 10,000/mes) y empaquetar el resultado como audio real dentro de la app. Sin depender de nada que el usuario configure.

Voz: masculina, una voz consistente y de acento nativo por idioma (elegida por Claude entre las voces pre-hechas de ElevenLabs, sin necesidad de clonar ni de aprobación previa de muestras).

## 1. Las frases pasan a vivir en un JSON empaquetado

Hoy `FeedbackPhraseBank.swift` tiene 4 arrays `static let [LocalizedString]` como literales de código. Pasan a un recurso empaquetado `IronPulse/Resources/FeedbackPhrases.json`, con esta forma (mismo patrón que `ExercisesSeed.json`, que ya se carga vía `Bundle.main.url(forResource:withExtension:)` + `JSONDecoder`):

```json
{
  "goodRep": [
    { "id": "goodRep_01", "es": "¡Bien hecho!", "en": "Well done!", "fr": "Bien joué !" },
    ...
  ],
  "notDeepEnough": [ ... ],
  "tooFast": [ ... ],
  "badForm": [ ... ]
}
```

Cada frase gana un `id` estable — es lo que conecta una frase con su archivo de audio (sección 2) sin duplicar el contenido en dos lugares que se puedan desincronizar.

`FeedbackPhraseBank` mantiene exactamente la misma API pública (`randomPhrase(for:language:)`, y los 4 arrays siguen expuestos como `static let [LocalizedString]` para no romper nada que ya los consuma) — internamente, en vez de ser literales, se cargan una vez desde el JSON al primer acceso. `LocalizedString` gana un campo `id: String` (con default vacío para no romper el uso existente en `ExerciseDatabaseSeeder.swift`, que no lo necesita).

## 2. Script de generación (una sola vez, no en build ni en runtime)

Un script en Python (`scripts/generate_smart_assistant_audio.py`) que:
1. Lee `IronPulse/Resources/FeedbackPhrases.json`.
2. Consulta el endpoint `/v1/voices` de ElevenLabs para listar voces pre-hechas disponibles y elige una voz masculina por idioma (es/en/fr) — se imprime en consola cuál se eligió, para que quede documentado, pero no requiere aprobación interactiva.
3. Por cada frase × idioma, llama a la API de generación de ElevenLabs (modelo `eleven_multilingual_v2`) y guarda el resultado como `IronPulse/Resources/SmartAssistantAudio/<id>_<idioma>.m4a` (ej. `goodRep_01_es.m4a`).
4. Lee la API key desde la variable de entorno `ELEVENLABS_API_KEY` — nunca hardcodeada ni pasada por argumento de línea de comandos.

Se corre una vez ahora (192 llamadas) y de nuevo solo si se agregan/cambian frases en el futuro — no es parte del pipeline de build de Xcode, los `.m4a` resultantes se agregan al repo y al target de la app como cualquier otro recurso bundled.

## 3. Reproducción: `SmartAssistantAudioAnnouncer` gana una ruta de audio pre-grabado

Hoy `speak(_ text: String, language:)` recibe el TEXTO ya elegido (vía `FeedbackPhraseBank.randomPhrase`) y lo sintetiza. Para poder buscar el archivo de audio correspondiente hace falta saber el `id` de la frase, no solo su texto — así que el punto de entrada cambia de recibir un `String` a recibir el `LocalizedString` completo (que ya trae `id` y los 3 idiomas):

- `FeedbackPhraseBank.randomPhrase(for feedback: FormFeedback, language:) -> String` cambia a `randomPhrase(for feedback: FormFeedback) -> LocalizedString` — devuelve la frase completa (con su `id` y los 3 idiomas) en vez de resolver ya el texto de un idioma. El único call site en producción (`SmartAssistantModel.swift:111`) y los tests existentes se actualizan a la nueva firma; el parámetro `language` deja de tener sentido en esta función porque ya no decide qué texto devolver, eso lo hace el caller.
- `SmartAssistantAudioAnnouncer.speak(_:language:)` cambia su primer parámetro de `String` a `LocalizedString`. Internamente:
  1. Busca `<phrase.id>_<language>.m4a` en el bundle.
  2. Si existe: lo reproduce con `AVAudioPlayer` (mismo `AVAudioSession` con `.mixWithOthers` ya configurado).
  3. Si NO existe (frase nueva sin audio generado todavía, id vacío, archivo corrupto): cae automáticamente al mecanismo actual de `AVSpeechSynthesizer` con el texto (`phrase.text(for: language)`) — cero riesgo de quedarse sin audio.
- `SmartAssistantModel.swift:109-115` — hoy asigna `feedbackMessage = phrase` (el `String` ya resuelto) y llama `audioAnnouncer.speak(phrase, language: language)` con ese mismo `String`. Con el cambio, `phrase` es un `LocalizedString`: `feedbackMessage = phrase.text(for: language)` (el banner en pantalla no cambia, solo de dónde saca el texto) y `audioAnnouncer.speak(phrase, language: language)` ahora pasa el `LocalizedString` completo (para que el announcer pueda armar `<phrase.id>_<language>.m4a`).

Todo lo demás no cambia: `isMuted`, el ritmo de habla (primero/mitad/último para `.goodRep`, siempre para las correctivas — `shouldSpeak` de la fase 4), `stop()`, `toggleMute()`. La selección de mejor-voz-instalada (`bestVoice`/`resolvedVoice`) y el rate/pitch tuneado (0.47/0.92) del código actual se mantienen intactos como parte del camino de respaldo (TTS en vivo), no se eliminan.

## Testing

- `FeedbackPhraseBank`: los tests existentes (conteos, no-vacío en los 3 idiomas) se mantienen y pasan igual cargando desde JSON. Se agrega un test de que cada frase tiene un `id` no vacío y único dentro de su categoría.
- `SmartAssistantAudioAnnouncer`: se agrega una función pura testeable para resolver el nombre de archivo esperado dado un `id` e idioma, y un test de que el fallback a TTS se activa cuando el archivo no existe (usando un `id` inventado que no tiene `.m4a`).
- El propio audio (si suena bien, si el volumen es consistente entre frases) no es testeable automáticamente — se verifica manualmente en dispositivo, igual que el resto del pipeline de audio de fases anteriores.

## Fuera de alcance

- No se regenera audio automáticamente cuando se agregan frases nuevas — es un paso manual (correr el script) que un desarrollador ejecuta a propósito.
- No se ofrece selección de voz al usuario final (una sola voz masculina consistente por idioma, fija).
- No se resuelve la selección de mejor-voz-instalada para el camino de respaldo (TTS en vivo) — ese código de fase 3 sigue como está, solo deja de ser el camino primario.
