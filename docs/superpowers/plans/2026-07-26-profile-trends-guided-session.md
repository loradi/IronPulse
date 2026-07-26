# Tendencias de perfil + sesión guiada con auto-avance: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perfil ahora muestra tendencias reales (volumen, entrenamientos,
racha, gráfico de 30 días, masa magra, progreso por ejercicio), sabe qué
día de la rutina toca hoy (asignado por día de la semana), y
`ActiveWorkoutView` avanza sola entre sets: al completar uno, descansa
60-90s según si el ejercicio es compuesto o de aislamiento, y arranca
solo el siguiente.

**Architecture:** `WorkoutStatsService` y `GuidedSessionFlow` son
funciones puras y sincrónicas (mismo espíritu que
`WorkoutGeneratorService`/`WorkoutLogGenerator`), testeables sin
`ModelContainer`. `RoutineDay` gana un `Weekday` asignado automáticamente
por una tabla fija indexada por posición. `DashboardView` se rediseña
in-place (no una vista nueva) para mostrar todo esto, ya que es la
pantalla a la que se llega al tocar un perfil.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Swift Testing, **Swift
Charts** (nativo desde iOS 16, el proyecto ya requiere iOS 17+ — sin
dependencia nueva).

## Global Constraints

- **Idioma:** todo texto visible en español, sin acentos.
- **Prohibido usar la palabra "IA"** en cualquier texto visible.
- **Tema:** usar los tokens existentes de `Theme/CustomColor.swift`
  (`Color.ironBackground`, `Color.ironCard`, `Color.ironAccent`,
  `Color.ironTextSecondary`, `.ironCard()`, `.neonGlow()`,
  `PrimarySportButtonStyle`, `HapticFeedback`, `diasLabel(_:)`). Nunca
  colores hardcodeados.
- **`Color` explícito en `foregroundStyle`:** siempre
  `.foregroundStyle(Color.ironAccent)`, nunca `.foregroundStyle(.ironAccent)`
  — no compila contra `ShapeStyle` en este proyecto.
- **SwiftData — solo lado "colección" de las relaciones:** nunca asignar
  el lado inverso a mano al construir árboles de modelos.
- **Migración de SwiftData:** `RoutineDay` gana `weekday: Weekday`, campo
  no-opcional nuevo — **borrar la app del simulador** (`xcrun simctl
  uninstall <device> com.BERNU.IronPulse`) antes de correr después de la
  Task 1. Reconfirmado como gotcha real en la limpieza chica del
  2026-07-26 (rename de `isGeneratedByAI` rompió el store viejo de la
  misma forma). No se implementa `VersionedSchema`, no hay usuarios
  reales.
- **Xcode usa file-system-synchronized groups:** los archivos `.swift`
  nuevos se toman solos — nunca editar `project.pbxproj`.
- **Build de verificación** (correr desde
  `/Users/diego/Documents/IRONPULSE/IronPulse`):
  ```bash
  xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
  ```
- **Tests** — SIEMPRE con `-only-testing:IronPulseTests` (sin eso corre
  también el suite de UI tests y `testLaunchPerformance` tarda 420
  segundos solo). `xcodebuild` imprime `Test case` con **c minúscula**.
  ```bash
  xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
    -destination 'platform=iOS Simulator,name=iPhone 17e' \
    -only-testing:IronPulseTests 2>&1 \
    | grep -E "\*\* TEST|Test case.*(passed|failed)" | sort -u
  ```
- **Simulador de referencia**: iPhone 17e, UDID
  `B93C823F-AAD5-46AF-B830-8A8390325C5F`, bundle id `com.BERNU.IronPulse`.
- **`xcrun simctl` a veces devuelve "Unable to lookup in current state:
  Shutdown"** en medio de una sesión larga — `xcrun simctl boot <UDID>` +
  `xcrun simctl bootstatus <UDID> -b` antes de reinstalar/lanzar.
- **SourceKit miente en este proyecto**: reporta constantemente `Cannot
  find type 'X' in scope` para tipos que existen. La verdad la dice
  `xcodebuild`.
- **No editar `IronPulse/PROGRESS.md`** como parte de esta ejecución —
  solo se actualiza cuando el usuario lo pide explícitamente.

---

### Task 1: `Weekday` + asignación automática de días

Sin esto ninguna otra tarea tiene de dónde sacar "qué día es hoy" ni
cómo asignar un día de la semana a cada `RoutineDay`. Va primero, como
en las fases anteriores.

**Files:**
- Modify: `IronPulse/Models/ProfileEnums.swift`
- Modify: `IronPulse/Models/WorkoutModels.swift:36-58` (clase `RoutineDay`)
- Modify: `IronPulse/Services/WorkoutGeneratorService.swift`
- Modify: `IronPulse/Views/Workouts/RoutineBuilderView.swift:149-156`
- Test: `IronPulseTests/WeekdayTests.swift` (nuevo)
- Test: `IronPulseTests/WorkoutGeneratorServiceTests.swift` (agregar tests)

**Interfaces:**
- Consumes: nada (primera tarea).
- Produces: `Weekday` (enum, `Models/ProfileEnums.swift`), `RoutineDay.weekday: Weekday`, `WorkoutGeneratorService.weekdaysForCount(_ count: Int) -> [Weekday]`. Las Tasks 2 y 6 usan `Weekday`; la Task 6 usa `Weekday.today()` y `RoutineDay.weekday`.

