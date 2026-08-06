# Smart Assistant: Expansión del catálogo de ejercicios

## Contexto

Último item del feedback original de uso real: "empecemos a gestionar para todos los ejercicios no solo uno la opción de smart assistance". Hoy el Smart Assistant cubre 64 de los 146 ejercicios del catálogo (`MovementProfileCatalog`, en `IronPulse/Services/MovementProfile.swift`), usando 10 patrones de movimiento compartidos (squat, pushUp, curl, overheadPress, hinge, row, tricepsExtension, lateralRaise, legExtension, legCurl). La UI ya no necesita ningún cambio para agregar cobertura — `GuidedWorkoutView.swift:264` decide si mostrar el botón de Smart Assistant únicamente en base a `MovementProfileCatalog.profile(forExerciseID:) != nil`, así que expandir cobertura es, en la mayoría de los casos, agregar entradas al diccionario `profiles`.

Se revisaron los 82 ejercicios sin cobertura, uno por uno, contra una restricción central del sistema: `RepCounterEngine`/`SkeletonOverlay` miden **ángulos en el plano de la imagen 2D** (vista frontal fija), no posición 3D real. Esto excluye por diseño cualquier movimiento cuyo desplazamiento principal sea:
- Tumbado o boca abajo (el sistema asume persona de pie/sentada frente a la cámara).
- Isométrico sin ciclo de repetición (planchas, vacío abdominal).
- En un plano de rotación o profundidad que la cámara frontal no resuelve bien (ver la sección siguiente).
- Dinámico/traslacional (caminando, saltando — el sujeto sale del encuadre).

## 1. El límite de "plano de rotación/profundidad"

Descubrimiento de esta revisión, no documentado antes: un ángulo articular en 2D (`AngleCalculator.angle(at:from:to:)`, usado por todos los `JointAngle`) solo cambia de forma útil cuando el segmento trackeado se mueve **acercándose o alejándose de una línea de referencia dentro del plano de la imagen** (flexión/extensión clásica — un codo doblándose, una cadera flexionando). No cambia de forma útil cuando el segmento se mueve:
- **En rotación** (ej. torso girando en un leñador de polea — el ángulo hombro-cadera-codo se mantiene prácticamente constante durante todo el giro).
- **En aducción/abducción horizontal frente al cuerpo** (ej. cruces de poleas — el codo se mueve de lado a lado a la misma altura del hombro; el ángulo hombro-codo respecto a la línea vertical hombro-cadera no cambia significativamente aunque el brazo cruce todo el frente del cuerpo).
- **Alejándose de la cámara en profundidad** (ej. patada de glúteo en polea — la pierna se extiende hacia atrás, un movimiento que en la proyección 2D de una cámara frontal apenas se distingue de estar parado quieto).

Este límite excluye explícitamente: leñador en polea (ya descartado en la conversación de diseño), cruces de poleas altas/bajas (nuevo hallazgo de esta revisión — inicialmente se habían propuesto como candidatos, pero el mismo análisis geométrico que descarta el leñador aplica acá), patada de glúteo en polea, abducción/aducción de cadera en máquina.

## 2. Grupo 1 — nuevas entradas de catálogo, cero perfil nuevo (18 ejercicios)

Estos ejercicios comparten la misma mecánica articular (mismo triángulo de ángulo, mismos rangos aproximados) que un perfil ya existente, hechos de pie/sentado compatible con la cámara. Se agregan como líneas nuevas al diccionario `profiles` de `MovementProfileCatalog`, sin tocar ninguno de los 10 `MovementProfile` existentes:

