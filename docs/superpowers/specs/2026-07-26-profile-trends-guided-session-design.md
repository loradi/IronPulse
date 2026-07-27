# Tendencias de perfil + sesión guiada con auto-avance

## Contexto

Hoy, tocar un perfil lleva a un `TabView` (Dashboard/Rutina/Ejercicios/
Perfil) donde lo más cercano a "progreso" es un link a
`WorkoutHistoryView`: una lista simple de sesiones terminadas, sin
tendencias ni forma de ver el progreso de un ejercicio en particular.
Tampoco existe el concepto de "qué día de la rutina toca hoy" — un
`RoutineDay` solo tiene un `dayNumber` secuencial dentro del ciclo del
split (Día 1, Día 2...), sin relación con el calendario real. Y
`ActiveWorkoutView` (Fase 5) requiere que el usuario tilde cada set a
mano, sin descanso ni avance automático entre sets.

Esta spec agrega: (A) una pantalla de tendencias/estadísticas, (B) el
concepto de "día de la semana" asignado a cada día de rutina + una
tarjeta de "hoy", y (C) auto-avance en `ActiveWorkoutView`: al completar
un set, descansa 60-90s según la intensidad del ejercicio y arranca solo
el siguiente. Se diseñan juntas porque viven en la misma pantalla y la
racha (parte de A) depende de la programación semanal (parte B).

Referencia visual: `MOCKUPS/perfil_de_usuario/`, `MOCKUPS/mi_rutina/` y
`MOCKUPS/sesi_n_en_curso/` (carpeta `MOCKUPS/` documentada en
`PROGRESS.md`, todavía sin decisión sobre el rebrand/reskin completo —
acá solo se toman las ideas de contenido y layout, **no** el tema visual
"Kinetic Onyx").

## Decisiones (con el usuario, 2026-07-26)

- **Alcance**: un solo spec para tendencias + sesión guiada, no dos
  proyectos separados — están relacionadas y se pidieron juntas.
- **"Día de hoy"**: por día de la semana real (no por secuencia desde el
  último entrenamiento). Cada `RoutineDay` se asigna a un día de la
  semana automáticamente al crear/guardar la rutina, sin que el usuario
  lo elija.
- **Intensidad → descanso**: se deriva de `Exercise.isCompound` (ya
  existe, cero campos nuevos ni migración de datos del catálogo).
  Compuesto = 90s, aislamiento = 60s.
- **El nuevo descanso reemplaza al viejo en la sesión guiada**:
  `RoutineExercise.restSeconds` (fijado por objetivo al crear la rutina)
  deja de controlar el timer real de `ActiveWorkoutView`. Sigue
  existiendo y lo sigue mostrando/editando el armador manual como valor
  sugerido, pero durante la sesión el descanso real siempre sale de
  `isCompound`.
- **Auto-avance es el único comportamiento de `ActiveWorkoutView`**, sin
  distinción entre "empezar un día cualquiera desde la tab Rutina" y
  "iniciar el día de hoy desde tendencias" — ambos entran a la misma
  vista con el mismo comportamiento.
- **Set no completado**: el auto-avance se pausa y espera que el usuario
  decida (no hay reintento automático ni avance sin descanso).
- **Métricas de tendencias**: volumen total, cantidad de entrenamientos,
  racha, gráfico de progreso de 30 días, progreso por ejercicio, y lean
  mass de HealthKit — las 6, todas en este spec.

## Modelo de datos

### `RoutineDay` — nuevo campo `weekday`

```swift
enum Weekday: Int, Codable, CaseIterable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    static func today(calendar: Calendar = .current, now: Date = Date()) -> Weekday {
        // Calendar.component(.weekday) es 1=domingo..7=sabado (US calendar);
        // se remapea a nuestro enum (1=lunes..7=domingo) para no heredar esa
        // convención hacia el resto del código.
        let raw = calendar.component(.weekday, from: now) // 1...7, domingo=1
        let mondayFirst = (raw + 5) % 7 + 1 // domingo(1)->7, lunes(2)->1, ...
        return Weekday(rawValue: mondayFirst)!
    }
}
```

