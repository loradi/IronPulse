# IRON & PULSE — Progreso

Reconstruccion de IronPulse hacia "IRON & PULSE" (SwiftUI + SwiftData, iOS 17+,
0 dependencias externas), siguiendo el plan de 8 fases del spec original.
Todo el trabajo vive en el branch `dev` (repo: https://github.com/loradi/IronPulse),
`main` es un checkpoint estable separado.

## Estado: Fase 1 y 2 completas y commiteadas en `dev`

- `006cf59` — Fase 1: sistema de diseno neon + `GIFImageView`
- `d39dfaa` — Fase 2: modelos SwiftData nuevos + seeder de 150 ejercicios

## Fase 1 — Tokens de diseno y GIFImageView

- `IronPulse/Theme/CustomColor.swift`: paleta neon dark/light (`Color.neonGreen`
  #00FF66, `Color.neonOrange` #FF3300), tipografia (`Font.ironTitle`,
  `Font.metricDisplay`), haptics (`HapticFeedback.setCompleted()` / `.restFinished()`),
  `.ironCard()`, `.neonGlow()`, `PrimarySportButtonStyle`.
- `IronPulse/Components/GIFImageView.swift`: reproductor nativo que decodifica
  un frame a la vez (`CGImageSource` + `CADisplayLink`) en lugar de precargar
  todos los frames — clave para no saturar RAM con ~150 GIFs. Soporta bundle
  local + fallback remoto con cache en disco (`Caches/ExerciseGIFs/`).
- Verificado con build real de Xcode, sin errores.

## Fase 2 — Modelos SwiftData + seeder de 150 ejercicios

- Modelos reescritos: `UserProfile` (age/primaryGoal/workoutDaysPerWeek/
  preferredEquipment), `WorkoutRoutine`/`RoutineDay`/`RoutineExercise`
  (ahora referencia un `Exercise` real via relacion, no campos inline),
  `WorkoutLog`/`SetLog` (renombrados de `WorkoutSession`/`WorkoutLogSet`).
- Modelo nuevo `Exercise.swift`: catalogo de ejercicios con gifFileName +
  gifRemoteURLString.
- Enums nuevos en `ProfileEnums.swift`: `PrimaryGoal` (hypertrophy/strength/
  fatLoss, reemplaza `FitnessGoal`), `SplitType` (fullBody/upperLower/
  pushPullLegs). `EquipmentType`/`MuscleGroup` se reutilizaron sin cambios.
- `Services/ExerciseDatabaseSeeder.swift` + `Resources/ExercisesSeed.json`:
  150 ejercicios reales (Pecho 22, Espalda 25, Piernas+Gluteos 30, Hombros 20,
  Biceps 18, Triceps 18, Core 17), generados por 7 subagentes en paralelo,
  validados con `jq` (ids unicos, enums validos, sin `fullGym` en ejercicios).
  Se siembran automaticamente en el primer arranque si la tabla `Exercise`
  esta vacia.
- **Fuente de imagenes temporal**: como no existe ningun CDN gratis de GIFs
  animados de ejercicios (wger no tiene, ExerciseDB/WorkoutX son de pago o
  con rate-limit), `gifRemoteURLString` apunta a fotos JPG estaticas reales
  y verificadas de `github.com/yuhonas/free-exercise-db` (dominio publico)
  como placeholder — no son GIFs animados, son fotos fijas. 140 de 150
  tienen match real verificado, 10 quedaron en `null` por no tener match
  confiable. Pendiente: conseguir/generar GIFs animados reales para
  reemplazar esto cuando se defina una fuente.
- `IronPulseApp.swift` registra el nuevo schema y llama al seeder al crear
  el `ModelContainer`.
- Fix trivial: `import Combine` faltante en `ExerciseListView.swift`.

### Ruptura esperada (documentada, no corregida en Fase 2)

Estos 3 archivos NO compilan hasta que la Fase 3/4 los recableen contra el
modelo nuevo (7 errores de compilacion, todos "cannot find type X in scope"):

- `Views/Workouts/AIRoutineGenerator.swift` — usa `FitnessGoal`, `wgerExerciseID`,
  `WgerExercise`/`WgerAPIService`, init viejo de `RoutineExercise`.
- `Views/Workouts/ActiveWorkoutView.swift` — tipado contra `WorkoutSession`/
  `WorkoutLogSet` (renombrados).
- `ContentView.swift` — usa `FitnessGoal.allCases`, `profile.fitnessGoal`,
  `profile.trainingDaysPerWeek`, y los nombres viejos en su schema local.

`ProfileSelectionView.swift` y `DashboardView.swift` tambien referencian
campos/nombres viejos pero, sorprendentemente, compilaron limpio en el build
real — revisar de todos modos al entrar a Fase 3/4 por si el compilador no
alcanzo a chequearlos a fondo.

`Views/Exercises/ExerciseListView.swift` sigue usando `WgerExercise`/
`WgerAPIService` sin tocar (fuera de alcance de Fase 2) — compila bien.

## Siguientes pasos (Fase 3 en adelante)

1. **Fase 3 — `WorkoutGeneratorService`**: reemplaza `AIRoutineGenerator`.
   Logica local (sin red) que arma splits (Full Body / Upper-Lower / PPL)
   segun `workoutDaysPerWeek`, seleccionando `Exercise` reales del catalogo
   sembrado (compuestos primero, aislamiento despues, core al final), y
   aplica reglas de series/reps/descanso segun `primaryGoal`.
2. **Fase 4 — Biblioteca de ejercicios UI**: buscador + filtros por
   `MuscleGroup`/`EquipmentType` sobre el catalogo `Exercise` real (ya no
   `WgerAPIService`), vista de detalle con `GIFImageView`. Esto es tambien
   cuando conviene decidir si `WgerAPIService`/`WgerModels.swift` se borran
   del todo (ya no deberian ser necesarios una vez el catalogo local este
   en uso).
3. **Fase 5 — Modo entrenamiento activo**: recablear `ActiveWorkoutView`
   contra `WorkoutLog`/`SetLog`, temporizador de descanso con
   `HapticFeedback.restFinished()`.
4. **Recablear navegacion**: desde la exploracion inicial del proyecto,
   `DashboardView`/`ActiveWorkoutView`/`ExerciseListView`/`ProfileSelectionView`
   estaban huerfanas (sin `NavigationLink` real entre ellas) — esto sigue
   pendiente independientemente de las fases de arriba.
5. Definir fuente real de GIFs animados (o aceptar las fotos JPG de
   free-exercise-db como definitivas) antes de pulir la Fase 4.
6. Sin tests todavia — ningun archivo de test cubre modelos/seeder/generator.

## Notas de contexto

- GitHub: repo privado `loradi/IronPulse`, branches `main` (checkpoint,
  no tocar) y `dev` (todo el trabajo activo).
- `gh` CLI autenticado localmente para push/PRs.
- Cualquier store SQLite local viejo (de antes de Fase 2) no migra
  automaticamente — borrar la app del simulador si el build da errores raros
  de SwiftData al correrla.
