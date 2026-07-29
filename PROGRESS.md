# IRON & PULSE — Progreso

Reconstruccion de IronPulse hacia "IRON & PULSE" (SwiftUI + SwiftData, iOS 17+,
0 dependencias externas), siguiendo el plan de 8 fases del spec original.
Todo el trabajo vive en el branch `dev` (repo: https://github.com/loradi/IronPulse),
`main` es un checkpoint estable separado.

## Estado (2026-07-27): Fases 1-5 + tendencias/sesion guiada + rebrand "Watt + Weight" completas, PR #1 abierto

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
- `5bfbd3c`..`6878439` — **Tendencias de perfil + sesion guiada con
  auto-avance COMPLETA** (ver seccion propia abajo): dia de rutina por
  dia de la semana, `WorkoutStatsService` (volumen/racha/grafico/progreso
  por ejercicio), masa magra de HealthKit, auto-avance de sets con
  descanso 60-90s segun `isCompound`, rediseno de `DashboardView`. Incluye
  un bug real serio encontrado y corregido (`Chart` de Swift Charts
  bloqueando todos los toques de la pantalla) y 2 hallazgos Important del
  review final tambien corregidos.
- `3c4c26b`..`9264a26` — **Rebrand "Watt + Weight" + reskin visual "Kinetic
  Onyx" COMPLETO** (13 tareas via `subagent-driven-development`, ver
  seccion propia abajo). El nombre visible, bundle id, app icon, paleta,
  tipografia, componentes nuevos (`TagBadge`, `LabeledProgressBar`,
  `AvatarPlaceholder`, `MuscleDiagramView`) y 146 pro tips de ejercicios
  se aplicaron a las 9 vistas existentes sin tocar logica de negocio.
  Verificacion final en simulador encontro y corrigio 2 bugs reales (ver
  seccion propia).
- **PR #1 abierto**: https://github.com/loradi/IronPulse/pull/1
  (`dev` → `main`), esperando review/merge del usuario.

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

**Actualizacion (2026-07-27): esto ya se implemento entero.** Ver la
seccion "Rebrand 'Watt + Weight' + reskin visual 'Kinetic Onyx' —
COMPLETA" mas abajo. Se deja esta seccion tal cual quedo escrita en su
momento como registro historico de la referencia original.

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

## Tendencias de perfil + sesion guiada con auto-avance — COMPLETA (2026-07-27)

Spec: `docs/superpowers/specs/2026-07-26-profile-trends-guided-session-design.md`.
Plan: `docs/superpowers/plans/2026-07-26-profile-trends-guided-session.md`.
Ejecutado con `subagent-driven-development` (7 tareas, cada una con
implementador + review propio, mas review final de toda la rama en el
modelo mas capaz). Esto era el pendiente 7 de la lista anterior — quedo
resuelto completo, incluidas las 3 decisiones de diseno que estaban
abiertas (dia por dia de la semana asignado automaticamente y parejo,
no por secuencia; intensidad = `Exercise.isCompound` → 90s/60s,
reemplaza al `restSeconds` viejo en la sesion guiada; set no completado
pausa el auto-avance en vez de reintentar solo).

- `5bfbd3c` — `Weekday` (enum nuevo) + asignacion automatica de dia de
  semana a `RoutineDay` (tabla fija por `workoutDaysPerWeek`, igual en
  el generador automatico y el armador manual).
- `7cbf696` — `WorkoutStatsService`: volumen total, conteo de
  entrenamientos, racha, serie de volumen diario (30 dias), progreso de
  peso maximo por ejercicio. Funciones puras, mismo estilo que
  `WorkoutGeneratorService`.
- `1bfca9d` — `leanBodyMassKg` en `HealthSnapshot` + lectura desde
  HealthKit (mismo patron que `bodyMassKg`, sin permiso nuevo que pedir
  aparte).
- `73a6666` — `GuidedSessionFlow` (logica pura: descanso por
  `isCompound`, siguiente set) + auto-avance en `ActiveWorkoutView`:
  el primer set se resalta solo al entrar, completar el set activo
  dispara descanso real y avanza solo al siguiente al terminar; marcar
  un set fuera de orden o destildarlo no dispara nada.
- `988579d` — `ExerciseProgressView`: grafico de progreso de un
  ejercicio (Swift Charts).
- `4372622`+`b9bf177` — Rediseno de `DashboardView` (no una vista
  nueva — es la pantalla a la que ya se llega al tocar un perfil):
  tarjeta de "hoy" con boton "Iniciar ejercicios", metricas, grafico de
  30 dias, masa magra (si hay >=2 snapshots), progreso por ejercicio,
  historial. El review de esta tarea encontro codigo duplicado entre
  `DashboardView.startTodaysSession` y `RoutineTabView.startWorkout`,
  extraido a `WorkoutLogGenerator.startSession(for:routineName:profile:in:)`.
- `35a20b7` — **Bug real encontrado en la verificacion en simulador,
  el mas serio de esta tanda**: al agregar el `Chart` de Swift Charts a
  `DashboardView`, la pantalla entera dejo de responder a CUALQUIER
  toque — no solo el grafico: el boton "Iniciar ejercicios", los
  `NavigationLink`, hasta la tab bar del `TabView` (que ni siquiera esta
  dentro del mismo `ScrollView`). Se descarto por bisagra en vivo que
  fuera el `NavigationStack` anidado (`ContentView` empuja `MainTabView`,
  que crea 4 `NavigationStack` propios) armando un fix con
  `fullScreenCover` que **no** resolvio nada — y se confirmo la causa
  real comparando, en el mismo simulador, contra el `DashboardView`
  viejo de antes de esta tanda (que si respondia) y despues quitando
  secciones nuevas una por una hasta aislar el `Chart`. **Fix real**:
  `.allowsHitTesting(false)` en el `Chart` (tanto en `DashboardView`
  como en `ExerciseProgressView`, mismo patron) — ningun grafico de esta
  pantalla tiene seleccion/scrubbing, son puramente decorativos.
  El review final califico esto como "mitigacion verificada, no causa
  raiz probada" (podria ser hit-testing genuino del Chart o un loop de
  layout contra `.ironCard()` sin ancho fijo; en cualquier caso el fix
  es correcto para un grafico decorativo). **Regla a futuro: cualquier
  `Chart` de Swift Charts sin interaccion propia dentro de un
  `ScrollView` necesita `.allowsHitTesting(false)`, o puede tragarse los
  toques de toda la pantalla, no solo los suyos.**
