# Fase 5 — Modo de entrenamiento activo: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar el modo de entrenamiento activo de punta a punta: empezar una sesión desde un día de la rutina, loguear peso/reps reales por set con descanso real (+ notificación de respaldo), terminar, y verla después en un historial simple.

**Architecture:** `WorkoutLogGenerator` es una función pura (mismo patrón que `WorkoutGeneratorService`) que convierte un `RoutineDay` en un árbol `WorkoutLog → SetLog` en memoria, sin tocar `ModelContext`. `RestNotificationScheduler` es un wrapper delgado sobre `UserNotifications`, sin estado. `ActiveWorkoutView` se reusa tanto para la sesión en vivo como para ver una del historial (`isReadOnly` según `endDate`).

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing, `UserNotifications` (framework de Apple, sin dependencias nuevas).

## Global Constraints

- **Idioma:** todo texto visible en español, sin acentos (convención ya usada: `"Perdida de grasa"`, `"Tiron"`).
- **Prohibido usar la palabra "IA"** en cualquier texto visible.
- **Tema:** usar los tokens existentes de `Theme/CustomColor.swift` (`Color.ironBackground`, `Color.ironCard`, `Color.ironAccent`, `Color.ironTextSecondary`, `.ironCard()`, `PrimarySportButtonStyle`, `HapticFeedback.setCompleted()`/`.restFinished()`). Nunca colores hardcodeados.
- **`Color` explícito en `foregroundStyle`:** siempre `.foregroundStyle(Color.ironAccent)`, nunca la forma corta `.foregroundStyle(.ironAccent)` — no compila contra `ShapeStyle` en este proyecto.
- **SwiftData — solo lado "colección" de las relaciones:** al construir árboles de modelos (`day.exercises = [...]`, `routine.days.append(day)`, `log.completedSets.append(setLog)`), nunca asignar el lado inverso a mano (`RoutineExercise.day`, `SetLog.session`) — SwiftData lo completa al insertar.
- **Migración de SwiftData:** `SetLog`/`WorkoutLog` ganan propiedades no-opcionales nuevas — hay que **borrar la app del simulador** antes de correr después de la Task 1. No se implementa `VersionedSchema`.
- **`UserNotifications` no necesita entitlement ni clave de Info.plist nueva** (a diferencia de HealthKit) — el permiso de notificaciones locales solo se pide en runtime con `UNUserNotificationCenter.requestAuthorization`.
- **Xcode usa file-system-synchronized groups:** los archivos `.swift` nuevos se toman solos — **nunca editar `project.pbxproj`**.
- **Build de verificación** (correr desde `/Users/diego/Documents/IRONPULSE/IronPulse`):
  ```bash
  xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
  ```
- **Tests** — SIEMPRE con `-only-testing:IronPulseTests` (sin eso corre también el suite de UI tests y `testLaunchPerformance` tarda 420 segundos solo). `xcodebuild` imprime `Test case` con **c minúscula**, un grep con `"Test Case"` no matchea nada.
  ```bash
  xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
    -destination 'platform=iOS Simulator,name=iPhone 17e' \
    -only-testing:IronPulseTests 2>&1 \
    | grep -E "\*\* TEST|Test case.*(passed|failed)" | sort -u
  ```
  `DVTAssertionHandler`/`launchSession should not be nil` en medio del output es ruido conocido del simulador, no una falla — mirar el veredicto `** TEST SUCCEEDED **`/`** TEST FAILED **`.
- **Simulador de referencia**: iPhone 17e, UDID `B93C823F-AAD5-46AF-B830-8A8390325C5F`, bundle id `com.BERNU.IronPulse`.
- **SourceKit (diagnósticos en vivo de Xcode) miente en este proyecto**: reporta constantemente `Cannot find type 'X' in scope` para tipos que existen. Es falta de contexto del target, no errores reales — la verdad la dice `xcodebuild`.
- **No editar `IronPulse/PROGRESS.md`** como parte de esta ejecución — el usuario pidió explícitamente que ese archivo solo se actualiza cuando lo pide, al final de una sesión, no tarea por tarea.

