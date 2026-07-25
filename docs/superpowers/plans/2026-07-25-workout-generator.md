# Fase 3 — Generador de rutinas: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el placeholder del Dashboard con dos flujos reales de creación de rutinas: una generada por heurística local ("Rutina inteligente") y un armador manual desde cero.

**Architecture:** `WorkoutGeneratorService` es un `enum` sin estado con métodos `static` puros — recibe el catálogo ya cargado y devuelve un árbol `WorkoutRoutine → RoutineDay → RoutineExercise` sin tocar el `ModelContext`, lo que lo hace testeable sin `ModelContainer`. La persistencia vive en un único helper compartido (`UserProfile.activate(_:in:)`) que usan los dos flujos, así no hay dos implementaciones de "activar rutina".

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing (`import Testing`), Xcode project con file-system-synchronized groups (los archivos nuevos se toman automáticamente, no hay que editar `project.pbxproj`).

## Global Constraints

- **Idioma del código y la UI:** todo el texto visible al usuario va en español, sin acentos en los identificadores Swift (el proyecto ya sigue esta convención: `"Perdida de grasa"`, `"Biceps"`).
- **Prohibido usar la palabra "IA"** en cualquier texto visible: el generador es heurística determinista. Nombre de rutina generada: exactamente `"Rutina personalizada - \(profile.primaryGoal.displayName)"`.
- **Sin dependencias externas:** 0 paquetes de terceros, solo frameworks de Apple.
- **Tema:** usar los tokens existentes de `Theme/CustomColor.swift` (`Color.ironBackground`, `Color.ironCard`, `Color.ironAccent`, `Color.ironTextSecondary`, `.ironCard()`, `PrimarySportButtonStyle`). Nunca colores hardcodeados.
- **`Color` explícito en `foregroundStyle`:** escribir `.foregroundStyle(Color.ironTextSecondary)`, no `.foregroundStyle(.ironTextSecondary)` — la forma corta no compila contra `ShapeStyle` (ya se corrigió una vez en este proyecto).
- **`preferredEquipment` NO se usa** en esta fase — el catálogo completo está disponible para ambos flujos.
- **Migración de SwiftData:** al agregar `isCompound` (propiedad no-opcional nueva), hay que **borrar la app del simulador** antes de correr. No se implementa `VersionedSchema`.
- **Build de verificación:**
  ```bash
  xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
  ```
  Correr desde `/Users/diego/Documents/IRONPULSE/IronPulse`.
- **Tests:**
  ```bash
  xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Case|error:|TEST" | sort -u
  ```

---

### Task 1: Agregar `isCompound` al modelo y al catálogo

Sin este campo el generador no puede ordenar "compuestos primero". Es un cambio de datos + modelo, sin lógica de negocio, por eso va primero y solo.

**Files:**
- Modify: `IronPulse/Models/Exercise.swift`
- Modify: `IronPulse/Services/ExerciseDatabaseSeeder.swift:4-27`
- Modify: `IronPulse/Resources/ExercisesSeed.json` (150 registros)

**Interfaces:**
- Consumes: nada (primera tarea).
- Produces: `Exercise.isCompound: Bool` (propiedad almacenada, no-opcional, con default `false` en el init). Todas las tareas siguientes leen esta propiedad.

- [ ] **Step 1: Agregar la propiedad al modelo**

En `IronPulse/Models/Exercise.swift`, agregar la propiedad después de `var equipment: EquipmentType`:

```swift
    var isCompound: Bool
```

Y en el `init`, agregar el parámetro después de `equipment: EquipmentType,`:

```swift
        isCompound: Bool = false,
```

Y la asignación en el cuerpo del init, después de `self.equipment = equipment`:

```swift
        self.isCompound = isCompound
```

- [ ] **Step 2: Clasificar los 150 ejercicios del JSON**

Correr este script desde `/Users/diego/Documents/IRONPULSE/IronPulse`. Ya fue probado en seco contra el catálogo real: produce 74 compuestos / 76 aislamiento.

```bash
python3 -c "
import json, unicodedata

def strip_accents(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

COMPOUND_KEYWORDS = ['press', 'sentadilla', 'peso muerto', 'dominada', 'remo', 'fondos', 'zancada', 'jalon', 'empuje', 'flexion', 'step-up']

# Movimientos multi-articulares que ningun keyword simple captura sin falsos positivos.
# Ej: 'prensa' matchearia tambien 'Elevacion de talones en prensa de piernas', que es aislamiento.
MANUAL_COMPOUND_OVERRIDES = {
    'ex_050_prensa_de_piernas_45_grados',
    'ex_069_puente_de_gluteos_con_barra',
    'ex_070_puente_de_gluteos_a_una_pierna',
    'ex_074_elevacion_de_cadera_en_maquina_smith',
}

path = 'IronPulse/Resources/ExercisesSeed.json'
with open(path) as f:
    data = json.load(f)

for ex in data:
    name = strip_accents(ex['name'].lower())
    ex['isCompound'] = any(kw in name for kw in COMPOUND_KEYWORDS) or ex['id'] in MANUAL_COMPOUND_OVERRIDES

with open(path, 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')

compound = sum(1 for ex in data if ex['isCompound'])
print(f'Total: {len(data)}, compound: {compound}, isolation: {len(data) - compound}')
"
```