`RoutineDay` gana `var weekday: Weekday` (no-opcional). Se asigna al
crearse, tanto en `WorkoutGeneratorService.generateRoutine` como en
`RoutineBuilderView.save()`, usando la tabla de abajo indexada por
posición dentro de los días de la rutina — no depende de qué split sea.

**Tabla de asignación automática** (nueva, `WorkoutGeneratorService.
weekdaysForCount(_ count: Int) -> [Weekday]`, uno por posición):

| días/semana | días asignados (en orden) |
|---|---|
| 1 | Lunes |
| 2 | Lunes, Jueves |
| 3 | Lunes, Miércoles, Viernes |
| 4 | Lunes, Martes, Jueves, Viernes |
| 5 | Lunes a Viernes |
| 6 | Lunes a Sábado |
| 7 | Todos los días |

`dayCount` ya está acotado a `1...7` en ambos flujos (stepper con ese
rango), así que la tabla no necesita un caso por defecto.

### `HealthSnapshot` — nuevo campo `leanBodyMassKg`

```swift
var leanBodyMassKg: Double?
```

Mismo patrón que `bodyMassKg`: opcional, `nil` si HealthKit no tiene el
dato o no se concedió el permiso. `HealthKitProfileImporter.readTypes`
agrega `HKQuantityTypeIdentifier.leanBodyMass` al mismo set que ya se
pide (sin permiso nuevo que solicitar aparte — se pide junto con el
resto la primera vez que el usuario toca "Importar datos de Salud").
`makeSnapshot()` agrega `async let leanBodyMass = latestQuantity(
.leanBodyMass, unit: .gramUnit(with: .kilo))`, mismo helper que ya
existe para `bodyMassKg`.

### Sin campos nuevos para métricas derivadas

Volumen total, conteo de entrenamientos, racha, y los puntos del
gráfico de 30 días **no se persisten** — se calculan al leer, sobre los
`WorkoutLog`/`SetLog` que ya existen. Es una app de un solo usuario
local, sin sincronización ni volumen de datos que justifique cachear
esto; agregar campos derivados hoy sería una fuente de bugs de
consistencia sin necesidad real (YAGNI).

**Migración**: `weekday` es un campo no-opcional nuevo en un `@Model` de
SwiftData sin plan de migración — mismo workaround ya usado en Fases 3 y
5 (y reconfirmado en la limpieza chica del 2026-07-26 con el rename de
`isGeneratedByAI`): `xcrun simctl uninstall <device> com.BERNU.IronPulse`
antes de compilar/correr. Sin `VersionedSchema`, no hay usuarios reales.

## `Services/WorkoutGeneratorService.swift` (agrega función)

```swift
extension WorkoutGeneratorService {
    static func weekdaysForCount(_ count: Int) -> [Weekday]
}
```

Función pura, tabla fija de arriba (`switch count`), usada por
`generateRoutine` (asigna `weekday: weekdaysForCount(count)[index]` al
crear cada `RoutineDay`) y por `RoutineBuilderView.save()` de la misma
forma.

**Tests**: para cada `count` en `1...7`, `weekdaysForCount(count).count
== count` y matchea la tabla exacta de arriba.

## `Services/WorkoutStatsService.swift` (nuevo)

Mismo espíritu que `WorkoutGeneratorService`/`WorkoutLogGenerator`:
funciones puras y sincrónicas sobre arrays ya cargados (`[WorkoutLog]`),
sin `ModelContext` ni `@Query` adentro — reciben los logs del perfil
como parámetro, para poder testear con fixtures sin `ModelContainer`.

