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

## Fase 3 COMPLETA — generador de rutinas (inteligente + manual)

Se esta ejecutando con el flujo Subagent-Driven Development de superpowers:
un subagente implementador por tarea, un reviewer despues de cada una, y un
review final de toda la rama al terminar.

**Documentos que gobiernan esta fase (leer estos primero al retomar):**

| Que | Ruta |
|---|---|
| Spec de diseno (el "que" y el "por que") | `docs/superpowers/specs/2026-07-25-workout-generator-design.md` |
| Plan de implementacion (6 tareas con codigo completo y comandos) | `docs/superpowers/plans/2026-07-25-workout-generator.md` |
| Ledger de progreso SDD (commits por tarea, hallazgos, decisiones) | `.superpowers/sdd/2026-07-25-workout-generator/progress.md` |
| Briefs y reportes por tarea | `.superpowers/sdd/2026-07-25-workout-generator/task-N-{brief,report}.md` |

El ledger es la fuente de verdad de que tareas estan hechas. Una tarea con
linea `Task N: complete` NO se vuelve a ejecutar.

### Alcance decidido con el usuario (2026-07-25)

- **Dos flujos**, no uno: "Rutina inteligente" (heuristica local) y "Crear
  rutina manual" (armador desde cero, el usuario elige cada ejercicio).
  Ambos activan la rutina con el mismo helper `UserProfile.activate(_:in:)`.
- **Sin la palabra "IA"** en ningun texto visible: es heuristica
  determinista. Nombre de rutina generada:
  `"Rutina personalizada - \(primaryGoal.displayName)"`.
- **`preferredEquipment` NO se usa** en esta fase (decision explicita).
- **Fuera de alcance, van en un spec aparte**: selector de idioma
  (espanol / ingles / frances) y foto por perfil. Son subsistemas
  independientes (i18n cross-cutting + almacenamiento de imagen); el
  usuario acepto separarlos para no inflar este spec.

### Estado tarea por tarea

- [x] **Task 1 — `Exercise.isCompound`** (`2cdf1b8` + fix `e931dc2`).
      Campo nuevo en el modelo + los 150 registros clasificados + seeder
      actualizado. **72 compuestos / 78 aislamiento.**
      Hallazgo del review, corregido: el keyword `press` clasificaba mal
      "Press frances" (skull crusher), que es aislamiento de triceps de una
      sola articulacion. Se agrego `MANUAL_ISOLATION_OVERRIDES` al script.
      Los otros press de triceps (`ex_122` agarre cerrado, `ex_130` cerrado
      con mancuernas, `ex_132` press JM) SI son compuestos y quedaron en
      `true` — verificado. Las hiperextensiones quedan como aislamiento por
      decision del usuario.
- [x] **Task 2 — split y estructura de dias** (`b1f1836`).
      `WorkoutGeneratorService.splitType(for:)` y `.dayTemplates(split:dayCount:)`,
      6 tests pasando. Review aprobado sin hallazgos bloqueantes.
- [x] **Task 3 — prescripcion y seleccion de ejercicios** (`48336be`).
      `prescription(goal:level:)`, `exercisesPerDay(for:)`,
      `generateRoutine(for:catalog:)`. Orden compuestos -> aislamiento ->
      core al final, series/reps/descanso segun `primaryGoal` (con caso
      especial `.advanced` + `.strength` = 5 series). Review aprobado sin
      hallazgos bloqueantes.
- [x] **Task 4 — helper de activacion + boton "Rutina inteligente"**
      (`1b70fd1`). `UserProfile.activate(_:in:)` desactiva las rutinas
      viejas (quedan de historial, no se borran) y activa la nueva; lo usan
      tanto el flujo generado como el manual. Review aprobado sin hallazgos
      bloqueantes.
- [x] **Task 5 — `ExercisePickerSheet` + `RoutineBuilderView`** (`37eb698`).
      Armador manual: split/dias precargados desde el perfil pero
      editables, una seccion por dia, buscador tap-to-select que marca los
      ya agregados con check verde, steppers de series/reps/descanso
      editables. Los "drafts" viven en memoria (structs, no SwiftData)
      hasta tocar "Guardar" — cancelar no deja basura en el store. Review
      aprobado sin hallazgos bloqueantes.
- [x] **Task 6 — verificacion en simulador + cierre de este documento.**
      Ver "Verificado en simulador" mas abajo.
- [ ] **Review final de toda la rama** (paso obligatorio del flujo SDD,
      con el modelo mas capaz). Se hace despues de cerrar esta tarea.