Esperado: `Total: 150, compound: 74, isolation: 76`

- [ ] **Step 3: Verificar la clasificación con casos conocidos**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse/IronPulse/Resources
jq '[.[] | select(.isCompound == null)] | length' ExercisesSeed.json
jq '.[] | select(.id=="ex_001_press_plano_barra") | .isCompound' ExercisesSeed.json
jq '.[] | select(.id=="ex_098_curl_barra_recta") | .isCompound' ExercisesSeed.json
jq '.[] | select(.id=="ex_050_prensa_de_piernas_45_grados") | .isCompound' ExercisesSeed.json
```

Esperado, en orden: `0` (ningún registro sin el campo), `true` (press plano es compuesto), `false` (curl de bíceps es aislamiento), `true` (override manual aplicado).

- [ ] **Step 4: Decodificar el campo nuevo en el seeder**

En `IronPulse/Services/ExerciseDatabaseSeeder.swift`, agregar a `ExerciseSeedDTO` después de `let equipment: EquipmentType`:

```swift
    let isCompound: Bool
```

Y en `toModel()`, pasar el valor después de `equipment: equipment,`:

```swift
            isCompound: isCompound,
```

- [ ] **Step 5: Build y verificar en simulador con store limpio**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`

Después, borrar la app del simulador (el campo nuevo rompe el store viejo) y reinstalar:

```bash
D=B93C823F-AAD5-46AF-B830-8A8390325C5F
xcrun simctl uninstall $D com.BERNU.IronPulse
APP=~/Library/Developer/Xcode/DerivedData/IronPulse-ajoavrdotvzltcgjcbvamxupnuzu/Build/Products/Debug-iphonesimulator/IronPulse.app
xcrun simctl install $D "$APP" && xcrun simctl launch $D com.BERNU.IronPulse
```

Verificar que el seeder corrió con el campo nuevo:

```bash
D=B93C823F-AAD5-46AF-B830-8A8390325C5F
sleep 3
DB=$(find ~/Library/Developer/CoreSimulator/Devices/$D/data/Containers/Data/Application -name "default.store" 2>/dev/null | head -1)
sqlite3 "$DB" "select count(*) from ZEXERCISE;"
sqlite3 "$DB" "select count(*) from ZEXERCISE where ZISCOMPOUND = 1;"
```
Esperado: `150` y `74`.

- [ ] **Step 6: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Models/Exercise.swift IronPulse/Services/ExerciseDatabaseSeeder.swift IronPulse/Resources/ExercisesSeed.json
git commit -m "Agrega Exercise.isCompound y clasifica los 150 ejercicios del catalogo"
```

---

### Task 2: `WorkoutGeneratorService` — split y estructura de días

Primera mitad del generador: decide el split y cuántos días, sin seleccionar ejercicios todavía. Se puede testear y revisar por separado de la lógica de selección.

**Files:**
- Create: `IronPulse/Services/WorkoutGeneratorService.swift`
- Create: `IronPulseTests/WorkoutGeneratorServiceTests.swift`

**Interfaces:**
- Consumes: `Exercise.isCompound` (Task 1); modelos existentes `UserProfile`, `WorkoutRoutine`, `RoutineDay`, `SplitType`, `MuscleGroup`, `ExperienceLevel`, `PrimaryGoal`.
- Produces:
  - `WorkoutGeneratorService.splitType(for daysPerWeek: Int) -> SplitType`
  - `WorkoutGeneratorService.DayTemplate` (struct interno con `title: String` y `muscleGroups: [MuscleGroup]`)
  - `WorkoutGeneratorService.dayTemplates(split: SplitType, dayCount: Int) -> [DayTemplate]`

- [ ] **Step 1: Escribir los tests que fallan**

Crear `IronPulseTests/WorkoutGeneratorServiceTests.swift`:

```swift
import Testing
@testable import IronPulse

struct WorkoutGeneratorServiceTests {

    @Test func splitEsFullBodyHastaDosDias() {
        #expect(WorkoutGeneratorService.splitType(for: 1) == .fullBody)
        #expect(WorkoutGeneratorService.splitType(for: 2) == .fullBody)
    }

    @Test func splitEsUpperLowerConTresOCuatroDias() {
        #expect(WorkoutGeneratorService.splitType(for: 3) == .upperLower)
        #expect(WorkoutGeneratorService.splitType(for: 4) == .upperLower)
    }