```swift
enum WorkoutStatsService {
    static func totalVolumeKg(_ logs: [WorkoutLog]) -> Double
    static func workoutCount(_ logs: [WorkoutLog]) -> Int
    static func currentStreak(
        scheduledWeekdays: Set<Weekday>,
        logs: [WorkoutLog],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int
    static func dailyVolume(
        _ logs: [WorkoutLog],
        lastDays: Int = 30,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(date: Date, volumeKg: Double)]
    static func progress(
        for exerciseId: String,
        in logs: [WorkoutLog]
    ) -> [(date: Date, maxWeightKg: Double)]
}
```

- `totalVolumeKg`: suma `weightKg * Double(repsCompleted)` de todo
  `SetLog` con `isCompleted == true`, en todo `WorkoutLog` con `endDate
  != nil`.
- `workoutCount`: cuenta de `logs` con `endDate != nil`.
- `currentStreak`: recorre días calendario hacia atrás desde `today`
  (inclusive). Por cada día: si su `Weekday` no está en
  `scheduledWeekdays`, se salta (no suma ni corta). Si está, busca un log
  con `endDate != nil` cuyo `startDate` caiga ese día calendario — si lo
  encuentra, sigue contando y retrocede un día más; si no lo encuentra,
  corta ahí y devuelve lo acumulado hasta el día anterior.
- `dailyVolume`: para cada uno de los últimos `lastDays` días calendario
  (incluido hoy), suma el volumen (misma fórmula que `totalVolumeKg`) de
  los `SetLog` completados de los logs cuyo `startDate` caiga ese día —
  `0` si no hay logs ese día. Devuelve siempre `lastDays` puntos, en
  orden cronológico, para que el gráfico no tenga huecos.
- `progress(for:in:)`: filtra `SetLog` con `exerciseId` igual y
  `isCompleted == true` a través de todos los `logs` con `endDate !=
  nil`, agrupados por el `startDate` (día) de su `WorkoutLog`, tomando el
  `weightKg` máximo de ese día. Devuelve ordenado cronológicamente.

**Tests** (`IronPulseTests/WorkoutStatsServiceTests.swift`, nuevo):
- `totalVolumeKg`/`workoutCount`: casos con 0 logs, logs sin terminar
  (no cuentan), varios logs con sets completos e incompletos mezclados.
- `currentStreak`: sin logs (0), racha perfecta de N días, un día
  asignado sin log corta la racha en ese punto, un día de descanso
  (no asignado) en el medio no corta nada, streak que arranca hoy mismo
  si hoy ya se completó.
- `dailyVolume`: siempre devuelve `lastDays` puntos aunque no haya datos;
  un día con dos sesiones suma ambas.
- `progress(for:in:)`: toma el máximo del día cuando hay varios sets del
  mismo ejercicio en la misma sesión; ignora sets de otros ejercicios;
  ignora logs no terminados.

## `Views/Workouts/DashboardView.swift` (rediseño, no una vista nueva)

`DashboardView` ya es la pantalla a la que se llega al tocar un perfil
(primer tab de `MainTabView`) y ya tiene el link "Ver historial de
entrenamientos" que el usuario señaló como "ahora solo esta mostrando el
historial" — se extiende ahí mismo, no se agrega una vista/tab nueva.
Reemplaza el resumen actual (header + `Text("\(active.name) ·
\(diasLabel(...))")` + link a historial). Estructura, de arriba a abajo:

1. **Tarjeta "hoy"**: si `profile.activeRoutine` es `nil`, el mismo
   estado vacío que ya existe en `RoutineTabView` ("Sin rutina activa").
   Si hay rutina activa, busca `routine.days.first { $0.weekday ==
   Weekday.today() }`:
   - Si lo encuentra: título del día + lista de sus ejercicios + botón
     **"Iniciar ejercicios"** que genera el `WorkoutLog` (mismo
     `WorkoutLogGenerator.generate` que ya usa `RoutineTabView`) y
     navega a `ActiveWorkoutView`.
   - Si no hay día asignado a hoy: tarjeta "Descanso hoy", sin botón.
