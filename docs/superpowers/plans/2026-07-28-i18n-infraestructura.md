# i18n: Infraestructura + Selector de Idioma + Chrome Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar selector de idioma (español/inglés/francés) con `String Catalog` nativo, traducir todo el chrome existente de la app, convertir los 7 enums con `displayName` hardcodeado, y establecer el esquema (sin traducciones reales) para que el catálogo de ejercicios tenga contenido por idioma — según `docs/superpowers/specs/2026-07-28-i18n-infraestructura-design.md`.

**Architecture:** `AppLanguage` (enum + función pura de resolución) guardado en `@AppStorage`, aplicado como `.environment(\.locale:)` en la raíz de la app (mismo lugar que `.preferredColorScheme(.dark)`). El chrome existente se localiza casi solo vía `Text("literal")` + un `String Catalog` (`Localizable.xcstrings`); los 7 enums y el catálogo de ejercicios (que no pasan por `Text()`) usan `String(localized:defaultValue:locale:)` explícito con el locale resuelto por `AppLanguage.current`.

**Tech Stack:** SwiftUI + SwiftData, `String Catalog` nativo (Xcode 15+), iOS 17+, cero dependencias externas.

## Global Constraints

- El idioma es del dispositivo completo (`@AppStorage`), no de un `UserProfile` — no agregar ningún campo de idioma al modelo de perfil.
- Ningún test existente (63+ en `IronPulseTests`) puede romperse. Correr siempre con `-only-testing:IronPulseTests`.
- **Gotcha de SwiftUI**: `Text("literal")` localiza solo automáticamente porque usa el init `Text(_ key: LocalizedStringKey)`. `Text(unaVariable)` (donde `unaVariable: String`) usa el init verbatim `Text(_ content: some StringProtocol)` y **no** localiza, aunque el valor original haya sido un literal en otro lado del código. Los 2 casos ya identificados en este codebase que caen en esta trampa (`TagBadge`/`FilterChip` reciben un `String` y hacen `Text(variable.uppercased())`) necesitan el string ya resuelto por `String(localized:locale:)` en el call site, no en el componente.
- Cualquier campo nuevo no-opcional en un `@Model` (Task 5) rompe el store existente del simulador — hace falta `xcrun simctl uninstall <device> com.BERNU.WattWeight` antes de correr después de esa tarea.
- Las traducciones a inglés y francés (del chrome, los enums, y los mensajes de permiso) las redacta el implementador de cada tarea — no son traducciones automáticas ni placeholders, deben ser naturales en cada idioma.

---

### Task 1: `AppLanguage` + ajustes de proyecto

**Files:**
- Modify: `IronPulse.xcodeproj/project.pbxproj`
- Create: `IronPulse/Models/AppLanguage.swift`
- Test: `IronPulseTests/AppLanguageTests.swift`

**Interfaces:**
- Produces: `enum AppLanguage: String, CaseIterable, Identifiable { case spanish = "es", english = "en", french = "fr" }`, `AppLanguage.resolve(storedRawValue:preferredLanguages:) -> AppLanguage`, `AppLanguage.current: AppLanguage`, `AppLanguage.locale: Locale`, `AppLanguage.displayName: String`.

- [ ] **Step 1: Actualizar `developmentRegion`/`knownRegions` en el proyecto**

En `IronPulse.xcodeproj/project.pbxproj`:

Buscar (aparece una sola vez):
```
			developmentRegion = en;
```
Reemplazar:
```
			developmentRegion = es;
```

Buscar:
```
			knownRegions = (
				en,
				Base,
			);
```
Reemplazar:
```
			knownRegions = (
				en,
				es,
				fr,
				Base,
			);
```

(El código fuente ya es 100% español — `developmentRegion` reflejaba mal esto desde antes de este plan; corregirlo ahora es parte de dejar la infraestructura de idiomas consistente.)

- [ ] **Step 2: Escribir el test primero**

