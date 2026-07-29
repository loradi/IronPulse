# Sesión Guiada de Entrenamiento Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la sesión de entrenamiento activa (lista plana) por un flujo guiado de un ejercicio a la vez con cronómetro por set, y cerrar los gaps del Dashboard/botón Terminar.

**Architecture:** `ActiveWorkoutView` se ramifica según `isReadOnly`: sesiones terminadas mantienen la lista plana actual (sin cambios de comportamiento); sesiones activas se delegan a una nueva `GuidedWorkoutView` con una máquina de 3 estados por set (`idle`/`runningSet`/`resting`) y navegación manual entre ejercicios. La lógica de agrupación/renumeración de sets y la validación de completar un set viven como funciones puras en `GuidedSessionFlow` (ya existente), reutilizables y testeables sin SwiftUI.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing (`GuidedSessionFlowTests.swift`/`WorkoutStatsServiceTests.swift` ya usan `import Testing` + `@Test`/`#expect`, NO XCTest — seguir ese estilo en esos dos archivos).

## Global Constraints

- Cero dependencias externas — todo con Foundation/SwiftUI/SwiftData estándar.
- iOS 17+.
- Todo string nuevo visible al usuario usa: `String(localized: "clave", defaultValue: "Texto es", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)`, agregado a `IronPulse/Localizable.xcstrings` en es/en/fr (`"extractionState": "manual"`). Valores con un entero interpolado usan `%lld` en el JSON (ver `profile.days_per_week_slider.plural` como referencia exacta).
- La duración del descanso sigue viniendo de `GuidedSessionFlow.restSeconds(isCompound:)` (90s compuestos / 60s aislamiento) — no un valor fijo.
- Sesiones YA terminadas (`log.endDate != nil`) mantienen la lista plana actual sin cambios de comportamiento ni apariencia.
- `IronPulseTests/GuidedSessionFlowTests.swift` y `IronPulseTests/WorkoutStatsServiceTests.swift` usan Swift Testing (`import Testing`, `struct ... { @Test func ... { #expect(...) } }`), NO XCTest — cualquier test nuevo en esos archivos sigue ese estilo exacto.

---

### Task 1: `WorkoutStatsService.todaysCompletedLog`

**Files:**
- Modify: `IronPulse/Services/WorkoutStatsService.swift`
- Test: `IronPulseTests/WorkoutStatsServiceTests.swift`

**Interfaces:**
- Produces: `WorkoutStatsService.todaysCompletedLog(logs: [WorkoutLog], today: Date = Date(), calendar: Calendar = .current) -> WorkoutLog?`. Task 3 lo consume.

- [ ] **Step 1: Escribir los tests (deben fallar — la función no existe aún)**

Agregar al final de `struct WorkoutStatsServiceTests` en `IronPulseTests/WorkoutStatsServiceTests.swift` (el archivo ya tiene una `private var calendar: Calendar` configurada en UTC — reusarla, no crear una nueva):

```swift
    @Test func todaysCompletedLogEncuentraElLogDeHoyTerminado() {
        let today = Date()
        let log = WorkoutLog(startDate: today, endDate: today, routineName: "R", dayTitle: "D")
        #expect(WorkoutStatsService.todaysCompletedLog(logs: [log], today: today, calendar: calendar) != nil)
    }

    @Test func todaysCompletedLogIgnoraLogsSinTerminar() {
        let today = Date()
        let log = WorkoutLog(startDate: today, endDate: nil, routineName: "R", dayTitle: "D")
        #expect(WorkoutStatsService.todaysCompletedLog(logs: [log], today: today, calendar: calendar) == nil)
    }

    @Test func todaysCompletedLogIgnoraLogsDeOtroDia() {
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let log = WorkoutLog(startDate: yesterday, endDate: yesterday, routineName: "R", dayTitle: "D")
        #expect(WorkoutStatsService.todaysCompletedLog(logs: [log], today: today, calendar: calendar) == nil)
    }
```

- [ ] **Step 2: Correr los tests, confirmar que fallan**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/WorkoutStatsServiceTests`
Expected: FAIL — "type 'WorkoutStatsService' has no member 'todaysCompletedLog'"

- [ ] **Step 3: Implementar la función**

Agregar a `IronPulse/Services/WorkoutStatsService.swift`, junto a `weekStrip` (antes de `private static func finishedLogs`):

```swift
    static func todaysCompletedLog(logs: [WorkoutLog], today: Date = Date(), calendar: Calendar = .current) -> WorkoutLog? {
        let todayStart = calendar.startOfDay(for: today)
        return finishedLogs(logs).first { calendar.startOfDay(for: $0.startDate) == todayStart }
    }