---

### Task 1: `SetLog` y `WorkoutLog` ganan campos nuevos

Sin este campo el resto de la fase no tiene de dónde sacar la duración real del descanso, ni cómo mostrar a qué día perteneció una sesión guardada. Va primero y sola, como en la Fase 3.

**Files:**
- Modify: `IronPulse/Models/WorkoutModels.swift:92-150`

**Interfaces:**
- Consumes: nada (primera tarea).
- Produces: `SetLog.restSeconds: Int`, `SetLog.targetRepsMin: Int`, `SetLog.targetRepsMax: Int`, `WorkoutLog.dayTitle: String`. Todas las tareas siguientes construyen `SetLog`/`WorkoutLog` pasando estos campos.

- [ ] **Step 1: Agregar los campos a `SetLog`**

En `IronPulse/Models/WorkoutModels.swift`, la clase `SetLog` (líneas 120-150) queda así — reemplazar el bloque completo:

```swift
@Model
final class SetLog {
    @Attribute(.unique) var id: UUID
    var exerciseId: String
    var setIndex: Int
    var weightKg: Double
    var repsCompleted: Int
    var restSeconds: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var isCompleted: Bool
    var timestamp: Date
    var session: WorkoutLog?

    init(
        id: UUID = UUID(),
        exerciseId: String,
        setIndex: Int,
        weightKg: Double,
        repsCompleted: Int,
        restSeconds: Int,
        targetRepsMin: Int,
        targetRepsMax: Int,
        isCompleted: Bool = false,
        timestamp: Date = Date(),
        session: WorkoutLog? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.repsCompleted = repsCompleted
        self.restSeconds = restSeconds
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.isCompleted = isCompleted
        self.timestamp = timestamp
        self.session = session
    }
}
```

- [ ] **Step 2: Agregar el campo a `WorkoutLog`**

En el mismo archivo, la clase `WorkoutLog` (líneas 92-118) queda así — reemplazar el bloque completo:

```swift
@Model
final class WorkoutLog {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var routineName: String
    var dayTitle: String
    var profile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \SetLog.session)
    var completedSets: [SetLog]

    init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        routineName: String,
        dayTitle: String,
        profile: UserProfile? = nil,
        completedSets: [SetLog] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.routineName = routineName
        self.dayTitle = dayTitle
        self.profile = profile
        self.completedSets = completedSets
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`. No debería haber ningún error — todavía no existe ningún lugar del código que construya `SetLog`/`WorkoutLog` (se confirmó con `grep -rn "WorkoutLog(\|SetLog(" --include="*.swift" .` antes de escribir este plan: cero resultados fuera del propio modelo), así que no hay call sites que romper.

- [ ] **Step 4: Verificar que la app arranca con el store limpio**

```bash
D=B93C823F-AAD5-46AF-B830-8A8390325C5F
xcrun simctl boot $D 2>/dev/null
xcrun simctl bootstatus $D -b
xcrun simctl uninstall $D com.BERNU.IronPulse
APP=~/Library/Developer/Xcode/DerivedData/IronPulse-ajoavrdotvzltcgjcbvamxupnuzu/Build/Products/Debug-iphonesimulator/IronPulse.app
xcrun simctl install $D "$APP" && xcrun simctl launch $D com.BERNU.IronPulse
```
Esperado: la app arranca sin crashear (el proceso queda corriendo). Tomar un screenshot con `mcp__Claude_Code_iOS_Simulator__control` (`attach` primero) y confirmar que se ve la lista de perfiles, no una pantalla en blanco ni el simulador volviendo al Home.

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Models/WorkoutModels.swift
git commit -m "Agrega restSeconds/targetReps a SetLog y dayTitle a WorkoutLog"
```

---

### Task 2: `WorkoutLogGenerator`

Convierte un día de rutina en el log de esa sesión. Función pura, sin `ModelContext`, testeable sin `ModelContainer` — mismo patrón que `WorkoutGeneratorService`.

**Files:**
- Create: `IronPulse/Services/WorkoutLogGenerator.swift`
- Test: `IronPulseTests/WorkoutLogGeneratorTests.swift`

**Interfaces:**
- Consumes: `SetLog`/`WorkoutLog` con los campos de la Task 1. `RoutineDay.exercises: [RoutineExercise]`, `RoutineExercise.{exercise, targetSets, targetRepsMin, targetRepsMax, restSeconds, orderIndex}` (ya existen, sin cambios).
- Produces: `WorkoutLogGenerator.generate(for day: RoutineDay, routineName: String, profile: UserProfile) -> WorkoutLog`. La Task 5 (`RoutineTabView`) llama a esta función exacta.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `IronPulseTests/WorkoutLogGeneratorTests.swift`:

```swift
import Foundation
import Testing
@testable import IronPulse