- `9236338` — Limpieza chica adicional pedida en la misma sesion: los 4
  ejercicios duplicados del seed (`Encogimientos con barra`, `Face pull
  en polea`, `Fondos en banco`, `Fondos en paralelas`, cada uno dado de
  alta dos veces bajo distinto grupo muscular) fusionados — cada
  entrada que se mantuvo ya tenia el grupo de la duplicada en
  `secondaryMuscles`, asi que el catalogo bajo de 150 a **146** sin
  perder cobertura muscular. `ProfileSelectionView.swift` (huerfana,
  sin ningun caller) borrada.
- `6878439` — **2 hallazgos Important del review final de toda la
  rama, corregidos en una sola tanda**: (1) `WorkoutStatsService.
  currentStreak` devolvia 0 en un dia programado si todavia no se
  entrenaba ese dia (rompia una racha real cada manana de dia de
  entrenamiento) — ahora el dia de hoy sin sesion no corta la racha,
  solo un dia *anterior* programado y sin sesion la corta; (2)
  destildar el set activo a mitad del descanso no cancelaba el timer ni
  la notificacion local, y el auto-avance seguia disparandose igual —
  ahora cancela ambos.

**Review final de toda la rama** (opus): veredicto "Ready to merge: Yes".
6 hallazgos Minor quedaron sin accion (no bloquean, ver ledger de la SDD
ya borrado — resumen: `Weekday.today(now:)` usado como mapeador general
de fechas pasadas, nombre confuso pero funciona; `RoutineBuilderView`
asigna `weekday` por posicion sin filtrar dias vacios, igual que ya
pasaba con `dayNumber`; `startTodaysSession`/`startWorkout` pueden crear
logs duplicados sin terminar si se sale sin terminar la sesion, invisible
en toda la UI porque todo filtra por `endDate != nil`; sin cache en las
metricas del Dashboard, irrelevante al volumen de datos actual; el
numero de volumen no se formatea en toneladas para usuarios de mucho
tiempo).

**PR abierto**: https://github.com/loradi/IronPulse/pull/1 (`dev` → `main`,
52 commits, Fases 1-5 completas + esta tanda). Decision de push+PR (en
vez de merge local o seguir en `dev`) tomada por el usuario via el flujo
`finishing-a-development-branch`.

## Rebrand "Watt + Weight" + reskin visual "Kinetic Onyx" — COMPLETA (2026-07-27)

Spec: `docs/superpowers/specs/2026-07-27-watt-weight-rebrand-design.md`.
Plan: `docs/superpowers/plans/2026-07-27-watt-weight-rebrand.md`. Ejecutado
con `subagent-driven-development` (13 tareas, implementador + review por
tarea, mas Tarea 13 de verificacion final en simulador + documentacion).
Esto era el pendiente 1 de la lista de abajo — la referencia visual de
`MOCKUPS/` (ver seccion propia arriba) que llevaba desde el 2026-07-25 sin
implementar.

### Que se construyo

- **Identidad de marca** (`3c4c26b`): bundle id `com.BERNU.WattWeight`,
  `CFBundleDisplayName` "Watt + Weight" (visible en home screen del
  simulador y en el navigation title de la lista de perfiles), App Icon
  nuevo (circulo negro + rayo/mancuerna + texto en lima electrico, ya no
  el icono generico gris de Xcode), y `wwLogoMark` (mismo logo escalado a
  60/120/180px, reutilizado como imagen de header en `ExerciseListView` —
  simplificacion documentada en el plan para no depender de un recorte
  manual impreciso de la imagen generada por IA).
- **Theme "Kinetic Onyx"** (`2e04fb7`), en `Theme/CustomColor.swift`,
  dark-only (cero `dynamic(light:dark:)`, todos los tokens son hex planos):
  - Colores: `ironAccent` `#CAF300` (lima electrico, unico acento),
    `ironDanger` `#FF3300`, `ironBackground` `#121317`, `ironCard`
    `#1E1F23`, `ironCardElevated` `#292A2E`, `ironBorder` `#343539`,
    `ironTextPrimary` `#E3E2E7`, `ironTextSecondary` `#9A9E86`. Los
    *nombres* de los tokens no cambiaron desde la Fase 1 (`ironAccent`,
    `ironCard`, etc.), solo sus valores hex — la mayoria de las vistas no
    tuvieron que tocar sus referencias de color.
  - `neonGlow()` (sombra) eliminado por completo, reemplazado por un
    borde extra en sus 2 call sites — el design system prohibe sombras,
    la profundidad se resuelve con bordes de 1px y capas de superficie.
  - Tipografia: Inter (Regular/Medium/Bold/ExtraBold) + JetBrains Mono
    (Regular/Medium) bundleadas en `Resources/Fonts/`, registradas via
    `INFOPLIST_FILE` merge (`UIAppFonts.plist`) en vez del array
    `INFOPLIST_KEY_UIAppFonts` — ese array se descarta en silencio con el
    `GENERATE_INFOPLIST_FILE=YES` de este proyecto, se verifico con
    build+lldb real. Tokens nuevos: `.wwDisplay`, `.wwHeadline`,
    `.wwTitle3`, `.wwBody`, `.wwCaption`, `.wwLabelCaps`,
    `.wwDataMono(_:)` (JetBrains Mono para pesos/reps/timers).
  - `CornerRadius`/`Spacing` enums + `.ironCard()` modifier (sin sombra).