    @Test func splitEsPushPullLegsConCincoOMas() {
        #expect(WorkoutGeneratorService.splitType(for: 5) == .pushPullLegs)
        #expect(WorkoutGeneratorService.splitType(for: 7) == .pushPullLegs)
    }

    @Test func upperLowerAlternaTorsoYPierna() {
        let templates = WorkoutGeneratorService.dayTemplates(split: .upperLower, dayCount: 4)
        #expect(templates.map(\.title) == ["Torso", "Pierna", "Torso", "Pierna"])
    }

    @Test func pushPullLegsCiclaLosTresDias() {
        let templates = WorkoutGeneratorService.dayTemplates(split: .pushPullLegs, dayCount: 5)
        #expect(templates.map(\.title) == ["Empuje", "Tiron", "Piernas", "Empuje", "Tiron"])
    }

    @Test func fullBodyRepiteElMismoDia() {
        let templates = WorkoutGeneratorService.dayTemplates(split: .fullBody, dayCount: 2)
        #expect(templates.map(\.title) == ["Cuerpo completo", "Cuerpo completo"])
    }
}
```

- [ ] **Step 2: Correr los tests para verificar que fallan**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|cannot find" | sort -u
```
Esperado: FALLA con `cannot find 'WorkoutGeneratorService' in scope`.

- [ ] **Step 3: Implementar split y templates de día**

Crear `IronPulse/Services/WorkoutGeneratorService.swift`:

```swift
import Foundation

enum WorkoutGeneratorService {

    struct DayTemplate {
        let title: String
        let muscleGroups: [MuscleGroup]
    }

    static func splitType(for daysPerWeek: Int) -> SplitType {
        switch daysPerWeek {
        case ...2: return .fullBody
        case 3...4: return .upperLower
        default: return .pushPullLegs
        }
    }

    static func dayTemplates(split: SplitType, dayCount: Int) -> [DayTemplate] {
        let cycle: [DayTemplate]
        switch split {
        case .fullBody:
            cycle = [
                DayTemplate(title: "Cuerpo completo",
                            muscleGroups: [.chest, .back, .legs, .shoulders, .biceps, .triceps, .core])
            ]
        case .upperLower:
            cycle = [
                DayTemplate(title: "Torso",
                            muscleGroups: [.chest, .back, .shoulders, .biceps, .triceps]),
                DayTemplate(title: "Pierna",
                            muscleGroups: [.legs, .glutes, .core])
            ]
        case .pushPullLegs:
            cycle = [
                DayTemplate(title: "Empuje", muscleGroups: [.chest, .shoulders, .triceps]),
                DayTemplate(title: "Tiron", muscleGroups: [.back, .biceps]),
                DayTemplate(title: "Piernas", muscleGroups: [.legs, .glutes, .core])
            ]
        }

        return (0..<max(1, dayCount)).map { cycle[$0 % cycle.count] }
    }
}
```

- [ ] **Step 4: Correr los tests para verificar que pasan**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Case.*(passed|failed)|TEST" | sort -u
```
Esperado: los 6 tests pasan, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Services/WorkoutGeneratorService.swift IronPulseTests/WorkoutGeneratorServiceTests.swift
git commit -m "Agrega WorkoutGeneratorService con seleccion de split y templates de dia"
```

---

### Task 3: `WorkoutGeneratorService` — prescripción y selección de ejercicios

Segunda mitad: cuántas series/reps/descanso según objetivo, y qué ejercicios entran en cada día.

**Files:**
- Modify: `IronPulse/Services/WorkoutGeneratorService.swift`
- Modify: `IronPulseTests/WorkoutGeneratorServiceTests.swift`

**Interfaces:**
- Consumes: `splitType(for:)`, `dayTemplates(split:dayCount:)`, `DayTemplate` (Task 2); `Exercise.isCompound` (Task 1).
- Produces:
  - `WorkoutGeneratorService.Prescription` (struct con `sets: Int`, `repsMin: Int`, `repsMax: Int`, `restSeconds: Int`)
  - `WorkoutGeneratorService.prescription(goal: PrimaryGoal, level: ExperienceLevel) -> Prescription`
  - `WorkoutGeneratorService.exercisesPerDay(for level: ExperienceLevel) -> Int`
  - `WorkoutGeneratorService.generateRoutine(for profile: UserProfile, catalog: [Exercise]) -> WorkoutRoutine`

- [ ] **Step 1: Escribir los tests que fallan**

Agregar a `IronPulseTests/WorkoutGeneratorServiceTests.swift`, dentro del `struct WorkoutGeneratorServiceTests`, después del último `@Test`. El helper `makeCatalog()` crea un catálogo sintético — no toca SwiftData porque `Exercise` se puede instanciar directamente:

```swift
    // MARK: - Helpers

    private func makeExercise(
        _ id: String,
        _ name: String,
        _ group: MuscleGroup,
        compound: Bool
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: group,
            equipment: .barbell,
            instructions: ["Paso uno."],
            gifFileName: "\(id).gif",
            isCompound: compound
        )
    }

    private func makeCatalog() -> [Exercise] {
        [
            makeExercise("c1", "Press plano", .chest, compound: true),
            makeExercise("c2", "Press inclinado", .chest, compound: true),
            makeExercise("c3", "Aperturas", .chest, compound: false),
            makeExercise("b1", "Remo con barra", .back, compound: true),
            makeExercise("b2", "Jalon al pecho", .back, compound: true),
            makeExercise("b3", "Pullover", .back, compound: false),
            makeExercise("l1", "Sentadilla", .legs, compound: true),
            makeExercise("l2", "Prensa", .legs, compound: true),
            makeExercise("l3", "Extension de piernas", .legs, compound: false),
            makeExercise("s1", "Press militar", .shoulders, compound: true),
            makeExercise("s2", "Elevaciones laterales", .shoulders, compound: false),
            makeExercise("bi1", "Curl con barra", .biceps, compound: false),
            makeExercise("tr1", "Extension de triceps", .triceps, compound: false),
            makeExercise("g1", "Puente de gluteos", .glutes, compound: true),
            makeExercise("co1", "Plancha", .core, compound: false),
            makeExercise("co2", "Crunch", .core, compound: false)
        ]
    }

    private func makeProfile(
        level: ExperienceLevel = .intermediate,
        goal: PrimaryGoal = .hypertrophy,
        days: Int = 4
    ) -> UserProfile {
        UserProfile(
            name: "Test",
            age: 30,
            weightKg: 70,
            heightCm: 170,
            experienceLevel: level,
            primaryGoal: goal,
            workoutDaysPerWeek: days
        )
    }

    // MARK: - Prescripcion

    @Test func fuerzaUsaSeriesAltasYRepsBajas() {
        let p = WorkoutGeneratorService.prescription(goal: .strength, level: .intermediate)
        #expect(p.sets == 4)
        #expect(p.repsMin == 3)
        #expect(p.repsMax == 6)
        #expect(p.restSeconds == 150)
    }

    @Test func fuerzaAvanzadoSumaUnaSerie() {
        let p = WorkoutGeneratorService.prescription(goal: .strength, level: .advanced)
        #expect(p.sets == 5)
    }

    @Test func hipertrofiaUsaRango8a12() {
        let p = WorkoutGeneratorService.prescription(goal: .hypertrophy, level: .beginner)
        #expect(p.repsMin == 8)
        #expect(p.repsMax == 12)
        #expect(p.restSeconds == 75)
    }

    @Test func perdidaDeGrasaUsaRepsAltasYDescansoCorto() {
        let p = WorkoutGeneratorService.prescription(goal: .fatLoss, level: .intermediate)
        #expect(p.sets == 3)
        #expect(p.repsMin == 12)
        #expect(p.repsMax == 15)
        #expect(p.restSeconds == 40)
    }

    // MARK: - Generacion completa

    @Test func generaUnDiaPorCadaDiaDeEntrenamiento() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(days: 4), catalog: makeCatalog()
        )
        #expect(routine.days.count == 4)
        #expect(routine.splitType == .upperLower)
    }

    @Test func cantidadDeEjerciciosPorDiaSegunNivel() {
        let catalog = makeCatalog()
        let principiante = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .beginner), catalog: catalog
        )
        let avanzado = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced), catalog: catalog
        )
        #expect(principiante.days[0].exercises.count == 4)
        #expect(avanzado.days[0].exercises.count == 6)
    }

    @Test func noRepiteEjerciciosDentroDelMismoDia() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced), catalog: makeCatalog()
        )
        for day in routine.days {
            let ids = day.exercises.map(\.exercise.id)
            #expect(ids.count == Set(ids).count)
        }
    }

    @Test func losCompuestosVanAntesQueLosDeAislamiento() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced, days: 3), catalog: makeCatalog()
        )
        for day in routine.days {
            let ordenados = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
            // Ignorando core (que siempre va al final), ningun aislamiento precede a un compuesto.
            let sinCore = ordenados.filter { $0.exercise.muscleGroup != .core }
            if let primerAislamiento = sinCore.firstIndex(where: { !$0.exercise.isCompound }) {
                let despues = sinCore[primerAislamiento...]
                #expect(despues.allSatisfy { !$0.exercise.isCompound })
            }
        }
    }

    @Test func elCoreVaAlFinalDelDia() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced, days: 3), catalog: makeCatalog()
        )
        for day in routine.days {
            let ordenados = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
            if let primerCore = ordenados.firstIndex(where: { $0.exercise.muscleGroup == .core }) {
                let despues = ordenados[primerCore...]
                #expect(despues.allSatisfy { $0.exercise.muscleGroup == .core })
            }
        }
    }

    @Test func laPrescripcionDelObjetivoSeAplicaACadaEjercicio() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(goal: .fatLoss), catalog: makeCatalog()
        )
        let todos = routine.days.flatMap(\.exercises)
        #expect(!todos.isEmpty)
        #expect(todos.allSatisfy { $0.targetSets == 3 && $0.targetRepsMin == 12 && $0.restSeconds == 40 })
    }

    @Test func elNombreDeLaRutinaNoMencionaIA() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(goal: .strength), catalog: makeCatalog()
        )
        #expect(routine.name == "Rutina personalizada - Fuerza")
        #expect(!routine.name.contains("IA"))
    }

    @Test func catalogoVacioDevuelveRutinaSinEjercicios() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(), catalog: []
        )
        #expect(routine.days.count == 4)
        #expect(routine.days.allSatisfy { $0.exercises.isEmpty })
    }
```