**18 tests** en `IronPulseTests/WorkoutGeneratorServiceTests.swift` cubren
split/dias/prescripcion/seleccion — todos pasando en cada tarea.

### Minors diferidos (para el review final, no bloquean)

- Task 2: `dayCount <= 0` cae a 1 dia por el `max(1, dayCount)`, sin test
  que documente esa decision.
- Task 2: ningun test cubre `DayTemplate.muscleGroups`, solo `.title` — un
  typo de grupo muscular pasaria los 6 tests igual.
- Task 3: no hay test de truncacion que corte especificamente dentro del
  bucket de `core` (el fixture de test nunca fuerza ese caso).
- Task 3: ningun test verifica variedad real entre corridas del
  `.shuffled()` (solo se testean invariantes, no la aleatoriedad en si).
- Task 5: `RoutineBuilderView.swift` tiene 4 `Stepper` con bindings de
  subscript anidado (`$draftDays[dayIndex].items[itemIndex].X`) — si la
  vista crece, extraer un `DraftItemRow` reduciria la carga del
  type-checker.
- Task 5: cambiar el split o la cantidad de dias borra todos los
  ejercicios ya agregados sin confirmar (es el comportamiento tal cual lo
  pide el brief, no un bug del implementer) — mejora de UX a futuro.
- Task 5: `ExercisePickerSheet` indexa `draftDays[target.dayIndex]` sin
  bounds check; hoy es inalcanzable porque la presentacion de la hoja es
  modal, pero es fragil si eso cambia (ej. presentacion no-modal en iPad).

### Verificado en simulador

Simulador iPhone 17e (`B93C823F-AAD5-46AF-B830-8A8390325C5F`), store
limpio (`simctl uninstall` + reinstall del build actual, commit `37eb698`).

- Instalacion limpia: lista de perfiles vacia, tema neon visible desde el
  arranque.
- Perfil nuevo creado con el boton "+" (`Perfil 1`, Principiante /
  Hipertrofia / 3 dias por defecto). Dashboard entra en estado "Sin rutina
  activa" con los dos botones ("Rutina inteligente" / "Crear rutina
  manual") visibles.
