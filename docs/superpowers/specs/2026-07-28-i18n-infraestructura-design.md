# i18n: infraestructura + selector de idioma + chrome de la app

## Contexto

El pendiente "selector de idioma" (español/inglés/francés) venía desde
`PROGRESS.md`, originalmente combinado con foto de perfil y separado en
dos specs independientes al arrancar esa tanda (2026-07-28). Foto de
perfil ya está completa. Este spec cubre idioma — pero incluso "idioma"
resultó tener dos subsistemas de tamaño y naturaleza muy distinta:
infraestructura de i18n + traducción del chrome de la interfaz (esta
spec), y la traducción real de las 146 entradas del catálogo de
ejercicios (292 piezas de contenido nuevo — nombre + instrucciones + pro
tip en inglés y francés, spec futura aparte).

Esta spec cubre: el mecanismo de i18n (String Catalog nativo), el
selector de idioma, la traducción del chrome existente (~35+ strings
literales + 7 enums con `displayName` hardcodeado), y el **esquema** para
que el catálogo de ejercicios pueda tener contenido por idioma — sin
escribir las traducciones reales del catálogo todavía (eso es la spec
futura).

## Decisiones (con el usuario, 2026-07-28)

- **Alcance**: separado en dos specs. Esta cubre infraestructura + chrome
  + esquema del catálogo. La traducción real de las 146 entradas del
  catálogo (292 piezas) es una spec aparte, posterior.
- **Idioma del selector**: del dispositivo completo, no por perfil (todos
  los perfiles del mismo teléfono comparten idioma) — `@AppStorage`, no un
  campo en `UserProfile`.
- **Mecanismo**: `String Catalog` nativo (`.xcstrings`, Xcode 15+, cero
  dependencias). La mayoría de los ~35+ `Text("...")` literales ya
  existentes se localizan solos (SwiftUI trata `String` como
  `LocalizedStringKey` en `Text`, `Button`, `.navigationTitle`, etc.) — no
  hace falta tocar esos call sites, solo crear el catálogo con las
  traducciones.
- **Cambio instantáneo, sin reiniciar**: `.environment(\.locale: ...)` en
  la raíz (`IronPulseApp.swift`), mismo lugar donde ya vive
  `.preferredColorScheme(.dark)`.
- **Primera instalación**: si nunca se eligió idioma explícitamente, se
  deriva de `Locale.preferredLanguages` (inglés/francés si el sistema está
  en esos idiomas, español si no).
- **Ubicación del selector**: nueva sección "Ajustes" en el `Form` de
  `ProfileDetailView` (no una pantalla nueva).
- **Los 7 enums con `displayName`** (`ExperienceLevel`, `PrimaryGoal`,
  `SplitType`, `BiologicalSex`, `EquipmentType`, `MuscleGroup`,
  `Weekday`) no pasan por `Text()`, así que no localizan solos — se
  convierten a `String(localized:defaultValue:locale:)` con un locale
  explícito resuelto por un helper nuevo (`AppLanguage.current`), sin
  tocar ninguno de los call sites existentes que ya leen `.displayName`.
- **Catálogo de ejercicios — solo el esquema**: `Exercise.name` /
  `.instructions` / `.proTip` dejan de ser propiedades guardadas y pasan a
  ser computadas (una por idioma guardada, más una computada que elige
  según `AppLanguage.current`) — mismo truco que los enums, cero call
  sites rotos. El JSON pasa a `{"es": ..., "en": ..., "fr": ...}` por
  campo, con `en`/`fr` duplicando el texto en español como placeholder en
  esta spec (las traducciones reales son la spec futura).
- **Traductor del chrome**: las traducciones de inglés/francés para el
  chrome (~35+ strings + 7 enums) las redacto yo como parte de la
  implementación, igual que se hizo con los 146 pro tips en el rebrand.

## `AppLanguage`

Nuevo archivo, `IronPulse/Models/AppLanguage.swift`:

```swift
enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"
    case french = "fr"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        case .french: return "Français"
        }
    }

    static func resolve(storedRawValue: String?, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        if let storedRawValue, let stored = AppLanguage(rawValue: storedRawValue) {
            return stored
        }
        for preferred in preferredLanguages {
            if preferred.hasPrefix("en") { return .english }
            if preferred.hasPrefix("fr") { return .french }
        }
        return .spanish
    }

    static var current: AppLanguage {
        resolve(storedRawValue: UserDefaults.standard.string(forKey: "appLanguage"))
    }
}
```

`resolve(storedRawValue:preferredLanguages:)` es una función pura,
testeable sin tocar `UserDefaults` real. `current` es el único punto que
lee `UserDefaults`, y usa la misma clave (`"appLanguage"`) que el
`@AppStorage` del picker y de `IronPulseApp`.

## `IronPulseApp.swift`

