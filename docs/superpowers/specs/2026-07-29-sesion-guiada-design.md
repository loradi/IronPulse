# Sesión guiada de entrenamiento (cronómetro por set + cierre de rutina)

## Contexto

Subsistema B del reporte del usuario tras revisar la app en simulador (el
subsistema A, edición de perfil + sistema de unidades, ya se implementó y
mergeó — ver `docs/superpowers/specs/2026-07-29-perfil-editable-unidades-design.md`).
Cubre los items 2, 3, 4, 5, 6 y 7 de ese reporte, más el item 10
(restricción transversal de i18n).

Hoy `ActiveWorkoutView` es una lista plana: todos los sets de todos los
ejercicios de la sesión visibles a la vez, sin concepto de "set activo con
cronómetro corriendo" ni pantalla de un ejercicio a la vez. Ya existe
auto-avance al siguiente set tras marcar uno completado
(`GuidedSessionFlow.nextSetID`, `restSeconds(isCompound:)` → 90s
compuestos / 60s aislamiento) y notificaciones locales de descanso
(`RestNotificationScheduler`). El botón "Terminar" hoy solo marca
`log.endDate = Date()` y guarda, sin volver al Dashboard.
`DashboardView.todaysCard` siempre ofrece "Iniciar ejercicios" si hay un
día de rutina asignado hoy, sin chequear si ya existe una sesión de hoy
terminada.

## Decisiones (con el usuario, 2026-07-29)

- **Paradigma de pantalla**: para sesiones ACTIVAS, se reemplaza la lista
  plana por una vista de un ejercicio a la vez, con navegación manual
  hacia atrás/adelante entre ejercicios ya vistos.
- **Sesiones YA terminadas** (Historial, resumen del Dashboard): se
  mantiene la lista plana actual, sin cambios — es mejor para repasar todo
  de un vistazo y ya no aplican los controles de cronómetro.
- **Flujo del cronómetro por set**: "Empezar set" arranca un cronómetro
  contando hacia arriba (tiempo transcurrido). Un botón separado
  "Terminar set" lo detiene y dispara el descanso. Durante el descanso
  aparece un botón "Start set" al lado del countdown, tocable en
  cualquier momento para saltar el descanso restante.
- **Duración del descanso**: se mantiene la lógica existente de
  `GuidedSessionFlow.restSeconds(isCompound:)` (90s compuestos / 60s
  aislamiento), no un valor fijo.
- **Editar cantidad de sets**: botones +/- junto a la lista de sets del
  ejercicio actual (agregar al final, eliminar cualquiera salvo si es el
  único).
- **Validación de completar un set**: el botón "Terminar set" está
  deshabilitado mientras `weightKg <= 0` o `repsCompleted <= 0`.
- **Ícono de info del ejercicio**: abre `ExerciseDetailView` (ya existe,
  reusado tal cual) en un `.sheet`; cerrarlo regresa automáticamente.
- **Dashboard con rutina de hoy ya terminada**: muestra "Completado hoy"
  con link al resumen de esa sesión (en modo solo-lectura, reusando
  `ActiveWorkoutView(log:)` tal como ya hace `WorkoutHistoryView`).
- **Botón "Terminar"**: siempre visible (barra superior) durante una
  sesión activa — guarda y regresa al Dashboard en cualquier momento, no
  solo al final.

## Arquitectura

`ActiveWorkoutView` (existente) se ramifica según `isReadOnly`:

- `isReadOnly == true`: cuerpo actual sin cambios (lista plana).
- `isReadOnly == false`: en vez de la lista plana, presenta la nueva
  `GuidedWorkoutView` (archivo nuevo).

Esto aísla el modelo de UI nuevo del que ya funciona para revisar
sesiones terminadas, sin tocar ese código.

## `GuidedWorkoutView` (nuevo)

Vista de un ejercicio a la vez. Estado:

```swift
@State private var currentExerciseIndex: Int = 0
@State private var setPhase: SetPhase = .idle
@State private var elapsedSetSeconds: Int = 0
@State private var restRemaining: Int = 0
@State private var timerTask: Task<(), Never>? = nil
```

```swift
enum SetPhase: Equatable {
    case idle
    case runningSet
    case resting
}
```

- **`.idle`**: muestra los campos de Peso/Reps del set activo y el botón
  "Empezar set" (deshabilitado si `weightKg <= 0` o `repsCompleted <= 0`
  — ver "Validación" abajo, aplica al momento de completar, no de
  empezar).
- **`.runningSet`**: cronómetro contando hacia arriba
  (`elapsedSetSeconds`), botón "Terminar set" — deshabilitado mientras
  `weightKg <= 0` o `repsCompleted <= 0` del set activo.
- **`.resting`**: countdown `restRemaining` (segundos, iniciado en
  `GuidedSessionFlow.restSeconds(isCompound: exercise.isCompound)`), con
  botón "Start set" al lado, siempre habilitado — tocarlo cancela el
  countdown y pasa al siguiente set en `.idle`.

Al tocar "Terminar set": marca el set activo `isCompleted = true`,
guarda, dispara `RestNotificationScheduler.scheduleRestFinished(in:)` con
la duración correspondiente, y pasa a `.resting`.

Al completar el último set del ejercicio actual (ya sea vía "Start set"
saltando el descanso o el countdown llegando a 0), avanza automáticamente
`currentExerciseIndex += 1` y vuelve a `.idle` para el primer set del
siguiente ejercicio. Si no hay más ejercicios, no avanza más (el usuario
usa "Terminar" para cerrar la sesión).