```swift
import XCTest
@testable import IronPulse

final class AppLanguageTests: XCTestCase {
    func testSinValorGuardadoYSistemaEnInglesDevuelveIngles() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: nil, preferredLanguages: ["en-US"]), .english)
    }

    func testSinValorGuardadoYSistemaEnFrancesDevuelveFrances() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: nil, preferredLanguages: ["fr-FR"]), .french)
    }

    func testSinValorGuardadoYSistemaEnOtroIdiomaDevuelveEspanol() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: nil, preferredLanguages: ["de-DE"]), .spanish)
    }

    func testValorGuardadoTienePrioridadSobreElSistema() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: "fr", preferredLanguages: ["en-US"]), .french)
    }

    func testValorGuardadoInvalidoCaeAlSistema() {
        XCTAssertEqual(AppLanguage.resolve(storedRawValue: "de", preferredLanguages: ["fr-FR"]), .french)
    }
}
```

- [ ] **Step 2: Correr y verificar que fallan (no existe `AppLanguage` todavia)**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/AppLanguageTests
```

- [ ] **Step 3: Implementar `AppLanguage.swift`**

```swift
import Foundation

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

- [ ] **Step 4: Correr de nuevo, confirmar verde**

Mismo comando del Step 2. Esperado: 5/5 en verde.

- [ ] **Step 5: Verificar que el proyecto sigue compilando**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 6: Commit**

```bash
git add IronPulse.xcodeproj/project.pbxproj IronPulse/Models/AppLanguage.swift IronPulseTests/AppLanguageTests.swift
git commit -m "Agrega AppLanguage + developmentRegion/knownRegions es/en/fr"
```

---

### Task 2: Wiring — `IronPulseApp` + selector en `ProfileDetailView`

**Files:**
- Modify: `IronPulse/IronPulseApp.swift`
- Modify: `IronPulse/ContentView.swift`

**Interfaces:**
- Consumes: `AppLanguage` (Task 1).

- [ ] **Step 1: `IronPulseApp.swift`**

Contenido actual completo (para referencia — no cambia `sharedModelContainer`):