- [ ] **Step 1: Agregar el enum `Weekday` a `ProfileEnums.swift`**

Al final de `IronPulse/Models/ProfileEnums.swift`, agregar:

```swift
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miercoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sabado"
        case .sunday: return "Domingo"
        }
    }

    /// `Calendar.component(.weekday)` devuelve 1=domingo..7=sabado (calendario
    /// gregoriano/US) — se remapea a este enum (1=lunes..7=domingo) para no
    /// heredar esa convencion hacia el resto del codigo.
    static func today(calendar: Calendar = .current, now: Date = Date()) -> Weekday {
        let raw = calendar.component(.weekday, from: now)
        let mondayFirst = (raw + 5) % 7 + 1
        return Weekday(rawValue: mondayFirst)!
    }
}
```

- [ ] **Step 2: Agregar el campo a `RoutineDay`**

En `IronPulse/Models/WorkoutModels.swift`, la clase `RoutineDay`
(líneas 36-58) queda así — reemplazar el bloque completo:

```swift
@Model
final class RoutineDay {
    @Attribute(.unique) var id: UUID
    var dayNumber: Int
    var title: String
    var weekday: Weekday
    var routine: WorkoutRoutine?

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.day)
    var exercises: [RoutineExercise]

    init(
        id: UUID = UUID(),
        dayNumber: Int,
        title: String,
        weekday: Weekday = .monday,
        routine: WorkoutRoutine? = nil,
        exercises: [RoutineExercise] = []
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.title = title
        self.weekday = weekday
        self.routine = routine
        self.exercises = exercises
    }
}
```

(`weekday` tiene default `.monday` para no romper el fixture existente
`RoutineDay(dayNumber: 1, title: "Torso")` de
`IronPulseTests/WorkoutLogGeneratorTests.swift`, que no le importa el
día de la semana.)

- [ ] **Step 3: Agregar `weekdaysForCount` a `WorkoutGeneratorService`**

En `IronPulse/Services/WorkoutGeneratorService.swift`, agregar este
método `static` dentro del `enum WorkoutGeneratorService` (junto a
`splitType`/`dayTemplates`, antes de `struct Prescription`):

```swift
static func weekdaysForCount(_ count: Int) -> [Weekday] {
    switch count {
    case 1: return [.monday]
    case 2: return [.monday, .thursday]
    case 3: return [.monday, .wednesday, .friday]
    case 4: return [.monday, .tuesday, .thursday, .friday]
    case 5: return [.monday, .tuesday, .wednesday, .thursday, .friday]
    case 6: return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    default: return Weekday.allCases // 7 dias: los 7 casos del enum, ya en orden
    }
}
```

- [ ] **Step 4: Asignar `weekday` en `generateRoutine`**

En el mismo archivo, dentro de `generateRoutine(for:catalog:)`, agregar
`let weekdays = weekdaysForCount(templates.count)` justo después de la
línea `let perDay = exercisesPerDay(for: profile.experienceLevel)`, y
cambiar la línea que crea el día:

```swift
let day = RoutineDay(dayNumber: index + 1, title: template.title, weekday: weekdays[index])
```

(reemplaza la línea actual `let day = RoutineDay(dayNumber: index + 1, title: template.title)` dentro del `for (index, template) in templates.enumerated()`).

- [ ] **Step 5: Asignar `weekday` en `RoutineBuilderView.save()`**

En `IronPulse/Views/Workouts/RoutineBuilderView.swift`, dentro de
`private func save()`, agregar `let weekdays =
WorkoutGeneratorService.weekdaysForCount(dayCount)` justo antes del
`for (index, draft) in draftDays.enumerated() where !draft.items.isEmpty {`,
y cambiar la línea que crea el día:

```swift
let day = RoutineDay(dayNumber: index + 1, title: draft.title, weekday: weekdays[index])
```

(reemplaza la línea actual `let day = RoutineDay(dayNumber: index + 1, title: draft.title)`.)

- [ ] **Step 6: Tests de `Weekday.today()`**

Crear `IronPulseTests/WeekdayTests.swift`:

```swift
import Foundation
import Testing
@testable import IronPulse

struct WeekdayTests {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func mapeaCadaDiaDeCalendarioAlWeekdayCorrecto() {
        // Semana real: 2026-07-26 (domingo) a 2026-08-01 (sabado).
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 27)) == .monday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 28)) == .tuesday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 29)) == .wednesday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 30)) == .thursday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 31)) == .friday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 8, 1)) == .saturday)
        #expect(Weekday.today(calendar: utcCalendar, now: date(2026, 7, 26)) == .sunday)
    }
}
```

- [ ] **Step 7: Tests de `weekdaysForCount` y de la asignación en `generateRoutine`**

Al final de `struct WorkoutGeneratorServiceTests` en
`IronPulseTests/WorkoutGeneratorServiceTests.swift` (antes de la llave
de cierre final), agregar:

```swift
// MARK: - Dias de la semana

@Test func weekdaysForCountDevuelveLaTablaCorrecta() {
    #expect(WorkoutGeneratorService.weekdaysForCount(1) == [.monday])
    #expect(WorkoutGeneratorService.weekdaysForCount(2) == [.monday, .thursday])
    #expect(WorkoutGeneratorService.weekdaysForCount(3) == [.monday, .wednesday, .friday])
    #expect(WorkoutGeneratorService.weekdaysForCount(4) == [.monday, .tuesday, .thursday, .friday])
    #expect(WorkoutGeneratorService.weekdaysForCount(5) == [.monday, .tuesday, .wednesday, .thursday, .friday])
    #expect(WorkoutGeneratorService.weekdaysForCount(6) == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
    #expect(WorkoutGeneratorService.weekdaysForCount(7) == Weekday.allCases)
}

@Test func cadaCountDevuelveLaCantidadDeDiasPedida() {
    for count in 1...7 {
        #expect(WorkoutGeneratorService.weekdaysForCount(count).count == count)
    }
}

@Test func generateRoutineAsignaLosWeekdaysEnOrden() {
    let routine = WorkoutGeneratorService.generateRoutine(for: makeProfile(days: 3), catalog: makeCatalog())
    let sortedDays = routine.days.sorted { $0.dayNumber < $1.dayNumber }
    #expect(sortedDays.map(\.weekday) == [.monday, .wednesday, .friday])
}
```

- [ ] **Step 8: Borrar la app del simulador (migración de SwiftData)**

```bash
xcrun simctl uninstall B93C823F-AAD5-46AF-B830-8A8390325C5F com.BERNU.IronPulse
```
Si devuelve "Unable to lookup in current state: Shutdown": `xcrun simctl
boot B93C823F-AAD5-46AF-B830-8A8390325C5F && xcrun simctl bootstatus
B93C823F-AAD5-46AF-B830-8A8390325C5F -b`, después reintentar el
uninstall.

- [ ] **Step 9: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Correr los tests**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **` (25 + 1 (WeekdayTests) + 3 (nuevos en
WorkoutGeneratorServiceTests) = 29 tests).

- [ ] **Step 11: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Models/ProfileEnums.swift IronPulse/Models/WorkoutModels.swift \
  IronPulse/Services/WorkoutGeneratorService.swift IronPulse/Views/Workouts/RoutineBuilderView.swift \
  IronPulseTests/WeekdayTests.swift IronPulseTests/WorkoutGeneratorServiceTests.swift
git commit -m "Agrega Weekday y asignacion automatica de dia de la semana a RoutineDay"
```

---

### Task 2: `WorkoutStatsService`

Función pura que calcula todas las métricas de tendencias a partir de
`[WorkoutLog]` ya cargados — sin `ModelContext` ni `@Query` adentro,
testeable con fixtures simples.

**Files:**
- Create: `IronPulse/Services/WorkoutStatsService.swift`
- Test: `IronPulseTests/WorkoutStatsServiceTests.swift`

**Interfaces:**
- Consumes: `Weekday` (Task 1), `WorkoutLog`/`SetLog` (ya existen).
- Produces: `WorkoutStatsService.{totalVolumeKg, workoutCount,
  currentStreak, dailyVolume, progress}`. La Task 6 (`DashboardView`) y
  la Task 5 (`ExerciseProgressView`) llaman a estas funciones.

- [ ] **Step 1: Crear el archivo**

```swift
import Foundation

enum WorkoutStatsService {
    static func totalVolumeKg(_ logs: [WorkoutLog]) -> Double {
        finishedLogs(logs).reduce(0) { $0 + volumeKg(of: $1) }
    }

    static func workoutCount(_ logs: [WorkoutLog]) -> Int {
        finishedLogs(logs).count
    }

    static func currentStreak(
        scheduledWeekdays: Set<Weekday>,
        logs: [WorkoutLog],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard !scheduledWeekdays.isEmpty else { return 0 }

        let completedDays = Set(finishedLogs(logs).map { calendar.startOfDay(for: $0.startDate) })
        let startDay = calendar.startOfDay(for: today)
        var streak = 0

        for offset in 0..<3650 { // ~10 anos: limite defensivo, no hay racha real mas larga
            guard let cursor = calendar.date(byAdding: .day, value: -offset, to: startDay) else { break }
            let weekday = Weekday.today(calendar: calendar, now: cursor)
            guard scheduledWeekdays.contains(weekday) else { continue }
            guard completedDays.contains(cursor) else { break }
            streak += 1
        }

        return streak
    }

    static func dailyVolume(
        _ logs: [WorkoutLog],
        lastDays: Int = 30,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(date: Date, volumeKg: Double)] {
        var volumeByDay: [Date: Double] = [:]
        for log in finishedLogs(logs) {
            let day = calendar.startOfDay(for: log.startDate)
            volumeByDay[day, default: 0] += volumeKg(of: log)
        }

        let startDay = calendar.startOfDay(for: today)
        return (0..<lastDays).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startDay) else { return nil }
            return (date: day, volumeKg: volumeByDay[day] ?? 0)
        }
    }

    static func progress(
        for exerciseId: String,
        in logs: [WorkoutLog],
        calendar: Calendar = .current
    ) -> [(date: Date, maxWeightKg: Double)] {
        var maxWeightByDay: [Date: Double] = [:]
        for log in finishedLogs(logs) {
            let day = calendar.startOfDay(for: log.startDate)
            for set in log.completedSets where set.isCompleted && set.exerciseId == exerciseId {
                maxWeightByDay[day] = max(maxWeightByDay[day] ?? 0, set.weightKg)
            }
        }
        return maxWeightByDay
            .map { (date: $0.key, maxWeightKg: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private static func finishedLogs(_ logs: [WorkoutLog]) -> [WorkoutLog] {
        logs.filter { $0.endDate != nil }
    }

    private static func volumeKg(of log: WorkoutLog) -> Double {
        log.completedSets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.weightKg * Double($1.repsCompleted) }
    }
}
```

