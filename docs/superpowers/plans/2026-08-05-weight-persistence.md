# Persistencia de Peso Entre Sets y Sesiones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El peso que el usuario pone en un set se propaga automáticamente a los demás sets vacíos del mismo ejercicio en la sesión, y una nueva sesión arranca con el peso de la última vez que se hizo ese ejercicio (en cualquier rutina).

**Architecture:** Dos piezas de lógica pura y testeable, reutilizando exactamente el patrón ya existente en el código — funciones estáticas sobre `[SetLog]`/`[WorkoutLog]` en `GuidedSessionFlow`/`WorkoutStatsService`, sin tocar `ModelContext` ni el esquema de datos. Las vistas solo llaman a esas funciones.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing (`@Test`/`#expect`).

## Global Constraints

- No hay cambios de esquema: `SetLog.weightKg` y las relaciones de `WorkoutLog`/`UserProfile.workoutLogs` ya existen tal cual.
- `WorkoutLogGenerator.generate(for:routineName:profile:)` sigue funcionando exactamente igual con su firma de 3 argumentos actual — el nuevo parámetro `previousWeights` tiene default `[:]`, así que los tests existentes (`IronPulseTests/WorkoutLogGeneratorTests.swift`) siguen compilando y pasando sin cambios.
- Toda la lógica de negocio va en funciones puras y testeables (`GuidedSessionFlow`, `WorkoutStatsService`) que reciben arreglos simples (`[SetLog]`, `[WorkoutLog]`) — nunca un `ModelContext` ni un `@Query` — igual que el resto del código existente en esos dos archivos. Las vistas (`GuidedWorkoutView`, `WorkoutLogGenerator.startSession`) solo llaman a esas funciones.
- Tests usan Swift Testing (`@Test`/`#expect`), igual que todos los archivos existentes en `IronPulseTests/`.
- Los test runs deben pasar `-parallel-testing-enabled NO` (headroom limitado del simulador en esta máquina).

---

### Task 1: Auto-rellenar sets vacíos del mismo ejercicio (dentro de la sesión)

**Files:**
- Modify: `IronPulse/Services/GuidedSessionFlow.swift`
- Modify: `IronPulse/Views/Workouts/GuidedWorkoutView.swift`
- Test: `IronPulseTests/GuidedSessionFlowTests.swift`

**Interfaces:**
- Produces: `GuidedSessionFlow.fillEmptyWeights(_ weightKg: Double, in sets: [SetLog], editedSetID: SetLog.ID)`, `GuidedSessionFlow.commonWeight(of sets: [SetLog]) -> Double?`.

- [ ] **Step 1: Write the failing tests**

En `IronPulseTests/GuidedSessionFlowTests.swift`, agregar estos tests (usa el `makeSet` que ya existe en el archivo; `SetLog` es una clase, así que se puede mutar `.weightKg` directamente después de crearla):

```swift
    @Test func fillEmptyWeightsRellenaLosSetsEnCeroDelMismoEjercicio() {
        let editado = makeSet(0)
        let vacio1 = makeSet(1)
        let vacio2 = makeSet(2)
        let sets = [editado, vacio1, vacio2]
        GuidedSessionFlow.fillEmptyWeights(40, in: sets, editedSetID: editado.id)
        #expect(vacio1.weightKg == 40)
        #expect(vacio2.weightKg == 40)
    }

    @Test func fillEmptyWeightsNoSobreescribeUnSetConValorPropio() {
        let editado = makeSet(0)
        let dropSet = makeSet(1)
        dropSet.weightKg = 25
        let sets = [editado, dropSet]
        GuidedSessionFlow.fillEmptyWeights(40, in: sets, editedSetID: editado.id)
        #expect(dropSet.weightKg == 25)
    }

    @Test func fillEmptyWeightsNoTocaElSetEditado() {
        let editado = makeSet(0)
        editado.weightKg = 40
        GuidedSessionFlow.fillEmptyWeights(999, in: [editado], editedSetID: editado.id)
        #expect(editado.weightKg == 40)
    }

    @Test func commonWeightDevuelveElValorSiTodosCoinciden() {
        let a = makeSet(0)
        a.weightKg = 40
        let b = makeSet(1)
        b.weightKg = 40
        #expect(GuidedSessionFlow.commonWeight(of: [a, b]) == 40)
    }

    @Test func commonWeightEsNilSiNoTodosCoinciden() {
        let a = makeSet(0)
        a.weightKg = 40
        let b = makeSet(1)
        b.weightKg = 35
        #expect(GuidedSessionFlow.commonWeight(of: [a, b]) == nil)
    }

    @Test func commonWeightEsNilSiNingunoTienePeso() {
        #expect(GuidedSessionFlow.commonWeight(of: [makeSet(0), makeSet(1)]) == nil)
    }

    @Test func commonWeightEsNilConListaVacia() {
        #expect(GuidedSessionFlow.commonWeight(of: []) == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/GuidedSessionFlowTests`
