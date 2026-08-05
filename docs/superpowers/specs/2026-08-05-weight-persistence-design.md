# Persistencia de Peso Entre Sets y Sesiones

## Contexto

Feedback de uso real del Smart Assistant (fase 4 ya en producción): cada set de un ejercicio guarda su propio `weightKg` de forma completamente independiente, arrancando siempre en `0`. Esto genera dos fricciones:

1. Dentro de una misma sesión, el usuario tiene que escribir el mismo peso en cada set del ejercicio (2, 3, 4 veces), aunque casi siempre use el mismo peso en todos.
2. Al repetir un ejercicio en una sesión futura (misma rutina u otra), no hay memoria del peso que se usó la última vez — siempre arranca en `0`.

Esta feature ataca ambas fricciones reutilizando el campo `weightKg` que ya existe en `SetLog` — no requiere cambios de esquema.

## 1. Auto-rellenar sets vacíos del mismo ejercicio (dentro de la sesión)

Cuando el usuario edita el peso de un set, ese valor se copia automáticamente a los demás sets del mismo ejercicio **que todavía tengan `weightKg <= 0`** (vacíos). Un set que el usuario ya editó a otro valor (drop set, pirámide) no se toca — solo se rellenan los que siguen vacíos, nunca se sobreescribe un valor que el usuario puso a propósito.

Ejemplo: ejercicio con 3 sets, todos en 0. El usuario pone 40kg en el set 1 → los sets 2 y 3 también quedan en 40kg automáticamente. Si luego el usuario cambia el set 3 a 35kg (drop set), el set 3 queda independiente; el set 1 o 2 no se re-sincronizan entre sí a partir de ahí salvo que el usuario los edite directamente.

Esto vive como una función pura y testeable en `GuidedSessionFlow` (mismo patrón que `canCompleteSet`), consumida por el binding de peso en `GuidedWorkoutView`.

**Nota relacionada — agregar un set nuevo:** hoy, al agregar un set extra a un ejercicio (botón "+" durante la sesión), el nuevo set arranca en `weightKg: 0` aunque copie reps/descanso del set anterior. Con esta feature, si todos los sets existentes del ejercicio comparten el mismo peso (>0), el set nuevo hereda ese peso en vez de arrancar en 0 — evita que se vea "roto" un set nuevo en blanco al lado de sets ya llenos.

## 2. Precargar el peso de la última sesión (entre sesiones)

Al generar una nueva sesión (`WorkoutLogGenerator.generate`/`startSession`), para cada ejercicio de la rutina del día se busca — entre **todas** las sesiones anteriores del perfil actual, sin importar en qué rutina o día se hizo — el `SetLog` completado (`isCompleted == true`) más reciente con ese mismo `exerciseId` y `weightKg > 0`. Si existe, **todos** los sets iniciales de ese ejercicio en la sesión nueva arrancan con ese peso en vez de `0`. Si el ejercicio nunca se hizo antes, arranca en `0` como hoy.

"Más reciente" se determina por la fecha de inicio (`startDate`) de la sesión a la que pertenece ese set, no por el `timestamp` del set individual — evita casos raros donde un set de una sesión más vieja tenga un timestamp posterior por edición manual.

Esto significa que, al repetir un ejercicio, la sesión ya arranca con el peso sugerido en todos sus sets — igual que si el usuario ya hubiera escrito el peso en el primer set y se hubiera propagado (sección 1). Si el usuario quiere subir de peso esa sesión, edita el/los sets que quiera cambiar; como ya no están en `0`, no se re-sincronizan automáticamente entre sí (mismo comportamiento de "solo rellena vacíos" de la sección 1, aplicado de forma consistente).

`generate(for:routineName:profile:)` sigue siendo una función pura y testeable sin `ModelContext` (los tests actuales la llaman así) — gana un parámetro opcional `previousWeights: [String: Double] = [:]` (diccionario `exerciseId -> weightKg`) que por defecto no cambia nada del comportamiento actual. `startSession(...)`, que sí tiene acceso al `ModelContext`, calcula ese diccionario con una consulta a `WorkoutLog`/`SetLog` antes de llamar a `generate`.

## Testing

- Función de auto-rellenar: pruebas puras con listas de `SetLog` in-memory — set editado no se toca dos veces, sets en 0 se rellenan, sets con valor propio no se sobreescriben.
- Búsqueda de peso histórico: pruebas con un `ModelContext` en memoria sembrado con varias sesiones anteriores (mismo patrón que `WorkoutStatsServiceTests`) — toma la sesión más reciente por `startDate`, ignora sets con `weightKg == 0` o `isCompleted == false`, ignora ejercicios sin historial (se queda en 0), no le importa si la sesión anterior fue de otra rutina/día.
- `generate(...)` con `previousWeights` vacío se comporta exactamente igual que hoy (regresión de los tests existentes).
- `addSet(to:)`: nuevo set hereda el peso común de los sets existentes del ejercicio si todos comparten el mismo valor >0; si no (ej. drop set en curso), arranca en 0 como hoy.

## Fuera de alcance

- No se toca `RoutineExercise` ni el modelo de rutina — el peso "sugerido" vive puramente en el historial de `SetLog`, no como un campo nuevo de configuración de la rutina.
- No hay UI para que el usuario vea o edite manualmente "el peso recordado" fuera del flujo normal de sets — simplemente aparece precargado.
- No cubre el caso de unidades mixtas (el usuario cambió de kg a lbs entre sesiones) de forma especial — `weightKg` siempre se guarda en kg internamente (ya es así hoy vía `UnitSystem`), así que el valor recordado se muestra convertido a la unidad activa igual que cualquier otro peso.