```

- [ ] **Step 4: Correr los tests, confirmar que pasan**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/WorkoutStatsServiceTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/WorkoutStatsService.swift IronPulseTests/WorkoutStatsServiceTests.swift
git commit -m "Agrega WorkoutStatsService.todaysCompletedLog"
```

---

### Task 2: `GuidedSessionFlow` — agrupación, renumeración y validación de sets

**Files:**
- Modify: `IronPulse/Services/GuidedSessionFlow.swift`
- Test: `IronPulseTests/GuidedSessionFlowTests.swift`

**Interfaces:**
- Produces: `GuidedSessionFlow.groupedSets(_ sets: [SetLog]) -> [(exerciseId: String, sets: [SetLog])]`, `GuidedSessionFlow.renumbered(_ sets: [SetLog], groupedBy exerciseOrder: [String])` (muta `setIndex` de cada `SetLog` in-place, no devuelve nada), `GuidedSessionFlow.canCompleteSet(weightKg: Double, repsCompleted: Int) -> Bool`. Tasks 4, 6 y 7 consumen todo esto.

- [ ] **Step 1: Escribir los tests (deben fallar — nada de esto existe aún)**

Modificar el helper existente `makeSet` en `IronPulseTests/GuidedSessionFlowTests.swift` para aceptar un `exerciseId` opcional (cambio compatible hacia atrás — los call sites existentes `makeSet(0)` siguen funcionando igual):

```swift
    private func makeSet(_ index: Int, exerciseId: String = "e1") -> SetLog {
        SetLog(
            exerciseId: exerciseId,
            setIndex: index,
            weightKg: 0,
            repsCompleted: 0,
            restSeconds: 60,
            targetRepsMin: 8,
            targetRepsMax: 12
        )
    }
```

Agregar al final de `struct GuidedSessionFlowTests`:

```swift
    @Test func groupedSetsAgrupaPorEjercicioEnOrdenDeAparicion() {
        let sets = [makeSet(0, exerciseId: "a"), makeSet(1, exerciseId: "a"), makeSet(2, exerciseId: "b")]
        let groups = GuidedSessionFlow.groupedSets(sets)
        #expect(groups.map(\.exerciseId) == ["a", "b"])
        #expect(groups[0].sets.count == 2)
        #expect(groups[1].sets.count == 1)
    }

    @Test func groupedSetsOrdenaPorSetIndexAntesDeAgrupar() {
        let sets = [makeSet(2, exerciseId: "b"), makeSet(0, exerciseId: "a"), makeSet(1, exerciseId: "a")]
        let groups = GuidedSessionFlow.groupedSets(sets)
        #expect(groups.map(\.exerciseId) == ["a", "b"])
    }

    @Test func renumberedDejaLosSetIndexContiguosPorEjercicio() {
        let sets = [makeSet(0, exerciseId: "a"), makeSet(1, exerciseId: "a"), makeSet(2, exerciseId: "b")]
        let nuevo = SetLog(exerciseId: "a", setIndex: 99, weightKg: 0, repsCompleted: 0, restSeconds: 60, targetRepsMin: 8, targetRepsMax: 12)
        let todos = sets + [nuevo]
        GuidedSessionFlow.renumbered(todos, groupedBy: ["a", "b"])
        let ordenadosA = todos.filter { $0.exerciseId == "a" }.sorted { $0.setIndex < $1.setIndex }
        #expect(ordenadosA.map(\.setIndex) == [0, 1, 2])
        let ordenadosB = todos.filter { $0.exerciseId == "b" }
        #expect(ordenadosB.first?.setIndex == 3)
    }

    @Test func renumberedConUnSoloEjercicioYUnSoloSet() {
        let sets = [makeSet(5, exerciseId: "a")]
        GuidedSessionFlow.renumbered(sets, groupedBy: ["a"])
        #expect(sets[0].setIndex == 0)
    }

    @Test func canCompleteSetRequierePesoYRepsPositivos() {
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 20, repsCompleted: 10) == true)
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 0, repsCompleted: 10) == false)
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 20, repsCompleted: 0) == false)
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 0, repsCompleted: 0) == false)
    }
```

- [ ] **Step 2: Correr los tests, confirmar que fallan**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/GuidedSessionFlowTests`
Expected: FAIL — "type 'GuidedSessionFlow' has no member 'groupedSets'" (y similares)

- [ ] **Step 3: Implementar las 3 funciones**

Reemplazar el contenido completo de `IronPulse/Services/GuidedSessionFlow.swift` por:

```swift
import Foundation