```swift
import SwiftUI
import SwiftData

@main
struct IronPulseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            HealthSnapshot.self,
            Exercise.self,
            WorkoutRoutine.self,
            RoutineDay.self,
            RoutineExercise.self,
            WorkoutLog.self,
            SetLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            ExerciseDatabaseSeeder.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

Reemplazar el `body` por:

```swift
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.current.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, (AppLanguage(rawValue: appLanguageRaw) ?? .spanish).locale)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
```

(La propiedad `@AppStorage` va como miembro de `IronPulseApp`, antes de `var body`.)

- [ ] **Step 2: Sección "Ajustes" en `ProfileDetailView`**

En `IronPulse/ContentView.swift`, `ProfileDetailView` gana la misma
`@AppStorage`:

```swift
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.current.rawValue
```

(como propiedad de `ProfileDetailView`, junto a `@State private var
isImportingHealthData = false`).

Y una nueva sección al final del `Form`, después de la `Section("Salud")`
(antes del `}` que cierra el `Form`):

```swift
            Section("Ajustes") {
                Picker("Idioma", selection: $appLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
            }
```

- [ ] **Step 3: Verificar que compila**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 4: Verificación manual en simulador**

Abrir un perfil, ir a la sección "Ajustes", cambiar el picker de idioma.
Confirmar que el título "Idioma" y las opciones ("Español"/"English"/
"Français") se ven — el resto del chrome todavía no traduce hasta Tasks
3-4, así que no hace falta confirmar más que esto ahora.

- [ ] **Step 5: Commit**

```bash
git add IronPulse/IronPulseApp.swift IronPulse/ContentView.swift
git commit -m "Wiring: .environment(\.locale) en la raiz + seccion Ajustes con selector de idioma"
```

---

### Task 3: `Localizable.xcstrings` — traducir el chrome existente

**Files:**
- Create: `IronPulse/Localizable.xcstrings`
- Modify: `IronPulse/Views/Exercises/ExerciseListView.swift` (2 call sites: `allLabel: "Todos"` × 2, `TagBadge(text: "Compound")` × 2 — ver Global Constraints sobre por qué estos no localizan solos)
- Modify: `IronPulse.xcodeproj/project.pbxproj` (agregar `NSCameraUsageDescription`/`NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` como claves localizables — ver Step 3)

**Interfaces:**
- Consumes: `AppLanguage.current` (Task 1), para los 2 call sites que necesitan `String(localized:locale:)` explícito.

- [ ] **Step 1: Inventario completo de strings del chrome**

Esta es la lista exhaustiva de literales que necesitan traducción a
inglés y francés (grep ya corrido sobre todo `IronPulse/`, excluyendo
tests). Para cada uno, redactar una traducción natural — no literal
palabra por palabra — en inglés y francés, manteniendo el mismo tono
directo que ya tiene el español.

**`ContentView.swift`**: "Perfiles", "Sin perfiles" (título de
`ContentUnavailableView`), "Crea un perfil para generar rutinas y
registrar progreso.", "Nuevo perfil", "Nombre", "Perfil" (Section),
"Datos fisicos" (Section), "\(profile.age) anos" (Stepper — el patrón es
"{N} años", mantener la interpolación), "Sexo", "Altura", "Peso", "Salud"
(Section), "Importar datos de Salud", "Ajustes" (Section, agregada en
Task 2), "Idioma" (Picker, agregado en Task 2).

**`EditableAvatarView.swift`**: "Foto de perfil" (aparece 2 veces: label
+ título del dialog), "Elegir de galeria", "Tomar foto", "Eliminar foto".

**`ExerciseListView.swift`**: "Watt + Weight" (header — mismo string que
`ContentView`'s navigationTitle, mantener consistente en las 3 traducciones),
"Todos" (×2 — ver Step 2, requiere fix de código, no solo traducción).

**`ExercisePickerSheet.swift`**: "Elegir ejercicio" (navigationTitle),
"Cancelar".

**`MainTabView.swift`**: "Dashboard", "Rutina", "Ejercicios", "Perfil"
(los 4 tabs).

**`ActiveWorkoutView.swift`**: "Terminar", "Descanso: {N}s" (mantener
interpolación), "Entrenamiento" (Text, línea 137), "Finalizada", "Set {N}"
(mantener interpolación), "Meta: {min}-{max}" (mantener interpolación),
"Peso" (TextField), "kg", "{N} reps" (Stepper, mantener interpolación).
(`Text("Active Workout")` en línea 211 vive dentro de
`ActiveWorkoutView_Previews: PreviewProvider` — código exclusivo de
Xcode Previews, nunca visible en la app real corriendo. **No traducir,
no agregar al catálogo.**)

**`DashboardView.swift`**: "Genera una rutina automatica o arma la tuya
desde la tab Rutina.", "Hoy: {titulo}" (mantener interpolación), "Iniciar
ejercicios", "Descanso hoy", "Hoy no hay ningun dia de la rutina
asignado.", "Progreso (30 dias)", "Masa magra", "Progreso por ejercicio",
"Ver historial de entrenamientos", "Sin rutina activa"
(`ContentUnavailableView`). (`Text("Dashboard")` en línea 247 vive dentro
de `DashboardView_Previews: PreviewProvider` — mismo caso que
`ActiveWorkoutView`, código exclusivo de Previews. **No traducir, no
agregar al catálogo.**)

**`ExerciseProgressView.swift`**: "Todavia no completaste ningun set de
este ejercicio.", "Sin datos todavia" (`ContentUnavailableView`),
"Progreso" (navigationTitle y Text, línea 41 y 50).

**`RoutineBuilderView.swift`**: "Rutina manual" (navigationTitle),
"Guardar", "Estructura" (Section), "{N} por semana" (Stepper, mantener
interpolación), "Dia {N} — {titulo}" (Section, mantener interpolación),
"Agregar ejercicio".

**`RoutineTabView.swift`**: "Rutina" (Text y navigationTitle — 2
lugares), "Genera una rutina automatica o arma la tuya ejercicio por
ejercicio." (`ContentUnavailableView`), "Rutina inteligente", "Crear
rutina manual", "{N dias} · {split}" (Text, mantener interpolación),
"Empezar", "{sets}x{min}-{max}" (Text, mantener interpolación, son
numeros y una "x" literal, ver si hace falta traducir algo aca — probablemente no).

**`WorkoutHistoryView.swift`**: "{rutina} · {dia}" (mantener
interpolación), "{fecha} · {duracion}" (mantener interpolación),
"Historial" (navigationTitle), "Sin entrenamientos"
(`ContentUnavailableView`), "Los entrenamientos que termines van a
aparecer aca."

**Mensajes de permiso** (`project.pbxproj`, ver Step 3): el texto de
`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, y
`NSCameraUsageDescription`.

- [ ] **Step 2: Arreglar los 2 call sites que NO localizan solos**

En `IronPulse/Views/Exercises/ExerciseListView.swift`, los dos
`allLabel: "Todos"` (líneas ~65 y ~71) pasan por `FilterChip`, que hace
`Text(title.uppercased())` con `title: String` — un `Text(variable)`, que
**no** localiza aunque el literal exista en otro archivo. Cambiar ambos a:

```swift
allLabel: String(localized: "exercise_filter.all", defaultValue: "Todos", locale: AppLanguage.current.locale),
```

Los dos `TagBadge(text: "Compound")` (líneas ~50 y ~152 del mismo
archivo) tienen el mismo problema (`TagBadge` hace
`Text(text.uppercased())`). Cambiar ambos a:

```swift
TagBadge(text: String(localized: "exercise.compound_badge", defaultValue: "Compound", locale: AppLanguage.current.locale))
```

- [ ] **Step 3: Traducir los mensajes de permiso**

En `IronPulse.xcodeproj/project.pbxproj`, estas 3 claves son texto plano
de Info.plist, no pasan por ningún mecanismo de i18n de SwiftUI — para
mostrarlas en el idioma correcto del sistema operativo (no del selector
in-app, ya que el permiso lo muestra iOS antes de que la app corra
código), Apple espera archivos `.lproj`/`InfoPlist.strings` por idioma, un
mecanismo aparte del `String Catalog` de SwiftUI. Dado que este spec
excluye explícitamente "cualquier ajuste que no sea el chrome de
SwiftUI", **dejar estos 3 mensajes solo en español por ahora** — no
agregar `InfoPlist.strings` en esta tarea. Anotar esto como pendiente
conocido en el reporte de la tarea, no como algo a resolver aca.

- [ ] **Step 4: Crear `Localizable.xcstrings`**

Formato de `String Catalog` (JSON). Estructura por cada clave (repetir
para cada uno de los ~60 strings inventariados en el Step 1, con las
traducciones redactadas):

```json
{
  "sourceLanguage" : "es",
  "strings" : {
    "Perfiles" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Profiles" } },
        "es" : { "stringUnit" : { "state" : "translated", "value" : "Perfiles" } },
        "fr" : { "stringUnit" : { "state" : "translated", "value" : "Profils" } }
      }
    }
  },
  "version" : "1.0"
}
```

Para las claves con interpolación (ej. `"\(profile.age) anos"`), la clave
del catálogo es el patrón con `%@`/`%lld` que Xcode genera — usar
`%lld` para `Int` interpolado y `%@` para `String` interpolado
(coincidiendo con el tipo real de cada variable en el código, ej.
`profile.age: Int` → `"%lld anos"` como clave, con localizaciones
`"%lld years"` / `"%lld ans"`).

- [ ] **Step 5: Verificar que compila**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 6: Verificación manual en simulador**

Cambiar el idioma en Ajustes a inglés y a francés, navegar por las 4 tabs
y confirmar que el chrome cambia en vivo (títulos, botones, mensajes de
estado vacío). El catálogo de ejercicios todavía no traduce (Task 5), así
que los nombres de ejercicios seguirán en español — eso es esperado en
este punto del plan.

- [ ] **Step 7: Commit**

```bash
git add IronPulse/Localizable.xcstrings IronPulse/Views/Exercises/ExerciseListView.swift
git commit -m "Agrega Localizable.xcstrings: traduce todo el chrome existente a en/fr"
```

---

### Task 4: Los 7 enums con `displayName`

**Files:**
- Modify: `IronPulse/Models/ProfileEnums.swift`

**Interfaces:**
- Consumes: `AppLanguage.current` (Task 1).

- [ ] **Step 1: Convertir cada `displayName` (y `Weekday.shortDisplayName`)**

Mismo patrón para los 7 enums — reemplazar cada `return "texto fijo"` por
`return String(localized: "clave.unica", defaultValue: "texto fijo", locale: AppLanguage.current.locale)`,
redactando la traducción a inglés y francés para cada caso. El contenido
completo actual de cada enum (para no perder ningún caso) está en
`IronPulse/Models/ProfileEnums.swift` — leerlo primero.

Ejemplo completo para `ExperienceLevel` (los otros 6 siguen el mismo
patrón, una clave por caso, con el prefijo del nombre del enum en
snake_case):

```swift
enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

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
}
```

Los 6 enums restantes con sus casos exactos (leer el archivo actual para
confirmar antes de escribir, esto es solo la lista de casos a cubrir):
`PrimaryGoal` (hypertrophy/strength/fatLoss), `SplitType`
(fullBody/upperLower/pushPullLegs), `BiologicalSex`
(notSet/female/male/other), `EquipmentType`
(fullGym/dumbbells/barbell/machines/cableMachine/bodyweight),
`MuscleGroup` (chest/back/legs/shoulders/arms/biceps/triceps/core/glutes/calves/fullBody),
`Weekday.displayName` (monday..sunday, nombres completos) y
`Weekday.shortDisplayName` (monday..sunday, abreviaturas de 3 letras —
en inglés/francés también deben ser 3 letras para no romper el layout de
la tira semanal del Dashboard, ej. inglés: MON/TUE/WED/THU/FRI/SAT/SUN,
francés: LUN/MAR/MER/JEU/VEN/SAM/DIM).

**No tocar** `wgerEquipmentIDs` ni `wgerMuscleIDs` (no son texto
visible, son IDs de una API externa histórica).

- [ ] **Step 2: Verificar que compila y corre la suite completa**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests
```

Esperado: `BUILD SUCCEEDED`, todos los tests en verde (ninguno depende
del texto exacto de `displayName`, pero confirma que no se rompió nada).

- [ ] **Step 3: Verificación manual en simulador**

Cambiar a inglés: abrir el picker de Nivel/Objetivo en Perfil, confirmar
que las opciones están en inglés. Cambiar a francés, confirmar lo mismo.
Confirmar que la tira semanal del Dashboard muestra abreviaturas de 3
letras en los 3 idiomas sin romper el layout de las 7 columnas.

- [ ] **Step 4: Commit**

```bash
git add IronPulse/Models/ProfileEnums.swift
git commit -m "Traduce los 7 enums con displayName a en/fr via String(localized:locale:)"
```

---

### Task 5: Esquema por idioma del catálogo de ejercicios (sin traducciones reales)

**Files:**
- Modify: `IronPulse/Models/Exercise.swift`
- Modify: `IronPulse/Services/ExerciseDatabaseSeeder.swift`
- Modify: `IronPulse/Resources/ExercisesSeed.json` (las 146 entradas, vía script)

**Interfaces:**
- Produces: `Exercise.name/.instructions/.proTip` siguen siendo `String`/`[String]`/`String?` — ahora computadas, no guardadas — ningún call site externo cambia.
- Consumes: `AppLanguage.current` (Task 1).

- [ ] **Step 1: `Exercise.swift` — campos por idioma + computadas**

Reemplazar el contenido completo del archivo:

```swift
import Foundation
import SwiftData

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

    init(
        id: String,
        nameEs: String,
        nameEn: String,
        nameFr: String,
        muscleGroup: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        equipment: EquipmentType,
        isCompound: Bool = false,
        instructionsEs: [String],
        instructionsEn: [String],
        instructionsFr: [String],
        gifFileName: String,
        gifRemoteURLString: String? = nil,
        isCustom: Bool = false,
        proTipEs: String? = nil,
        proTipEn: String? = nil,
        proTipFr: String? = nil
    ) {
        self.id = id
        self.nameEs = nameEs
        self.nameEn = nameEn
        self.nameFr = nameFr
        self.muscleGroup = muscleGroup
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructionsEs = instructionsEs
        self.instructionsEn = instructionsEn
        self.instructionsFr = instructionsFr
        self.gifFileName = gifFileName
        self.gifRemoteURLString = gifRemoteURLString
        self.isCustom = isCustom
        self.proTipEs = proTipEs
        self.proTipEn = proTipEn
        self.proTipFr = proTipFr
    }
}
```

- [ ] **Step 2: Migrar `ExercisesSeed.json` (script mecánico, sin traducir nada)**

```python
import json

