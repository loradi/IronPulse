# IRON & PULSE — Progreso

Reconstruccion de IronPulse hacia "IRON & PULSE" (SwiftUI + SwiftData, iOS 17+,
0 dependencias externas), siguiendo el plan de 8 fases del spec original.
Todo el trabajo vive en el branch `dev` (repo: https://github.com/loradi/IronPulse),
`main` es un checkpoint estable separado.

## Estado: Fase 1 y 2 completas, proyecto compila y corre limpio

- `006cf59` — Fase 1: sistema de diseno neon + `GIFImageView`
- `d39dfaa` — Fase 2: modelos SwiftData nuevos + seeder de 150 ejercicios
- (siguiente commit) — recableado post-Fase 2: 0 errores de compilacion,
  0 `gifRemoteURLString` en null

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
  como placeholder — no son GIFs animados, son fotos fijas. Pendiente:
  conseguir/generar GIFs animados reales cuando se defina una fuente.
- `IronPulseApp.swift` registra el nuevo schema y llama al seeder al crear
  el `ModelContainer`.
- Fix trivial: `import Combine` faltante en `ExerciseListView.swift`.

## Recableado post-Fase 2 (ruptura ya cerrada)

La ruptura que la Fase 2 dejo documentada ya esta resuelta. `xcodebuild` da
**BUILD SUCCEEDED** y la app arranca en simulador sembrando 150 ejercicios.
El alcance real era mas amplio que los 3 archivos previstos: Swift solo
reporta la primera tanda de errores por archivo, asi que al arreglar las
firmas aparecieron los errores de los cuerpos.

- **Borrado** `Services/AIRoutineGenerator.swift` — obsoleto entero (wger +
  `FitnessGoal` + init viejo de `RoutineExercise`). La Fase 3 lo reemplaza
  con `WorkoutGeneratorService`, no tenia sentido recablearlo para tirarlo.
- `ContentView.swift` — init nuevo de `UserProfile`, `primaryGoal`/
  `workoutDaysPerWeek`, schema del `#Preview` actualizado. El sexo biologico
  ahora se lee del ultimo `HealthSnapshot` (ya no vive en `UserProfile`);
  se cayeron el toggle `syncsWithHealth` y el stepper de duracion de sesion
  porque esos campos ya no existen en el modelo.
- `ActiveWorkoutView.swift` — reescrito contra `WorkoutLog`/`SetLog`. El
  nombre del ejercicio se resuelve con un `@Query` sobre `Exercise` mapeado
  por id (`SetLog` guarda `exerciseId: String`, no una relacion). Se
  engancharon `HapticFeedback.setCompleted()` y `.restFinished()`.
- `DashboardView.swift` — recableado a `splitType`/`dayNumber`/`targetSets`/
  `targetRepsMin-Max`/`ex.exercise.name`. El boton "Generar rutina con IA"
  se quito hasta la Fase 3; queda un `ContentUnavailableView` que lo dice.
- `ProfileSelectionView.swift` — el modelo nuevo no tiene `isActive` en
  `UserProfile`, la seleccion es local a la vista.
- `HealthKitProfileImporter.swift` — `apply()` escribia 4 campos que ya no
  existen (`birthDate`, `biologicalSex`, `syncsWithHealth`,
  `updateTimestamp()`); ahora solo actualiza peso, altura y deriva `age`
  desde la fecha de nacimiento.
- `Models/UserProfile.swift` — se agrego `activeRoutine` (la rutina con
  `isActive`), que usan Dashboard y usara la Fase 3.
- `Components/GIFImageView.swift` — bug real de la Fase 1 que no se habia
  visto porque el build moria antes: dentro de un `UIView`, `ContentMode`
  sin calificar resuelve a `UIView.ContentMode`. Se calificó a
  `SwiftUI.ContentMode`.
- `Theme/CustomColor.swift` — se agrego `ironTextSecondary` (faltaba y lo
  usaban 4 vistas). Los tokens muertos de las vistas viejas se renombraron
  a los de la Fase 1: `ironPrimary`→`ironAccent`, `ironSurface`→`ironCard`,
  `redGlow()`→`neonGlow(color: .ironDanger)`.
- `IronPulse.xcodeproj` — HealthKit estaba a la vez enlazada y **embebida**
  como framework, con la ruta del SDK iOS 26.5 hardcodeada; eso rompia el
  empaquetado ("did not contain an Info.plist"). Se quitaron ambas
  referencias: Swift la autolinkea desde `import HealthKit` (verificado con
  `otool -L` sobre `IronPulse.debug.dylib`).

`Views/Exercises/ExerciseListView.swift` sigue usando `WgerExercise`/
`WgerAPIService`; la Fase 4 decide si se borran.

## Navegacion real + tema visible (post-recableado)

El recableado de arriba solo arreglaba la compilacion; al correr la app se
veia una lista de perfiles con estilo iOS de fabrica, sin ningun color neon
y sin forma de llegar a ejercicios. Causa real: `ContentView` (root de
`IronPulseApp.swift`) nunca aplicaba los tokens del tema, y `DashboardView`/
`ActiveWorkoutView`/`ExerciseListView` estaban huerfanas — ni una tenia un
solo `NavigationLink` real hacia ellas en todo el proyecto (confirmado con
grep). Era el punto 4 que ya estaba anotado como pendiente.

- `ContentView.swift`: la fila de perfil ahora navega a `DashboardView`
  (antes iba directo al form de edicion). `ironBackground` de fondo,
  `ironCard` en las filas, `.tint(.ironAccent)` en el `NavigationStack`
  (tiene que ir ahi y no en el `List` interno, si no el toolbar no hereda
  el tint). `ProfileDetailView` paso de `private` a `internal` para que
  `DashboardView` la pueda referenciar desde su toolbar.
- `DashboardView.swift`: toolbar con 2 botones — uno a `ExerciseListView`
  (catalogo), otro a `ProfileDetailView` (editar perfil / import de Salud).
- `ExerciseListView.swift` — **reescrita entera**: ya no llama a
  `WgerAPIService`/wger.de, hace `@Query` directo sobre el catalogo local
  `Exercise` (los 150 sembrados). El thumbnail usa `GIFImageView` (el
  componente de la Fase 1) en vez de `AsyncImage` — reutiliza el decoder
  frame-a-frame que ya soporta bundle local + remoto con cache, y funciona
  igual de bien con las fotos JPG estaticas actuales que con GIFs reales el
  dia que se reemplacen.
- **Borrados** `Services/WgerAPIService.swift` y `DTOs/WgerModels.swift`:
  quedaron sin un solo caller en todo el proyecto en cuanto
  `ExerciseListView` dejo de usarlos — la pregunta que la Fase 2 dejaba
  abierta ("se borran cuando el catalogo local este en uso") ya tiene
  respuesta.
- Verificado en simulador real (no solo build): perfil nuevo con card neon,
  Dashboard con el glow verde y el placeholder de "Fase 3", los 150
  ejercicios con thumbnail cargando de free-exercise-db, busqueda en vivo
  ("sentadilla" filtra correctamente incluidas las que tenian null antes).

## Dos bugs post-navegacion: import de Salud y tocar un ejercicio

Reportados por el usuario despues de probar la app: el boton "Importar
datos de Salud" no hacia nada, y tocar una fila de `ExerciseListView`
tampoco.

- **Import de Salud**: el proyecto nunca tuvo la entitlement de HealthKit
  ni las claves `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription`
  en Info.plist — ninguna de las dos existia desde el commit original.
  Sin la entitlement + esas claves, `HKHealthStore.requestAuthorization`
  no muestra ningun error observable (no crashea con esta config del SDK,
  simplemente no hace nada). Se agrego
  `IronPulse/IronPulse.entitlements` (`com.apple.developer.healthkit`) y
  las dos claves `INFOPLIST_KEY_NSHealth*UsageDescription` en el
  `project.pbxproj` (Debug y Release). Verificado en simulador: ahora el
  sistema muestra la hoja real de "Health Access", se puede dar permiso, y
  el import corre (en el simulador da "No data available for the
  specified predicate" porque no hay datos de Salud cargados ahi, eso es
  esperado, no un bug).
- **Tocar un ejercicio**: `ExerciseListView` nunca envolvia las filas en un
  `NavigationLink` — se agrego, con una `ExerciseDetailView` nueva (imagen
  grande via `GIFImageView`, musculos secundarios, instrucciones
  numeradas).
- Nota de debugging: `print()` no aparece en `xcrun simctl spawn log
  show/stream` en este simulador (se confirmo con un boton que **si**
  funciona — `print()` nunca aparecio en el log a pesar de que la accion
  se ejecutaba). Para verificar que un tap realmente llega a un control,
  la senal confiable es la linea `(UIKitCore) send control actions` en
  `log stream`, no los prints de la app.

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
3. **Fase 5 — Modo entrenamiento activo**: `ActiveWorkoutView` ya esta
   recableada y con haptics, pero falta lo de verdad: que una rutina genere
   el `WorkoutLog` con sus `SetLog`, y que el descanso salga del
   `RoutineExercise.restSeconds` en vez de los 60s fijos que hay hoy
   (marcado con un comentario `ponytail:` en el archivo).
4. **Recablear navegacion**: desde la exploracion inicial del proyecto,
   `DashboardView`/`ActiveWorkoutView`/`ExerciseListView`/`ProfileSelectionView`
   estaban huerfanas (sin `NavigationLink` real entre ellas) — esto sigue
   pendiente independientemente de las fases de arriba.
5. Definir fuente real de GIFs animados (o aceptar las fotos JPG de
   free-exercise-db como definitivas) antes de pulir la Fase 4.
6. Sin tests todavia — ningun archivo de test cubre modelos/seeder/generator.
7. **4 ejercicios duplicados en el seed** (mismo ejercicio dado de alta dos
   veces bajo dos grupos musculares, herencia de los 7 subagentes en
   paralelo): `Encogimientos con barra` (back/shoulders), `Face pull en
   polea` (back/shoulders), `Fondos en banco` (chest/triceps), `Fondos en
   paralelas` (chest/triceps). Los ids son unicos asi que el seeder inserta
   los 8; en la biblioteca de la Fase 4 van a salir repetidos. Decidir si se
   fusionan usando `secondaryMuscles` o se dejan.

### Verificacion de imagenes

`ExercisesSeed.json`: **0 de 150** con `gifRemoteURLString` en null. Los 10
que faltaban se completaron contra free-exercise-db:

| ejercicio | imagen usada |
|---|---|
| Peso muerto rumano con mancuernas | `Stiff-Legged_Dumbbell_Deadlift` |
| Zancadas caminando con mancuernas | `Dumbbell_Lunges` |
| Sentadilla bulgara con mancuernas | `Split_Squat_with_Dumbbells` |
| Sentadilla sissy | `Weighted_Sissy_Squat` |
| Abduccion de cadera en maquina | `Thigh_Abductor` |
| Peso muerto a una pierna con mancuerna | `Kettlebell_One-Legged_Deadlift` (kettlebell, no mancuerna) |
| Aperturas posteriores en maquina | `Reverse_Machine_Flyes` |
| Crunch de bicicleta | `Air_Bike` |
| Plancha hueca | `Cocoons` (aproximacion, no hay hollow hold en la db) |
| Plancha lateral | `Side_Bridge` |

Las 145 URLs unicas (150 entradas, 5 comparten imagen por los duplicados de
arriba) devuelven HTTP 200 — verificado una por una con `curl -I`.

## Notas de contexto

- GitHub: repo privado `loradi/IronPulse`, branches `main` (checkpoint,
  no tocar) y `dev` (todo el trabajo activo).
- `gh` CLI autenticado localmente para push/PRs.
- Cualquier store SQLite local viejo (de antes de Fase 2) no migra
  automaticamente — borrar la app del simulador si el build da errores raros
  de SwiftData al correrla.
