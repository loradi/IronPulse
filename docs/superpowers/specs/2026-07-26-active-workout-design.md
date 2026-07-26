# Fase 5 — Modo de entrenamiento activo

## Contexto

`ActiveWorkoutView` existe desde el recableado post-Fase 2 pero nunca se
conectó a nada real: no hay forma de empezar un entrenamiento desde una
rutina, los sets no son editables (solo se tildan), y el descanso está
hardcodeado en 60s (comentario `ponytail:` en el archivo) porque
`SetLog` no guarda de qué `RoutineExercise` salió.

Esta fase conecta todo el circuito: elegir un día de la rutina activa →
generar el log de esa sesión → loguear peso/reps reales por set →
descanso con la duración real del plan (+ notificación local de respaldo)
→ terminar → verlo después en un historial simple.

## Decisiones (con el usuario, 2026-07-26)

- **Punto de entrada**: un botón "Empezar" por día dentro de `RoutineCard`
  (tab Rutina), no una pantalla nueva.
- **Logging real**: peso y reps se editan por set, no solo se tildan.
- **Descanso**: cuenta regresiva en pantalla (como hoy) + notificación
  local de respaldo para cuando el usuario sale de la app durante el
  descanso.
- **Historial**: se agrega ahora, lista simple, no una fase aparte.

## Cambio de modelo (`IronPulse/Models/WorkoutModels.swift`)

`SetLog` gana 3 propiedades, copiadas del `RoutineExercise` al generar el
log (mismo patrón que `WorkoutLog.routineName`, que ya es un string
copiado y no una relación viva):

```swift
var restSeconds: Int
var targetRepsMin: Int
var targetRepsMax: Int
```

`WorkoutLog` gana:

```swift
var dayTitle: String
```

**Orden sin campo nuevo**: `setIndex` pasa a ser un contador global que
sube a lo largo de todo el día (ejercicio 1 usa 0,1,2; ejercicio 2 sigue
en 3,4,5...) en vez de reiniciar por ejercicio. La vista agrupa los sets
por `exerciseId`, ordena los grupos por su `setIndex` mínimo, y el "Set N"
que ve el usuario se calcula por posición dentro del grupo ya ordenado
(`index + 1`), no del valor crudo de `setIndex`. Evita agregar un campo
de "orden de ejercicio en el día".

**Migración**: son propiedades no-opcionales nuevas en `@Model` de
SwiftData sin plan de migración — aplica el mismo workaround ya usado en
la Fase 3 (borrar la app del simulador antes de correr). No hay usuarios
reales todavía.

## `Services/WorkoutLogGenerator.swift` (nuevo)

Mismo espíritu que `WorkoutGeneratorService`: función pura y sincrónica,
sin `ModelContext`, testeable con Swift Testing sin `ModelContainer`.

```swift
enum WorkoutLogGenerator {
    static func generate(for day: RoutineDay, profile: UserProfile) -> WorkoutLog
}
```

Por cada `RoutineExercise` del día (ordenados por `orderIndex`), genera
`targetSets` instancias de `SetLog` con `exerciseId`, `restSeconds`,
`targetRepsMin`/`targetRepsMax` copiados del ejercicio, `weightKg: 0`,
`repsCompleted: 0`, `isCompleted: false`, y `setIndex` como contador
global creciente (no reinicia entre ejercicios). El `WorkoutLog`
resultante lleva `routineName` (nombre de la rutina) y `dayTitle`
(`day.title`), sin insertar en el `ModelContext` — quien llama decide
cuándo persistir, igual que `WorkoutGeneratorService.generateRoutine`.

**Tests** (`IronPulseTests/WorkoutLogGeneratorTests.swift`, nuevo):
- Genera la cantidad correcta de `SetLog` (suma de `targetSets` de todos
  los ejercicios del día).
- `restSeconds`/`targetRepsMin`/`targetRepsMax` de cada `SetLog` matchean
  los del `RoutineExercise` correspondiente.
- `setIndex` es estrictamente creciente a lo largo de todo el día, sin
  reiniciar por ejercicio.
- `dayTitle`/`routineName` correctos.

## `Services/RestNotificationScheduler.swift` (nuevo)

Mismo estilo que `HapticFeedback` (`Theme/CustomColor.swift`): un `enum`
sin estado con métodos `static`. Usa `UserNotifications`, sin entitlement
ni clave de Info.plist nueva (a diferencia de HealthKit, el permiso de
notificaciones locales solo necesita el pedido en runtime).

```swift
enum RestNotificationScheduler {
    static func requestAuthorizationIfNeeded() async
    static func scheduleRestFinished(in seconds: Int)
    static func cancelPending()
}
```

`requestAuthorizationIfNeeded()` chequea `UNUserNotificationCenter
.current().notificationSettings().authorizationStatus`; si es
`.notDetermined`, pide `[.alert, .sound]`. Se llama una vez al aparecer
`ActiveWorkoutView` (`.task`), igual que el patrón ya usado para el
permiso de Salud — nunca al arrancar la app.

`scheduleRestFinished(in:)` cancela cualquier notificación pendiente con
el identifier fijo `"rest-finished"` y programa una nueva
(`UNTimeIntervalNotificationTrigger`, sin repetir) con esa duración. Se
llama junto con el timer en pantalla, cada vez que se tilda un set.