- **Componentes compartidos nuevos** (`49199ad`, `92b0112`):
  `TagBadge` (chip con borde, usado para el badge "COMPOUND"),
  `LabeledProgressBar` (barra de progreso etiquetada, usada para el
  volumen de sesion), `AvatarPlaceholder` (circulo con iniciales del
  perfil, funcion pura `initials(from:)` testeada aparte),
  `MuscleDiagramView` (diagrama abstracto de 5 zonas del cuerpo —
  hombros/pecho/brazos/core/piernas — no una ilustracion anatomica
  realista; mapeo fijo de los 11 `MuscleGroup` a esas 5 zonas via la
  funcion pura `zones(primary:secondary:)`, testeada aparte).
- **`WorkoutStatsService.weekStrip`** (`6a5de49`): tira semanal Lun-Dom
  para el Dashboard (`WeekdayStatus`: `.notScheduled`/`.pending`/
  `.completed` por dia).
- **146 pro tips de ejercicios** (`b6c763e`): campo nuevo `Exercise.proTip:
  String?`, un consejo especifico por ejercicio (no una plantilla generica
  por grupo muscular) redactado a partir de los campos existentes de cada
  entrada (`instructions`, `isCompound`, `secondaryMuscles`), verificado
  con script que confirma cobertura 146/146 y cero duplicados.
- **Las 9 vistas existentes** actualizadas a los tokens nuevos
  (`9ec1c4d`, `f1920b6`, `2fc5f66`, `3ad4893`, `6a9f343`): Dashboard (tira
  semanal nueva insertada entre header y tarjeta de hoy), lista/detalle de
  ejercicios (badge "Compound", `MuscleDiagramView`, tarjeta de pro tip),
  sesion activa (barra de "Session Volume" via `LabeledProgressBar`,
  calculo inline de `weightKg × reps` de los sets completados), perfil
  (avatar con iniciales, `Slider` en vez de `Stepper` para dias/semana),
  resto de pantallas (Rutina, Constructor de rutina, Historial,
  Selector de ejercicio, Progreso por ejercicio, tab bar) con la regla
  mecanica de reemplazo de fuentes de sistema por tokens `.ww*`.

### Verificacion final (Tarea 13) — 2 bugs reales encontrados y corregidos

**Suite de tests**: 59/59 en verde (`xcodebuild test -only-testing:
IronPulseTests`, iPhone 17) — los 58 tests previos (incluidos los nuevos
de `AvatarPlaceholderTests`, `MuscleDiagramZoneTests` y los casos nuevos
de `WorkoutStatsServiceTests` de tareas anteriores) mas 1 test de
regresion nuevo agregado en esta tarea.

**Recorrido visual completo en simulador** (iPhone 17, sesion con acceso
real al dispositivo) — las 9 vistas se vieron corriendo, incluidas 3 que
nunca se habian confirmado en vivo en ninguna tarea anterior por
problemas de acceso al simulador: `RoutineBuilderView`,
`WorkoutHistoryView` y `ExercisePickerSheet`. Tambien se confirmo en vivo
que la barra de "Session Volume" sube de "0 kg" a "200 kg" al instante al
completar reps de un set (200kg × 1 rep), que el Dashboard con la tira
semanal nueva no tiene ningun boton/NavigationLink sin responder (la
regresion historica de `Chart` de la tanda anterior no reaparecio), que
el diagrama muscular resalta la zona correcta segun `primary`/
`secondary`, y que el app icon + nombre "Watt + Weight" se ven bien en el
home screen del simulador.

Esta misma verificacion **encontro 2 bugs reales que ningun review por
tarea habia detectado** (commit `9264a26`, causa raiz confirmada
inspeccionando el store SwiftData en runtime, no solo leyendo codigo):

1. **Los 146 pro tips nunca llegaban a la app corriendo.**
   `ExerciseSeedDTO` (`ExerciseDatabaseSeeder.swift`) nunca declaraba el
   campo `proTip` agregado en la Tarea 7, asi que `JSONDecoder` lo
   ignoraba en silencio (Codable ignora claves no declaradas) y todo
   `Exercise` sembrado quedaba con `proTip = nil` pese a que las 146
   entradas del JSON lo tienen relleno. La tarjeta de pro tip en
   `ExerciseDetailView` (con codigo correcto desde la Tarea 9) nunca se
   habia renderizado en ningun build hasta este fix — se confirmo
   consultando directo la tabla `ZEXERCISE` del `.store` sqlite del
   simulador (`ZPROTIP` vacio en las 146 filas) antes del fix, y viendo
   la tarjeta con el lightbulb + texto real en pantalla despues. Fix:
   agregar `proTip` a la DTO + pasarlo en `toModel()`, mas un test de
   regresion (`todosLosEjerciciosSembradosTienenProTip`) que decodifica
   el catalogo real y falla si algun `proTip` llega vacio al modelo
   sembrado — exactamente el hueco que dejo pasar el bug sin que ningun
   test lo agarrara.
