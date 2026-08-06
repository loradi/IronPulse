# Ícono de "Smart Assistant disponible" en biblioteca y rutina

## Contexto

Con la expansión reciente del catálogo (64 → 84 de 146 ejercicios), el usuario no tiene forma de saber, mirando la biblioteca de ejercicios o su rutina, cuáles ejercicios soportan Smart Assistant sin entrar a cada uno y buscar el botón. Se agrega un ícono chico identificador en los lugares donde ya se listan ejercicios.

## 1. Señal: reusar `MovementProfileCatalog`, sin cambios de datos

La misma condición que ya usa `GuidedWorkoutView.swift:264` para mostrar el botón del Smart Assistant — `MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil` — se reutiliza como la señal de "tiene ícono". Cero cambios en el modelo `Exercise` ni en `MovementProfileCatalog`.

## 2. Componente nuevo: `SmartAssistantBadge`

`IronPulse/Components/SmartAssistantBadge.swift`: una vista chica y reusable, mismo patrón que `TagBadge`/`AvatarPlaceholder` (componentes ya compartidos en `IronPulse/Components/`). Envuelve `Image(systemName: "camera.viewfinder")` — el mismo símbolo que ya usa el botón del Smart Assistant en `GuidedWorkoutView.swift:268`, para que el usuario asocie visualmente el ícono con la función — en color `Color.ironAccent`, tamaño chico (14pt), con `accessibilityLabel` localizado ("Compatible con Smart Assistant" / "Smart Assistant available" / "Smart Assistant disponible" según idioma, mismo patrón `String(localized:defaultValue:bundle:locale:)` que ya usa `exercise.compound_badge`).

## 3. Tres puntos de uso

Todos condicionados a `MovementProfileCatalog.profile(forExerciseID: exercise.id) != nil`:

- **`ExerciseListView`** (`IronPulse/Views/Exercises/ExerciseListView.swift:47-53`): en la misma `HStack` donde ya se muestra el `TagBadge` de "Compound", junto al nombre del ejercicio.
- **`ExerciseDetailView`** (mismo archivo, `:152-154`): junto al `TagBadge` de "Compound" que ya aparece debajo del GIF.
- **`RoutineTabView.RoutineCard`** (`IronPulse/Views/Workouts/RoutineTabView.swift:164-177`): en la fila de cada ejercicio dentro de un día de rutina, junto al nombre.

## Testing

- Lógica de la señal ya está cubierta por los tests existentes de `MovementProfileCatalog` — no hace falta test nuevo para eso.
- `SmartAssistantBadge` es una vista SwiftUI pura sin lógica condicional propia (la condición vive en cada call site, no en el componente) — no es testeable automáticamente, igual que `TagBadge`/`AvatarPlaceholder` no lo son. Se verifica manualmente en simulador: el ícono aparece en los 84 ejercicios correctos y no aparece en los otros 62, en los 3 lugares.

## Fuera de alcance

- No se agrega ningún filtro/toggle para mostrar "solo ejercicios con Smart Assistant" en la biblioteca — sería una mejora de UX separada, no pedida acá.
- No se toca `ActiveWorkoutView`/`GuidedWorkoutView` — esas pantallas ya muestran el botón de Smart Assistant explícitamente cuando aplica, no necesitan el ícono además del botón.