with open('IronPulse/Resources/ExercisesSeed.json') as f:
    data = json.load(f)

for entry in data:
    name = entry.pop('name')
    entry['name'] = {'es': name, 'en': name, 'fr': name}

    instructions = entry.pop('instructions')
    entry['instructions'] = {'es': instructions, 'en': instructions, 'fr': instructions}

    pro_tip = entry.pop('proTip', None)
    if pro_tip is not None:
        entry['proTip'] = {'es': pro_tip, 'en': pro_tip, 'fr': pro_tip}

with open('IronPulse/Resources/ExercisesSeed.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
```

Correr este script una vez, no dejarlo como parte del build.

- [ ] **Step 3: `ExerciseDatabaseSeeder.swift` — DTO anidado**

Reemplazar el contenido completo del archivo:

```swift
import Foundation
import SwiftData

struct LocalizedString: Codable {
    let es: String
    let en: String
    let fr: String
}

struct LocalizedStringArray: Codable {
    let es: [String]
    let en: [String]
    let fr: [String]
}

struct ExerciseSeedDTO: Codable {
    let id: String
    let name: LocalizedString
    let muscleGroup: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: EquipmentType
    let isCompound: Bool
    let instructions: LocalizedStringArray
    let gifFileName: String
    let gifRemoteURLString: String?
    let proTip: LocalizedString?

    func toModel() -> Exercise {
        Exercise(
            id: id,
            nameEs: name.es,
            nameEn: name.en,
            nameFr: name.fr,
            muscleGroup: muscleGroup,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            isCompound: isCompound,
            instructionsEs: instructions.es,
            instructionsEn: instructions.en,
            instructionsFr: instructions.fr,
            gifFileName: gifFileName,
            gifRemoteURLString: gifRemoteURLString,
            isCustom: false,
            proTipEs: proTip?.es,
            proTipEn: proTip?.en,
            proTipFr: proTip?.fr
        )
    }
}

enum ExerciseDatabaseSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return }
        guard let url = Bundle.main.url(forResource: "ExercisesSeed", withExtension: "json") else {
            assertionFailure("ExercisesSeed.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let seedDTOs = try JSONDecoder().decode([ExerciseSeedDTO].self, from: data)
            seedDTOs.forEach { context.insert($0.toModel()) }
            try context.save()
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }
}
```

- [ ] **Step 4: Verificar la migracion del JSON con un script**

```bash
python3 -c "
import json
with open('IronPulse/Resources/ExercisesSeed.json') as f:
    data = json.load(f)