- [ ] **Step 2: Tests**

Crear `IronPulseTests/WorkoutStatsServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import IronPulse

struct WorkoutStatsServiceTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeSet(exerciseId: String, weightKg: Double, reps: Int, completed: Bool = true) -> SetLog {
        SetLog(
            exerciseId: exerciseId,
            setIndex: 0,
            weightKg: weightKg,
            repsCompleted: reps,
            restSeconds: 60,
            targetRepsMin: 8,
            targetRepsMax: 12,
            isCompleted: completed
        )
    }

    private func makeLog(start: Date, finished: Bool, sets: [SetLog]) -> WorkoutLog {
        let log = WorkoutLog(startDate: start, endDate: finished ? start : nil, routineName: "R", dayTitle: "D")
        log.completedSets = sets
        return log
    }

    // MARK: - totalVolumeKg / workoutCount

    @Test func sumaSoloSetsCompletadosDeSesionesTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [
                makeSet(exerciseId: "e1", weightKg: 100, reps: 5),
                makeSet(exerciseId: "e1", weightKg: 50, reps: 10, completed: false)
            ]),
            makeLog(start: day(2026, 7, 2), finished: false, sets: [
                makeSet(exerciseId: "e1", weightKg: 999, reps: 999)
            ])
        ]
        #expect(WorkoutStatsService.totalVolumeKg(logs) == 500)
    }

    @Test func sinLogsElVolumenYElConteoSonCero() {
        #expect(WorkoutStatsService.totalVolumeKg([]) == 0)
        #expect(WorkoutStatsService.workoutCount([]) == 0)
    }

    @Test func workoutCountSoloCuentaSesionesTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: []),
            makeLog(start: day(2026, 7, 2), finished: true, sets: []),
            makeLog(start: day(2026, 7, 3), finished: false, sets: [])
        ]
        #expect(WorkoutStatsService.workoutCount(logs) == 2)
    }

    // MARK: - currentStreak

    @Test func sinDiasAsignadosLaRachaEsCero() {
        #expect(WorkoutStatsService.currentStreak(scheduledWeekdays: [], logs: [], today: day(2026, 7, 27)) == 0)
    }

    @Test func rachaPerfectaCuentaLosDiasAsignadosCompletados() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: []),
            makeLog(start: day(2026, 7, 29), finished: true, sets: []),
            makeLog(start: day(2026, 7, 31), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: logs,
            today: day(2026, 7, 31),
            calendar: calendar
        )
        #expect(streak == 3)
    }

    @Test func diaAsignadoSinSesionCortaLaRacha() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: []),
            makeLog(start: day(2026, 7, 31), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: logs,
            today: day(2026, 7, 31),
            calendar: calendar
        )
        #expect(streak == 1)
    }

    @Test func diaDeDescansoNoAsignadoNoCortaLaRacha() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday],
            logs: logs,
            today: day(2026, 7, 28),
            calendar: calendar
        )
        #expect(streak == 1)
    }

    // MARK: - dailyVolume

    @Test func dailyVolumeSiempreDevuelveLaCantidadDeDiasPedida() {
        let points = WorkoutStatsService.dailyVolume([], lastDays: 30, today: day(2026, 7, 31), calendar: calendar)
        #expect(points.count == 30)
        #expect(points.allSatisfy { $0.volumeKg == 0 })
    }

    @Test func dailyVolumeSumaVariasSesionesElMismoDia() {
        let logs = [
            makeLog(start: day(2026, 7, 31), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 100, reps: 5)]),
            makeLog(start: day(2026, 7, 31), finished: true, sets: [makeSet(exerciseId: "e2", weightKg: 50, reps: 10)])
        ]
        let points = WorkoutStatsService.dailyVolume(logs, lastDays: 7, today: day(2026, 7, 31), calendar: calendar)
        #expect(points.last?.volumeKg == 1000)
        #expect(points.last?.date == day(2026, 7, 31))
    }

    // MARK: - progress(for:in:)

    @Test func progresoTomaElPesoMaximoDelDia() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [
                makeSet(exerciseId: "e1", weightKg: 60, reps: 8),
                makeSet(exerciseId: "e1", weightKg: 65, reps: 6),
                makeSet(exerciseId: "otro", weightKg: 999, reps: 1)
            ])
        ]
        let points = WorkoutStatsService.progress(for: "e1", in: logs, calendar: calendar)
        #expect(points.count == 1)
        #expect(points.first?.maxWeightKg == 65)
    }

    @Test func progresoIgnoraSesionesNoTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: false, sets: [
                makeSet(exerciseId: "e1", weightKg: 999, reps: 1)
            ])
        ]
        #expect(WorkoutStatsService.progress(for: "e1", in: logs).isEmpty)
    }
}
```