2. **`.preferredColorScheme(.dark)` nunca se aplicaba a la app real,
   solo a los `#Preview` de 6 vistas.** Las Tareas 8-12 agregaron
   `.preferredColorScheme(.dark)` correctamente dentro de cada
   `_Previews`/`PreviewProvider` de `DashboardView`, `ActiveWorkoutView`,
   `RoutineTabView`, `WorkoutHistoryView`, `ExerciseListView` y
   `ExerciseProgressView` — pero `IronPulseApp.swift` (el `WindowGroup`
   raiz de la app real) nunca lo tuvo. Mientras el simulador estuviera en
   apariencia Light del sistema (confirmado con
   `xcrun simctl ui ... appearance` = `light`), cualquier control que
   dependiera de `.primary`/chrome nativo en vez de un token `Color.iron*`
   explicito se veia en modo claro: el `Form` completo de
   `ProfileDetailView` (fondo blanco, texto negro — la mayoria de las
   demas vistas se salvaban por pura casualidad, porque el paso mecanico
   de tokens de las Tareas 8-12 les puso `.foregroundStyle(Color.iron*)`
   a practicamente todo texto), el `Text(exercise.name)` sin estilo de
   `ExerciseListView`/`ExercisePickerSheet` (heredaba el color de label
   por defecto de `NavigationLink`/`Button`, negro o lima segun el
   control, no `ironTextPrimary`), y hasta el titulo "Watt + Weight" y el
   texto "Sin perfiles" de la lista de perfiles raiz (`ContentView`)
   salian en un gris casi invisible sobre el fondo oscuro. Fix de raiz en
   un solo lugar: `.preferredColorScheme(.dark)` en el `WindowGroup` de
   `IronPulseApp.swift` — se verifico en vivo que esto arreglo los 3
   sitios de una sola vez (Form de perfil, texto de la lista de
   ejercicios, titulo de la lista de perfiles) sin tocar ninguna otra
   vista.

**Hallazgos menores confirmados en vivo, sin accion (cosmeticos, ya
sopesados por reviews anteriores)**:

- `TagBadge` junto al nombre del ejercicio en `ExerciseListView` fuerza
  wrap en nombres largos (ej. "Press inclinado con mancuernas" queda en
  3 lineas, con la palabra "con" sola en su propia linea) — se ve
  raro pero sigue siendo legible, consistente con el juicio ya registrado
  en el ledger de la Tarea 9 ("Text wraps gracefully").
- El sistema de alerta nativo de iOS (permiso de notificaciones, "Watt +
  Weight Would Like to Send You Notifications") sale en apariencia clara
  incluso con el fix de `.preferredColorScheme(.dark)` aplicado — es
  comportamiento esperado de iOS, las apps no pueden forzar el tema de
  las hojas de permiso del sistema.

### Simplificaciones documentadas del spec (decisiones, no atajos)

- `MuscleDiagramView` es un diagrama abstracto de 5 zonas geometricas,
  no una ilustracion anatomica realista ni un par frente/espalda —
  cubre la intencion del mockup (resaltar la zona objetivo) con la
  complejidad minima.
- `wwLogoMark` reutiliza la misma imagen 1024×1024 del App Icon
  (circulo + rayo + texto), solo escalada, en vez de un recorte
  separado sin anillo/texto.
- La barra de "Session Volume" en `ActiveWorkoutView` usa
  `progress: 1.0` fijo (barra siempre llena) porque no existe un
  "volumen objetivo" real en el modelo — agregar ese campo solo para
  esta barra hubiera sido alcance fuera de lo pedido.

Commits de la tanda completa: `3c4c26b`..`9264a26` (13 tareas + 1 commit
de fix post-verificacion). Sin PR nuevo — se suma al mismo PR #1 abierto
(`dev` → `main`), que sigue esperando review/merge del usuario.

## Foto de perfil — 7/7 tareas completas, bug del picker corregido (2026-07-28)

Spec: `docs/superpowers/specs/2026-07-28-profile-photo-design.md`. Plan:
`docs/superpowers/plans/2026-07-28-profile-photo.md`. Ejecutado con
`subagent-driven-development` (7 tareas, implementador + review por tarea).
Era la mitad "foto de perfil" del pendiente 2 de la lista de abajo — el
selector de idioma (espanol/ingles/frances) sigue siendo un pendiente propio
sin arrancar, se separaron a proposito desde el principio de esta tanda.

### Que se construyo (Tareas 1-6, todas completas y con review limpio)

- `UserProfile.photoData: Data?` nuevo + permiso de camara
  (`NSCameraUsageDescription`, con un typo menor deferido: falta el acento
  en "camara") — `308532c..bd8b146`.
- `resizedProfilePhotoData(from:)`: recorte a cuadrado + compresion JPEG a
  512x512. El implementador se desvio del codigo de ejemplo del plan
  agregando `UIGraphicsImageRendererFormat` con `scale=1.0` explicito — el
  review confirmo que era necesario (el codigo literal del plan renderizaba
  a la escala del device, ej. 1536x1536px en 3x, y fallaba los tests que
  esperan 512x512 porque `UIImage(data:)` asume escala 1.0 por defecto) —
  `bd8b146..2b3e7a5`.
- `CameraPicker`: wrapper de `UIImagePickerController` para camara —
  `2b3e7a5..73e2e5d`.
- `AvatarPlaceholder` extendido: dibuja la foto real si `photoData` existe,
  iniciales si no — `73e2e5d..d0d7493`.
- `EditableAvatarView`: menu (`.confirmationDialog`) con "Elegir de
  galeria" (`PhotosPicker`), "Tomar foto" (solo si
  `UIImagePickerController.isSourceTypeAvailable(.camera)`) y "Eliminar
  foto" (si ya hay una) — `d0d7493..38a8cf5` + fix `03e00b5` (import UIKit
  explicito, no alcanzaba con la visibilidad transitiva via SwiftUI).
- Integrado en `ProfileDetailView` (avatar grande arriba del form) y en el
  header de `DashboardView` (avatar chico) — `03e00b5..30c9088`.
- **63 tests** en verde (`IronPulseTests`, incluye 4 nuevos de
  `ProfilePhotoProcessorTests`) — confirmado por xcresult, no por scroll
  del log (la Tarea 6 detecto que el reporte del implementador decia "49
  tests" cuando el real via xcresult era 63/63, solo error de reporte, sin
  regresion real).