enum GuidedSessionFlow {
    static func restSeconds(isCompound: Bool) -> Int {
        isCompound ? 90 : 60
    }

    static func nextSetID(after currentID: SetLog.ID?, in orderedSets: [SetLog]) -> SetLog.ID? {
        guard let currentID,
              let currentIndex = orderedSets.firstIndex(where: { $0.id == currentID }),
              currentIndex + 1 < orderedSets.count
        else {
            return nil
        }
        return orderedSets[currentIndex + 1].id
    }

    static func groupedSets(_ sets: [SetLog]) -> [(exerciseId: String, sets: [SetLog])] {
        let sorted = sets.sorted { $0.setIndex < $1.setIndex }
        var order: [String] = []
        var buckets: [String: [SetLog]] = [:]
        for set in sorted {
            if buckets[set.exerciseId] == nil { order.append(set.exerciseId) }
            buckets[set.exerciseId, default: []].append(set)
        }
        return order.map { ($0, buckets[$0]!) }
    }

    static func renumbered(_ sets: [SetLog], groupedBy exerciseOrder: [String]) {
        var index = 0
        for exerciseId in exerciseOrder {
            for set in sets.filter({ $0.exerciseId == exerciseId }).sorted(by: { $0.setIndex < $1.setIndex }) {
                set.setIndex = index
                index += 1
            }
        }
    }