- [ ] **Step 3: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Correr los tests**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **` (29 + 11 nuevos de `WorkoutStatsServiceTests` = 40).

- [ ] **Step 5: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Services/WorkoutStatsService.swift IronPulseTests/WorkoutStatsServiceTests.swift
git commit -m "Agrega WorkoutStatsService: volumen, racha, grafico de 30 dias y progreso por ejercicio"
```

---

### Task 3: Masa magra (`leanBodyMassKg`) en `HealthSnapshot`

**Files:**
- Modify: `IronPulse/Models/HealthSnapshot.swift` (reemplazo completo)
- Modify: `IronPulse/Services/HealthKitProfileImporter.swift`

**Interfaces:**
- Consumes: nada nuevo (extiende el patrón ya existente de `bodyMassKg`).
- Produces: `HealthSnapshot.leanBodyMassKg: Double?`. La Task 6
  (`DashboardView`) lo lee para la tarjeta de masa magra.

- [ ] **Step 1: Reemplazar `HealthSnapshot.swift`**

```swift
import Foundation
import SwiftData

@Model
final class HealthSnapshot {
    @Attribute(.unique) var id: UUID
    var capturedAt: Date
    var source: String
    var bodyMassKg: Double?
    var leanBodyMassKg: Double?
    var heightCm: Double?
    var biologicalSex: BiologicalSex
    var dateOfBirth: Date?
    var stepCount: Double?
    var activeEnergyKcal: Double?
    var restingHeartRateBPM: Double?
    var workoutMinutes: Double?
    var profile: UserProfile?

    init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        source: String = "HealthKit",
        bodyMassKg: Double? = nil,
        leanBodyMassKg: Double? = nil,
        heightCm: Double? = nil,
        biologicalSex: BiologicalSex = .notSet,
        dateOfBirth: Date? = nil,
        stepCount: Double? = nil,
        activeEnergyKcal: Double? = nil,
        restingHeartRateBPM: Double? = nil,
        workoutMinutes: Double? = nil,
        profile: UserProfile? = nil
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.source = source
        self.bodyMassKg = bodyMassKg
        self.leanBodyMassKg = leanBodyMassKg
        self.heightCm = heightCm
        self.biologicalSex = biologicalSex
        self.dateOfBirth = dateOfBirth
        self.stepCount = stepCount
        self.activeEnergyKcal = activeEnergyKcal
        self.restingHeartRateBPM = restingHeartRateBPM
        self.workoutMinutes = workoutMinutes
        self.profile = profile
    }
}
```

- [ ] **Step 2: Pedir el tipo en `readTypes`**

En `IronPulse/Services/HealthKitProfileImporter.swift`, dentro de `var
readTypes: Set<HKObjectType>`, agregar este bloque justo después del de
`bodyMass`:

```swift
if let leanBodyMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
    types.insert(leanBodyMass)
}
```

- [ ] **Step 3: Leerlo en `makeSnapshot()`**

En el mismo archivo, dentro de `makeSnapshot(for:)`, agregar la línea
`async let leanBodyMass = latestQuantity(.leanBodyMass, unit:
.gramUnit(with: .kilo))` junto a la de `bodyMass`, y pasar
`leanBodyMassKg: try await leanBodyMass` al `HealthSnapshot(...)` que se
construye ahí (junto a `bodyMassKg: try await bodyMass`).

- [ ] **Step 4: Borrar la app del simulador (migración de SwiftData)**

```bash
xcrun simctl uninstall B93C823F-AAD5-46AF-B830-8A8390325C5F com.BERNU.IronPulse
```

- [ ] **Step 5: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Correr los tests de regresión**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **` (sin cambio de conteo — esta tarea no
toca tests, `HealthKitProfileImporter` no tiene tests dedicados hoy
tampoco, igual que antes de esta tarea).

- [ ] **Step 7: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Models/HealthSnapshot.swift IronPulse/Services/HealthKitProfileImporter.swift
git commit -m "Agrega masa magra (leanBodyMassKg) al importador de Salud"
```

---

### Task 4: `GuidedSessionFlow` + auto-avance en `ActiveWorkoutView`

Al completar el set activo, descansa 60-90s según `Exercise.isCompound`
y avanza solo al siguiente. Si se marca no completado, no pasa nada —
sin descanso ni avance, el usuario sigue a su ritmo.

**Files:**
- Create: `IronPulse/Services/GuidedSessionFlow.swift`
- Test: `IronPulseTests/GuidedSessionFlowTests.swift`
- Modify: `IronPulse/Views/Workouts/ActiveWorkoutView.swift` (reemplazo completo)

**Interfaces:**
- Consumes: `Exercise.isCompound` (ya existe).
- Produces: `GuidedSessionFlow.{restSeconds, nextSetID}`. Sin cambios en
  la firma pública de `ActiveWorkoutView(log:)` — las Tasks 5/6 (y el
  `RoutineTabView`/`DashboardView` ya existentes) siguen instanciándola igual.

- [ ] **Step 1: Crear `GuidedSessionFlow`**

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
}
```

- [ ] **Step 2: Tests**

```swift
import Foundation
import Testing
@testable import IronPulse

struct GuidedSessionFlowTests {