2. **Fila de métricas**: volumen total, entrenamientos, racha — tres
   `LabeledContent` o tarjetas chicas, vía `WorkoutStatsService`.
3. **Gráfico de progreso (30 días)**: `Chart` de Swift Charts (nativo,
   iOS 16+; el proyecto ya requiere iOS 17+, cero dependencia nueva) con
   `dailyVolume(profile.workoutLogs)`. `AreaMark` + `LineMark` sobre
   `Color.ironAccent`, eje X con solo un par de fechas etiquetadas (no
   las 30) para no saturar.
4. **Lean mass**: si hay al menos 2 `HealthSnapshot` del perfil con
   `leanBodyMassKg != nil`, tarjeta con el último valor y la diferencia
   contra el primero (`"+X.Xkg desde que empezaste"`). Si no hay
   suficientes datos, la tarjeta no se muestra — sin placeholder.
5. **Progreso por ejercicio**: lista de los ejercicios que el perfil ya
   entrenó al menos una vez (`Set<String>` de `exerciseId` sacado de
   `workoutLogs`), cada uno navega a `ExerciseProgressView(profile:
   exercise:)`.
6. **Link al historial**: el mismo `NavigationLink` a
   `WorkoutHistoryView(profile:)` que ya existe, sin cambios de
   comportamiento — solo se reordena dentro de la pantalla más larga.

`header` (nombre, nivel/objetivo) se mantiene igual, arriba de todo.

## `Views/Workouts/ExerciseProgressView.swift` (nuevo)

Recibe `profile: UserProfile` y `exercise: Exercise`. Un `Chart` de
`WorkoutStatsService.progress(for: exercise.id, in: profile.
workoutLogs)` — `LineMark` de peso máximo por sesión a lo largo del
tiempo, con `PointMark` en cada dato real (pocos puntos, no una curva
densa). Sin paginado ni filtro de rango — todo el historial del
ejercicio, ya acotado naturalmente a lo que el usuario entrenó.

## `ActiveWorkoutView.swift` (auto-avance)

Nuevo estado, además de lo que ya existe:

```swift
@State private var activeSetID: SetLog.ID?
```

`flatSets: [SetLog]` — el mismo `log.completedSets.sorted { $0.setIndex
< $1.setIndex }` que ya arma `groupedSets`, sin agrupar; es el orden que
recorre el auto-avance.

Al entrar a la vista (si `!isReadOnly`), `activeSetID` se setea al
primer elemento de `flatSets` apenas aparece (no requiere un tap
adicional — "el primer set arranca automáticamente" al entrar a la
sesión, ya con el botón "Iniciar ejercicios" de la tarjeta de hoy en
`DashboardView` habiendo sido el gesto explícito del usuario).

La fila del set con `id == activeSetID` se resalta (borde
`Color.ironAccent`, ya hay un patrón de borde/glow en `Theme/
CustomColor.swift`). El resto de la interacción de esa fila (`TextField`
de peso, `Stepper` de reps, el círculo tildable) sigue igual — el
resaltado es visual, no cambia qué controles están habilitados.

`toggleCompleted(_:)` cambia de forma:

```swift
private func toggleCompleted(_ set: SetLog) {
    set.isCompleted.toggle()
    set.timestamp = Date()
    try? modelContext.save()

    guard set.id == activeSetID else { return } // tildar un set fuera de orden no dispara auto-avance
    guard set.isCompleted else { return } // no completado: no arranca descanso ni avanza, se queda esperando
    HapticFeedback.setCompleted()
    let seconds = restSeconds(for: set)
    startRest(seconds: seconds) { advanceToNextSet() }
    RestNotificationScheduler.scheduleRestFinished(in: seconds)
}

private func restSeconds(for set: SetLog) -> Int {
    exercise(for: set)?.isCompound == true ? 90 : 60
}

private func advanceToNextSet() {
    guard let currentIndex = flatSets.firstIndex(where: { $0.id == activeSetID }),
          currentIndex + 1 < flatSets.count else {
        activeSetID = nil // fue el ultimo set, no hay mas que resaltar
        return
    }
    activeSetID = flatSets[currentIndex + 1].id
}
```