| Ejercicio | Perfil reusado | Nota |
|---|---|---|
| `ex_016_press_pecho_polea_de_pie` | `pushUp` | Press de pie en polea — mismo ángulo codo (hombro-codo-muñeca), mismo chequeo de estabilidad de torso que ya cubre variantes sentadas de `pushUp`. |
| `ex_026_remo_barra_inclinado` | `row` | Remo con barra inclinado, de pie. |
| `ex_030_remo_mancuerna_un_brazo` | `row` | **Un solo brazo** — ver limitación en la sección 4. |
| `ex_036_remo_t_manija` | `row` | Remo en T con manija, de pie. |
| `ex_041_remo_kettlebell_un_brazo` | `row` | **Un solo brazo** — ver limitación en la sección 4. |
| `ex_044_remo_alto_maquina_palanca` | `row` | Remo alto en máquina de palanca. |
| `ex_047_jalon_tras_nuca_agarre_ancho` | `row` | Mismo patrón de tirón que `ex_028_jalon_pecho_agarre_ancho`, ya cubierto por `row`. |
| `ex_077_peso_muerto_a_una_pierna_con_mancuerna` | `hinge` | Mismo ángulo cadera (hombro-cadera-rodilla) que el resto de las variantes de peso muerto. |
| `ex_059_zancada_con_barra` | `squat` | Zancada estática (no caminando) — mismo ángulo rodilla, mismos rangos aproximados que sentadilla; el chequeo de torso ya es permisivo (50-180°), sigue siendo seguro para una zancada más erguida. |
| `ex_086_elevaciones_laterales_polea` | `lateralRaise` | Variante en polea del ejercicio ya cubierto con mancuernas. |
| `ex_088_elevaciones_frontales_polea` | `lateralRaise` | Idem — `lateralRaise` ya documenta que cubre tanto elevación lateral como frontal. |
| `ex_089_aperturas_posteriores_mancuernas` | `lateralRaise` | Apertura posterior (reverse fly) con torso inclinado hacia adelante — el brazo pasa de colgar cerca del torso a extenderse lejos de él, el mismo tipo de movimiento que `lateralRaise` mide, solo con el torso inclinado en vez de erguido. |
| `ex_090_aperturas_posteriores_polea` | `lateralRaise` | Idem, variante en polea. |
| `ex_091_aperturas_posteriores_maquina` | `lateralRaise` | Idem, variante en máquina (pecho apoyado). |
| `ex_115_curl_cruzado_martillo` | `curl` | Curl martillo cruzado — mismo ángulo de codo que el resto de variantes de curl. |
| `ex_121_patada_triceps_mancuerna` | `tricepsExtension` | Patada de tríceps, torso inclinado — **el mapeo de menor confianza de todo el lote** (ver sección 4). |
| `ex_125_extension_polea_una_mano` | `tricepsExtension` | Extensión de tríceps en polea a una mano, mismo ángulo que las variantes ya cubiertas (`ex_117`, `ex_118`). |
| `ex_127_extension_mancuerna_una_mano_sobre_cabeza` | `tricepsExtension` | Extensión sobre cabeza a una mano — mismo triángulo que `ex_120_extension_mancuernas_dos_manos_sobre_cabeza`, ya cubierto por `tricepsExtension`. **Un solo brazo** — ver limitación en la sección 4. |

## 3. Grupo 2 — perfiles nuevos (2 ejercicios)

### `straightArmPulldown` (`ex_040_jalon_brazos_rectos_polea`)

De pie, brazos rectos (codo no se dobla), tirando desde una polea alta hacia los muslos. Mismo triángulo que `overheadPress`/`lateralRaise` (hombro-cadera-codo — cadera-hombro-codo en `JointAngle`), pero con los extremos invertidos: el reposo es brazo extendido hacia arriba/adelante (ángulo chico, brazo casi en línea con la línea cadera-hombro) y el pico es brazo abajo a los costados (ángulo grande).

```swift
private static let straightArmPulldown = MovementProfile(
    primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow),
    downRange: 0...30,
    upRange: 150...180,
    secondaryCheck: .stability(
        angle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
        toleranceDegrees: 15
    )
)
```

### `hangingLegRaise` (`ex_135_elevacion_piernas_colgado`)

Colgado de una barra, hombros fijos (sosteniendo el agarre), las piernas suben por flexión de cadera. Ángulo cadera (hombro-cadera-rodilla) — mismo triángulo que el chequeo secundario de `squat`/`hinge` y varios más, pero acá es el ángulo **primario**, no secundario. En reposo (colgado, piernas rectas hacia abajo) el ángulo es cercano a una línea recta (~160-180°); al subir las piernas el ángulo cae significativamente.

```swift
private static let hangingLegRaise = MovementProfile(
    primaryAngle: JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee),
    downRange: 160...180,
    upRange: 60...110,
    secondaryCheck: nil
)
```