    static func canCompleteSet(weightKg: Double, repsCompleted: Int) -> Bool {
        weightKg > 0 && repsCompleted > 0
    }
}
```

- [ ] **Step 4: Correr los tests, confirmar que pasan**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/GuidedSessionFlowTests`
Expected: PASS, 11/11 (6 tests existentes + 5 nuevos)

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/GuidedSessionFlow.swift IronPulseTests/GuidedSessionFlowTests.swift
git commit -m "GuidedSessionFlow: agrupacion, renumeracion y validacion de sets"
```

---

### Task 3: Dashboard — detectar rutina de hoy ya terminada

**Files:**
- Modify: `IronPulse/Views/Workouts/DashboardView.swift`
- Modify: `IronPulse/Localizable.xcstrings` (2 claves nuevas)

**Interfaces:**
- Consumes: `WorkoutStatsService.todaysCompletedLog(logs:today:calendar:)` (Task 1).

- [ ] **Step 1: Agregar las 2 claves nuevas a `Localizable.xcstrings`**

```json
"dashboard.today_completed": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Completed today" } },
    "es": { "stringUnit": { "state": "translated", "value": "Completado hoy" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Terminé aujourd'hui" } }
  }
},
"dashboard.view_summary": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "View summary" } },
    "es": { "stringUnit": { "state": "translated", "value": "Ver resumen" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Voir le résumé" } }
  }
}
```

Insertarlas en el diccionario `"strings"` y validar: `python3 -c "import json; json.load(open('IronPulse/Localizable.xcstrings'))" && echo "JSON valido"`.

- [ ] **Step 2: Reemplazar la rama de `todaysCard` que muestra "Iniciar ejercicios"**

En `IronPulse/Views/Workouts/DashboardView.swift`, reemplazar:

```swift
        } else if let day = todaysDay {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hoy: \(day.title)").font(.wwHeadline)
                ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                    Text(ex.exercise.name)
                        .font(.wwBody)
                        .foregroundStyle(Color.ironTextSecondary)
                }
                Button("Iniciar ejercicios", action: startTodaysSession)
                    .buttonStyle(PrimarySportButtonStyle())
            }
            .ironCard()
        } else {
```

por:

```swift
        } else if let day = todaysDay {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hoy: \(day.title)").font(.wwHeadline)
                ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                    Text(ex.exercise.name)
                        .font(.wwBody)
                        .foregroundStyle(Color.ironTextSecondary)
                }
                if let completedLog = WorkoutStatsService.todaysCompletedLog(logs: profile.workoutLogs) {
                    Text(completedTodayLabel)
                        .font(.wwBody)
                        .foregroundStyle(Color.ironAccent)
                    Button(viewSummaryLabel) {
                        activeLog = completedLog
                    }
                    .buttonStyle(PrimarySportButtonStyle())
                } else {
                    Button("Iniciar ejercicios", action: startTodaysSession)
                        .buttonStyle(PrimarySportButtonStyle())
                }
            }
            .ironCard()
        } else {
```

- [ ] **Step 3: Agregar las 2 propiedades de label**

Agregar junto a `private func startTodaysSession()`:

```swift
    private var completedTodayLabel: String {
        String(localized: "dashboard.today_completed", defaultValue: "Completado hoy", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var viewSummaryLabel: String {
        String(localized: "dashboard.view_summary", defaultValue: "Ver resumen", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
```

- [ ] **Step 4: Compilar y correr toda la suite**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests`
Expected: todos los tests existentes siguen pasando.

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Views/Workouts/DashboardView.swift IronPulse/Localizable.xcstrings
git commit -m "Dashboard: detecta rutina de hoy ya terminada y ofrece ver resumen"
```

---

### Task 4: `GuidedWorkoutView` — motor del cronómetro por set

**Files:**
- Create: `IronPulse/Views/Workouts/GuidedWorkoutView.swift`
- Modify: `IronPulse/Localizable.xcstrings` (4 claves nuevas)

**Interfaces:**
- Consumes: `GuidedSessionFlow.groupedSets(_:)`, `GuidedSessionFlow.restSeconds(isCompound:)`, `GuidedSessionFlow.canCompleteSet(weightKg:repsCompleted:)` (Task 2); `RestNotificationScheduler.requestAuthorizationIfNeeded()`, `.scheduleRestFinished(in:)`, `.cancelPending()` (ya existentes); `HapticFeedback.setCompleted()`, `.restFinished()` (ya existentes); `UnitSystem.current`, `.kgToLbs`, `.lbsToKg` (ya existentes).
- Produces: `struct GuidedWorkoutView: View { init(log: WorkoutLog, catalog: [Exercise]) }`. Tasks 5, 6 y 7 lo extienden/consumen.

- [ ] **Step 1: Agregar las 4 claves nuevas a `Localizable.xcstrings`**

```json
"guided_session.start_set": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Start set" } },
    "es": { "stringUnit": { "state": "translated", "value": "Empezar set" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Démarrer la série" } }
  }
},
"guided_session.finish_set": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Finish set" } },
    "es": { "stringUnit": { "state": "translated", "value": "Terminar set" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Terminer la série" } }
  }
},
"guided_session.rest_seconds": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Rest: %lld s" } },
    "es": { "stringUnit": { "state": "translated", "value": "Descanso: %lld s" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Repos : %lld s" } }
  }
},
"guided_session.elapsed_seconds": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "%lld s" } },
    "es": { "stringUnit": { "state": "translated", "value": "%lld s" } },
    "fr": { "stringUnit": { "state": "translated", "value": "%lld s" } }
  }
}
```

Validar JSON como en tareas anteriores.

- [ ] **Step 2: Crear `GuidedWorkoutView.swift`**

```swift
import SwiftUI
import SwiftData

struct GuidedWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: WorkoutLog
    let catalog: [Exercise]

    @State private var currentExerciseIndex: Int = 0
    @State private var activeSetID: SetLog.ID?
    @State private var setPhase: SetPhase = .idle
    @State private var elapsedSetSeconds: Int = 0
    @State private var restRemaining: Int = 0
    @State private var timerTask: Task<(), Never>? = nil

    private var groups: [(exerciseId: String, sets: [SetLog])] {
        GuidedSessionFlow.groupedSets(log.completedSets)
    }

    private var currentGroup: (exerciseId: String, sets: [SetLog])? {
        guard groups.indices.contains(currentExerciseIndex) else { return nil }
        return groups[currentExerciseIndex]
    }

    private var currentExercise: Exercise? {
        guard let currentGroup else { return nil }
        return catalog.first { $0.id == currentGroup.exerciseId }
    }

    private var activeSet: SetLog? {
        guard let currentGroup else { return nil }
        return currentGroup.sets.first { $0.id == activeSetID } ?? currentGroup.sets.first
    }

    var body: some View {
        VStack(spacing: 16) {
            if let currentGroup, let exercise = currentExercise {
                Text(exercise.name).font(.wwHeadline).padding(.top)

                List {
                    ForEach(Array(currentGroup.sets.enumerated()), id: \.element.id) { index, set in
                        setRow(set: set, index: index)
                    }
                }

                if let set = activeSet {
                    controls(for: set)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    "Sin ejercicios",
                    systemImage: "checkmark.circle"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("wwLogoMark")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Entrenamiento").font(.wwHeadline)
                }
            }
        }
        .task {
            await RestNotificationScheduler.requestAuthorizationIfNeeded()
        }
        .onAppear {
            selectFirstIncompleteSet()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func setRow(set: SetLog, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Set \(index + 1)").font(.wwHeadline)
                Spacer()
                Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                    .font(.wwCaption)
                    .foregroundStyle(Color.ironTextSecondary)
                if set.isCompleted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ironAccent)
                }
            }

            HStack {
                HStack(spacing: 4) {
                    TextField("Peso", value: bindingForWeight(set), format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                    Text(UnitSystem.current == .metric ? "kg" : "lbs").font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
                }
                Spacer()
                Stepper("\(set.repsCompleted) reps", value: bindingForReps(set), in: 0...50)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background {
            if set.id == activeSetID {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.ironAccent.opacity(0.12))
            }
        }
        .overlay {
            if set.id == activeSetID {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.ironAccent, lineWidth: 2)
            }
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func controls(for set: SetLog) -> some View {
        switch setPhase {
        case .idle:
            Button(startSetLabel) {
                startSet()
            }
            .buttonStyle(PrimarySportButtonStyle())
        case .runningSet:
            VStack(spacing: 8) {
                Text(elapsedLabel(elapsedSetSeconds)).font(.wwHeadline).foregroundStyle(Color.ironAccent)
                Button(finishSetLabel) {
                    finishSet(set)
                }
                .buttonStyle(PrimarySportButtonStyle())
                .disabled(!GuidedSessionFlow.canCompleteSet(weightKg: set.weightKg, repsCompleted: set.repsCompleted))
            }
        case .resting:
            HStack(spacing: 12) {
                Text(restLabel(restRemaining)).font(.wwHeadline).foregroundStyle(Color.ironAccent)
                Spacer()
                Button(startSetLabel) {
                    startNextSet()
                }
                .buttonStyle(PrimarySportButtonStyle())
            }
        }
    }

    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(
            get: { UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg) },
            set: { newValue in
                set.weightKg = UnitSystem.current == .metric ? newValue : UnitSystem.lbsToKg(newValue)
            }
        )
    }

    private func bindingForReps(_ set: SetLog) -> Binding<Int> {
        Binding(get: { set.repsCompleted }, set: { set.repsCompleted = $0 })
    }

    private func startSet() {
        setPhase = .runningSet
        elapsedSetSeconds = 0
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                elapsedSetSeconds += 1
            }
        }
    }

    private func finishSet(_ set: SetLog) {
        set.isCompleted = true
        set.timestamp = Date()
        try? modelContext.save()
        HapticFeedback.setCompleted()

        let isCompound = currentExercise?.isCompound ?? false
        let seconds = GuidedSessionFlow.restSeconds(isCompound: isCompound)
        RestNotificationScheduler.scheduleRestFinished(in: seconds)
        startRest(seconds: seconds)
    }

    private func startRest(seconds: Int) {
        timerTask?.cancel()
        setPhase = .resting
        restRemaining = seconds

        timerTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restRemaining -= 1
            }
            if !Task.isCancelled {
                HapticFeedback.restFinished()
                RestNotificationScheduler.cancelPending()
                startNextSet()
            }
        }
    }

    private func startNextSet() {
        timerTask?.cancel()
        RestNotificationScheduler.cancelPending()

        guard let currentGroup, let activeSet else { return }
        if let nextID = GuidedSessionFlow.nextSetID(after: activeSet.id, in: currentGroup.sets) {
            activeSetID = nextID
            setPhase = .idle
        } else {
            advanceToNextExercise()
        }
    }

    private func advanceToNextExercise() {
        guard currentExerciseIndex < groups.count - 1 else {
            setPhase = .idle
            return
        }
        currentExerciseIndex += 1
        selectFirstIncompleteSet()
    }

    private func selectFirstIncompleteSet() {
        timerTask?.cancel()
        setPhase = .idle
        elapsedSetSeconds = 0
        restRemaining = 0
        guard let currentGroup else { return }
        activeSetID = currentGroup.sets.first { !$0.isCompleted }?.id ?? currentGroup.sets.last?.id
    }

    private var startSetLabel: String {
        String(localized: "guided_session.start_set", defaultValue: "Empezar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var finishSetLabel: String {
        String(localized: "guided_session.finish_set", defaultValue: "Terminar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func restLabel(_ seconds: Int) -> String {
        String(localized: "guided_session.rest_seconds", defaultValue: "Descanso: \(seconds) s", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        String(localized: "guided_session.elapsed_seconds", defaultValue: "\(seconds) s", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
}

private enum SetPhase: Equatable {
    case idle
    case runningSet
    case resting
}

struct GuidedWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Guided Workout")
            .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 3: Compilar**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **` (este archivo aún no se usa desde ningún lado — eso es Task 7 — pero debe compilar solo)

- [ ] **Step 4: Commit**

```bash
git add IronPulse/Views/Workouts/GuidedWorkoutView.swift IronPulse/Localizable.xcstrings
git commit -m "Agrega GuidedWorkoutView: motor del cronometro por set"
```

---

### Task 5: `GuidedWorkoutView` — navegación entre ejercicios, Terminar e ícono de info

**Files:**
- Modify: `IronPulse/Views/Workouts/GuidedWorkoutView.swift`
- Modify: `IronPulse/Localizable.xcstrings` (2 claves nuevas)

**Interfaces:**
- Consumes: `ExerciseDetailView(exercise:)` (ya existe en `IronPulse/Views/Exercises/ExerciseListView.swift`, struct pública, se reusa tal cual).

- [ ] **Step 1: Agregar las 2 claves nuevas a `Localizable.xcstrings`**

```json
"guided_session.finish": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Finish" } },
    "es": { "stringUnit": { "state": "translated", "value": "Terminar" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Terminer" } }
  }
},
"guided_session.close_info": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Close" } },
    "es": { "stringUnit": { "state": "translated", "value": "Cerrar" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Fermer" } }
  }
}
```

Validar JSON.

- [ ] **Step 2: Agregar `@Environment(\.dismiss)` y el estado del sheet de info**

En `GuidedWorkoutView`, agregar junto a las demás propiedades `@Environment`/`@State`:

```swift
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingExerciseInfo = false
```

- [ ] **Step 3: Agregar el toolbar de navegación, Terminar e info**

Reemplazar el bloque `.toolbar { ToolbarItem(placement: .principal) { ... } }` existente por:

```swift
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("wwLogoMark")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Entrenamiento").font(.wwHeadline)
                }
            }
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    goToPreviousExercise()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentExerciseIndex == 0)

                Button {
                    goToNextExercise()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentExerciseIndex >= groups.count - 1)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShowingExerciseInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                Button(finishLabel) {
                    finishSession()
                }
            }
        }
        .sheet(isPresented: $isShowingExerciseInfo) {
            if let exercise = currentExercise {
                NavigationStack {
                    ExerciseDetailView(exercise: exercise)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(closeLabel) {
                                    isShowingExerciseInfo = false
                                }
                            }
                        }
                }
            }
        }
