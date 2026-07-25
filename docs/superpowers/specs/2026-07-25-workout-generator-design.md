# Fase 3 — Generador de rutinas (inteligente + manual)

## Contexto

`AIRoutineGenerator` (borrado en el recableado post-Fase 2) llamaba a la API
de wger.de y generaba rutinas contra un catálogo remoto. Ahora el catálogo
de 150 ejercicios está sembrado localmente (`Exercise` + `ExercisesSeed.json`),
así que el generador puede ser lógica local, sin red.

El Dashboard hoy muestra un placeholder ("El generador de rutinas llega en
la Fase 3.") sin ningún botón — esta fase lo reemplaza con dos flujos reales:
una rutina generada por heurística ("inteligente") y un armador manual desde
cero. Ambos flujos activan una `WorkoutRoutine` a través del mismo helper de
persistencia.

Idioma de la app (español/inglés/francés) y foto de perfil quedaron **fuera
de alcance** de este spec — son subsistemas independientes (i18n cross-cutting
y almacenamiento de imagen), se diseñan por separado.

## Cambio de modelo: `Exercise.isCompound`

El catálogo no tiene ningún campo que distinga ejercicios compuestos
(press banca, sentadilla, peso muerto, dominadas, remo, fondos, zancadas)
de aislamiento (aperturas, extensiones, curl, elevaciones, encogimientos).
Se probó aproximar con `secondaryMuscles.count >= 2` pero no es confiable:
muchos press reales solo tienen 1 músculo secundario etiquetado, igual que
varias aperturas.

- Se agrega `isCompound: Bool` a `Models/Exercise.swift` (propiedad + init).
- Se clasifican los 150 registros de `Resources/ExercisesSeed.json` por
  coincidencia de substring en el nombre (case/acento-insensitive — ej.
  `"zancada"` matchea tanto `"Zancada"` como `"Zancadas caminando..."`, y
  `"jalon"` matchea `"jalón"`):
  - **Compuesto** si el nombre contiene alguna de: `press`, `sentadilla`,
    `peso muerto`, `dominada`, `remo`, `fondos`, `zancada`, `jalon`,
    `empuje`, `flexion` (flexiones de brazo/pecho — no colisiona con nada
    de piernas en este catálogo), `step-up`.
  - **Aislamiento** en cualquier otro caso (incluye: `extension`, `curl`,
    `apertura`, `elevacion`, `encogimiento`, `crunch`, `giro`, `vacio`,
    `plancha`, `abduccion`, `aduccion`).
  - Se probó automatizar la clasificación contra el catálogo real
    (script Python) antes de fijar esta lista: confirma 66 compuestos /
    84 aislamiento razonables. Quedan casos borderline que el keyword
    matching no puede resolver sin colisionar con otros nombres — ej.
    `"prensa"` matchea tanto `"Prensa de piernas a 45 grados"` (compuesto)
    como `"Elevacion de talones en prensa de piernas"` (aislamiento, es
    un ejercicio de pantorrilla que usa la prensa como equipo). Por eso
    la revisión a mano después del paso automático no es opcional:
    reclasificar manualmente al menos `Prensa de piernas a 45 grados`,
    `Puente de gluteos con barra`/`a una pierna`, y `Elevacion de cadera
    en maquina Smith` a compuesto (son movimientos de cadera
    multi-articulares que ningún keyword simple captura sin
    falsos positivos).
- `Services/ExerciseDatabaseSeeder.swift` decodifica el campo nuevo.
- Como es una propiedad no-opcional nueva en un `@Model` de SwiftData sin
  plan de migración, aplica el mismo workaround ya documentado en
  `PROGRESS.md`: borrar la app del simulador antes de correr el build
  nuevo. No hay usuarios reales todavía, no se justifica un
  `VersionedSchema`/`SchemaMigrationPlan` para esto.

## `WorkoutGeneratorService`

Reemplaza a `AIRoutineGenerator`. Como no hay I/O de red, es una función
pura y sincrónica — no un `actor`, no `async`:

```swift
enum WorkoutGeneratorService {
    static func splitType(for daysPerWeek: Int) -> SplitType
    static func generateRoutine(for profile: UserProfile, catalog: [Exercise]) -> WorkoutRoutine
}
```

Recibe el catálogo ya cargado (la vista lo trae con `@Query`) y devuelve un
árbol `WorkoutRoutine → RoutineDay → RoutineExercise` **sin insertar** en el
`ModelContext` — la persistencia la maneja quien llama (ver más abajo). Esto
la hace testeable sin `ModelContainer`.

### Split según días por semana

| `workoutDaysPerWeek` | `SplitType` | Ciclo de días |
|---|---|---|
| 1–2 | `fullBody` | Cuerpo completo repetido |
| 3–4 | `upperLower` | Torso/Pierna alternado |
| 5–7 | `pushPullLegs` | Empuje/Tirón/Pierna en ciclo |

### Grupos musculares y título por tipo de día

| Día | Título | Grupos musculares (orden de prioridad) |
|---|---|---|
| Cuerpo completo | "Cuerpo completo" | pecho, espalda, piernas, hombros, bíceps/tríceps alternado, core |
| Torso | "Torso" | pecho, espalda, hombros, bíceps, tríceps |
| Pierna | "Pierna" | piernas, glúteos, core |
| Empuje | "Empuje" | pecho, hombros, tríceps |
| Tirón | "Tirón" | espalda, bíceps |
| Piernas (PPL) | "Piernas" | piernas, glúteos, core |

### Selección de ejercicios por día

1. Filtrar el catálogo a los grupos musculares del día.
2. Ordenar en 3 niveles: `isCompound && muscleGroup != .core` primero,
   aislamiento no-core después, todo lo de `core` al final (el core va al
   final del día sin importar si el movimiento es compuesto).
3. Mezclar aleatoriamente dentro de cada nivel (variedad entre
   generaciones) y tomar los primeros N.
4. N ejercicios por día según `experienceLevel`: principiante 4,
   intermedio 5, avanzado 6.

**Simplificación conocida** (marcar con comentario `ponytail:` en el
código): no hay lógica para evitar que el mismo ejercicio se repita entre
días del mismo tipo dentro de la semana (ej. Empuje del día 1 vs día 4 en
un split de 5 días) — cada día se sortea independiente. Mejora razonable a
futuro, no crítica para v1.

**Sin filtro de equipo**: `UserProfile.preferredEquipment` no se usa en
esta fase (decisión explícita — el catálogo completo está disponible para
ambos flujos).

### Series, reps y descanso según objetivo

| `PrimaryGoal` | Series | Reps | Descanso |
|---|---|---|---|
| `strength` | 4 (5 si `experienceLevel == .advanced`) | 3–6 | 120–180s |
| `hypertrophy` | 3–4 | 8–12 | 60–90s |
| `fatLoss` | 3 | 12–15 | 30–45s |

## Persistencia compartida

```swift
extension UserProfile {
    func activate(_ routine: WorkoutRoutine, in context: ModelContext) {
        for r in routines { r.isActive = false }
        routines.append(routine)
        context.insert(routine)
        try? context.save()
    }
}
```

Las rutinas viejas no se borran, quedan con `isActive = false` como
historial — el modelo ya soporta esto (`WorkoutRoutine.isActive`), no hace
falta lógica de limpieza. Este helper es el único punto de "activar una
rutina": lo usan tanto el flujo generado como el manual, para no duplicar
la lógica de desactivar-la-anterior en dos lados.

## UI: Dashboard

Reemplaza el placeholder "El generador de rutinas llega en la Fase 3." por
dos botones, **siempre visibles** (haya o no rutina activa — así
"regenerar" y "crear manual" están disponibles en todo momento sin UI
condicional extra):

- **"Rutina inteligente"**: llama
  `WorkoutGeneratorService.generateRoutine(for:catalog:)` (sincrónico, sin
  `Task`) y activa el resultado con `profile.activate(_:in:)`.
- **"Crear rutina manual"**: `NavigationLink` a `RoutineBuilderView`.

Ningún texto usa la palabra "IA" — es heurística determinista, no
inteligencia artificial. Nombre de rutina generada:
`"Rutina personalizada - \(profile.primaryGoal.displayName)"`.

## UI: `RoutineBuilderView` (nuevo)

`Form` de una sola pantalla scrolleable (sin wizard multi-paso):

1. **Split y días**: `Picker` de `SplitType` (prefilled con
   `WorkoutGeneratorService.splitType(for: profile.workoutDaysPerWeek)`,
   editable) + `Stepper` de días 1–7 (prefilled con
   `profile.workoutDaysPerWeek`, editable).
2. **Una `Section` por día**, título auto-derivado del split + índice
   (tabla de arriba, no se escribe a mano). Cada sección:
   - Lista los ejercicios ya agregados, con steppers de `targetSets`,
     `targetRepsMin`/`targetRepsMax`, `restSeconds` (prefilled con la
     tabla de series/reps/descanso según `profile.primaryGoal`, editable),
     y swipe-to-delete.
   - Botón "Agregar ejercicio" → abre `ExercisePickerSheet`.
3. **Guardar**: arma el árbol `WorkoutRoutine(isGeneratedByAI: false,
   isActive: true, ...)` desde los drafts en memoria y lo activa con
   `profile.activate(_:in:)`.

### `ExercisePickerSheet` (nuevo, reutilizable)

Lista con buscador, mismo look que `ExerciseListView` (thumbnail vía
`GIFImageView` + nombre + grupo muscular/equipo) pero **tap-to-select** en
vez de tap-to-detalle: tocar un ejercicio lo agrega al día actual con los
valores default de la tabla de series/reps/descanso, sin permitir
duplicados dentro del mismo día (chequeo por `id`). Vive en
`Views/Exercises/` junto a `ExerciseListView.swift` pero es un componente
separado — la interacción (seleccionar vs. ver detalle) es distinta,
mezclar los dos modos en una vista con flag sería más confuso que dos
vistas chicas y claras.

## Testing

`WorkoutGeneratorService` es función pura — se testea con Swift Testing
sin `ModelContainer`, construyendo un catálogo sintético chico (10-15
`Exercise` cubriendo push/pull/legs/core, mezcla de `isCompound`).

Nuevo archivo `IronPulseTests/WorkoutGeneratorServiceTests.swift`:

- `workoutDaysPerWeek` 1–2 → `splitType == .fullBody`, cantidad de días
  correcta.
- `workoutDaysPerWeek` 3–4 → `.upperLower`.
- `workoutDaysPerWeek` 5–7 → `.pushPullLegs`, ciclo Empuje/Tirón/Pierna
  correcto.
- Cantidad de ejercicios por día según `experienceLevel` (4/5/6).
- Series/reps/descanso coinciden con la tabla según `primaryGoal`.
- Sin ejercicios duplicados dentro del mismo día.
- Los ejercicios de `core` quedan al final del día cuando aparecen.

`RoutineBuilderView`/`ExercisePickerSheet` son UI — se verifican en
simulador (mismo criterio usado en el resto del proyecto), sin test
unitario: no tienen lógica de rama no trivial, solo binding de formulario.

## Archivos afectados

**Nuevos:**
- `Services/WorkoutGeneratorService.swift`
- `Views/Workouts/RoutineBuilderView.swift`
- `Views/Exercises/ExercisePickerSheet.swift`
- `IronPulseTests/WorkoutGeneratorServiceTests.swift`

**Modificados:**
- `Models/Exercise.swift` (campo `isCompound`)
- `Resources/ExercisesSeed.json` (150 registros con `isCompound`)
- `Services/ExerciseDatabaseSeeder.swift` (decodificar campo nuevo)
- `Models/UserProfile.swift` (extension `activate(_:in:)`)
- `Views/Workouts/DashboardView.swift` (dos botones en vez del placeholder)

## Fuera de alcance (specs separados)

- Selector de idioma (español/inglés/francés).
- Foto de perfil por `UserProfile`.
- Filtro de `preferredEquipment` en la selección de ejercicios.
- Evitar repetir el mismo ejercicio entre días del mismo tipo en la semana.