- [ ] **Step 2: Correr los tests para verificar que fallan**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|cannot find" | sort -u
```
Esperado: FALLA con `type 'WorkoutGeneratorService' has no member 'prescription'`.

- [ ] **Step 3: Implementar prescripción y generación**

Agregar dentro del `enum WorkoutGeneratorService` en `IronPulse/Services/WorkoutGeneratorService.swift`, después de `dayTemplates(split:dayCount:)`:

```swift
    struct Prescription {
        let sets: Int
        let repsMin: Int
        let repsMax: Int
        let restSeconds: Int
    }

    static func prescription(goal: PrimaryGoal, level: ExperienceLevel) -> Prescription {
        switch goal {
        case .strength:
            return Prescription(sets: level == .advanced ? 5 : 4, repsMin: 3, repsMax: 6, restSeconds: 150)
        case .hypertrophy:
            return Prescription(sets: level == .beginner ? 3 : 4, repsMin: 8, repsMax: 12, restSeconds: 75)
        case .fatLoss:
            return Prescription(sets: 3, repsMin: 12, repsMax: 15, restSeconds: 40)
        }
    }

    static func exercisesPerDay(for level: ExperienceLevel) -> Int {
        switch level {
        case .beginner: return 4
        case .intermediate: return 5
        case .advanced: return 6
        }
    }

    static func generateRoutine(for profile: UserProfile, catalog: [Exercise]) -> WorkoutRoutine {
        let split = splitType(for: profile.workoutDaysPerWeek)
        let templates = dayTemplates(split: split, dayCount: profile.workoutDaysPerWeek)
        let plan = prescription(goal: profile.primaryGoal, level: profile.experienceLevel)
        let perDay = exercisesPerDay(for: profile.experienceLevel)

        let routine = WorkoutRoutine(
            name: "Rutina personalizada - \(profile.primaryGoal.displayName)",
            splitType: split,
            isGeneratedByAI: false,
            isActive: true
        )

        for (index, template) in templates.enumerated() {
            let picked = selectExercises(for: template, from: catalog, limit: perDay)
            let day = RoutineDay(dayNumber: index + 1, title: template.title)

            // Solo se asigna el lado "coleccion" de cada relacion: SwiftData completa
            // el inverso (RoutineExercise.day, RoutineDay.routine) al insertar.
            // Setear ambos lados a mano puede duplicar entradas.
            day.exercises = picked.enumerated().map { position, exercise in
                RoutineExercise(
                    exercise: exercise,
                    targetSets: plan.sets,
                    targetRepsMin: plan.repsMin,
                    targetRepsMax: plan.repsMax,
                    restSeconds: plan.restSeconds,
                    orderIndex: position
                )
            }

            routine.days.append(day)
        }

        return routine
    }

    /// Compuestos primero, aislamiento despues, y todo el core al final del dia
    /// sin importar si el movimiento es compuesto.
    private static func selectExercises(
        for template: DayTemplate,
        from catalog: [Exercise],
        limit: Int
    ) -> [Exercise] {
        let candidates = catalog.filter { template.muscleGroups.contains($0.muscleGroup) }

        let compounds = candidates.filter { $0.isCompound && $0.muscleGroup != .core }.shuffled()
        let isolation = candidates.filter { !$0.isCompound && $0.muscleGroup != .core }.shuffled()
        let core = candidates.filter { $0.muscleGroup == .core }.shuffled()

        return Array((compounds + isolation + core).prefix(limit))
    }