missing = [e['id'] for e in data if not isinstance(e.get('name'), dict) or set(e['name'].keys()) != {'es','en','fr'}]
print(f'Total ejercicios: {len(data)}')
print(f'Con esquema incorrecto: {len(missing)} {missing[:5]}')
"
```

Esperado: `Total ejercicios: 146`, `Con esquema incorrecto: 0`.

- [ ] **Step 5: Desinstalar la app del simulador antes de correr (gotcha de migracion)**

```bash
xcrun simctl uninstall booted com.BERNU.WattWeight
```

(Si no hay un simulador booteado con la app instalada, este paso no hace
nada y no falla — no bloqueante si es la primera vez que se corre en esa
sesion.)

- [ ] **Step 6: Verificar que compila y corre la suite completa**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests
```

Esperado: `BUILD SUCCEEDED`, todos los tests en verde (el test de
`WorkoutGeneratorServiceTests` que decodifica el catalogo real y verifica
`proTip` no vacio — de la tanda del rebrand — debe seguir pasando, ya que
`proTip` sigue siendo `String?` desde afuera).

- [ ] **Step 7: Verificación manual en simulador**

Abrir la lista de ejercicios, confirmar que los nombres siguen viendose
(en español, ya que en/fr son placeholders identicos). Cambiar el idioma
a ingles/frances y confirmar que los nombres de ejercicios NO cambian
todavia (esperado — son identicos al español en este punto, la
traduccion real es la spec futura) pero tampoco truena ni muestra vacio.