**Navegación manual**: flechas `<` `>` en la barra superior mueven
`currentExerciseIndex` dentro de `0..<groupedSets.count`, sin restricción
— reutiliza `groupedSets` (ya existe en `ActiveWorkoutView`, se comparte
o se recalcula igual en `GuidedWorkoutView`). Ir a un ejercicio anterior
no resetea sus sets ya completados; los campos de Peso/Reps de sets
anteriores siguen editables igual que hoy (no se bloquean al estar
completados). Cada cambio de `currentExerciseIndex` (manual o
automático) resetea `setPhase` a `.idle`, cancela cualquier timer
corriendo (`timerTask?.cancel()`), y selecciona como "set activo" el
primer set no completado del ejercicio mostrado (o el último si todos ya
están completados, para no dejar ningún set sin selección).

**Botón "Terminar"** en la barra superior, siempre habilitado: guarda
(`log.endDate = Date()` + `try? modelContext.save()`) y llama
`dismiss()` (vía `@Environment(\.dismiss)`) para volver al Dashboard.

**Ícono de info**: en la barra superior o junto al nombre del ejercicio,
abre `ExerciseDetailView(exercise:)` en `.sheet(isPresented:)`.

**Editar cantidad de sets**: botón "+ Agregar set" al final de la lista
de sets del ejercicio actual, y una opción de eliminar por cada set
(salvo si es el único de ese ejercicio). Ver "Renumeración de sets"
abajo.

## Renumeración de sets (nuevo, función pura testeable)

`groupedSets` agrupa por contigüidad de `setIndex` — agregar o quitar un
set a mitad de sesión requiere renumerar TODOS los `setIndex` del log
para mantener cada ejercicio contiguo, no solo insertar un índice suelto
en el medio. Nueva función pura en `GuidedSessionFlow.swift`:

```swift
static func renumbered(_ sets: [SetLog], groupedBy exerciseOrder: [String]) -> Void {
    var index = 0
    for exerciseId in exerciseOrder {
        for set in sets.filter({ $0.exerciseId == exerciseId }) {
            set.setIndex = index
            index += 1
        }
    }
}
```

`exerciseOrder` es el orden de aparición de `groupedSets` (ya calculado).
Se llama después de insertar o eliminar un `SetLog` del `log.completedSets`,
antes de guardar. Un nuevo set copia `restSeconds`/`targetRepsMin`/`targetRepsMax`
del último set existente de ese ejercicio (o de `RoutineExercise` si el
ejercicio no tiene sets aún, caso borde no esperado en este flujo ya que
`WorkoutLogGenerator` siempre pre-crea al menos el mínimo de sets al
iniciar la sesión).

## Dashboard (item 2)

`DashboardView.todaysCard`: antes del botón "Iniciar ejercicios", se
verifica si `profile.workoutLogs` ya tiene un log de hoy
(`Calendar.current.isDateInToday(log.startDate)`) con `endDate != nil`.
Si existe, se muestra un estado "Completado hoy ✓" con un
`NavigationLink` a `ActiveWorkoutView(log:)` (modo solo-lectura,
automático vía `isReadOnly`), igual patrón que ya usa
`WorkoutHistoryView`.

## i18n

Todo texto nuevo se agrega a `Localizable.xcstrings` (es/en/fr), mismo
patrón `String(localized:defaultValue:bundle:locale:)` ya establecido:
"Empezar set", "Terminar set", "Descanso", "Start set", "+ Agregar set",
"Completado hoy", más cualquier etiqueta de navegación/info que la
implementación necesite. Las claves ya existentes (`GuidedSessionFlow`,
`RestNotificationScheduler`) no cambian de significado, solo se reusan.

## Testing

- `GuidedSessionFlow.renumbered(_:groupedBy:)`: tests puros — insertar un
  set a mitad de un ejercicio con 2+ ejercicios en el log y confirmar que
  el `setIndex` de cada set queda contiguo por ejercicio en el orden
  dado; eliminar un set y confirmar lo mismo; caso borde de un solo
  ejercicio con un solo set.
- Validación de "Terminar set" deshabilitado sin peso/reps: se verifica
  a nivel de lógica de habilitación (una función pura que reciba
  `weightKg`/`repsCompleted` y devuelva si el botón debe estar
  habilitado), no acoplada a la vista.
- Detección de "rutina de hoy ya terminada" en `DashboardView`: test
  sobre la lógica de filtrado (dado una lista de `WorkoutLog`, confirmar
  que se detecta correctamente un log de hoy con `endDate != nil` vs.
  ninguno vs. uno de otro día).
- Resto (flujo completo del cronómetro, navegación entre ejercicios,
  ícono de info, botón Terminar) se verifica en simulador — mismo
  patrón que el resto del proyecto. Dada la flakiness de inyección de
  taps documentada repeatedamente en este entorno, si la verificación en
  vivo falla, se usa el fallback ya establecido: reproducción sintética
  vía tests + lectura de código, dejando explícito qué no se pudo
  confirmar en vivo.

## Fuera de alcance

- Cualquier cambio a `RestNotificationScheduler`'s textos existentes
  ("Descanso terminado", "A por el siguiente set.") — pre-existen, no
  son parte de este reporte, quedan como están (no localizados, gap
  pre-existente, no introducido aquí).
- GIFs de ejercicios — descartado explícitamente por el usuario en una
  sesión anterior.
- Traducción real del catálogo de ejercicios — spec futura separada, sin
  relación con esto.