```

- [ ] **Step 4: Correr los tests para verificar que pasan**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Case.*(passed|failed)|TEST" | sort -u
```
Esperado: los 18 tests pasan, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Services/WorkoutGeneratorService.swift IronPulseTests/WorkoutGeneratorServiceTests.swift
git commit -m "Agrega generacion de rutina con prescripcion por objetivo y seleccion de ejercicios"
```

---

### Task 4: Helper de activación + botón "Rutina inteligente" en el Dashboard

Conecta el generador a la UI. Al terminar esta tarea el flujo generado funciona de punta a punta.

**Files:**
- Modify: `IronPulse/Models/UserProfile.swift`
- Modify: `IronPulse/Views/Workouts/DashboardView.swift:13-20`

**Interfaces:**
- Consumes: `WorkoutGeneratorService.generateRoutine(for:catalog:)` (Task 3).
- Produces: `UserProfile.activate(_ routine: WorkoutRoutine, in context: ModelContext)` — el armador manual (Task 5) usa este mismo método.

- [ ] **Step 1: Agregar el helper de activación**

Al final de `IronPulse/Models/UserProfile.swift`, fuera de la clase:

```swift
extension UserProfile {
    /// Unico punto de activacion de rutinas: lo usan tanto el generador como el armador manual.
    /// Las rutinas viejas quedan con isActive = false a modo de historial, no se borran.
    func activate(_ routine: WorkoutRoutine, in context: ModelContext) {
        for existing in routines {
            existing.isActive = false
        }
        routine.isActive = true
        routine.profile = self
        context.insert(routine)
        try? context.save()
    }
}
```

- [ ] **Step 2: Agregar el estado y el catálogo a `DashboardView`**

En `IronPulse/Views/Workouts/DashboardView.swift`, reemplazar las líneas 4-6 (la declaración del struct y sus propiedades) por:

```swift
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var catalog: [Exercise]
    @Bindable var profile: UserProfile
    let healthImporter: HealthKitProfileImporter
```

- [ ] **Step 3: Reemplazar el placeholder por los dos botones**

En el mismo archivo, reemplazar el bloque `if let active = profile.activeRoutine { ... } else { ... }` (líneas 13-17 originales) por:

```swift
                if let active = profile.activeRoutine {
                    RoutineCard(routine: active)
                } else {
                    ContentUnavailableView(
                        "Sin rutina activa",
                        systemImage: "bolt.slash",
                        description: Text("Genera una rutina automatica o arma la tuya ejercicio por ejercicio.")
                    )
                }

                VStack(spacing: 12) {
                    Button("Rutina inteligente", action: generateRoutine)
                        .buttonStyle(PrimarySportButtonStyle())

                    NavigationLink {
                        RoutineBuilderView(profile: profile)
                    } label: {
                        Text("Crear rutina manual")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.ironAccent)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.ironAccent, lineWidth: 1.5)
                            }
                    }
                }
```

- [ ] **Step 4: Agregar el método de generación**

En el mismo archivo, agregar dentro de `struct DashboardView`, justo antes de `private var header: some View`:

```swift
    private func generateRoutine() {
        let routine = WorkoutGeneratorService.generateRoutine(for: profile, catalog: catalog)
        profile.activate(routine, in: modelContext)
    }
```

- [ ] **Step 5: Build**

`RoutineBuilderView` todavía no existe, así que este build **debe fallar** con ese error específico y ningún otro:

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:" | sort -u
```
Esperado: exactamente un error, `cannot find 'RoutineBuilderView' in scope`. Si aparece cualquier otro error, arreglarlo antes de seguir.

- [ ] **Step 6: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Models/UserProfile.swift IronPulse/Views/Workouts/DashboardView.swift
git commit -m "Agrega helper de activacion de rutinas y boton de rutina inteligente"
```

---

### Task 5: `ExercisePickerSheet` y `RoutineBuilderView`

El armador manual. Los dos archivos van juntos porque el picker no tiene ningún consumidor hasta que existe el builder — separarlos daría una tarea que no compila sola.

**Files:**
- Create: `IronPulse/Views/Exercises/ExercisePickerSheet.swift`
- Create: `IronPulse/Views/Workouts/RoutineBuilderView.swift`

**Interfaces:**
- Consumes: `WorkoutGeneratorService.splitType(for:)`, `.dayTemplates(split:dayCount:)`, `.prescription(goal:level:)`, `.Prescription` (Tasks 2-3); `UserProfile.activate(_:in:)` (Task 4).
- Produces: `RoutineBuilderView(profile: UserProfile)` — ya referenciado por `DashboardView` en Task 4.

- [ ] **Step 1: Crear `ExercisePickerSheet`**

Crear `IronPulse/Views/Exercises/ExercisePickerSheet.swift`. Es tap-to-select, a diferencia de `ExerciseListView` que es tap-to-detalle:

```swift
import SwiftUI
import SwiftData

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText: String = ""

    /// Ids ya agregados al dia: se muestran deshabilitados para no duplicar.
    let excludedIDs: Set<String>
    let onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return exercises }
        let term = searchText.lowercased()
        return exercises.filter { $0.name.lowercased().contains(term) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { exercise in
                let yaAgregado = excludedIDs.contains(exercise.id)

                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        GIFImageView(
                            localName: exercise.gifFileName,
                            remoteURL: exercise.gifRemoteURLString.flatMap(URL.init(string:)),
                            contentMode: .fill
                        )
                        .frame(width: 56, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.muscleGroup.displayName) • \(exercise.equipment.displayName)")
                                .font(.caption)
                                .foregroundStyle(Color.ironTextSecondary)
                        }

                        Spacer()

                        if yaAgregado {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.ironAccent)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .disabled(yaAgregado)
                .listRowBackground(Color.ironCard)
            }
            .scrollContentBackground(.hidden)
            .background(Color.ironBackground)
            .navigationTitle("Elegir ejercicio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .tint(Color.ironAccent)
    }
}
```

- [ ] **Step 2: Crear `RoutineBuilderView`**

Crear `IronPulse/Views/Workouts/RoutineBuilderView.swift`. Los "drafts" son structs en memoria: el árbol de SwiftData recién se construye al guardar, así que cancelar no deja basura en el store:

```swift
import SwiftUI
import SwiftData

struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile

    @State private var splitType: SplitType
    @State private var dayCount: Int
    @State private var draftDays: [DraftDay]
    @State private var pickerTarget: Int?

    init(profile: UserProfile) {
        self.profile = profile
        let split = WorkoutGeneratorService.splitType(for: profile.workoutDaysPerWeek)
        _splitType = State(initialValue: split)
        _dayCount = State(initialValue: profile.workoutDaysPerWeek)
        _draftDays = State(initialValue: Self.emptyDays(split: split, count: profile.workoutDaysPerWeek))
    }

    struct DraftDay: Identifiable {
        let id = UUID()
        var title: String
        var items: [DraftItem] = []
    }

    struct DraftItem: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var sets: Int
        var repsMin: Int
        var repsMax: Int
        var restSeconds: Int
    }

    private static func emptyDays(split: SplitType, count: Int) -> [DraftDay] {
        WorkoutGeneratorService.dayTemplates(split: split, dayCount: count)
            .map { DraftDay(title: $0.title) }
    }

    private var totalExercises: Int {
        draftDays.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        Form {
            Section("Estructura") {
                Picker("Split", selection: $splitType) {
                    ForEach(SplitType.allCases) { split in
                        Text(split.displayName).tag(split)
                    }
                }
                Stepper("\(dayCount) dias por semana", value: $dayCount, in: 1...7)
            }
            .listRowBackground(Color.ironCard)

            ForEach(Array(draftDays.enumerated()), id: \.element.id) { dayIndex, day in
                Section("Dia \(dayIndex + 1) — \(day.title)") {
                    ForEach(Array(day.items.enumerated()), id: \.element.id) { itemIndex, item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.exercise.name).font(.headline)

                            Stepper(
                                "\(item.sets) series",
                                value: $draftDays[dayIndex].items[itemIndex].sets,
                                in: 1...10
                            )
                            Stepper(
                                "Minimo \(item.repsMin) reps",
                                value: $draftDays[dayIndex].items[itemIndex].repsMin,
                                in: 1...item.repsMax
                            )
                            Stepper(
                                "Maximo \(item.repsMax) reps",
                                value: $draftDays[dayIndex].items[itemIndex].repsMax,
                                in: item.repsMin...30
                            )
                            Stepper(
                                "\(item.restSeconds)s de descanso",
                                value: $draftDays[dayIndex].items[itemIndex].restSeconds,
                                in: 15...300,
                                step: 15
                            )
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        draftDays[dayIndex].items.remove(atOffsets: offsets)
                    }

                    Button("Agregar ejercicio") { pickerTarget = dayIndex }
                        .foregroundStyle(Color.ironAccent)
                }
                .listRowBackground(Color.ironCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Rutina manual")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", action: save).disabled(totalExercises == 0)
            }
        }
        .onChange(of: splitType) { _, nuevo in
            draftDays = Self.emptyDays(split: nuevo, count: dayCount)
        }
        .onChange(of: dayCount) { _, nuevo in
            draftDays = Self.emptyDays(split: splitType, count: nuevo)
        }
        .sheet(item: Binding(
            get: { pickerTarget.map { PickerTarget(dayIndex: $0) } },
            set: { pickerTarget = $0?.dayIndex }
        )) { target in
            ExercisePickerSheet(
                excludedIDs: Set(draftDays[target.dayIndex].items.map(\.exercise.id))
            ) { exercise in
                addExercise(exercise, toDay: target.dayIndex)
            }
        }
    }

    private struct PickerTarget: Identifiable {
        let dayIndex: Int
        var id: Int { dayIndex }
    }

    private func addExercise(_ exercise: Exercise, toDay dayIndex: Int) {
        let plan = WorkoutGeneratorService.prescription(
            goal: profile.primaryGoal,
            level: profile.experienceLevel
        )
        draftDays[dayIndex].items.append(
            DraftItem(
                exercise: exercise,
                sets: plan.sets,
                repsMin: plan.repsMin,
                repsMax: plan.repsMax,
                restSeconds: plan.restSeconds
            )
        )
    }

    private func save() {
        let routine = WorkoutRoutine(
            name: "Rutina manual - \(profile.name)",
            splitType: splitType,
            isGeneratedByAI: false,
            isActive: true
        )

        // Igual que en WorkoutGeneratorService: solo el lado "coleccion",
        // SwiftData completa el inverso al insertar.
        for (index, draft) in draftDays.enumerated() where !draft.items.isEmpty {
            let day = RoutineDay(dayNumber: index + 1, title: draft.title)
            day.exercises = draft.items.enumerated().map { position, item in
                RoutineExercise(
                    exercise: item.exercise,
                    targetSets: item.sets,
                    targetRepsMin: item.repsMin,
                    targetRepsMax: item.repsMax,
                    restSeconds: item.restSeconds,
                    orderIndex: position
                )
            }
            routine.days.append(day)
        }

        profile.activate(routine, in: modelContext)
        dismiss()
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`, sin errores.

- [ ] **Step 4: Correr los tests de regresión**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Case.*(passed|failed)|TEST" | sort -u
```
Esperado: los 18 tests siguen pasando, `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Views/Exercises/ExercisePickerSheet.swift IronPulse/Views/Workouts/RoutineBuilderView.swift
git commit -m "Agrega armador manual de rutinas con selector de ejercicios"
```

---

### Task 6: Verificación en simulador y cierre

El proyecto tiene el criterio de que las vistas se verifican corriendo la app, no solo compilando. Esta tarea existe porque los bugs de las sesiones anteriores (botones muertos, vistas huérfanas) compilaban perfecto.

**Files:**
- Modify: `IronPulse/PROGRESS.md`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: nada de código.

- [ ] **Step 1: Instalar la app con store limpio**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
D=B93C823F-AAD5-46AF-B830-8A8390325C5F
xcrun simctl terminate $D com.BERNU.IronPulse 2>/dev/null
xcrun simctl uninstall $D com.BERNU.IronPulse
APP=~/Library/Developer/Xcode/DerivedData/IronPulse-ajoavrdotvzltcgjcbvamxupnuzu/Build/Products/Debug-iphonesimulator/IronPulse.app
xcrun simctl install $D "$APP" && xcrun simctl launch $D com.BERNU.IronPulse
```

- [ ] **Step 2: Verificar el flujo de rutina inteligente**

Con `mcp__Claude_Code_iOS_Simulator__control` (`attach`, después `tap`/`screenshot`):

1. Crear un perfil con el botón "+".
2. Tocar el perfil para entrar al Dashboard.
3. Tocar "Rutina inteligente".
4. **Verificar en el screenshot:** aparece una `RoutineCard` con el nombre `"Rutina personalizada - Hipertrofia"`, 3 días (el default de `workoutDaysPerWeek`), y cada día lista ejercicios reales con formato `NxM-M`.
5. Tocar "Rutina inteligente" otra vez y confirmar que la tarjeta se reemplaza por una rutina nueva (no se duplica ni se acumulan dos tarjetas).

- [ ] **Step 3: Verificar el flujo manual**

1. Tocar "Crear rutina manual".
2. **Verificar:** el Picker de split viene preseleccionado en "Torso / Pierna" y el stepper en 3 días; hay 3 secciones de día tituladas Torso/Pierna/Torso.
3. Tocar "Agregar ejercicio" en el Día 1 → se abre la hoja con el buscador.
4. Buscar "press" y tocar un resultado → la hoja se cierra y el ejercicio aparece en el Día 1 con sus steppers.
5. Volver a abrir el picker en el Día 1 y **verificar que el ejercicio ya agregado aparece deshabilitado con un check verde**.
6. Agregar un segundo ejercicio, tocar "Guardar".
7. **Verificar:** vuelve al Dashboard y la `RoutineCard` muestra `"Rutina manual - <nombre del perfil>"` con los ejercicios elegidos.

- [ ] **Step 4: Actualizar `PROGRESS.md`**

En `IronPulse/PROGRESS.md`, en la sección "Siguientes pasos (Fase 3 en adelante)", reemplazar el punto 1 (que empieza con `1. **Fase 3 — \`WorkoutGeneratorService\`**`) por una sección de Fase 3 completada que documente: los dos flujos (generado y manual), el campo `isCompound` nuevo y su clasificación por keywords con 4 overrides manuales, el helper `UserProfile.activate(_:in:)` compartido, los 18 tests de `WorkoutGeneratorServiceTests`, y las simplificaciones conocidas (no evita repetir ejercicios entre días del mismo tipo; `preferredEquipment` sigue sin usarse). Renumerar los puntos restantes.

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/PROGRESS.md
git commit -m "Documenta la Fase 3 completa en PROGRESS.md"
```

---

## Fuera de alcance (specs separados)

- Selector de idioma (español/inglés/francés).
- Foto de perfil por `UserProfile`.
- Filtro de `preferredEquipment` en la selección de ejercicios.
- Evitar repetir el mismo ejercicio entre días del mismo tipo en la semana.