### Tarea 7 (verificacion final) — bug real bloqueante encontrado

La Tarea 5 habia dejado anotado en el ledger un punto sin verificar: el
`PhotosPicker` esta puesto como una fila **dentro** del
`.confirmationDialog` (no como su propio boton en la vista), un patron que
compila y es estructuralmente correcto, pero cuya interaccion en tiempo de
ejecucion (el dialog cerrandose mientras el picker de `PhotosPicker` quiere
presentar su propia hoja) quedo sin probar en vivo — se pidio confirmarlo
en esta tarea.

**Se probo en vivo y el bug es real**: tocar "Elegir de galeria" cierra el
`.confirmationDialog` correctamente, pero la hoja del selector de fotos
(`PHPicker`) **nunca aparece** — ni error, ni crash, ni nada en el log del
sistema, simplemente no presenta nada. Reproducido de forma consistente
**4 veces** (relanzando la app, con esperas de hasta 4 segundos entre el
tap y el screenshot). Se descarto que fuera un problema de coordenadas de
tap: el boton "Tomar foto" en el mismo dialog, con la misma metodologia de
tap, **si** abre la camara del sistema de forma confiable — asi que el tap
llega bien al dialog, es especificamente el boton de `PhotosPicker` el que
no dispara su presentacion. Como consecuencia, no se pudo verificar en
vivo: foto recortada en circulo en `ProfileDetailView`/`Dashboard`, opcion
"Eliminar foto" apareciendo tras elegir una foto, ni el revertir a
iniciales tras eliminarla — los 3 quedan bloqueados por este bug hasta que
se arregle el picker.

**Hallazgo adicional, no bloqueante**: el simulador de esta sesion (Xcode
26.6, iPhone 17, iOS 26.5) **si** mostro "Tomar foto" en el menu (el plan
asumia que no, porque "el simulador no tiene camara"). Xcode 14+ agrega
camera passthrough al webcam del Mac host cuando hay una disponible (esta
Mac tiene FaceTime HD Camera) — `UIImagePickerController.isSourceTypeAvailable(.camera)`
devuelve `true` legitimamente en ese caso. El codigo de `EditableAvatarView`
ya hace ese chequeo correctamente; es la asuncion del plan sobre el entorno
la que quedo desactualizada, no un bug de la app.

**Suite de tests**: 63/63 en verde, confirmado con
`xcrun xcresulttool get test-results summary` (no alcanza con leer el
scroll del log de `xcodebuild`).

**Camara real (captura fisica)**: no se pudo verificar completamente ni
siquiera con el passthrough del webcam (el shutter no respondio a los
taps sinteticos en la UI nativa de camara) — sigue pendiente de
verificacion manual del usuario en un dispositivo fisico, tal cual pedia
el plan original.

**Este bug no se arreglo en esta tarea** (Tarea 7 esta explicitamente
delimitada a verificacion, "Files: ninguno" en el brief) — se arreglo aparte,
ver seccion siguiente.

### Fix del bug del `PhotosPicker` (commit `52de635`)

Causa raiz: `PhotosPicker` puesto como fila directa dentro de un
`.confirmationDialog` no llega a presentar su propia hoja — el dialog se
cierra y la presentacion en cola del picker se pierde con el, un problema de
timing conocido de SwiftUI al anidar dos presentaciones modales asi. Fix:
`PhotosPicker` se saco del `.confirmationDialog` (que ahora solo tiene
`Button`s simples, "Elegir de galeria" incluido) y se agrego el modifier
`.photosPicker(isPresented:selection:matching:)` sobre la vista, controlado
por un `@State private var showingPhotosPicker = false` que el boton del
dialog activa — mismo patron que ya usaban "Tomar foto" (`showingCamera`) y
"Eliminar foto".

El implementador del fix ya habia verificado en vivo (con screenshots reales,
sesion de simulador previa a esta): el dialog abre, "Elegir de galeria" ahora
si presenta la hoja de seleccion de fotos, y una foto elegida se ve recortada
en circulo en el avatar del header del **Dashboard**. Review post-fix: limpio,
sin hallazgos.

**Esta tarea (Tarea 7, cierre final) volvio a correr la suite completa** —
**63/63 en verde**, confirmado con `xcrun xcresulttool get test-results
summary` (no por scroll del log). Se intento ademas re-verificar en vivo los
3 puntos que quedaban sin confirmar (foto recortada en circulo tambien en
`ProfileDetailView` y no solo Dashboard; "Eliminar foto" aparece tocando el
avatar de nuevo una vez que ya hay foto; volver a iniciales en ambos lugares
al eliminarla) — **no se pudo**: la inyeccion de taps del simulador de esta
sesion dejo de responder por completo (confirmado con 4 intentos de tap en
distintas coordenadas + un intento con `touch_path`, contra la fila de
"Perfil 1" y contra el icono de la app en el home screen; la app si lanza y
renderiza bien via el comando directo de `launch`, y el boton HOME si
funciona, asi que es especificamente la inyeccion de tap la que quedo rota,
no el simulador entero). Siguiendo la instruccion de no forzar una
herramienta con una falla ya conocida (un reviewer anterior tuvo el mismo
problema), se dejo esto anotado en vez de fabricar una verificacion que no
se pudo hacer. Riesgo bajo igual: los 3 puntos dependen del mismo componente
(`EditableAvatarView`/`AvatarPlaceholder`) ya confirmado funcionando en el
Dashboard por el implementer del fix — pero **sigue pendiente confirmarlo
independientemente en `ProfileDetailView`** la proxima vez que haya acceso
confiable al simulador.

## Selector de idioma (i18n) — infraestructura + chrome + enums COMPLETA (2026-07-28)