- [ ] **Step 8: Commit**

```bash
git add IronPulse/Models/Exercise.swift IronPulse/Services/ExerciseDatabaseSeeder.swift IronPulse/Resources/ExercisesSeed.json
git commit -m "Catalogo de ejercicios: esquema por idioma (es/en/fr), placeholders identicos al espanol"
```

---

### Task 6: Verificación completa en simulador

**Files:** ninguno (solo verificación manual + automatizada)

- [ ] **Step 1: Suite de tests completo**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests
```

Esperado: todos los tests en verde (suite existente + los 5 nuevos de
`AppLanguageTests`).

- [ ] **Step 2: Recorrido visual completo, en los 3 idiomas**

Para cada uno de los 3 idiomas (Español/English/Français), cambiar el
picker en Ajustes y navegar las 4 tabs completas (Dashboard, Rutina,
Ejercicios, Perfil) más el detalle de un ejercicio y una sesión activa.
Confirmar:
- El chrome (títulos, botones, mensajes de estado vacío, tabs) cambia en
  vivo sin reiniciar la app.
- Los 7 enums (Nivel, Objetivo, Sexo, grupos musculares, equipamiento,
  días de la semana) muestran el idioma correcto.
- La tira semanal del Dashboard no rompe su layout con las abreviaturas
  de 3 letras en inglés/francés.
- Los nombres de ejercicios se ven bien (aunque sean iguales al español
  en inglés/francés — eso es esperado en este plan).
- Ningún botón/NavigationLink queda sin responder al toque (regresión
  conocida de sesiones anteriores con `Chart` en `DashboardView` — no
  debería aplicar aca ya que este plan no toca ningun `Chart`, pero
  confirmar igual como red de seguridad).

- [ ] **Step 3: Actualizar `PROGRESS.md`**

Documentar esta tanda (infraestructura i18n + chrome): qué se hizo, la
decisión de dejar los 3 mensajes de permiso (`NSHealthShareUsageDescription`,
etc.) sin traducir por ahora, y mover el pendiente correspondiente de
"Siguientes pasos" a completado — dejando claro que la traducción real
del catálogo de ejercicios (146 × 3 campos a inglés/francés) sigue siendo
un pendiente separado, con su propia spec futura.

- [ ] **Step 4: Commit**

```bash
git add PROGRESS.md
git commit -m "Documenta la infraestructura i18n + chrome en PROGRESS.md"
```
