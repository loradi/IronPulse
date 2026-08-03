# Smart Assistant Phase 4: Detección de Mala Forma y Audio Menos Frecuente

## Contexto

Al probar la fase 3 en dispositivo (aunque terminó probando una build de la fase 2, ya que la fase 3 no estaba mergeada), el usuario encontró dos problemas de fondo, además de un bug ya corregido por separado (el target de reps usaba el techo fijo del perfil en vez de lo configurado en el set — ver rama `fix-smart-assistant-target-reps`):

1. **El audio habla en cada repetición** — debería sonar solo 2-3 veces por set, no en cada una.
2. **El tracking cuenta repeticiones con mala forma** — como cada perfil de movimiento solo rastrea UN ángulo, cualquier movimiento del brazo que entre en el rango cuenta como repetición, incluso si el usuario usa impulso/balanceo del cuerpo en vez de aislar el músculo correcto.

Esta fase agrega un **segundo ángulo de validación por perfil** (reutilizando los mismos 4 triángulos de articulación ya existentes — cero cambios en `AngleCalculator.swift` o `PoseDetectorService.swift`) para detectar cuando el cuerpo se mueve de más para ayudar con el movimiento, y reduce la frecuencia del audio motivacional.

**Alcance**: esta fase cubre los **73 ejercicios que ya tienen uno de los 10 perfiles construidos** (fases 1-3). Expandir la cobertura a los ~73 ejercicios restantes del catálogo (isométricos, acostados, de una sola extremidad) es un esfuerzo separado y más grande — esos necesitan mecanismos de tracking que hoy no existen (distancia entre puntos, tiempo en vez de repeticiones, tracking por extremidad individual) y quedan fuera de esta fase, pendientes de validar primero que este chequeo de forma funciona bien en dispositivo real.

## 1. Audio menos frecuente

- **`.goodRep`**: se anuncia por voz solo en la primera repetición completada, la más cercana a la mitad de la meta (`targetReps / 2`, redondeado hacia abajo, mínimo 1), y la última (`repCount == targetReps`). El resto de las repeticiones buenas se siguen mostrando en pantalla (banner + contador), solo se omite el audio.
- **Correctivas** (`.notDeepEnough`, `.tooFast`, y la nueva `.badForm`): se anuncian siempre que ocurren, sin límite — son las más importantes de escuchar en el momento exacto en que pasan.
- En sets con meta muy chica (ej. 1-2 reps), es normal que "primera/mitad/última" coincidan en la misma repetición — en ese caso simplemente se habla una sola vez, no es un error.

## 2. Segundo ángulo de validación por perfil ("chequeo secundario")

Cada `MovementProfile` gana un chequeo secundario opcional, de uno de dos tipos:

- **`.stability(angle:toleranceDegrees:)`**: para ejercicios de aislamiento, donde una articulación (típicamente el hombro o el torso) debe quedarse quieta mientras solo la articulación principal se mueve. Se mide cuánto se aleja el ángulo secundario de su propio valor inicial (capturado al empezar la fase "abajo" de la repetición) — si se aleja más que la tolerancia en cualquier momento antes de completar la repetición, se marca como mala forma.
- **`.bounded(angle:allowedRange:)`**: para ejercicios compuestos, donde el torso naturalmente se mueve como parte del movimiento correcto (ej. una sentadilla inclina el torso hacia adelante) — se permite ese movimiento natural, pero se marca mala forma si el ángulo se sale de un rango absoluto durante la repetición (ej. el torso se encorva demasiado, o la rodilla se dobla más de lo esperado en una bisagra).

Una repetición marcada como mala forma **no cuenta** (igual que "no llegaste al rango completo" hoy) y dispara una frase correctiva nueva (`.badForm`).

### Asignación por perfil

Los triángulos reutilizados son los mismos 4 que ya existen: hombro-codo-muñeca, cadera-hombro-codo, hombro-cadera-rodilla, cadera-rodilla-tobillo (este último ya es el ángulo primario de `hinge`).

| Perfil | Chequeo | Ángulo | Qué detecta |
|---|---|---|---|
| `squat` | Rango: 50°...180° | hombro-cadera-rodilla | El torso se colapsa demasiado hacia adelante (redondear la espalda) |
| `pushUp` | Rango: 150°...180° | hombro-cadera-rodilla | La cadera se cae (perder la línea recta del cuerpo) |
| `curl` | Estabilidad: ±15° | cadera-hombro-codo | El hombro se balancea para dar impulso |
| `overheadPress` | Rango: 150°...180° | hombro-cadera-rodilla | Empujar con las piernas/espalda en vez del hombro |
| `hinge` | Rango: 150°...180° | cadera-rodilla-tobillo | La rodilla se dobla de más (se convierte en sentadilla) |
| `row` | Estabilidad: ±15° | hombro-cadera-rodilla | El torso se balancea hacia atrás para ayudar a jalar |
| `tricepsExtension` | Estabilidad: ±15° | cadera-hombro-codo | El hombro se balancea para dar impulso |
| `lateralRaise` | Estabilidad: ±15° | hombro-cadera-rodilla | El torso se balancea para ayudar a levantar el brazo |
| `legExtension` | Estabilidad: ±15° | hombro-cadera-rodilla | El torso se mueve para ayudarse |
| `legCurl` | Estabilidad: ±15° | hombro-cadera-rodilla | El torso se mueve para ayudarse |

Todos los valores (tolerancias y rangos) son estimaciones de partida, igual que los ángulos primarios de fases anteriores — se afinan contra Vision real en dispositivo físico.

### Nota de honestidad técnica

Este chequeo detecta específicamente **balanceo/impulso del cuerpo** (el tipo de mala forma más común y más fácil de detectar con un segundo ángulo). No detecta otros problemas de forma como rodillas hacia adentro (requiere posición lateral/horizontal, no solo un ángulo), redondeo de columna (no hay puntos de la columna en el tracking), o forma incorrecta que no involucre balanceo. Es una mejora real y acotada, no una validación completa de forma.

## Testing

- `RepCounterEngineTests` se extiende con casos para ambos tipos de chequeo secundario (`.stability` y `.bounded`): una repetición que viola el chequeo debe devolver `.badForm` y NO incrementar el contador; una repetición que se mantiene dentro del chequeo debe contar normalmente. Se incluye un caso con `secondaryCheck: nil` para confirmar que el mecanismo no aplica cuando el perfil no lo define.
- `MovementProfileCatalogTests` se extiende para verificar que los 10 perfiles existentes tienen el chequeo secundario esperado (tipo y ángulo correctos).
- `FeedbackPhraseBankTests` se extiende para la nueva categoría `.badForm` (cantidad esperada de frases, no vacías en los 3 idiomas).
- La detección real en dispositivo (si el chequeo efectivamente distingue una repetición con impulso de una sin impulso) no se puede verificar con tests automatizados ni en el simulador — necesita verificación manual en dispositivo físico, igual que el resto del pipeline de Vision.

## Fuera de alcance (esta fase)

- Expandir la cobertura de ejercicios más allá de los 73 actuales — esfuerzo separado, pendiente de validar primero que este chequeo funciona.
- Detectar otros tipos de mala forma (rodillas hacia adentro, redondeo de columna, alineación de pies) — necesitarían tracking adicional (posición lateral, más articulaciones) fuera del alcance de esta fase.
- Ajustar automáticamente la tolerancia según el nivel del usuario (principiante vs. avanzado) — por ahora es un valor fijo por perfil.