Spec/plan: `.superpowers/sdd/2026-07-28-i18n-infraestructura/`. Ejecutado con
`subagent-driven-development` (6 tareas, implementador + review por tarea).
Era la mitad "selector de idioma" del pendiente 2 que quedaba abierto desde
la tanda de foto de perfil. **Alcance real: espanol/ingles/frances para todo
el chrome (titulos, botones, mensajes de estado vacio, tabs) y los 7 enums
con `displayName`** (`ExperienceLevel`, `PrimaryGoal`, `SplitType`,
`BiologicalSex`, `EquipmentType`, `MuscleGroup`, `Weekday`) — la traduccion
real de los 146 ejercicios del catalogo (nombre/instrucciones/pro tip) es
explicitamente **NO** parte de este alcance, queda como spec futura propia
(ver "Siguientes pasos").

### Que se construyo (Tareas 1-5)

- **`AppLanguage`** (Tarea 1): enum nuevo `es`/`en`/`fr`, persistido en
  `@AppStorage("appLanguage")`, con `resolve()` que mapea el idioma del
  sistema a uno de los 3 soportados (heuristica `hasPrefix("en")`/
  `hasPrefix("fr")`, cualquier otro cae a `es`) si el usuario nunca eligio
  explicitamente. `developmentRegion`/`knownRegions` agregados al
  `project.pbxproj`.
- **Wiring en vivo** (Tarea 2): `.environment(\.locale:)` en el
  `WindowGroup` raiz de `IronPulseApp.swift` + seccion "Ajustes" con
  `Picker("Idioma", ...)` en `ProfileDetailView`. Cambiar el picker
  recalcula el `locale` del environment sin reiniciar la app.