    private func makeSet(_ index: Int) -> SetLog {
        SetLog(
            exerciseId: "e1",
            setIndex: index,
            weightKg: 0,
            repsCompleted: 0,
            restSeconds: 60,
            targetRepsMin: 8,
            targetRepsMax: 12
        )
    }

    @Test func compuestoDescansaNoventaSegundos() {
        #expect(GuidedSessionFlow.restSeconds(isCompound: true) == 90)
    }

    @Test func aislamientoDescansaSesentaSegundos() {
        #expect(GuidedSessionFlow.restSeconds(isCompound: false) == 60)
    }

    @Test func avanzaAlSiguienteSetEnOrden() {
        let sets = [makeSet(0), makeSet(1), makeSet(2)]
        #expect(GuidedSessionFlow.nextSetID(after: sets[0].id, in: sets) == sets[1].id)
    }

    @Test func elUltimoSetNoTieneSiguiente() {
        let sets = [makeSet(0), makeSet(1)]
        #expect(GuidedSessionFlow.nextSetID(after: sets[1].id, in: sets) == nil)
    }

    @Test func sinSetActivoNoHaySiguiente() {
        let sets = [makeSet(0), makeSet(1)]
        #expect(GuidedSessionFlow.nextSetID(after: nil, in: sets) == nil)
    }

