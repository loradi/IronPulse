# IRON & PULSE — Progreso

Reconstruccion de IronPulse hacia "IRON & PULSE" (SwiftUI + SwiftData, iOS 17+,
0 dependencias externas), siguiendo el plan de 8 fases del spec original.
Todo el trabajo vive en el branch `dev` (repo: https://github.com/loradi/IronPulse),
`main` es un checkpoint estable separado.

## Estado (2026-07-26): Fases 1-5 completas + limpieza chica de deuda diferida

- `006cf59` — Fase 1: sistema de diseno neon + `GIFImageView`
- `d39dfaa` — Fase 2: modelos SwiftData nuevos + seeder de 150 ejercicios
- `90b8c94`..`0628067` — recableado post-Fase 2 + navegacion real + fix de
  import de Salud y detalle de ejercicio: 0 errores de compilacion,
  0 `gifRemoteURLString` en null
- `6f48c97`..`e1578a4` — **Fase 3 completa**: generador de rutinas
  inteligente + armador manual, con un bug Critico encontrado en el
  review final y corregido (ver seccion "Fase 3 COMPLETA" abajo)
- `82104fa` — **Navegacion reestructurada a tab bar** (Dashboard/Rutina/
  Ejercicios/Perfil), primer paso hacia adoptar la referencia de
  `MOCKUPS/` — ver seccion propia abajo. Solo arquitectura de navegacion,
  el tema visual (verde/naranja) no cambio.
- `ba94b45`..`4d64c41` — **Fase 4 completa**: filtros por `MuscleGroup` y
  `EquipmentType` en `ExerciseListView` (lo unico que faltaba).
- `3a466e8`..`23affcf` — **Fase 5 completa**: modo de entrenamiento activo
  (ver seccion propia abajo). Incluye 2 bugs reales encontrados y
  corregidos durante la verificacion/review final.
- `df0da8f` — **Limpieza chica de deuda diferida de Fase 3/5** (ver seccion
  propia abajo): singularizacion de "N dias", rename de `isGeneratedByAI`,
  guard de catalogo vacio, step de `restSeconds` manual, nombre de rutina
  manual distinguible.
- Nueva referencia visual sin implementar en `MOCKUPS/` (rebrand +
  sistema de diseno "Kinetic Onyx" + tab bar) — ver seccion propia abajo,
  pendiente de decision del usuario

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
- [x] **Review final de toda la rama** (modelo mas capaz, sobre las 6
      tareas juntas). Encontro **1 bug Critico real** que ningun review
      por tarea podia ver — ver seccion siguiente.

**19 tests** en `IronPulseTests/WorkoutGeneratorServiceTests.swift` cubren
split/dias/prescripcion/seleccion (18 de las tareas + 1 del fix del bug
critico) — todos pasando.

### Bug Critico encontrado en el review final, corregido

El review final (el que mira las 6 tareas juntas, no cada diff por
separado) encontro que **`selectExercises` nunca elegia biceps ni core en
ninguna rutina generada, nunca**. Causa: el algoritmo original armaba 3
buckets (compuesto/aislamiento/core), los concatenaba, y cortaba a los
primeros N. Como el bucket de compuestos por si solo ya tiene 20+
ejercicios en cualquier dia real, `prefix(N)` nunca llegaba a aislamiento
ni a core. Y como **biceps y core no tienen NINGUN ejercicio compuesto en
todo el catalogo** (18 y 17 ejercicios respectivamente, todos aislamiento),
esos dos grupos musculares quedaban afuera de toda rutina generada, siempre
— un dia "Tiron" (espalda+biceps) salia 100% espalda. Confirmado
simulando 3000 rutinas contra el catalogo real: cero ejercicios de
aislamiento o core seleccionados, nunca.

Es un bug del algoritmo del spec (mio), no una desviacion del implementer
— el codigo matcheaba el spec al pie de la letra.

**Fix** (commit `e1578a4`): `selectExercises` reescrito a round-robin por
grupo muscular — arma un pool por cada grupo del template del dia, y elige
de a un ejercicio por grupo por ronda (ronda 0 = el primero de cada grupo,
ronda 1 = el segundo de los grupos que aun tengan, etc.) hasta llegar al
limite o agotar los pools. Esto garantiza que todo grupo del dia tenga
turno antes de que ningun grupo repita. Despues de elegir el conjunto, se
reordena para mostrar (compuesto -> aislamiento -> core), preservando
exactamente los invariantes que ya probaban los tests viejos.

Tambien en el mismo fix: 2 tests que eran vacuos (`if let` sobre un
resultado que podia no existir, pasaban sin verificar nada si no
encontraban el elemento buscado — eso fue lo que dejo pasar el bug sin que
ningun test lo agarrara) ahora tienen precondicion que falla si el bucket
viene vacio; y se agrego 1 test nuevo que corre `generateRoutine` contra
el catalogo REAL de 150 ejercicios (no el fixture sintetico de 16) en
todas las combinaciones de split/nivel, verificando que cada grupo
muscular del template del dia aparezca al menos una vez.

Re-review scoped confirmo: el fix arregla el bug de verdad (RED contra el
algoritmo viejo, GREEN contra el nuevo), sin roturas nuevas. Un Minor
quedo parqueado: el test nuevo no cubre el template "Cuerpo completo"
(fullBody) en ningun nivel porque tiene 7 grupos musculares y el limite
maximo es 6 — el guard que evita falsos negativos del test lo saltea
siempre en ese caso. No bloquea: el algoritmo en si es correcto, solo la
cobertura de ese test especifico es mas angosta de lo ideal.

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
- Fix del bug critico: el test nuevo `todosLosGruposDelTemplateAparecenConElCatalogoReal`
  no cubre el template "Cuerpo completo" (fullBody) en ningun nivel — su
  guard salta templates con mas grupos musculares (7) que el limite maximo
  de ejercicios por dia (6).

### Del review final — declinados o parqueados por decision del usuario

- **`RoutineBuilderView.save()` genera `dayNumber` con huecos** (Important,
  plan-mandated). Si el usuario llena el Dia 1 y el Dia 3 pero deja el Dia
  2 vacio, la rutina guardada tiene `dayNumber` 1 y 3 — sin el 2. La rutina
  generada siempre es consecutiva (1,2,3...). El usuario decidio **no
  arreglarlo ahora** — anotado porque la Fase 5 (conectar rutina con
  `WorkoutLog`) probablemente va a asumir dias consecutivos. Fix cuando se
  toque ese archivo: `for (index, draft) in draftDays.filter({ !$0.items.isEmpty }).enumerated()`
  en vez de filtrar despues de enumerar.
- ~~`isGeneratedByAI` queda permanentemente en `false`~~ — **RESUELTO**
  en la limpieza chica del 2026-07-26 (`df0da8f`): renombrado a
  `isAutoGenerated`, `true` desde `generateRoutine`.
- ~~Nombres de rutina inconsistentes entre los dos flujos~~ — **RESUELTO**
  en la misma limpieza: `"Rutina manual - \(splitType.displayName)"`.
- **Comentario de "solo lado coleccion" no matchea `UserProfile.activate`**:
  el comentario en `WorkoutGeneratorService.swift`/`RoutineBuilderView.swift`
  dice que solo se asigna el lado coleccion de la relacion, pero
  `UserProfile.activate` si asigna `routine.profile = self` (el lado
  inverso del edge profile<->rutina). Funciona igual por como SwiftData
  mantiene el inverso, pero es confuso para quien lea el comentario
  literal. Acotar el comentario a los edges dia/ejercicio, o alinear el
  helper.
- ~~`restSeconds` del stepper manual no divide el default de `fatLoss`~~ —
  **RESUELTO** en la limpieza chica del 2026-07-26 (`df0da8f`): step
  bajado de 15 a 5.
- ~~Mas sitios de "1 dias" sin singularizar~~ — **RESUELTO** en la misma
  limpieza con el helper `diasLabel()` en los 5 sitios (`DashboardView`,
  `ContentView` x2, `RoutineTabView`, `RoutineBuilderView`).
- ~~Sin guard contra activar una rutina sin ejercicios~~ — **RESUELTO**:
  `RoutineTabView.generateRoutine()` (el guard se movio ahi con el
  recableado de tabs) ahora tiene `guard !catalog.isEmpty else { return }`.
- **`MuscleGroup.arms/.calves/.fullBody` sin cobertura en ningun
  template**: el catalogo actual no usa esos 3 casos, pero si algun
  ejercicio futuro se agrega bajo esos grupos, queda silenciosamente
  imposible de seleccionar — sin senal en compilacion ni en runtime.
- **Nota vieja sobre "1 dias" en la seccion "Verificado en simulador" de
  abajo estaba mal**: decia "no es bug". El review final SI lo confirmo
  como bug real (menor, cosmetico) — ver el punto de arriba.

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
- Nota corregida por el review final: la tarjeta manual mostro "1 dias".
  Que los dias 2 y 3 sin ejercicios no se persistan como `RoutineDay`
  vacios **si es el comportamiento correcto** (el spec no pide dias
  vacios). Pero el texto "1 dias" en si (sin singularizar) **es un bug
  real, aunque menor** — confirmado por el review final, ver "Minors
  diferidos" arriba.
- Ningun screenshot mostro contenido faltante o incorrecto frente a lo
  esperado por el brief.

## Navegacion por tabs — COMPLETA (2026-07-26)

Primer paso hacia adoptar la arquitectura de `MOCKUPS/` (ver seccion de
abajo): se decidio separar la navegacion (tab bar) del reskin visual
completo (Kinetic Onyx) — esto es solo lo primero. Spec:
`docs/superpowers/specs/2026-07-26-tab-navigation-design.md`. Se
implemento directo (sin el aparato de subagentes de la Fase 3, cambio
chico y bien acotado), commit `82104fa`.

**Decisiones**: multi-perfil se mantiene (`ContentView` sigue siendo la
pantalla raiz de lista de perfiles; al elegir uno se entra a un
`TabView` para ESE perfil, no se colapsa a un solo usuario como asume el
mockup). El tab "Rutina" (sin mockup dedicado) se definio en la charla:
la `RoutineCard` completa + los dos botones de creacion. El tab "Perfil"
por ahora es el `ProfileDetailView` de siempre, sin las metricas de
volumen/racha del mockup (dependen de `WorkoutLog`, Fase 5).

- [x] `Views/MainTabView.swift` (nuevo) — `TabView` de 4 tabs, cada uno
      con su propio `NavigationStack`: Dashboard, Rutina, Ejercicios,
      Perfil.
- [x] `Views/Workouts/RoutineTabView.swift` (nuevo) — contenido movido
      tal cual desde `DashboardView`: la `RoutineCard`, los botones
      "Rutina inteligente"/"Crear rutina manual", `generateRoutine()`.
- [x] `DashboardView.swift` — se achico a header + una linea de resumen
      (`"<nombre rutina> · N dias"`) si hay rutina activa. Perdio el
      `@Query` del catalogo, el toolbar de 2 botones, y el parametro
      `healthImporter` (ya no lo usa).
- [x] `ContentView.swift` — el `NavigationLink` de cada perfil apunta a
      `MainTabView` en vez de `DashboardView`.
- [x] Verificado en simulador: los 4 tabs navegan, cada uno con su
      propio historial de push (confirmado empujando el detalle de un
      ejercicio dentro del tab Ejercicios y volviendo). Los 19 tests de
      `WorkoutGeneratorServiceTests` siguen pasando (sin logica nueva,
      es reorganizacion de vistas).
- Sin hallazgos — no se toco ningun flujo de negocio, solo donde se
  montan las vistas existentes.

## MOCKUPS/ — referencia visual nueva, SIN implementar (2026-07-25)

El usuario agrego una carpeta `MOCKUPS/` en la raiz del repo (no versionada
todavia — es nueva, no confundir con parte del codigo actual) con
referencia de diseno para toda la app. **No se implemento nada de esto
todavia**, queda documentado para cuando se decida abordarlo.

Contenido:

- **`kinetic_onyx/DESIGN.md`** — sistema de diseno completo con nombre
  propio ("Kinetic Onyx"): negro puro (`#000000`/`#121212` para
  superficies) + lima electrico `#D4FF00` como unico acento, tipografia
  Inter (texto) + JetBrains Mono (numeros: reps/series/pesos/timers), sin
  sombras (profundidad via bordes de 1px `#222222` y capas de superficie),
  esquinas redondeadas 1rem en cards, botones pill. **Distinto del tema
  actual de la app** (`Theme/CustomColor.swift`: verde neon `#00FF66` +
  naranja `#FF3300`, sin fuente monoespaciada para datos).
- **`logo/screen.png`** — logo real de marca: circulo negro, borde y
  rayo+mancuerna en lima electrico, texto **"WATT + WEIGHT"**. Sugiere que
  el usuario esta considerando un rebrand del nombre actual ("IRON &
  PULSE") a "Watt + Weight" — no confirmado, no preguntado todavia.
- **7 mockups de pantalla** (`screen.png` + `code.html` con la
  implementacion HTML/CSS de referencia en cada carpeta): `mi_rutina`
  (dashboard con calendario semanal Lun-Dom, tarjeta de "sesion de hoy"
  con foto de fondo, tab bar inferior Dashboard/Routine/Exercises/Profile
  — la app actual no tiene tab bar, es todo `NavigationStack` con push),
  `biblioteca_de_ejercicios`, `perfil_de_usuario`,
  `configuracion_de_perfil`, `detalle_de_ejercicio`, `sesion_en_curso`,
  `sesion_en_curso_con_guia`.
- **`professional_3d_medical_illustration_.../screen.png`** — arte de
  referencia (ilustracion 3D de alguien haciendo press banca), probable
  imagen hero.
- **`swift_workoutgeneratorservice_specification.md`** — un spec/codigo
  Swift de referencia para `WorkoutGeneratorService`, aparentemente
  externo o de una sesion anterior a que se implementara el real. Modelo
  de datos mas simple que el actual (`UserProfile.availableDays`, sin
  `RoutineDay`, usa `WorkoutSession`/`ScheduledExercise`, splits con
  limites de dias distintos: `1...3` full body en vez de `1...2`).
  Interesante: su algoritmo de seleccion (`generateSession`) elige **un
  compuesto Y un aislamiento por grupo muscular**, en espiritu igual al
  round-robin-por-grupo al que se termino llegando arreglando el bug
  critico de arriba — coincidencia util, no una contradiccion. No es
  literalmente lo que hay que implementar (el modelo de datos ya no
  matchea la app real), pero vale la pena mirarlo si se revisita el
  algoritmo.

**No hay ninguna decision tomada todavia sobre si/como adoptar esto.**
Antes de tocar UI para alinearla con estos mockups hace falta una sesion
de brainstorming propia (alcance grande: rebrand + nueva IA de navegacion
con tab bar + sistema de diseno completo nuevo) — no es un ajuste chico
que se cuela en otra fase.

## Fase 4 — COMPLETA

La Fase 4 original ("biblioteca de ejercicios UI") se hizo casi entera
durante el recableado de navegacion, antes de arrancar la Fase 3, y se
cerro con los filtros:

- [x] `ExerciseListView` lee el catalogo local con `@Query` (ya no
      `WgerAPIService`), con buscador por nombre.
- [x] Vista de detalle (`ExerciseDetailView`) con imagen grande via
      `GIFImageView`, musculos secundarios e instrucciones numeradas.
- [x] `WgerAPIService.swift` y `WgerModels.swift` **borrados** — quedaron
      con 0 callers. La pregunta que la Fase 2 dejaba abierta ya tiene
      respuesta.
- [x] Filtros por `MuscleGroup` y `EquipmentType` agregados a
      `ExerciseListView` (spec: `docs/superpowers/specs/2026-07-26-exercise-filters-design.md`,
      commit `4d64c41`).

## Fase 5 — Modo de entrenamiento activo — COMPLETA

Spec: `docs/superpowers/specs/2026-07-26-active-workout-design.md`. Plan:
`docs/superpowers/plans/2026-07-26-active-workout.md`. Ejecutado con
`subagent-driven-development` (subagente implementador por tarea + review
por tarea + review final de rama completa en el modelo mas capaz).

7 tareas, todas completas:

1. Campos nuevos en `SetLog`/`WorkoutLog` (`restSeconds`, `targetReps`,
   `dayTitle`).
2. `WorkoutLogGenerator`: arma el `WorkoutLog` + `SetLog`s desde un
   `RoutineDay` de la rutina activa.
3. `RestNotificationScheduler`: notificacion local de respaldo para el
   descanso (por si la app esta en background cuando termina el timer).
4. Rediseño de `ActiveWorkoutView`: sets agrupados por ejercicio, peso/reps
   editables en vivo, descanso real tomado de `RoutineExercise.restSeconds`
   (ya no 60s fijos).
5. Boton "Empezar" por dia en `RoutineTabView` que genera el log y navega
   a `ActiveWorkoutView`.
6. `WorkoutHistoryView` (lista de sesiones terminadas) + entrada desde el
   Dashboard.
7. Verificacion completa en simulador de todo el flujo: generar rutina →
   empezar dia → editar peso/reps → completar set (timer real + prompt de
   notificacion) → terminar → verificar entrada en historial → reabrir en
   modo solo-lectura.

**2 bugs reales encontrados y corregidos durante la Fase 5** (uno en la
Tarea 7 de verificacion, otro en el review final de toda la rama):

- **Navegacion rota en `WorkoutHistoryView`** (`2999722`): un `NavigationLink`
  dentro de un `List` que a su vez esta empujado dentro de otro
  `NavigationStack` dejaba de responder a CUALQUIER tap, incluso el boton
  de volver atras — reproducido de forma consistente (relanzando la app,
  reiniciando el simulador, reiniciando Simulator.app). Fix: reemplazar el
  `NavigationLink` por `Button { selectedLog = log }` +
  `.navigationDestination(item: $selectedLog)`, el mismo patron que ya
  funcionaba en `RoutineTabView` → `ActiveWorkoutView`. **Si en el futuro
  aparece una fila de `List` que no responde a taps dentro de una vista
  empujada (no la raiz de su propio stack), sospechar primero de este
  patron antes que de otra cosa.**
- **Fuga de historial entre perfiles** (`fad2cb8`, Importante, encontrado
  por el review final): `WorkoutHistoryView` leia todos los `WorkoutLog`
  de la base con un `@Query` sin escopar por perfil — en una app
  multi-perfil real, el Perfil B veia el historial del Perfil A. Fix:
  `WorkoutHistoryView` ahora toma `profile: UserProfile` como parametro y
  deriva `logs` de `profile.workoutLogs` (la relacion inversa ya existente
  en `UserProfile.workoutLogs`, `@Relationship(deleteRule: .cascade,
  inverse: \WorkoutLog.profile)`) en vez de un `@Query` global.
- 2 hallazgos Menores mas del mismo review, corregidos en `23affcf`: el
  prompt de permiso de notificaciones se disparaba tambien al abrir una
  sesion ya terminada en modo lectura (ahora solo pide permiso si
  `!isReadOnly`), y el `Task` del timer de descanso no se cancelaba al
  salir de la vista (`onDisappear { restTask?.cancel() }`).

Review final de toda la rama corrido en el modelo mas capaz (opus), NEEDS
FIXES en la primera pasada por los 2 items de arriba + los 2 menores, un
solo round de fix + re-review acotado, limpio en la segunda pasada. Al
cerrar limpio, se borro el workspace de SDD
(`.superpowers/sdd/2026-07-26-active-workout/`) por instruccion del
skill.

## Limpieza chica de deuda diferida de Fase 3/5 (2026-07-26)

5 items de la lista "Minors diferidos"/"declinados" de abajo, todos de
bajo riesgo y sin decision de producto pendiente (commit `df0da8f`):

- **Singularizacion de "1 dias"**: nueva funcion `diasLabel(_ count: Int)`
  en `Theme/CustomColor.swift` (`"1 dia"` / `"N dias"`), usada en los 5
  sitios que mostraban el bug: `DashboardView.swift`, `ContentView.swift`
  (x2: resumen de perfil y stepper de dias), `RoutineTabView.swift`
  (`RoutineCard`) y `RoutineBuilderView.swift` (stepper de dias). Verificado
  en vivo con un perfil en 1/2/3 dias — singular y plural correctos en los
  3 primeros sitios (los otros 2 comparten el mismo helper).
- **`isGeneratedByAI` (dead field, siempre `false`) renombrado a
  `isAutoGenerated`**, ahora seteado en `true` desde
  `WorkoutGeneratorService.generateRoutine` (el flujo manual sigue pasando
  `false`). Distingue por primera vez una rutina generada de una manual.
- **Nombre de rutina manual** cambiado de `"Rutina manual - \(profile.name)"`
  (constante por perfil, indistinguible en el historial) a
  `"Rutina manual - \(splitType.displayName)"`.
- **Guard contra generar una rutina inteligente con el catalogo vacio**:
  `RoutineTabView.generateRoutine()` ahora tiene
  `guard !catalog.isEmpty else { return }` antes de llamar al generador.
- **Step del `Stepper` de `restSeconds` manual** bajado de 15 a 5 — con
  15 nunca se llegaba al default de 40s de `fatLoss` (40 → 25 o 55, nunca
  30/45/60).

**Gotcha nuevo confirmado en esta limpieza**: renombrar una property
`@Model` (no solo agregar una nueva no-opcional) tiene el mismo efecto que
el gotcha de SwiftData ya documentado abajo — el store viejo en el
simulador no migra y `ModelContainer` explota con
`fatalError("Could not create ModelContainer: ...")` (`EXC_BREAKPOINT` en
`IronPulseApp.swift`, closure de `sharedModelContainer`). Mismo fix:
`xcrun simctl uninstall <device> com.BERNU.IronPulse` antes de reinstalar.
Build compila igual con SourceKit quejandose y con `xcodebuild` en verde;
el error solo aparece en runtime al intentar migrar el store.

## Siguientes pasos

**Fases 1-5 estan 100% completas** (ver secciones propias arriba), mas la
limpieza chica de deuda diferida del 2026-07-26. Sigue pendiente una sola
decision del usuario, no tecnica: si integrar la rama `dev` (merge/PR) o
seguir trabajando encima — no se ejecuta solo, se espera instruccion
explicita (flujo `finishing-a-development-branch`).

Pendientes reales que quedan, todos requieren alguna decision de producto
o son de alcance mayor (no son fixes directos):

1. **Rebrand visual `MOCKUPS/`** (rebrand "Watt + Weight" + reskin visual
   "Kinetic Onyx" completo) — pendiente de su propia sesion de
   brainstorming, alcance grande. El tab bar fue la primera pieza
   adoptada de esa referencia, ya resuelta.
2. **Spec nuevo — idioma + foto de perfil**: selector espanol/ingles/frances
   (i18n de toda la app) y foto por `UserProfile`. Ya acordado con el
   usuario que van en un documento aparte.
3. Definir fuente real de GIFs animados (o aceptar las fotos JPG de
   free-exercise-db como definitivas).
4. **4 ejercicios duplicados en el seed** (mismo ejercicio dado de alta dos
   veces bajo dos grupos musculares, herencia de los 7 subagentes en
   paralelo): `Encogimientos con barra` (back/shoulders), `Face pull en
   polea` (back/shoulders), `Fondos en banco` (chest/triceps), `Fondos en
   paralelas` (chest/triceps). Los ids son unicos asi que el seeder inserta
   los 8; en la biblioteca salen repetidos. Decidir si se fusionan usando
   `secondaryMuscles` o se dejan.
5. `ProfileSelectionView.swift` sigue huerfana y duplica lo que ya hace
   `ContentView` (listar perfiles + crear). Evaluar si se borra.
6. `RoutineBuilderView.save()` genera `dayNumber` con huecos — declinado
   explicitamente por el usuario, no tocar salvo que lo pida (ver "Del
   review final — declinados o parqueados" arriba).

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
- **Coordenadas de tap para tab bars**: el espacio de tap del control del
  simulador es 390x844 puntos. Para un `TabView` de N tabs, cada tab
  ocupa `390/N` puntos de ancho — para 4 tabs, centros aprox en x=49,
  146, 244, 341. El eje Y de la tab bar esta cerca de `y=810` (no calcular
  a partir del porcentaje visual de un screenshot, da resultados muy
  lejos del real — cuesta varios intentos fallidos si se hace asi).
- **Simctl a veces devuelve "Unable to lookup in current state: Shutdown"**
  o un timeout de "simulator likely rebooted" en medio de una sesion larga.
  Se soluciona con `xcrun simctl boot <UDID>` +
  `xcrun simctl bootstatus <UDID> -b` antes de reinstalar/lanzar.
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