- **Catalogo de chrome** (Tarea 3, `Localizable.xcstrings`): 126 keys
  cubriendo titulos, botones, tabs, mensajes de estado vacio, labels de
  formularios, etc. de las 9 vistas existentes. Encontro y corrigio 2 bugs
  arquitectonicos reales durante la ejecucion (ver "Hallazgos reales"
  abajo): un mismatch de caracter bullet (`•` U+2022 vs `·` U+00B7`) en 5
  call sites, y el gotcha de que `String(localized:defaultValue:locale:)`
  **no** fuerza el idioma sin un `bundle:` explicito (cae en silencio al
  idioma del sistema) — afectaba los 13 call sites que ya usaban ese
  patron.
- **7 enums traducidos** (Tarea 4): las 44 `case` con `displayName` de
  `ProfileEnums.swift` pasaron todas a
  `String(localized: "...", defaultValue: "...", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)`
  — el mismo patron con `bundle:` explicito que corrigio el gotcha de la
  Tarea 3. Confirmado que `weekday.short.*` (la tira semanal del Dashboard)
  da exactamente 3 letras en ingles/frances (`MON`/`TUE`/... , `LUN`/`MAR`/...)
  sin romper el layout.
- **Esquema por idioma del catalogo de ejercicios** (Tarea 5,
  `IronPulse/Models/Exercise.swift` + `ExerciseDatabaseSeeder.swift` +
  `ExercisesSeed.json`): `name`/`instructions`/`proTip` pasaron de
  propiedades guardadas a computadas que eligen entre `nameEs/En/Fr` (etc.,
  guardadas) segun `AppLanguage.current`. Las 146 entradas del JSON
  migraron a `{es, en, fr}` con `en`/`fr` **duplicando** el valor de `es`
  como placeholder — la traduccion real es spec futura, no tocada aca.

### Hallazgos reales encontrados y corregidos durante la ejecucion (Tareas 3-5)

- **Bug de test hermeticity** (Tarea 5): `elNombreDeLaRutinaNoMencionaIA()`
  comparaba contra el literal espanol `"Fuerza"` — dejo de pasar en un
  simulador con idioma de sistema frances en cuanto `PrimaryGoal.displayName`
  paso a depender de `AppLanguage.current` (Tarea 4). Fix: comparar contra
  el valor dinamico (`PrimaryGoal.strength.displayName`) en vez del
  literal, preservando la intencion real del test.
- **Bug Critico de crash real** (Tarea 5, encontrado en el review final):
  `@Query(sort: \Exercise.name)` en `ExerciseListView.swift` y
  `ExercisePickerSheet.swift` crasheaba en runtime porque `name` paso a ser
  una propiedad computada (no guardada) en la misma tarea — SwiftData no
  puede construir un sort descriptor sobre una computada. Ni el build ni
  los 71 tests lo agarraban porque ninguno ejercita `@Query` de verdad.
  Reproducido de forma sintetica (SwiftData `FetchDescriptor` standalone)
  por dos personas independientes antes de escribir el fix. **Fix**: sacar
  el `sort:` del `@Query` y ordenar el array en Swift sobre `.name`
  (tambien re-ordena correctamente segun el idioma activo, ya que `.name`
  es dinamico).
- **Bug arquitectonico del gotcha `bundle:`** (Tarea 3): confirmado
  empiricamente con un test descartable antes de despachar el fix —
  `String(localized:defaultValue:locale:)` sin `bundle:` cae en silencio al
  idioma del sistema (`Bundle.main`) en vez del idioma elegido por el
  usuario. Se corrigieron los 13 call sites existentes y se actualizo el
  plan para que las Tareas 4-5 no repitieran el mismo bug en su propio
  codigo de ejemplo.

### Verificacion final (Tarea 6)

**Suite de tests**: `xcodebuild test -only-testing:IronPulseTests` en
iPhone 17 (iOS 26.5) → **71/71 passed, 0 failed**, confirmado con
`xcrun xcresulttool get test-results summary` (no por scroll del log).

**Prioridad #1 — confirmacion en vivo del crash de la Tarea 5**: la Tarea 5
habia dejado esto como el pendiente mas importante — 3 intentos previos
(fix implementer, re-reviewer, controller) fallaron por la inyeccion de
taps rota del simulador en esa sesion, dejando solo evidencia sintetica.
**Esta vez se logro la confirmacion en vivo real**: `simctl uninstall` +
reinstall limpio del build actual, perfil nuevo creado, tab Ejercicios
abierta con exito — **renderiza los nombres de los ejercicios ordenados
alfabeticamente sin crashear**, con los filtros de grupo muscular/equipo
tambien traducidos. El crash esta genuinamente resuelto y confirmado en
dispositivo real, no solo en teoria.

**Recorrido visual en los 3 idiomas**: el simulador arranco en frances
(idioma de sistema de esa maquina, sin override guardado). Se navegaron
las 4 tabs (Dashboard/Rutina/Ejercicios/Perfil) + el detalle de un
ejercicio en frances, despues se cambio el picker de Idioma en vivo a
ingles y se repitio el recorrido completo, despues a espanol. Confirmado
en las 3 corridas:
- El chrome (titulos, tabs, botones, mensajes de estado vacio, labels de
  formulario) cambia en vivo sin reiniciar la app.
- Los 7 enums muestran el idioma correcto donde se probaron: Nivel/Level
  (Debutant/Beginner/Principiante), Objetivo/Goal (Hypertrophie/Hypertrophy/
  Hipertrofia), Sexo/Sex, grupos musculares y equipamiento (en los chips de
  filtro y en los tags de cada ejercicio: "Pectoraux"/"Chest"/"Pecho",
  "Halteres"/"Dumbbells"/"Mancuernas", etc.).
- La tira semanal del Dashboard no rompe layout con las abreviaturas de 3
  letras: `LUN MAR MER JEU VEN SAM DIM` (fr) y `MON TUE WED THU FRI SAT SUN`
  (en) caben igual de bien que el espanol.
- Los nombres de ejercicios se ven identicos entre los 3 idiomas (esperado
  — son placeholders, la traduccion real del catalogo es spec futura).
- Ningun boton/`NavigationLink` quedo sin responder (la regresion historica
  de `Chart` de la tanda de tendencias no aplica aca, este plan no toca
  ningun `Chart`, confirmado como red de seguridad).

**2 hallazgos reales nuevos encontrados durante esta verificacion** (no
corregidos aca — Tarea 6 esta explicitamente delimitada a verificacion,
"Files: ninguno" en el brief — quedan documentados como pendientes):

1. **Sufijo `"/semana"` hardcodeado sin traducir**
   (`ContentView.swift:78`, `ProfileRow.body`): la fila de perfil en la
   lista raiz arma el resumen como
   `"\(experienceLevel.displayName) • \(primaryGoal.displayName) • \(diasLabel(...))/semana"`
   — el `/semana` final es un literal espanol fijo, nunca pasa por el
   catalogo de traduccion. Confirmado en vivo: con la app en frances se vio
   literalmente `"Debutant • Hypertrophie • 3 jours/semana"` — `jours`
   (frances, correcto) pegado a `/semana` (espanol, hardcodeado). Cosmetico
   pero real, se le escapo al barrido "exhaustivo" de la Tarea 3 igual que
   los otros gaps que esa tarea ya documento haber encontrado en rondas
   sucesivas.
2. **Gap de refresco en vivo para vistas no re-renderizadas al momento del
   cambio de idioma** — **RESUELTO** (ver mas abajo). Los 7 enums usan
   `String(localized:bundle:locale:)` leyendo `AppLanguage.current` (una
   variable global), **no** `\.locale` del environment de SwiftUI — es el
   mismo patron que ya arreglo el gotcha `bundle:` de la Tarea 3, pero como
   consecuencia SwiftUI no tiene forma de saber que esas vistas dependen
   del idioma. El alcance real es mayor de lo que se penso al encontrarlo:
   afecta a practicamente **cualquier vista que muestre alguno de los 7
   `displayName` traducidos** (no solo los dos puntos donde se reprodujo en
   vivo), y el texto viejo **no se autocorrige solo**, queda mostrando el
   idioma anterior durante el resto de la sesion hasta que la app se
   relanza por completo — no es un parpadeo breve. Confirmado en vivo,
   reproducido dos veces: (a) el `Picker(selection:
   $profile.experienceLevel)` de "Nivel"/"Objetivo" en `ProfileDetailView`
   sigue mostrando el valor colapsado en el idioma anterior (ej. quedo en
   "Beginner"/"Hypertrophy" en ingles justo despues de cambiar el picker de
   Idioma a espanol, mientras que las etiquetas "Nivel"/"Objetivo" y todo
   el resto de la pantalla si cambiaron a espanol al instante); (b) la fila
   de perfil en la lista raiz (`ContentView`/`ProfileRow`), al no haber
   sido re-visitada desde antes del cambio de idioma, seguia mostrando
   texto del idioma viejo. Los datos y el idioma persistido (`@AppStorage`)
   siempre fueron correctos — es una ventana de refresco incompleta en
   vistas ya montadas fuera de pantalla o en el label colapsado de un
   `Picker(.menu)`, no un problema de fiabilidad de la traduccion en si.
   **Fix aplicado** (este commit): `.id(appLanguageRaw)` en `ContentView()`
   dentro de `IronPulseApp.swift`, antes del `.environment(\.locale:)` —
   fuerza a SwiftUI a reconstruir toda la jerarquia de vistas cuando cambia
   el idioma, en vez de depender de que cada vista se re-renderice sola al
   leer la variable global `AppLanguage.current`.

### Mensajes de permiso — decision de alcance (ya tomada en la Tarea 3)

`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` y
`NSCameraUsageDescription` (`project.pbxproj`) se dejan **solo en
espanol**, por decision explicita de alcance ya documentada en el reporte
de la Tarea 3: son texto de Info.plist, un mecanismo de i18n distinto al
String Catalog de SwiftUI (requeriria `InfoPlist.strings` por idioma), y
traducirlos quedo fuera de alcance de este plan.

## Siguientes pasos

**Fases 1-5, la tanda de tendencias/sesion guiada y el rebrand "Watt +
Weight" estan 100% completos** (ver secciones propias arriba). El PR #1
esta abierto, esperando review/merge del usuario — no se mergea solo.

Pendientes reales que quedan, todos requieren alguna decision de producto
o son de alcance mayor (no son fixes directos):

1. ~~**Rebrand visual `MOCKUPS/`** (rebrand "Watt + Weight" + reskin
   visual "Kinetic Onyx" completo) — pendiente de su propia sesion de
   brainstorming, alcance grande.~~ — **RESUELTO** (2026-07-27): las 13
   tareas del plan `docs/superpowers/plans/2026-07-27-watt-weight-rebrand.md`
   estan completas, incluida la verificacion final en simulador. Ver
   seccion "Rebrand 'Watt + Weight' + reskin visual 'Kinetic Onyx' —
   COMPLETA" arriba.
2. ~~**Spec nuevo — idioma + foto de perfil**~~ — se separaron en dos
   pendientes independientes desde el principio de la tanda de foto de
   perfil (2026-07-28):
   - **Foto de perfil**: 7/7 tareas completas. El bug real encontrado en la
     Tarea 7 de verificacion (`PhotosPicker` como fila del
     `.confirmationDialog` en `EditableAvatarView.swift` nunca presentaba su
     hoja de seleccion) esta **corregido** (commit `52de635`) y confirmado
     con screenshots reales en el Dashboard. Ver seccion "Foto de perfil"
     arriba para el detalle completo. Queda un pendiente chico: confirmar en
     vivo (bloqueado esta vez por inyeccion de taps rota en el simulador)
     que la foto recortada, "Eliminar foto" y el revertir a iniciales
     tambien se ven bien en `ProfileDetailView` (no solo Dashboard) — mismo
     componente ya verificado, riesgo bajo, pero sin confirmacion
     independiente todavia. **Camara real en dispositivo fisico** tambien
     sigue pendiente de verificacion manual del usuario, como ya estaba
     anotado.
   - ~~**Selector de idioma** (espanol/ingles/frances, i18n de toda la
     app)~~ — **RESUELTO** (2026-07-28): infraestructura + chrome (126
     keys) + los 7 enums con `displayName` estan completos y verificados
     en vivo en los 3 idiomas. Ver seccion "Selector de idioma (i18n) —
     infraestructura + chrome + enums COMPLETA" arriba para el detalle
     completo, incluidos 2 hallazgos reales nuevos (sufijo `/semana`
     hardcodeado, gap de refresco en vivo en vistas no re-renderizadas)
     que quedan pendientes mas abajo. **La traduccion real del catalogo de
     ejercicios (146 × 3 campos: nombre/instrucciones/pro tip, a
     ingles/frances) sigue siendo un pendiente separado** — el esquema
     `{es, en, fr}` ya existe (Tarea 5 de esta misma tanda) pero `en`/`fr`
     son placeholders identicos a `es`; la traduccion de contenido en si
     necesita su propia spec futura (no es un fix directo, es contenido a
     producir/revisar para 146 ejercicios).
3. Definir fuente real de GIFs animados (o aceptar las fotos JPG de
   free-exercise-db como definitivas).
4. `RoutineBuilderView.save()` genera `dayNumber` con huecos — declinado
   explicitamente por el usuario, no tocar salvo que lo pida (ver "Del
   review final — declinados o parqueados" arriba).
5. **6 hallazgos Minor del review final de la tanda de tendencias** (ver
   seccion propia arriba) — ninguno bloquea, ninguno se toco todavia.
6. **Preparacion para publicar en la App Store** — pendiente de
   arrancar: el rebrand ya resolvio el App Icon (antes salia
   vacio/generico, ahora es el icono real de "Watt + Weight" — confirmado
   en el home screen del simulador en la Tarea 13). Falta todavia definir
   bundle id final/certificados, screenshots, texto de App Store Connect,
   privacy manifest (la app pide permisos de HealthKit y notificaciones
   locales), y decidir que politica de privacidad usar.
7. **`TagBadge` sin `Spacer`/`lineLimit` en `ExerciseListView`**:
   confirmado en vivo en la Tarea 13 que nombres largos (ej. "Press
   inclinado con mancuernas") envuelven en 3 lineas con una palabra sola
   en la ultima linea — sigue siendo legible, cosmetico, sin accion (ver
   ledger de la Tarea 9 y la seccion de verificacion final arriba).
8. **Sufijo `"/semana"` hardcodeado en `ContentView.swift:78`**
   (`ProfileRow.body`) — encontrado en la verificacion final de la tanda
   de i18n (2026-07-28), ver seccion propia arriba. Fix directo y chico
   (agregar la key al catalogo y usarla en vez del literal), no se aplico
   porque la Tarea 6 que lo encontro estaba delimitada a verificacion
   ("Files: ninguno").
9. ~~**Gap de refresco en vivo del idioma en vistas no re-renderizadas**~~ —
   **RESUELTO**: afectaba practicamente cualquier vista que muestre alguno
   de los 7 `displayName` traducidos (no solo `Picker(.menu)` de
   Nivel/Objetivo en `ProfileDetailView` y la fila de perfil en
   `ContentView`, que fueron donde se reprodujo en vivo primero), y el
   texto viejo quedaba mostrandose el resto de la sesion hasta relanzar la
   app por completo (no era un parpadeo breve). Encontrado en la
   verificacion final de la tanda de i18n (2026-07-28). Fix aplicado:
   `.id(appLanguageRaw)` en `ContentView()` (`IronPulseApp.swift`) fuerza
   la reconstruccion completa de la jerarquia de vistas al cambiar de
   idioma. Ver seccion propia arriba para el detalle completo.

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