struct WorkoutLogGeneratorTests {

    private func makeExercise(_ id: String, _ name: String) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: .chest,
            equipment: .barbell,
            instructions: ["Paso uno."],
            gifFileName: "\(id).gif"
        )
    }

    private func makeDay() -> RoutineDay {
        let day = RoutineDay(dayNumber: 1, title: "Torso")
        let ex1 = RoutineExercise(
            exercise: makeExercise("e1", "Press plano"),
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 90,
            orderIndex: 0
        )
        let ex2 = RoutineExercise(
            exercise: makeExercise("e2", "Remo con barra"),
            targetSets: 2,
            targetRepsMin: 6,
            targetRepsMax: 10,
            restSeconds: 120,
            orderIndex: 1
        )
        day.exercises = [ex1, ex2]
        return day
    }

    private func makeProfile() -> UserProfile {
        UserProfile(name: "Test", age: 30, weightKg: 70, heightCm: 170)
    }

    @Test func generaUnSetLogPorCadaSerieObjetivo() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        #expect(log.completedSets.count == 5)
    }

    @Test func copiaRestSecondsYTargetsDelEjercicio() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())

        let primerEjercicio = log.completedSets.filter { $0.exerciseId == "e1" }
        #expect(primerEjercicio.count == 3)
        #expect(primerEjercicio.allSatisfy { $0.restSeconds == 90 && $0.targetRepsMin == 8 && $0.targetRepsMax == 12 })

        let segundoEjercicio = log.completedSets.filter { $0.exerciseId == "e2" }
        #expect(segundoEjercicio.count == 2)
        #expect(segundoEjercicio.allSatisfy { $0.restSeconds == 120 && $0.targetRepsMin == 6 && $0.targetRepsMax == 10 })
    }

    @Test func setIndexEsCrecienteSinReiniciarPorEjercicio() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        let indices = log.completedSets.sorted { $0.setIndex < $1.setIndex }.map(\.setIndex)
        #expect(indices == [0, 1, 2, 3, 4])
    }

    @Test func copiaNombreDeRutinaYTituloDeDia() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        #expect(log.routineName == "Rutina de prueba")
        #expect(log.dayTitle == "Torso")
    }

    @Test func losSetsArrancanSinCompletarYEnCero() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        #expect(log.completedSets.allSatisfy { !$0.isCompleted && $0.weightKg == 0 && $0.repsCompleted == 0 })
    }
}
```

- [ ] **Step 2: Correr los tests y confirmar que fallan**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests/WorkoutLogGeneratorTests 2>&1 \
  | grep -E "error:|\*\* TEST"
```
Esperado: falla de compilación, `cannot find 'WorkoutLogGenerator' in scope` (el tipo todavía no existe). Esa es la falla esperada — confirma que los tests realmente ejercitan código nuevo.

- [ ] **Step 3: Implementar `WorkoutLogGenerator`**

Crear `IronPulse/Services/WorkoutLogGenerator.swift`:

```swift
import Foundation

enum WorkoutLogGenerator {
    static func generate(for day: RoutineDay, routineName: String, profile: UserProfile) -> WorkoutLog {
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
                    weightKg: 0,
                    repsCompleted: 0,
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

- [ ] **Step 4: Correr los tests y confirmar que pasan**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST|Test case.*(passed|failed)" | sort -u
```
Esperado: `** TEST SUCCEEDED **`, las 5 pruebas de `WorkoutLogGeneratorTests` pasan, y los 19 tests preexistentes de `WorkoutGeneratorServiceTests` siguen pasando (24 en total).

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Services/WorkoutLogGenerator.swift IronPulseTests/WorkoutLogGeneratorTests.swift
git commit -m "Agrega WorkoutLogGenerator: arma el log de una sesion desde un dia de rutina"
```

---

### Task 3: `RestNotificationScheduler`

Wrapper delgado sobre `UserNotifications` para el respaldo de la notificación de descanso. Sin tests automáticos — es código que envuelve una API del sistema, se verifica manualmente en simulador en la Task 7 (mismo criterio que el resto de este proyecto para código que envuelve frameworks de Apple, ej. `HealthKitProfileImporter`).

**Files:**
- Create: `IronPulse/Services/RestNotificationScheduler.swift`

**Interfaces:**
- Consumes: nada nuevo — solo `UserNotifications` (framework de Apple).
- Produces: `RestNotificationScheduler.requestAuthorizationIfNeeded() async`, `.scheduleRestFinished(in: Int)`, `.cancelPending()`. La Task 4 (`ActiveWorkoutView`) llama a las tres.

- [ ] **Step 1: Implementar**

Crear `IronPulse/Services/RestNotificationScheduler.swift`:

```swift
import Foundation
import UserNotifications