`startRest(seconds:onFinished:)` gana un parámetro de callback (hoy no
tiene ninguno, solo actualiza `restRemaining` y hace haptic al llegar a
0) — al llegar a 0 sin haber sido cancelado, además de lo que ya hace,
llama `onFinished()`.

Marcar un set como completado que **no** es el `activeSetID` (el usuario
vuelve atrás y edita un set ya pasado) no dispara descanso ni avance —
solo actualiza el dato, igual que hoy. El auto-avance solo se dispara
sobre el set activo, en orden.

`exercise(for:)` — helper chico para resolver `Exercise` desde
`exerciseId` vía el `catalog: [Exercise]` que la vista ya tiene con
`@Query`, análogo a `exerciseNames` que ya existe.

**No completado**: no se arranca descanso ni se llama
`advanceToNextSet()` — el `activeSetID` no cambia. La vista no necesita
estado ni botón nuevo para esto: sin descanso corriendo, `restRemaining`
se queda en 0 y no se muestra ningún contador (mismo comportamiento que
hoy), y el usuario sigue interactuando con la lista a su ritmo (puede
reintentar el mismo set editando peso/reps y volviendo a tildar, o
tildar el siguiente a mano).

## Archivos afectados

**Nuevos:**
- `Services/WorkoutStatsService.swift`
- `Views/Workouts/ExerciseProgressView.swift`
- `IronPulseTests/WorkoutStatsServiceTests.swift`
- `IronPulseTests/WeekdayAssignmentTests.swift` (o agregado a
  `WorkoutGeneratorServiceTests.swift` existente)

**Modificados:**
- `Models/WorkoutModels.swift` (`RoutineDay` +1 campo: `weekday`)
- `Models/HealthSnapshot.swift` (+1 campo: `leanBodyMassKg`)
- `Services/WorkoutGeneratorService.swift` (+`weekdaysForCount`, asigna
  `weekday` en `generateRoutine`)
- `Services/HealthKitProfileImporter.swift` (+`leanBodyMass` en
  `readTypes` y `makeSnapshot`)
- `Views/Workouts/RoutineBuilderView.swift` (asigna `weekday` en `save()`)
- `Views/Workouts/ActiveWorkoutView.swift` (auto-avance, descanso por
  `isCompound`)
- `Views/Workouts/DashboardView.swift` (rediseño: tarjeta de hoy +
  métricas + gráfico + lean mass + progreso por ejercicio + historial,
  ver sección propia arriba).

## Fuera de alcance

- Rebrand/reskin visual "Kinetic Onyx" de `MOCKUPS/` — sigue como
  decisión aparte, esta spec solo toma ideas de contenido/layout.
- Elegir manualmente el día de la semana de cada `RoutineDay` — queda
  automático; si más adelante se pide edición manual, es una spec
  chica aparte (agregar un picker, la asignación automática queda como
  default).
- Reprogramar/correr los días si se salta uno (el modelo es "día de la
  semana fijo", no "el próximo día disponible") — si el usuario no
  entrena el día asignado, esa sesión de esa semana queda perdida, no se
  corre a otro día.
- Botón de "continuar" explícito tras un set no completado — el usuario
  sigue interactuando a mano con la lista, sin un control nuevo.
- Prellenar peso/reps con el valor de la sesión anterior — ya estaba
  fuera de alcance en la Fase 5, sigue igual acá.
- `-15s`/`+15s` de ajuste manual del descanso (visible en los mockups de
  sesión en curso) — el descanso es fijo por `isCompound`, sin ajuste
  manual en esta iteración.