Expected: FAIL (`fillEmptyWeights`/`commonWeight` no existen todavía)

- [ ] **Step 3: Implement the two functions**

En `IronPulse/Services/GuidedSessionFlow.swift`, agregar al final del enum (después de `remainingSeconds`, antes del `}` de cierre):

```swift

    /// Sets que deben adoptar `weightKg` por ser hermanos vacíos
    /// (`<= 0`) del set que el usuario acaba de editar — mismo
    /// ejercicio, sin contar el set editado. Un set que ya tiene un
    /// valor propio (drop set, pirámide) se deja intacto: solo se
    /// rellenan los que de verdad están vacíos.
    static func fillEmptyWeights(_ weightKg: Double, in sets: [SetLog], editedSetID: SetLog.ID) {
        for set in sets where set.id != editedSetID && set.weightKg <= 0 {
            set.weightKg = weightKg
        }
    }

    /// El peso en el que están de acuerdo todos los sets de `sets`,
    /// si lo hay — usado para que un set nuevo herede ese peso en vez
    /// de arrancar en blanco al lado de sets ya llenos. `nil` si los
    /// sets no coinciden (ej. un drop set en curso) o ninguno tiene
    /// peso todavía.
    static func commonWeight(of sets: [SetLog]) -> Double? {
        guard let first = sets.first?.weightKg, first > 0,
              sets.allSatisfy({ $0.weightKg == first }) else { return nil }
        return first
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/GuidedSessionFlowTests`
Expected: PASS

- [ ] **Step 5: Wire `bindingForWeight` in `GuidedWorkoutView.swift`**

Encontrar (alrededor de la línea 289):

```swift
    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(
            get: { UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg) },
            set: { newValue in
                set.weightKg = UnitSystem.current == .metric ? newValue : UnitSystem.lbsToKg(newValue)
            }
        )
    }
```

Reemplazar con:

```swift
    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(
            get: { UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg) },
            set: { newValue in
                let weightKg = UnitSystem.current == .metric ? newValue : UnitSystem.lbsToKg(newValue)
                set.weightKg = weightKg
                if let currentGroup {
                    GuidedSessionFlow.fillEmptyWeights(weightKg, in: currentGroup.sets, editedSetID: set.id)
                }
            }
        )
    }
```

- [ ] **Step 6: Wire `addSet(to:)` in `GuidedWorkoutView.swift`**

Encontrar (alrededor de la línea 381):

```swift
    private func addSet(to exerciseId: String) {
        let exerciseSets = log.completedSets.filter { $0.exerciseId == exerciseId }
        guard let template = exerciseSets.max(by: { $0.setIndex < $1.setIndex }) else { return }
        let newSet = SetLog(
            exerciseId: exerciseId,
            setIndex: (log.completedSets.map(\.setIndex).max() ?? 0) + 1,
            weightKg: 0,
            repsCompleted: template.targetRepsMin,
            restSeconds: template.restSeconds,
            targetRepsMin: template.targetRepsMin,
            targetRepsMax: template.targetRepsMax
        )
        log.completedSets.append(newSet)
        renumberSets()
        try? modelContext.save()
    }
```

Reemplazar con:

```swift
    private func addSet(to exerciseId: String) {
        let exerciseSets = log.completedSets.filter { $0.exerciseId == exerciseId }
        guard let template = exerciseSets.max(by: { $0.setIndex < $1.setIndex }) else { return }
        let newSet = SetLog(
            exerciseId: exerciseId,
            setIndex: (log.completedSets.map(\.setIndex).max() ?? 0) + 1,
            weightKg: GuidedSessionFlow.commonWeight(of: exerciseSets) ?? 0,
            repsCompleted: template.targetRepsMin,
            restSeconds: template.restSeconds,
            targetRepsMin: template.targetRepsMin,
            targetRepsMax: template.targetRepsMax
        )
        log.completedSets.append(newSet)
        renumberSets()
        try? modelContext.save()
    }
```