```

- [ ] **Step 4: Agregar las funciones de navegación, finalizar sesión y las 2 labels**

Agregar junto a `advanceToNextExercise`:

```swift
    private func goToPreviousExercise() {
        guard currentExerciseIndex > 0 else { return }
        currentExerciseIndex -= 1
        selectFirstIncompleteSet()
    }

    private func goToNextExercise() {
        guard currentExerciseIndex < groups.count - 1 else { return }
        currentExerciseIndex += 1
        selectFirstIncompleteSet()
    }

    private func finishSession() {
        timerTask?.cancel()
        log.endDate = Date()
        try? modelContext.save()
        dismiss()
    }
```

Agregar junto a `elapsedLabel`:

```swift
    private var finishLabel: String {
        String(localized: "guided_session.finish", defaultValue: "Terminar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var closeLabel: String {
        String(localized: "guided_session.close_info", defaultValue: "Cerrar", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
```

- [ ] **Step 5: Compilar**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Views/Workouts/GuidedWorkoutView.swift IronPulse/Localizable.xcstrings
git commit -m "GuidedWorkoutView: navegacion entre ejercicios, Terminar e icono de info"
```

---

### Task 6: `GuidedWorkoutView` — editar cantidad de sets

**Files:**
- Modify: `IronPulse/Views/Workouts/GuidedWorkoutView.swift`
- Modify: `IronPulse/Localizable.xcstrings` (2 claves nuevas)

**Interfaces:**
- Consumes: `GuidedSessionFlow.groupedSets(_:)`, `GuidedSessionFlow.renumbered(_:groupedBy:)` (Task 2).

- [ ] **Step 1: Agregar las 2 claves nuevas a `Localizable.xcstrings`**

```json
"guided_session.add_set": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Add set" } },
    "es": { "stringUnit": { "state": "translated", "value": "Agregar set" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Ajouter une série" } }
  }
},
"guided_session.remove_set": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Remove set" } },
    "es": { "stringUnit": { "state": "translated", "value": "Eliminar set" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Supprimer la série" } }
  }
}
```

Validar JSON.

- [ ] **Step 2: Agregar el botón "Agregar set" a la `List`**

En el `body`, dentro del `List { ForEach(...) { ... } }`, agregar después del `ForEach`:

```swift
                List {
                    ForEach(Array(currentGroup.sets.enumerated()), id: \.element.id) { index, set in
                        setRow(set: set, index: index)
                    }
                    Button {
                        addSet(to: currentGroup.exerciseId)
                    } label: {
                        Label(addSetLabel, systemImage: "plus")
                    }
                }
```

- [ ] **Step 3: Agregar la opción de eliminar en `setRow`**

En `setRow(set:index:)`, agregar dentro del `VStack` principal, después del segundo `HStack` (el de Peso/Reps), antes del `.padding(.vertical, 4)`:

```swift
            if (currentGroup?.sets.count ?? 0) > 1 {
                Button(role: .destructive) {
                    removeSet(set)
                } label: {
                    Label(removeSetLabel, systemImage: "trash")
                }
                .font(.wwCaption)
            }
```

- [ ] **Step 4: Agregar `addSet`, `removeSet`, `renumberSets` y las 2 labels**

Agregar junto a `finishSession`:

```swift
    private func addSet(to exerciseId: String) {
        let exerciseSets = log.completedSets.filter { $0.exerciseId == exerciseId }
        guard let template = exerciseSets.max(by: { $0.setIndex < $1.setIndex }) else { return }
        let newSet = SetLog(
            exerciseId: exerciseId,
            setIndex: (log.completedSets.map(\.setIndex).max() ?? 0) + 1,
            weightKg: 0,
            repsCompleted: 0,
            restSeconds: template.restSeconds,
            targetRepsMin: template.targetRepsMin,
            targetRepsMax: template.targetRepsMax
        )
        log.completedSets.append(newSet)
        renumberSets()
        try? modelContext.save()
    }

    private func removeSet(_ set: SetLog) {
        let exerciseSetCount = log.completedSets.filter { $0.exerciseId == set.exerciseId }.count
        guard exerciseSetCount > 1 else { return }
        log.completedSets.removeAll { $0.id == set.id }
        modelContext.delete(set)
        if activeSetID == set.id {
            selectFirstIncompleteSet()
        }
        renumberSets()
        try? modelContext.save()
    }

    private func renumberSets() {
        let order = GuidedSessionFlow.groupedSets(log.completedSets).map(\.exerciseId)
        GuidedSessionFlow.renumbered(log.completedSets, groupedBy: order)
    }
```

Agregar junto a `closeLabel`:

```swift
    private var addSetLabel: String {
        String(localized: "guided_session.add_set", defaultValue: "Agregar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var removeSetLabel: String {
        String(localized: "guided_session.remove_set", defaultValue: "Eliminar set", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }
```

- [ ] **Step 5: Compilar**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Views/Workouts/GuidedWorkoutView.swift IronPulse/Localizable.xcstrings
git commit -m "GuidedWorkoutView: editar cantidad de sets (agregar/eliminar)"
```

---

### Task 7: Conectar `GuidedWorkoutView` en `ActiveWorkoutView`

**Files:**
- Modify: `IronPulse/Views/Workouts/ActiveWorkoutView.swift`

**Interfaces:**
- Consumes: `GuidedWorkoutView(log:catalog:)` (Task 4), `GuidedSessionFlow.groupedSets(_:)` (Task 2).

- [ ] **Step 1: Reemplazar el contenido completo de `ActiveWorkoutView.swift`**

`ActiveWorkoutView` ahora solo decide qué mostrar; toda la lógica interactiva (cronómetro, completar sets, editar cantidad de sets) vive en `GuidedWorkoutView` desde las Tasks 4-6, así que se elimina de aquí (dead code: `activeSetID`, `restRemaining`, `restTask`, `toggleCompleted`, `bindingForWeight`/`bindingForReps` mutables, `restSeconds(for:)`, `advanceToNextSet`, `startRest`, el botón "Terminar" interactivo, y el `.task`/`.onAppear`/`.onDisappear` relacionados con el cronómetro — todos dejan de tener call site una vez que el modo no-solo-lectura se delega a `GuidedWorkoutView`).

Reemplazar el archivo completo por:

```swift
import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Bindable var log: WorkoutLog
    @Query private var catalog: [Exercise]

    private var isReadOnly: Bool { log.endDate != nil }

    private var exerciseNames: [String: String] {
        Dictionary(catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var sessionVolumeKg: Double {
        log.completedSets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.weightKg * Double($1.repsCompleted) }
    }

    private var groupedSets: [(exerciseId: String, sets: [SetLog])] {
        GuidedSessionFlow.groupedSets(log.completedSets)
    }

    var body: some View {
        Group {
            if isReadOnly {
                readOnlyBody
            } else {
                GuidedWorkoutView(log: log, catalog: catalog)
            }
        }
    }

    private var readOnlyBody: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(log.routineName).font(.wwHeadline)
                    Text(log.dayTitle).font(.wwBody).foregroundStyle(Color.ironTextSecondary)
                }
                Spacer()
                Text("Finalizada").foregroundStyle(Color.ironTextSecondary)
            }
            .padding()

            LabeledProgressBar(
                label: "Session Volume",
                valueText: UnitSystem.formattedWeight(sessionVolumeKg, system: UnitSystem.current),
                progress: 1.0
            )
            .ironCard()
            .padding(.horizontal)

            List {
                ForEach(groupedSets, id: \.exerciseId) { group in
                    Section(exerciseNames[group.exerciseId] ?? group.exerciseId) {
                        ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Set \(index + 1)").font(.wwHeadline)
                                    Spacer()
                                    Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                                        .font(.wwCaption)
                                        .foregroundStyle(Color.ironTextSecondary)
                                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(set.isCompleted ? Color.ironAccent : Color.ironTextSecondary)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        TextField("Peso", value: .constant(displayWeight(set)), format: .number.precision(.fractionLength(1)))
                                            .keyboardType(.decimalPad)
                                            .disabled(true)
                                            .frame(width: 60)
                                        Text(UnitSystem.current == .metric ? "kg" : "lbs").font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
                                    }
                                    Spacer()
                                    Stepper("\(set.repsCompleted) reps", value: .constant(set.repsCompleted), in: 0...50)
                                        .disabled(true)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("wwLogoMark")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    Text("Entrenamiento").font(.wwHeadline)
                }
            }
        }
    }

    private func displayWeight(_ set: SetLog) -> Double {
        UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg)
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Active Workout")
            .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Compilar y correr toda la suite**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests`
Expected: todos los tests existentes siguen pasando (nada de lo eliminado tenía tests propios — la lógica que sí los tenía, `GuidedSessionFlow`/`WorkoutStatsService`, no se tocó en este paso).

- [ ] **Step 3: Commit**

```bash
git add IronPulse/Views/Workouts/ActiveWorkoutView.swift
git commit -m "Conecta GuidedWorkoutView: ActiveWorkoutView se ramifica segun isReadOnly"
```

---

### Task 8: Verificación completa en simulador

**Files:** ninguno (solo verificación manual, sin cambios de código)

- [ ] **Step 1: Correr toda la suite de tests**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests -resultBundlePath /tmp/testresults_sesion_guiada.xcresult`