enum RestNotificationScheduler {
    private static let identifier = "rest-finished"

    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleRestFinished(in seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Descanso terminado"
        content.body = "A por el siguiente set."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelPending() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`. `UserNotifications` es un framework del sistema — no hace falta agregar nada a `project.pbxproj`, Swift lo autolinkea desde el `import` (mismo comportamiento ya confirmado con `HealthKit` en la Fase 3).

- [ ] **Step 3: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Services/RestNotificationScheduler.swift
git commit -m "Agrega RestNotificationScheduler: notificacion local de respaldo para el descanso"
```

---

### Task 4: `ActiveWorkoutView` — rediseño completo

Pasa de una lista plana con sets de solo lectura a secciones por ejercicio con peso/reps editables, descanso real, y modo lectura para sesiones ya terminadas (reusado por el historial en la Task 6).

**Files:**
- Modify: `IronPulse/Views/Workouts/ActiveWorkoutView.swift` (reemplazo completo del archivo)

**Interfaces:**
- Consumes: `SetLog.{restSeconds, targetRepsMin, targetRepsMax}` y `WorkoutLog.dayTitle` (Task 1), `RestNotificationScheduler.{requestAuthorizationIfNeeded, scheduleRestFinished, cancelPending}` (Task 3).
- Produces: sin cambios en la firma pública — sigue siendo `ActiveWorkoutView(log: WorkoutLog)`. Las Tasks 5 y 6 navegan a esta vista sin cambios en cómo la instancian.

- [ ] **Step 1: Reemplazar el archivo completo**

Reemplazar todo el contenido de `IronPulse/Views/Workouts/ActiveWorkoutView.swift`:

```swift
import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: WorkoutLog
    @Query private var catalog: [Exercise]
    @State private var restRemaining: Int = 0
    @State private var restTask: Task<(), Never>? = nil

    private var isReadOnly: Bool { log.endDate != nil }

    private var exerciseNames: [String: String] {
        Dictionary(catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var groupedSets: [(exerciseId: String, sets: [SetLog])] {
        let sorted = log.completedSets.sorted { $0.setIndex < $1.setIndex }
        var order: [String] = []
        var buckets: [String: [SetLog]] = [:]
        for set in sorted {
            if buckets[set.exerciseId] == nil { order.append(set.exerciseId) }
            buckets[set.exerciseId, default: []].append(set)
        }
        return order.map { ($0, buckets[$0]!) }
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text(log.routineName).font(.title2).fontWeight(.black)
                    Text(log.dayTitle).font(.subheadline).foregroundStyle(Color.ironTextSecondary)
                }
                Spacer()
                if isReadOnly {
                    Text("Finalizada").foregroundStyle(Color.ironTextSecondary)
                }
            }
            .padding()

            List {
                ForEach(groupedSets, id: \.exerciseId) { group in
                    Section(exerciseNames[group.exerciseId] ?? group.exerciseId) {
                        ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Set \(index + 1)").font(.headline)
                                    Spacer()
                                    Text("Meta: \(set.targetRepsMin)-\(set.targetRepsMax)")
                                        .font(.caption)
                                        .foregroundStyle(Color.ironTextSecondary)
                                    Button(action: { toggleCompleted(set) }) {
                                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(set.isCompleted ? Color.ironAccent : Color.ironTextSecondary)
                                    }
                                    .disabled(isReadOnly)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        TextField("Peso", value: bindingForWeight(set), format: .number)
                                            .keyboardType(.decimalPad)
                                            .disabled(isReadOnly)
                                            .frame(width: 60)
                                        Text("kg").font(.caption).foregroundStyle(Color.ironTextSecondary)
                                    }

                                    Spacer()

                                    Stepper("\(set.repsCompleted) reps", value: bindingForReps(set), in: 0...50)
                                        .disabled(isReadOnly)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            if !isReadOnly {
                HStack(spacing: 12) {
                    Button("Terminar") {
                        log.endDate = Date()
                        try? modelContext.save()
                    }
                    .buttonStyle(PrimarySportButtonStyle())

                    Spacer()

                    if restRemaining > 0 {
                        Text("Descanso: \(restRemaining)s").font(.headline).foregroundStyle(Color.ironAccent)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Entrenamiento")
        .task {
            await RestNotificationScheduler.requestAuthorizationIfNeeded()
        }
    }

    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(get: { set.weightKg }, set: { set.weightKg = $0 })
    }

    private func bindingForReps(_ set: SetLog) -> Binding<Int> {
        Binding(get: { set.repsCompleted }, set: { set.repsCompleted = $0 })
    }

    private func toggleCompleted(_ set: SetLog) {
        set.isCompleted.toggle()
        set.timestamp = Date()
        try? modelContext.save()

        if set.isCompleted {
            HapticFeedback.setCompleted()
            startRest(seconds: set.restSeconds)
            RestNotificationScheduler.scheduleRestFinished(in: set.restSeconds)
        }
    }

    private func startRest(seconds: Int) {
        restTask?.cancel()
        restRemaining = seconds

        restTask = Task { @MainActor in
            while restRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                restRemaining -= 1
            }
            if !Task.isCancelled {
                HapticFeedback.restFinished()
                RestNotificationScheduler.cancelPending()
            }
        }
    }
}

struct ActiveWorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Active Workout")
            .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Correr los tests de regresión**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **` (24 tests, sin regresiones — esta tarea no toca ningún archivo de tests).

- [ ] **Step 4: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Views/Workouts/ActiveWorkoutView.swift
git commit -m "Rediseña ActiveWorkoutView: agrupado por ejercicio, peso/reps editables, descanso real"
```

---

### Task 5: Empezar un entrenamiento desde `RoutineTabView`

**Files:**
- Modify: `IronPulse/Views/Workouts/RoutineTabView.swift` (reemplazo completo del archivo)

**Interfaces:**
- Consumes: `WorkoutLogGenerator.generate(for:routineName:profile:)` (Task 2), `ActiveWorkoutView(log:)` (Task 4, firma sin cambios).
- Produces: nada que otra tarea consuma — es el punto de entrada final del flujo.

- [ ] **Step 1: Reemplazar el archivo completo**

Reemplazar todo el contenido de `IronPulse/Views/Workouts/RoutineTabView.swift`:

```swift
import SwiftUI
import SwiftData

struct RoutineTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var catalog: [Exercise]
    @Bindable var profile: UserProfile
    @State private var activeLog: WorkoutLog?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let active = profile.activeRoutine {
                    RoutineCard(routine: active, onStartDay: startWorkout)
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
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Rutina")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(item: $activeLog) { log in
            ActiveWorkoutView(log: log)
        }
    }