    @Test func idQueNoEstaEnLaListaNoTieneSiguiente() {
        let sets = [makeSet(0), makeSet(1)]
        let otro = makeSet(99)
        #expect(GuidedSessionFlow.nextSetID(after: otro.id, in: sets) == nil)
    }
}
```

- [ ] **Step 3: Reemplazar `ActiveWorkoutView.swift` completo**

```swift
import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: WorkoutLog
    @Query private var catalog: [Exercise]
    @State private var restRemaining: Int = 0
    @State private var restTask: Task<(), Never>? = nil
    @State private var activeSetID: SetLog.ID?

    private var isReadOnly: Bool { log.endDate != nil }

    private var exerciseNames: [String: String] {
        Dictionary(catalog.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var flatSets: [SetLog] {
        log.completedSets.sorted { $0.setIndex < $1.setIndex }
    }

    private var groupedSets: [(exerciseId: String, sets: [SetLog])] {
        let sorted = flatSets
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
            if !isReadOnly {
                await RestNotificationScheduler.requestAuthorizationIfNeeded()
            }
        }
        .onAppear {
            if !isReadOnly && activeSetID == nil {
                activeSetID = flatSets.first?.id
            }
        }
        .onDisappear {
            restTask?.cancel()
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

        guard set.id == activeSetID, set.isCompleted else { return }
        HapticFeedback.setCompleted()
        let seconds = restSeconds(for: set)
        startRest(seconds: seconds) { advanceToNextSet() }
        RestNotificationScheduler.scheduleRestFinished(in: seconds)
    }

    private func restSeconds(for set: SetLog) -> Int {
        let isCompound = catalog.first { $0.id == set.exerciseId }?.isCompound ?? false
        return GuidedSessionFlow.restSeconds(isCompound: isCompound)
    }

    private func advanceToNextSet() {
        activeSetID = GuidedSessionFlow.nextSetID(after: activeSetID, in: flatSets)
    }

    private func startRest(seconds: Int, onFinished: @escaping () -> Void) {
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
                onFinished()
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

- [ ] **Step 4: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Correr los tests**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **` (40 + 6 de `GuidedSessionFlowTests` = 46).

- [ ] **Step 6: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Services/GuidedSessionFlow.swift IronPulseTests/GuidedSessionFlowTests.swift \
  IronPulse/Views/Workouts/ActiveWorkoutView.swift
git commit -m "Agrega auto-avance a ActiveWorkoutView: descanso 60-90s por isCompound, avanza solo al siguiente set"
```

---

### Task 5: `ExerciseProgressView` (nuevo)

Vista chica de progreso de un ejercicio — la Task 6 la referencia desde
`DashboardView`, así que va antes para no dejar una referencia rota a
mitad de plan.

**Files:**
- Create: `IronPulse/Views/Workouts/ExerciseProgressView.swift`

**Interfaces:**
- Consumes: `WorkoutStatsService.progress(for:in:)` (Task 2).
- Produces: `ExerciseProgressView(profile: UserProfile, exercise:
  Exercise)`. La Task 6 navega a esta vista.

- [ ] **Step 1: Crear el archivo**

```swift
import SwiftUI
import Charts

struct ExerciseProgressView: View {
    let profile: UserProfile
    let exercise: Exercise

    private var points: [(date: Date, maxWeightKg: Double)] {
        WorkoutStatsService.progress(for: exercise.id, in: profile.workoutLogs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.name).font(.ironTitle)

                if points.isEmpty {
                    ContentUnavailableView(
                        "Sin datos todavia",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Todavia no completaste ningun set de este ejercicio.")
                    )
                } else {
                    Chart(points, id: \.date) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.maxWeightKg))
                            .foregroundStyle(Color.ironAccent)
                        PointMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.maxWeightKg))
                            .foregroundStyle(Color.ironAccent)
                    }
                    .frame(height: 220)
                    .ironCard()
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle("Progreso")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ExerciseProgressView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Progreso")
            .preferredColorScheme(.dark)
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD" | sort -u
```
Esperado: `** BUILD SUCCEEDED **` (esta vista todavia no se referencia
desde ningun lado — se conecta en la Task 6 — pero debe compilar sola).

- [ ] **Step 3: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Views/Workouts/ExerciseProgressView.swift
git commit -m "Agrega ExerciseProgressView: grafico de peso maximo por sesion de un ejercicio"
```

---

### Task 6: Rediseño de `DashboardView`

Junta todo: tarjeta de "hoy" (con el botón "Iniciar ejercicios"),
métricas, gráfico de 30 días, masa magra, progreso por ejercicio, y el
link al historial que ya existía.

**Files:**
- Modify: `IronPulse/Views/Workouts/DashboardView.swift` (reemplazo completo)

**Interfaces:**
- Consumes: `Weekday.today()` (Task 1), `WorkoutStatsService` (Task 2),
  `HealthSnapshot.leanBodyMassKg` (Task 3), `WorkoutLogGenerator.generate`
  (ya existe, Fase 5), `ActiveWorkoutView` (Task 4), `ExerciseProgressView`
  (Task 5), `WorkoutHistoryView` (ya existe, Fase 5).
- Produces: sin cambios en la firma pública — sigue siendo
  `DashboardView(profile: UserProfile)`. `MainTabView` no cambia.

- [ ] **Step 1: Reemplazar `DashboardView.swift` completo**

```swift
import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @Query private var catalog: [Exercise]

    @State private var activeLog: WorkoutLog?

    private var todaysDay: RoutineDay? {
        profile.activeRoutine?.days.first { $0.weekday == Weekday.today() }
    }

    private var trainedExercises: [Exercise] {
        let trainedIds = Set(
            profile.workoutLogs
                .filter { $0.endDate != nil }
                .flatMap { $0.completedSets.filter(\.isCompleted).map(\.exerciseId) }
        )
        return catalog.filter { trainedIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    private var leanMassEntries: [HealthSnapshot] {
        profile.healthSnapshots
            .filter { $0.leanBodyMassKg != nil }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    private var currentStreak: Int {
        guard let routine = profile.activeRoutine else { return 0 }
        let scheduledWeekdays = Set(routine.days.map(\.weekday))
        return WorkoutStatsService.currentStreak(scheduledWeekdays: scheduledWeekdays, logs: profile.workoutLogs)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                todaysCard
                metricsRow
                progressChart
                leanMassCard
                exerciseProgressSection
                historyLink
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.ironBackground)
        .navigationTitle(profile.name)
        .navigationDestination(item: $activeLog) { log in
            ActiveWorkoutView(log: log)
        }
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

    @ViewBuilder
    private var todaysCard: some View {
        if profile.activeRoutine == nil {
            ContentUnavailableView(
                "Sin rutina activa",
                systemImage: "bolt.slash",
                description: Text("Genera una rutina automatica o arma la tuya desde la tab Rutina.")
            )
        } else if let day = todaysDay {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hoy: \(day.title)").font(.headline)
                ForEach(day.exercises.sorted { $0.orderIndex < $1.orderIndex }) { ex in
                    Text(ex.exercise.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.ironTextSecondary)
                }
                Button("Iniciar ejercicios", action: startTodaysSession)
                    .buttonStyle(PrimarySportButtonStyle())
            }
            .ironCard()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Descanso hoy").font(.headline)
                Text("Hoy no hay ningun dia de la rutina asignado.")
                    .font(.subheadline)
                    .foregroundStyle(Color.ironTextSecondary)
            }
            .ironCard()
        }
    }

    private var metricsRow: some View {
        HStack {
            metric("Volumen", "\(Int(WorkoutStatsService.totalVolumeKg(profile.workoutLogs))) kg")
            Spacer()
            metric("Entrenamientos", "\(WorkoutStatsService.workoutCount(profile.workoutLogs))")
            Spacer()
            metric("Racha", diasLabel(currentStreak))
        }
        .ironCard()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3).fontWeight(.black)
            Text(title).font(.caption).foregroundStyle(Color.ironTextSecondary)
        }
    }

    private var progressChart: some View {
        let points = WorkoutStatsService.dailyVolume(profile.workoutLogs)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Progreso (30 dias)").font(.headline)
            Chart(points, id: \.date) { point in
                AreaMark(x: .value("Dia", point.date), y: .value("Volumen", point.volumeKg))
                    .foregroundStyle(Color.ironAccent.opacity(0.2))
                LineMark(x: .value("Dia", point.date), y: .value("Volumen", point.volumeKg))
                    .foregroundStyle(Color.ironAccent)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 15))
            }
            .frame(height: 140)
        }
        .ironCard()
    }

    @ViewBuilder
    private var leanMassCard: some View {
        if leanMassEntries.count >= 2,
           let firstValue = leanMassEntries.first?.leanBodyMassKg,
           let lastValue = leanMassEntries.last?.leanBodyMassKg {
            let delta = lastValue - firstValue
            VStack(alignment: .leading, spacing: 4) {
                Text("Masa magra").font(.headline)
                Text(String(format: "%.1f kg (%@%.1fkg desde que empezaste)", lastValue, delta >= 0 ? "+" : "", delta))
                    .font(.subheadline)
                    .foregroundStyle(Color.ironTextSecondary)
            }
            .ironCard()
        }
    }

    @ViewBuilder
    private var exerciseProgressSection: some View {
        if !trainedExercises.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Progreso por ejercicio").font(.headline)
                ForEach(trainedExercises) { exercise in
                    NavigationLink {
                        ExerciseProgressView(profile: profile, exercise: exercise)
                    } label: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.ironTextSecondary)
                    }
                }
            }
            .ironCard()
        }
    }

    private var historyLink: some View {
        NavigationLink {
            WorkoutHistoryView(profile: profile)
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

    private func startTodaysSession() {
        guard let routine = profile.activeRoutine, let day = todaysDay else { return }
        let log = WorkoutLogGenerator.generate(for: day, routineName: routine.name, profile: profile)
        modelContext.insert(log)
        try? modelContext.save()
        activeLog = log
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        Text("Dashboard")
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
Esperado: `** TEST SUCCEEDED **` (46, sin cambio — esta tarea no toca tests).

- [ ] **Step 4: Commit**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
git add IronPulse/Views/Workouts/DashboardView.swift
git commit -m "Rediseña DashboardView: tarjeta de hoy, metricas, grafico de 30 dias, masa magra y progreso por ejercicio"
```

---

### Task 7: Verificación completa en simulador

Tarea de verificación pura, sin cambios de código — la última línea de
defensa antes del review final. Si algún paso no se comporta como se
espera, es un hallazgo real de esta tarea — no seguir adelante
silenciosamente. Documentar qué se vio vs. qué se esperaba.

**Files:** ninguno (solo verificación).

**Interfaces:** ninguna (consume todo lo de las Tasks 1-6).

- [ ] **Step 1: Instalación limpia**

```bash
xcrun simctl uninstall B93C823F-AAD5-46AF-B830-8A8390325C5F com.BERNU.IronPulse
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -derivedDataPath /tmp/ip_build build
```
Instalar y lanzar el `.app` resultante en el simulador (UDID de
referencia de arriba).

- [ ] **Step 2: Crear un perfil de 3 dias/semana**

Verificar que se cree con nivel/objetivo por defecto. Generar una
rutina inteligente (3 dias → Torso/Pierna/Torso).

- [ ] **Step 3: Verificar la asignación de días**

Confirmar contra la tabla de la Task 1 que los 3 días quedaron
Lunes/Miércoles/Viernes — no hay UI directa para ver el `weekday` de
cada `RoutineDay` (fuera de alcance del spec), así que esto se verifica
indirectamente: si hoy es uno de esos 3 días, `DashboardView` debe
mostrar la tarjeta de "Hoy: <título>" con botón "Iniciar ejercicios"; si
no, debe mostrar "Descanso hoy".

- [ ] **Step 4: Flujo guiado completo**

Si hoy cae en un día asignado: tocar "Iniciar ejercicios", confirmar que
el primer set del primer ejercicio aparece resaltado. Tildar ese set:
confirmar que arranca el descanso (60s si el ejercicio es de aislamiento,
90s si es compuesto — chequear `Exercise.isCompound` del ejercicio en
cuestión para saber cuál esperar) y que, al llegar a 0, el resaltado se
mueve solo al siguiente set sin ninguna acción del usuario. Repetir para
un segundo set. En algún set, marcarlo como NO completado (destildar) y
confirmar que NO arranca descanso ni se mueve el resaltado — el usuario
sigue interactuando a mano.

Si hoy NO cae en un día asignado: cambiar la fecha del simulador
(`xcrun simctl` no tiene un comando directo para esto — usar Ajustes >
General > Fecha y hora dentro del simulador, o generar una rutina con 7
días/semana para garantizar que cualquier día de hoy esté cubierto) y
reintentar este paso.

- [ ] **Step 5: Terminar la sesión y verificar métricas**

Tocar "Terminar". Volver al Dashboard: confirmar que "Entrenamientos"
subió en 1, que "Volumen" refleja los pesos/reps cargados, y que el
gráfico de 30 días muestra un punto distinto de 0 en el día de hoy.

- [ ] **Step 6: Progreso por ejercicio**

Confirmar que la sección "Progreso por ejercicio" lista los ejercicios
recién entrenados, y que tocar uno abre `ExerciseProgressView` con un
gráfico de al menos un punto.

- [ ] **Step 7: Masa magra (si HealthKit tiene el dato)**

Si el simulador no tiene datos de salud simulados, confirmar que la
tarjeta de masa magra simplemente no aparece (sin crash, sin
placeholder) — comportamiento esperado sin datos suficientes, no un bug.

- [ ] **Step 8: Historial sigue funcionando**

Confirmar que "Ver historial de entrenamientos" sigue navegando a
`WorkoutHistoryView` y muestra la sesión recién terminada.

- [ ] **Step 9: Regresión — flujo manual desde la tab Rutina**

Desde la tab Rutina, tocar "Empezar" en un día cualquiera (no
necesariamente el de hoy) y confirmar que el mismo auto-avance funciona
ahí también (Decisión: auto-avance es el único comportamiento de
`ActiveWorkoutView`, sin importar el punto de entrada).

- [ ] **Step 10: Correr el suite completo una vez más**

```bash
cd /Users/diego/Documents/IRONPULSE/IronPulse
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:IronPulseTests 2>&1 \
  | grep -E "\*\* TEST" | sort -u
```
Esperado: `** TEST SUCCEEDED **`.

---