```swift
struct IronPulseApp: App {
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.current.rawValue
    // ... resto sin cambios (sharedModelContainer, etc.)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, (AppLanguage(rawValue: appLanguageRaw) ?? .spanish).locale)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

## Selector en `ProfileDetailView`

Nueva `Section("Ajustes")` en el `Form` existente (después de la sección
"Salud", al final):

```swift
Section("Ajustes") {
    Picker("Idioma", selection: $appLanguageRaw) {
        ForEach(AppLanguage.allCases) { language in
            Text(language.displayName).tag(language.rawValue)
        }
    }
}
```

`ProfileDetailView` gana su propio `@AppStorage("appLanguage") private var
appLanguageRaw: String = AppLanguage.current.rawValue` (mismo patrón que
`IronPulseApp`, misma clave — cambiar el picker aquí actualiza el
`@AppStorage` que `IronPulseApp` ya está observando, forzando el
re-render de toda la jerarquía con el nuevo `.environment(\.locale:)`).

## Los 7 enums

Cada `displayName` (y `Weekday.shortDisplayName`) cambia de un `switch`
que retorna un string fijo a uno que pasa por `String(localized:)` con
`locale: AppLanguage.current.locale` explícito. Ejemplo
(`ExperienceLevel`, en `IronPulse/Models/ProfileEnums.swift`):

```swift
var displayName: String {
    switch self {
    case .beginner:
        return String(localized: "experience_level.beginner", defaultValue: "Principiante", locale: AppLanguage.current.locale)
    case .intermediate:
        return String(localized: "experience_level.intermediate", defaultValue: "Intermedio", locale: AppLanguage.current.locale)
    case .advanced:
        return String(localized: "experience_level.advanced", defaultValue: "Avanzado", locale: AppLanguage.current.locale)
    }
}
```

Mismo patrón para los 6 enums restantes, una clave única por caso
(`primary_goal.hypertrophy`, `muscle_group.chest`, etc.). El
`defaultValue:` es el texto español actual — Xcode lo usa para poblar el
catálogo automáticamente la primera vez que compila.

## Catálogo de ejercicios — esquema (sin traducciones reales)

### `Exercise` (modelo)

`IronPulse/Models/Exercise.swift`: `name`, `instructions`, `proTip` dejan
de ser `@Attribute` guardados y pasan a ser computados:

```swift
@Model
final class Exercise {
    @Attribute(.unique) var id: String
    var nameEs: String
    var nameEn: String
    var nameFr: String
    var muscleGroup: MuscleGroup
    var secondaryMuscles: [MuscleGroup]
    var equipment: EquipmentType
    var isCompound: Bool
    var instructionsEs: [String]
    var instructionsEn: [String]
    var instructionsFr: [String]
    var gifFileName: String
    var gifRemoteURLString: String?
    var isCustom: Bool
    var proTipEs: String?
    var proTipEn: String?
    var proTipFr: String?

    var name: String {
        switch AppLanguage.current {
        case .spanish: return nameEs
        case .english: return nameEn
        case .french: return nameFr
        }
    }

    var instructions: [String] {
        switch AppLanguage.current {
        case .spanish: return instructionsEs
        case .english: return instructionsEn
        case .french: return instructionsFr
        }
    }

    var proTip: String? {
        switch AppLanguage.current {
        case .spanish: return proTipEs
        case .english: return proTipEn
        case .french: return proTipFr
        }
    }

    init(/* ...todos los campos de arriba, sin name/instructions/proTip... */) { ... }
}
```

Todos los call sites existentes (`exercise.name`, `exercise.instructions`,
`exercise.proTip` en `ExerciseListView`, `WorkoutGeneratorService`,
`WorkoutLogGenerator`, etc.) siguen funcionando igual — son propiedades
computadas con el mismo nombre y tipo que antes.

### `ExercisesSeed.json` + `ExerciseSeedDTO`

Cada entrada pasa de:

```json
{ "id": "ex_001", "name": "Press de Banca", "instructions": ["..."], "proTip": "..." }
```

a:

```json
{
  "id": "ex_001",
  "name": { "es": "Press de Banca", "en": "Press de Banca", "fr": "Press de Banca" },
  "instructions": { "es": ["..."], "en": ["..."], "fr": ["..."] },
  "proTip": { "es": "...", "en": "...", "fr": "..." }
}
```

Un script (Python, mecánico) migra las 146 entradas existentes:
duplica el valor de `es` en `en` y `fr` — **no traduce nada**, solo cambia
la forma del JSON. `ExerciseSeedDTO` gana structs `Decodable` anidados
(`LocalizedString { es, en, fr: String }`,
`LocalizedStringArray { es, en, fr: [String] }`,
`LocalizedOptionalString { es, en, fr: String }` para el proTip opcional
— si falta la clave completa, `proTip` queda `nil`).

### Gotcha de migración

`name`/`instructions`/`proTip` dejan de ser columnas guardadas de
`Exercise` (se reemplazan por 9 campos nuevos no-opcionales) — esto rompe
el store SwiftData existente del simulador. Hace falta
`xcrun simctl uninstall <device> com.BERNU.WattWeight` antes de correr
después de este cambio, igual que otros campos no-opcionales nuevos en
sesiones anteriores.

## Testing

- `AppLanguage.resolve(storedRawValue:preferredLanguages:)`: 4 casos —
  sin valor + sistema en inglés → inglés; sin valor + sistema en francés
  → francés; sin valor + sistema en otro idioma → español; valor guardado
  tiene prioridad sobre el sistema.
- Script de verificación (estilo Tarea 7 del rebrand): confirma que las
  146 entradas de `ExercisesSeed.json` tienen la estructura `{es, en, fr}`
  en los 3 campos, con `en`/`fr` no vacíos.
- Resto manual en simulador: cambiar el picker de idioma y confirmar que
  el chrome, los 7 enums, y los nombres/instrucciones/pro tips de
  ejercicios cambian en vivo sin reiniciar la app (aunque `en`/`fr` se
  vean idénticos a `es` todavía, ya que son placeholders).

## Fuera de alcance

- Traducción real del catálogo de ejercicios a inglés/francés (146 × 3
  campos = 438 piezas de contenido) — spec futura, aparte.
- Fuente real de GIFs animados — pendiente sin relación, no tocado aquí.
- Cualquier ajuste de idioma por perfil (se decidió explícitamente que es
  del dispositivo, no por perfil).