Sin chequeo secundario: no hay un candidato claro de "estabilidad de torso" cuando el torso está colgado sosteniéndose de una barra — a diferencia de todos los perfiles existentes, acá no hay una articulación de referencia que debería quedarse quieta de forma comparable. `secondaryCheck: SecondaryCheck? = nil` ya es un valor soportado por el tipo `MovementProfile` (no usado hasta ahora por ninguno de los 10 perfiles existentes, pero es parte del diseño original).

El rango amplio de `upRange` (60...110) es deliberado: cubre tanto elevación de piernas rectas (rango de movimiento más amplio, ángulo más chico) como con rodillas dobladas hacia el pecho (rango más corto) sin forzar una técnica específica.

## 4. Limitaciones conocidas (documentadas, no resueltas en este alcance)

- **Ejercicios de un solo brazo** (`ex_030`, `ex_041`, `ex_127`): el sistema solo trackea articulaciones del lado izquierdo (`JointAngle` en los 12 perfiles, existentes y nuevos, usa exclusivamente `.left*`). Un ejercicio unilateral solo cuenta repeticiones correctamente si el usuario trabaja con el brazo/pierna izquierdo hacia la cámara — si usa el derecho, el ángulo trackeado no se mueve y no se detectan repeticiones. No se resuelve acá (requeriría trackear ambos lados y elegir cuál está activo); se documenta como limitación conocida en el código, igual que ya se documentan otras asunciones de los perfiles existentes.
- **`ex_121_patada_triceps_mancuerna`** es el mapeo de menor confianza del lote: aunque los rangos angulares coinciden numéricamente con `tricepsExtension`, el movimiento (antebrazo extendiéndose hacia atrás desde una posición de torso inclinado) tiene algo del mismo problema de profundidad que llevó a excluir la patada de glúteo — pero a diferencia de esa, acá el antebrazo se mueve dentro de un arco mayormente vertical (no puramente hacia atrás en profundidad), por lo que se incluye pero se marca para atención extra durante la verificación manual en dispositivo (Task de verificación).

## 5. Fuera de alcance (excluidos, no un TODO pendiente)

- Todo ejercicio tumbado/boca abajo/reclinado en banco (presses de pecho, aperturas, press francés, pullover, hiperextensiones, prensa de piernas a 45°, empuje de cadera, puente de glúteos).
- Sostenes isométricos sin ciclo de repetición (planchas, vacío abdominal, dead bug).
- Ejercicios dinámicos/traslacionales donde el sujeto se desplaza fuera del encuadre fijo (zancadas caminando, step-ups, escaladores).
- Movimientos de rotación de torso (leñador en polea) — requeriría un tipo de señal nuevo (medir giro, no flexión) fuera del alcance de esta iteración.
- Movimientos de aducción/abducción horizontal frente al cuerpo (cruces de poleas) o en el plano lateral de cadera (abducción/aducción de cadera en máquina) — mismo límite de plano de rotación/profundidad que el leñador.
- Encogimientos de hombros (barra/mancuernas) y press cubano — no hay un ángulo articular existente que capture el movimiento (elevación vertical del hombro sin flexión de codo, o rotación externa compleja).
- Elevaciones de talón (de pie/sentado/en prensa) — requeriría trackear el pie/dedos, articulación que Vision detecta pero que este sistema no trackea hoy (`BodyJoint` no incluye pie).

## Testing

- Cada entrada nueva de catálogo (Grupo 1) se prueba igual que las 64 existentes: un test por ejercicio confirmando que `MovementProfileCatalog.profile(forExerciseID:)` devuelve el perfil esperado, más una extensión de `MovementProfileCatalogTests.everyMovementProfileHasANonNilSecondaryCheck` — actualizada para reflejar que ahora SÍ existe un perfil sin chequeo secundario (`hangingLegRaise`), o renombrada/dividida para no romper su intención original.
- Los 2 perfiles nuevos (Grupo 2) se prueban con `RepCounterEngineTests` sintéticos, mismo patrón que los 10 existentes (secuencia de ángulos → verificar transición de fase y conteo de repetición).
- Los rangos angulares exactos (igual que los 10 perfiles existentes) son un punto de partida basado en biomecánica estándar — se espera reajustarlos contra Vision real en dispositivo físico durante la verificación manual, consistente con el comentario ya existente en el header de `MovementProfileCatalog`.