    private func generateRoutine() {
        let routine = WorkoutGeneratorService.generateRoutine(for: profile, catalog: catalog)
        profile.activate(routine, in: modelContext)
    }

    private func startWorkout(_ day: RoutineDay) {
        guard let routine = profile.activeRoutine else { return }
        let log = WorkoutLogGenerator.generate(for: day, routineName: routine.name, profile: profile)
        modelContext.insert(log)
        try? modelContext.save()
        activeLog = log
    }
}

private struct RoutineCard: View {
    let routine: WorkoutRoutine
    let onStartDay: (RoutineDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text(routine.name).font(.headline)
                Text("\(routine.days.count) dias · \(routine.splitType.displayName)")
                    .font(.caption)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            ForEach(routine.days.sorted { $0.dayNumber < $1.dayNumber }) { day in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(day.title).font(.subheadline).bold()
                        Spacer()
                        Button("Empezar") { onStartDay(day) }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.ironAccent)
                    }
                    ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                        NavigationLink {
                            ExerciseDetailView(exercise: ex.exercise)
                        } label: {
                            HStack {
                                Text(ex.exercise.name).font(.caption)
                                Spacer()
                                Text("\(ex.targetSets)x\(ex.targetRepsMin)-\(ex.targetRepsMax)")
                                    .font(.caption2)
                                    .foregroundStyle(Color.ironTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .ironCard()
    }
}

struct RoutineTabView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Rutina")
            .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Views/Workouts/RoutineTabView.swift
git commit -m "Agrega boton para empezar un entrenamiento desde cada dia de la rutina"
```

---

### Task 6: `WorkoutHistoryView` + entrada desde el Dashboard

**Files:**
- Create: `IronPulse/Views/Workouts/WorkoutHistoryView.swift`
- Modify: `IronPulse/Views/Workouts/DashboardView.swift` (reemplazo completo del archivo)

**Interfaces:**
- Consumes: `ActiveWorkoutView(log:)` con el modo `isReadOnly` de la Task 4, `WorkoutLog.{routineName, dayTitle, startDate, endDate}` (Task 1).
- Produces: nada que otra tarea consuma.

- [ ] **Step 1: Crear `WorkoutHistoryView`**

Crear `IronPulse/Views/Workouts/WorkoutHistoryView.swift`:

```swift
import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Query(
        filter: #Predicate<WorkoutLog> { $0.endDate != nil },
        sort: \WorkoutLog.startDate,
        order: .reverse
    )
    private var logs: [WorkoutLog]

    var body: some View {
        List(logs) { log in
            NavigationLink {
                ActiveWorkoutView(log: log)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(log.routineName) · \(log.dayTitle)").font(.headline)
                    Text("\(log.startDate.formatted(date: .abbreviated, time: .shortened)) · \(duration(log))")
                        .font(.caption)
                        .foregroundStyle(Color.ironTextSecondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.ironCard)
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Historial")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if logs.isEmpty {
                ContentUnavailableView(
                    "Sin entrenamientos",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Los entrenamientos que termines van a aparecer aca.")
                )
            }
        }
    }

    private func duration(_ log: WorkoutLog) -> String {
        guard let endDate = log.endDate else { return "" }
        let minutes = Int(endDate.timeIntervalSince(log.startDate) / 60)
        return "\(minutes) min"
    }
}

struct WorkoutHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutHistoryView()
        }
        .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Agregar el link desde `DashboardView`**

Reemplazar todo el contenido de `IronPulse/Views/Workouts/DashboardView.swift`:

```swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let active = profile.activeRoutine {
                    Text("\(active.name) · \(active.days.count) dias")
                        .font(.subheadline)
                        .foregroundStyle(Color.ironTextSecondary)
                }

                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    HStack {
                        Text("Ver historial de entrenamientos")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ironAccent)
                    .padding()
                    .background(Color.ironCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle(profile.name)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name).font(.ironTitle)
                Text("\(profile.experienceLevel.displayName) • \(profile.primaryGoal.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(Color.ironTextSecondary)
            }

            Spacer()

            Circle().fill(Color.ironAccent).frame(width: 56, height: 56).neonGlow()
        }
        .ironCard()
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dashboard")
            .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Correr los tests de regresión**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **`, 24 tests, sin regresiones.

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Views/Workouts/WorkoutHistoryView.swift IronPulse/Views/Workouts/DashboardView.swift
git commit -m "Agrega historial de entrenamientos y su entrada desde el Dashboard"
```

---

### Task 7: Verificación completa en simulador

Esta fase conecta piezas que ningún test unitario puede verificar juntas (permiso de notificaciones, navegación real, persistencia de un entrenamiento completo). Se verifica corriendo la app, no solo compilando — mismo criterio que la Fase 3.

**Files:**
- Ninguno — esta tarea no modifica código.

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: nada de código.

- [ ] **Step 1: Instalar con store limpio**

```bash
D=B93C823F-AAD5-46AF-B830-8A8390325C5F
xcrun simctl boot $D 2>/dev/null
xcrun simctl bootstatus $D -b
xcrun simctl uninstall $D com.BERNU.IronPulse
APP=~/Library/Developer/Xcode/DerivedData/IronPulse-ajoavrdotvzltcgjcbvamxupnuzu/Build/Products/Debug-iphonesimulator/IronPulse.app
xcrun simctl install $D "$APP" && xcrun simctl launch $D com.BERNU.IronPulse
```

- [ ] **Step 2: Verificar el flujo completo de una sesión**

Con `mcp__Claude_Code_iOS_Simulator__control` (`attach` primero, después `tap`/`screenshot`):

1. Crear un perfil, entrar al tab Rutina, tocar "Rutina inteligente" para tener una rutina activa.
2. Tocar "Empezar" en el primer día.
3. **Verificar:** `ActiveWorkoutView` muestra el nombre de la rutina + el título del día, con una sección por ejercicio (no una lista plana), cada set numerado 1, 2, 3... (no salteado ni reiniciado raro).
4. Tocar el campo de peso de un set, escribir un número (ej. `62.5`) — confirmar que el teclado es numérico y el valor se actualiza en pantalla.
5. Usar el stepper de reps para cambiar el valor.
6. Tocar el círculo para completar el set — **verificar:** aparece "Descanso: Ns" con la duración real del `restSeconds` de ese ejercicio (no 60 fijo — comparar contra lo que muestra `RoutineCard` para ese mismo ejercicio en el tab Rutina). En este punto el sistema debería pedir permiso de notificaciones (primera vez) — dar el permiso.
7. Esperar a que el descanso llegue a 0 — confirmar el haptic/duración visual (no hace falta esperar los 60-150s completos para verificar esto en detalle, con confirmar que arrancó con el número correcto alcanza).
8. Tocar "Terminar" — confirmar que vuelve a mostrar "Finalizada" si se reabre esa vista.

- [ ] **Step 3: Verificar el historial**

1. Volver al tab Dashboard.
2. Tocar "Ver historial de entrenamientos".
3. **Verificar:** aparece el entrenamiento recién terminado, con nombre de rutina + día + fecha + duración.
4. Tocarlo — **verificar:** abre la misma `ActiveWorkoutView`, pero ahora en modo lectura: el campo de peso, el stepper de reps y el círculo de completar están deshabilitados, no aparece el botón "Terminar" ni la fila de descanso.

- [ ] **Step 4: Reportar cualquier discrepancia**

Si algún paso no se comporta como se espera, es un hallazgo real de esta tarea — no seguir adelante silenciosamente. Documentar qué se vio vs. qué se esperaba.