- [ ] **Step 7: Build to verify the view still compiles**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add IronPulse/Services/GuidedSessionFlow.swift IronPulse/Views/Workouts/GuidedWorkoutView.swift IronPulseTests/GuidedSessionFlowTests.swift
git commit -m "Auto-rellenar peso en sets vacios del mismo ejercicio, incluyendo sets nuevos"
```

---

### Task 2: Precargar el peso de la última sesión (entre sesiones)

**Files:**
- Modify: `IronPulse/Services/WorkoutStatsService.swift`
- Modify: `IronPulse/Services/WorkoutLogGenerator.swift`
- Test: `IronPulseTests/WorkoutStatsServiceTests.swift`
- Test: `IronPulseTests/WorkoutLogGeneratorTests.swift`

**Interfaces:**
- Consumes: `UserProfile.workoutLogs` (relación ya existente).
- Produces: `WorkoutStatsService.mostRecentWeights(in logs: [WorkoutLog]) -> [String: Double]`; `WorkoutLogGenerator.generate(for:routineName:profile:previousWeights:)` (nuevo parámetro con default `[:]`).

- [ ] **Step 1: Write the failing tests for `mostRecentWeights`**

En `IronPulseTests/WorkoutStatsServiceTests.swift`, agregar una nueva sección (usa los `makeSet`/`makeLog`/`day` que ya existen en el archivo):

```swift
    // MARK: - mostRecentWeights

    @Test func mostRecentWeightsTomaElPesoDeLaSesionMasReciente() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 40, reps: 8)]),
            makeLog(start: day(2026, 7, 8), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 45, reps: 8)])
        ]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == 45)
    }

    @Test func mostRecentWeightsIgnoraSesionesNoTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 40, reps: 8)]),
            makeLog(start: day(2026, 7, 8), finished: false, sets: [makeSet(exerciseId: "e1", weightKg: 999, reps: 8)])
        ]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == 40)
    }

    @Test func mostRecentWeightsIgnoraSetsNoCompletadosOEnCero() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [
                makeSet(exerciseId: "e1", weightKg: 999, reps: 8, completed: false),
                makeSet(exerciseId: "e1", weightKg: 0, reps: 8)
            ])
        ]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == nil)
    }

    @Test func mostRecentWeightsSinHistorialQuedaVacio() {
        #expect(WorkoutStatsService.mostRecentWeights(in: []).isEmpty)
    }

    @Test func mostRecentWeightsUsaElPrimerSetPorSetIndexDeLaSesionMasReciente() {
        let sets = [
            makeSet(exerciseId: "e1", weightKg: 50, reps: 6),
            makeSet(exerciseId: "e1", weightKg: 45, reps: 8)
        ]
        sets[0].setIndex = 1
        sets[1].setIndex = 0
        let logs = [makeLog(start: day(2026, 7, 1), finished: true, sets: sets)]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == 45)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/WorkoutStatsServiceTests`
Expected: FAIL (`mostRecentWeights` no existe todavía)

- [ ] **Step 3: Implement `mostRecentWeights`**

En `IronPulse/Services/WorkoutStatsService.swift`, agregar justo después de la función `progress(for:in:calendar:)` (antes de `enum WeekdayStatus`):

```swift

    /// El peso más reciente completado por ejercicio, tomado de `logs`
    /// sin importar en qué rutina o día se hizo — usado para precargar
    /// una sesión nueva con lo que el usuario levantó la última vez.
    /// Solo cuentan sesiones terminadas y sets completados con peso; un
    /// ejercicio sin historial que cumpla eso simplemente no aparece en
    /// el resultado.
    static func mostRecentWeights(in logs: [WorkoutLog]) -> [String: Double] {
        var result: [String: Double] = [:]
        for log in finishedLogs(logs).sorted(by: { $0.startDate > $1.startDate }) {
            let orderedSets = log.completedSets.sorted { $0.setIndex < $1.setIndex }
            for set in orderedSets where set.isCompleted && set.weightKg > 0 {
                if result[set.exerciseId] == nil {
                    result[set.exerciseId] = set.weightKg
                }
            }
        }
        return result
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/WorkoutStatsServiceTests`
Expected: PASS

- [ ] **Step 5: Write the failing tests for `WorkoutLogGenerator`**

En `IronPulseTests/WorkoutLogGeneratorTests.swift`, agregar:

```swift
    @Test func precargaElPesoDeLaUltimaSesionSiHayHistorial() {
        let log = WorkoutLogGenerator.generate(
            for: makeDay(),
            routineName: "Rutina de prueba",
            profile: makeProfile(),
            previousWeights: ["e1": 42.5]
        )
        let setsE1 = log.completedSets.filter { $0.exerciseId == "e1" }
        #expect(setsE1.allSatisfy { $0.weightKg == 42.5 })
        let setsE2 = log.completedSets.filter { $0.exerciseId == "e2" }
        #expect(setsE2.allSatisfy { $0.weightKg == 0 })
    }
```

(El test existente `losSetsArrancanSinCompletarYSinPeso` ya cubre el caso sin `previousWeights` — debe seguir pasando sin cambios, confirmando que el default `[:]` no rompe nada.)

- [ ] **Step 6: Run tests to verify the new one fails**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/WorkoutLogGeneratorTests`
Expected: FAIL (`previousWeights` no existe todavía en `generate`)

- [ ] **Step 7: Implement `previousWeights` in `WorkoutLogGenerator`**

En `IronPulse/Services/WorkoutLogGenerator.swift`, reemplazar el archivo completo con:

```swift
import Foundation
import SwiftData

enum WorkoutLogGenerator {
    /// Generates a log for `day`, inserts it into `context`, and saves — the shared
    /// "start a session" behavior used by both DashboardView and RoutineTabView.
    @MainActor
    static func startSession(
        for day: RoutineDay,
        routineName: String,
        profile: UserProfile,
        in context: ModelContext
    ) -> WorkoutLog {
        let previousWeights = WorkoutStatsService.mostRecentWeights(in: profile.workoutLogs)
        let log = generate(for: day, routineName: routineName, profile: profile, previousWeights: previousWeights)
        context.insert(log)
        try? context.save()
        return log
    }

    static func generate(
        for day: RoutineDay,
        routineName: String,
        profile: UserProfile,
        previousWeights: [String: Double] = [:]
    ) -> WorkoutLog {
        let log = WorkoutLog(
            routineName: routineName,
            dayTitle: day.title,
            profile: profile
        )

        var setIndex = 0
        for routineExercise in day.exercises.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            for _ in 0..<routineExercise.targetSets {
                let setLog = SetLog(
                    exerciseId: routineExercise.exercise.id,
                    setIndex: setIndex,
                    weightKg: previousWeights[routineExercise.exercise.id] ?? 0,
                    repsCompleted: routineExercise.targetRepsMin,
                    restSeconds: routineExercise.restSeconds,
                    targetRepsMin: routineExercise.targetRepsMin,
                    targetRepsMax: routineExercise.targetRepsMax
                )
                log.completedSets.append(setLog)
                setIndex += 1
            }
        }

        return log
    }
}
```

- [ ] **Step 8: Run tests to verify they pass, then run the full suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/WorkoutLogGeneratorTests`
Expected: PASS

Then: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **` (confirma que Task 1 y Task 2 integran bien juntas)

- [ ] **Step 9: Commit**

```bash
git add IronPulse/Services/WorkoutStatsService.swift IronPulse/Services/WorkoutLogGenerator.swift IronPulseTests/WorkoutStatsServiceTests.swift IronPulseTests/WorkoutLogGeneratorTests.swift
git commit -m "Precargar el peso de la ultima sesion al generar una sesion nueva"
```

---

### Task 3: Verificación completa

**Files:** ninguno (solo verificación)

- [ ] **Step 1: Full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`, incluyendo todos los tests nuevos de Tasks 1-2 más todos los preexistentes.

- [ ] **Step 2: Build para dispositivo real**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Nota de verificación manual**

Documentar (en el reporte, no en código) que lo siguiente necesita probarse en dispositivo real porque depende de `WorkoutLogGenerator.startSession`, que usa `ModelContext`/`UserProfile.workoutLogs` reales y no está cubierto por los tests unitarios (mismo patrón que el resto de `startSession`, que tampoco tiene tests directos):
- Poner peso en el primer set de un ejercicio y confirmar que los demás sets del mismo ejercicio se rellenan solos.
- Cambiar el peso de un set ya lleno (simulando un drop set) y confirmar que los demás sets NO se tocan.
- Agregar un set nuevo a un ejercicio con peso ya puesto y confirmar que hereda el peso.
- Terminar una sesión con un ejercicio en cierto peso, empezar una sesión nueva (misma rutina u otra) con ese mismo ejercicio, y confirmar que arranca con ese peso.