Run: `xcrun xcresulttool get test-results summary --path /tmp/testresults_sesion_guiada.xcresult`
Expected: `"result": "Passed"`, 0 `failedTests`.

- [ ] **Step 2: Recorrido en vivo — sesión ya terminada (sin cambios de comportamiento)**

Abrir el Historial o el resumen del Dashboard de una sesión ya terminada, confirmar que se ve exactamente igual que antes (lista plana, campos deshabilitados, sin cronómetro).

- [ ] **Step 3: Recorrido en vivo — sesión activa nueva**

Iniciar una sesión nueva desde el Dashboard. Confirmar:
- Se ve un ejercicio a la vez (no la lista plana).
- "Empezar set" arranca el cronómetro contando hacia arriba.
- "Terminar set" está deshabilitado hasta ingresar peso y reps, y al tocarlo dispara el descanso (90s en un compuesto, 60s en aislamiento).
- "Start set" durante el descanso salta el countdown de inmediato.
- Al completar todos los sets de un ejercicio, avanza automáticamente al siguiente.
- Las flechas `<` `>` permiten navegar manualmente entre ejercicios ya vistos.
- El ícono de info abre el detalle del ejercicio y, al cerrarlo, regresa a la sesión.
- Se puede agregar y eliminar sets del ejercicio actual (no se puede eliminar si es el único).
- "Terminar" (siempre visible) guarda y regresa al Dashboard en cualquier momento.

- [ ] **Step 4: Recorrido en vivo — Dashboard con rutina de hoy ya terminada**

Terminar una sesión y volver al Dashboard el mismo día. Confirmar que ya no ofrece "Iniciar ejercicios" sino "Completado hoy" + "Ver resumen", y que el resumen abre esa sesión en modo solo-lectura.

- [ ] **Step 5: Actualizar PROGRESS.md**

Solo si el usuario lo pide explícitamente en este punto — no agregarlo de forma proactiva.