`cancelPending()` se llama cuando el timer en pantalla llega a 0 estando
la app en foreground, para no duplicar el aviso (el usuario ya sintió el
haptic de `HapticFeedback.restFinished()`). Si el usuario sale de la app
durante el descanso, la notificación programada es el respaldo real — un
`Task` de Swift en una vista no es confiable en background.

## `ActiveWorkoutView.swift` (rediseño)

Pasa de una lista plana ordenada por `setIndex` a secciones por ejercicio.

```swift
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
```

Cada sección: nombre del ejercicio (via `exerciseNames`, ya existe) como
header, y por cada set (enumerado dentro del grupo ya ordenado, el índice
+1 es el "Set N" que se muestra):

- **Peso**: `TextField` numérico atado a `set.weightKg`
  (`.keyboardType(.decimalPad)`) — hoy es texto fijo, no editable.
- **Reps**: `Stepper` atado a `set.repsCompleted`, mismo patrón que ya
  usa `RoutineBuilderView` para series/reps/descanso.
- **Meta**: texto chico `"Meta: \(targetRepsMin)-\(targetRepsMax)"`.
- **Completar**: el círculo tildable de siempre.

`isReadOnly: Bool { log.endDate != nil }` — cuando es `true` (log ya
terminado, se llega acá desde el historial): los `TextField`/`Stepper`
se deshabilitan (`.disabled(isReadOnly)`), se oculta el botón "Terminar"
y la fila de descanso. Así se reusa la misma vista para sesión en vivo y
para ver una sesión pasada, sin duplicar una `WorkoutDetailView` aparte.

Al tildar un set (`toggleCompleted`): si pasa a completo, además del
haptic ya existente, arranca `startRest(seconds: set.restSeconds)` (ya
no 60 fijo) y llama `RestNotificationScheduler.scheduleRestFinished(in:
set.restSeconds)`. Cuando el timer en pantalla llega a 0,
`RestNotificationScheduler.cancelPending()`.

`.task { await RestNotificationScheduler.requestAuthorizationIfNeeded() }`
al aparecer la vista.

## `RoutineTabView.swift` (empezar un entrenamiento)

`RoutineCard` pasa a recibir un closure en vez de ser puramente
decorativa — crear el `WorkoutLog` es un efecto secundario (insert +
save), no algo que una vista de solo-lectura deba hacer por su cuenta:

```swift
private struct RoutineCard: View {
    let routine: WorkoutRoutine
    let onStartDay: (RoutineDay) -> Void
    // ...
    // dentro del ForEach de dias, junto al Text(day.title):
    Button("Empezar") { onStartDay(day) }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color.ironAccent)
}
```

`RoutineTabView` guarda el día elegido en un `@State private var
activeLog: WorkoutLog?`, arma el log con `WorkoutLogGenerator.generate`,
lo inserta + guarda en el `modelContext`, y usa
`.navigationDestination(item: $activeLog) { log in ActiveWorkoutView(log: log) }`
para navegar. `WorkoutLog` no pasa por `UserProfile.activate(_:in:)` —
ese helper es para rutinas (desactivar la anterior), acá cada sesión
coexiste con las anteriores a propósito, es el historial.

## `WorkoutHistoryView.swift` (nuevo)

`@Query` de `WorkoutLog` filtrado a `endDate != nil`, ordenado por
`startDate` descendente. Cada fila: `routineName` + `dayTitle` + fecha
formateada + duración (`endDate - startDate`, formato "45 min").
`NavigationLink` a `ActiveWorkoutView(log:)` — la misma vista, en modo
lectura por el `isReadOnly` de arriba.

## `DashboardView.swift` (entrada al historial)

Debajo del resumen de rutina activa (`Text("\(active.name) ·
\(active.days.count) dias")`), un `NavigationLink` chico a
`WorkoutHistoryView()`. Visible siempre, no solo cuando hay rutina activa
— el historial puede tener contenido aunque la rutina actual cambie.

## Archivos afectados

**Nuevos:**
- `Services/WorkoutLogGenerator.swift`
- `Services/RestNotificationScheduler.swift`
- `Views/Workouts/WorkoutHistoryView.swift`
- `IronPulseTests/WorkoutLogGeneratorTests.swift`

**Modificados:**
- `Models/WorkoutModels.swift` (`SetLog` +3 campos, `WorkoutLog` +1 campo)
- `Views/Workouts/RoutineTabView.swift` (`RoutineCard` con closure,
  navegación a `ActiveWorkoutView`)
- `Views/Workouts/ActiveWorkoutView.swift` (agrupado por ejercicio,
  campos editables, descanso real + notificación, modo lectura)
- `Views/Workouts/DashboardView.swift` (link al historial)

## Fuera de alcance

- Prellenar el peso con el último registrado para ese ejercicio (queda
  en 0, el usuario lo tipea) — requeriría cruzar el historial completo
  por ejercicio, más complejo, se puede agregar después si hace falta.
- Detección de sesión sin terminar para reanudar en vez de crear una
  nueva — cada tap en "Empezar" crea un `WorkoutLog` nuevo, igual que
  "Rutina inteligente" siempre reemplaza sin preguntar.
- Filtros/búsqueda en el historial — es una lista simple por ahora.