- **Flujo inteligente**: primer tap en "Rutina inteligente" genera una
  `RoutineCard` con nombre `"Rutina personalizada - Hipertrofia"`, 3 dias
  (Torso/Pierna/Torso), cada dia con 4 ejercicios reales en formato
  `3x8-12`. Segundo tap regenera: la lista de ejercicios cambia
  (confirmado — "Press cubano"/"Peso muerto rumano"... paso a "Press
  inclinado con mancuernas"/"Zancadas caminando"...), sigue habiendo
  **una sola** `RoutineCard` (reemplazo, no duplicado).
- **Flujo manual**: "Crear rutina manual" abre `RoutineBuilderView` con
  split preseleccionado en "Torso / Pierna", 3 dias por semana, y 3
  secciones (Dia 1 — Torso, Dia 2 — Pierna, Dia 3 — Torso). Buscador
  "press" filtra en vivo; se agrego "Press Arnold" al Dia 1 y aparecio con
  sus steppers (3 series, 8-12 reps, 75s descanso). Reabrir el picker del
  Dia 1 y buscar "arnold" muestra la fila **deshabilitada con check
  verde**. Se agrego un segundo ejercicio ("Remo al menton con barra") al
  mismo dia y se toco "Guardar": vuelve al Dashboard con la `RoutineCard`
  `"Rutina manual - Perfil 1"` y los dos ejercicios elegidos.
- Nota (no es bug): la tarjeta manual mostro "1 dias" porque solo se
  cargaron ejercicios en el Dia 1 — los dias 2 y 3 sin ejercicios no se
  persisten como `RoutineDay` vacios. Es coherente con que el spec no pide
  dias vacios en la rutina guardada.
- Ningun screenshot mostro contenido faltante o incorrecto frente a lo
  esperado por el brief.

## Fase 4 — practicamente completa ya (adelantada sin querer)

La Fase 4 original ("biblioteca de ejercicios UI") se hizo casi entera
durante el recableado de navegacion, antes de arrancar la Fase 3:

- [x] `ExerciseListView` lee el catalogo local con `@Query` (ya no
      `WgerAPIService`), con buscador por nombre.
- [x] Vista de detalle (`ExerciseDetailView`) con imagen grande via
      `GIFImageView`, musculos secundarios e instrucciones numeradas.
- [x] `WgerAPIService.swift` y `WgerModels.swift` **borrados** — quedaron
      con 0 callers. La pregunta que la Fase 2 dejaba abierta ya tiene
      respuesta.
- [ ] **Lo unico que falta de la Fase 4**: filtros por `MuscleGroup` y
      `EquipmentType` (hoy solo hay busqueda por texto libre).

## Siguientes pasos (despues de la Fase 3)

1. Review final de toda la rama de la Fase 3 (el unico paso que falta,
   ver arriba).
2. Cerrar Fase 4: agregar los filtros por `MuscleGroup`/`EquipmentType` a
   `ExerciseListView`.
3. **Spec nuevo — idioma + foto de perfil**: selector espanol/ingles/frances
   (i18n de toda la app) y foto por `UserProfile`. Ya acordado con el
   usuario que van en un documento aparte, no en el de la Fase 3.
4. **Fase 5 — Modo entrenamiento activo**: `ActiveWorkoutView` ya esta
   recableada y con haptics, pero falta lo de verdad: que una rutina genere
   el `WorkoutLog` con sus `SetLog`, y que el descanso salga del
   `RoutineExercise.restSeconds` en vez de los 60s fijos que hay hoy
   (marcado con un comentario `ponytail:` en el archivo).
5. Definir fuente real de GIFs animados (o aceptar las fotos JPG de
   free-exercise-db como definitivas).
6. **4 ejercicios duplicados en el seed** (mismo ejercicio dado de alta dos
   veces bajo dos grupos musculares, herencia de los 7 subagentes en
   paralelo): `Encogimientos con barra` (back/shoulders), `Face pull en
   polea` (back/shoulders), `Fondos en banco` (chest/triceps), `Fondos en
   paralelas` (chest/triceps). Los ids son unicos asi que el seeder inserta
   los 8; en la biblioteca salen repetidos. Decidir si se fusionan usando
   `secondaryMuscles` o se dejan.
7. `ProfileSelectionView.swift` sigue huerfana y duplica lo que ya hace
   `ContentView` (listar perfiles + crear). Evaluar si se borra.

## Gotchas del entorno (cuestan horas si se redescubren)

- **Tests**: SIEMPRE pasar `-only-testing:IronPulseTests`. Sin eso corre
  tambien el suite de UI tests y `testLaunchPerformance` solo tarda **420
  segundos**. Ademas `xcodebuild` imprime `Test case` con **c minuscula**,
  un grep con `"Test Case"` no matchea nada.
  ```
  xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse \
    -destination 'platform=iOS Simulator,name=iPhone 17e' \
    -only-testing:IronPulseTests 2>&1 \
    | grep -E "\*\* TEST|Test case.*(passed|failed)" | sort -u
  ```
- **`print()` NO aparece** en `xcrun simctl spawn log show/stream` en este
  simulador — se confirmo con un boton que si funcionaba. Para saber si un
  tap realmente llego a un control, la senal confiable es la linea
  `(UIKitCore) send control actions` en `log stream`.
- **SwiftData sin migracion**: cualquier propiedad no-opcional nueva en un
  `@Model` rompe el store viejo. Hay que
  `xcrun simctl uninstall <device> com.BERNU.IronPulse` antes de reinstalar.
  No se implemento `VersionedSchema` a proposito (no hay usuarios reales).
- **Los diagnosticos de SourceKit mienten** en este proyecto: reporta
  constantemente `Cannot find type 'X' in scope` / `No such module 'UIKit'`
  para tipos que existen. Es falta de contexto del target, no errores
  reales. La verdad la dice `xcodebuild`.
- **`.foregroundStyle(.ironTextSecondary)` no compila** — la forma corta no
  resuelve contra `ShapeStyle` con colores custom. Escribir siempre
  `.foregroundStyle(Color.ironTextSecondary)`.
- **Simulador de referencia**: iPhone 17e, UDID
  `B93C823F-AAD5-46AF-B830-8A8390325C5F`, bundle id `com.BERNU.IronPulse`.
- **Xcode usa file-system-synchronized groups**: los archivos `.swift`
  nuevos se toman solos, NO hay que editar `project.pbxproj`.
- **La API de Anthropic tuvo caidas transitorias durante esta sesion**
  (error 529 "Overloaded", dos veces: una interrumpio un fix a mitad de
  camino, otra interrumpio justo despues de generar un review package). No
  es nada del proyecto. El flujo SDD esta pensado para esto: el ledger en
  `.superpowers/sdd/2026-07-25-workout-generator/progress.md` y los
  commits en git son la fuente de verdad, asi que al reintentar no hay que
  repetir trabajo — solo retomar en el punto exacto que diga el ledger.

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
