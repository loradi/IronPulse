# Smart Assistant Phase 3: Cobertura Máxima del Catálogo y Audio Más Natural

## Contexto

Fase 2 (ya en `main`) subió la cobertura del Smart Assistant de 8 a 24 ejercicios y agregó audio TTS con la voz por defecto del sistema. El usuario pidió dos cosas para esta fase:

1. Expandir la cobertura a "toda la base de ejercicios" (146 ejercicios en total).
2. Que el audio suene más humano.

Sobre el punto 1: no es técnicamente posible cubrir el 100%. El motor de conteo (`RepCounterEngine`) solo sabe rastrear UN ángulo articular (3 puntos: proximal-vértice-distal) contra dos rangos, y la cámara asume que la persona está de pie o sentada, de frente al teléfono propado. Eso excluye de raíz:

- Ejercicios isométricos/sin repeticiones (planchas, vacío abdominal, etc. — 17 ejercicios de "core").
- Ejercicios acostado boca arriba o boca abajo (press de banca, empuje de cadera, puente de glúteos, curl femoral tumbado, pullover).
- Movimientos que necesitan vista lateral o dependen de una sola extremidad (remo a un brazo, zancadas, estocadas, patadas de glúteo/tríceps, peso muerto a una pierna) — la misma razón por la que las zancadas ya se habían excluido en la fase 1.
- Movimientos que son traslación (encogimientos/trapecio, elevación de talón) o rotación/plano horizontal (aperturas de pecho, abducción/aducción de cadera) en vez de un ángulo de flexión — el sistema actual no tiene una forma de rastrear esto sin agregar un tipo de `MovementProfile` completamente nuevo (distancia entre puntos o traslación vertical), lo cual queda fuera de esta fase.

Con esas exclusiones, la cobertura máxima realista sube de **24 a 64 ejercicios** (de 146) — la fase se enfoca en eso, aprovechando al máximo los 7 perfiles ya construidos y agregando solo 3 perfiles nuevos, todos reutilizando los triángulos de articulación que ya existen.

Nota de transparencia: este mapeo se hizo a partir del nombre y el equipo de cada ejercicio en `ExercisesSeed.json`, no de las imágenes/GIFs — algunas decisiones de "¿esto se hace de pie o acostado?" son juicio razonable, no certeza absoluta. Si alguno queda mal clasificado, se corrige puntualmente sin rehacer el resto.

## 1. Tres perfiles de movimiento nuevos

Los tres reutilizan un triángulo de articulación ya existente — cero cambios en `AngleCalculator.swift` o `PoseDetectorService.swift`.

- **`lateralRaise`**: mismo triángulo que `overheadPress` (`JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow)`), con un rango más corto: `downRange: 0...25` (brazo pegado al cuerpo — el piso es 0, no ~10, porque con el brazo colgando de forma natural en reposo el ángulo puede llegar a estar prácticamente en 0) a `upRange: 75...95` (brazo a la altura del hombro) — a diferencia de `overheadPress`, que sigue hasta ~180° por encima de la cabeza. Cubre tanto elevaciones laterales como frontales: desde una cámara de frente, ambas producen un cambio de ángulo hombro-codo muy similar en magnitud aunque el plano de movimiento sea distinto (lateral vs. frontal) — el sistema no distingue el plano, solo el ángulo, así que un solo perfil sirve para ambas.
- **`legExtension`**: mismo triángulo que `squat`/`hinge` para la pierna (`JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle)`), sentado en máquina: `downRange: 80...100` (pierna doblada) a `upRange: 160...180` (pierna extendida).
- **`legCurl`** (variante sentada únicamente — la variante acostada boca abajo queda excluida): mismo triángulo que `legExtension`, dirección invertida: `downRange: 160...180` (pierna extendida) a `upRange: 70...90` (pierna flexionada bajo el asiento).

## 2. Audio más natural

- **Selección de voz de mejor calidad**: en vez de `AVSpeechSynthesisVoice(language:)` (que siempre trae la voz "default" del sistema), se busca entre `AVSpeechSynthesisVoice.speechVoices()` la voz de mayor `.quality` (`.premium` > `.enhanced` > `.default`) que coincida con el idioma actual (`es-ES`/`en-US`/`fr-FR`), con fallback a la voz default si el usuario no tiene una mejorada descargada en Ajustes > Accesibilidad > Contenido Hablado > Voces. El resultado se cachea por idioma (no se recalcula en cada `speak()`, ya que recorrer `speechVoices()` en cada repetición sería innecesariamente costoso).
- **Ritmo y tono**: `AVSpeechUtterance.rate` baja de el valor por defecto (`AVSpeechUtteranceDefaultSpeechRate`, ~0.5) a `0.47`, y `pitchMultiplier` baja de `1.0` a `0.92` — un poco más lento y un poco más grave, menos "robótico" y más conversacional. Son constantes ajustables, no valores mágicos regados por el código.

## 3. Mapeo completo de ejercicios

### Perfiles existentes — nuevas asignaciones

**`squat`** (+2, total 8): `ex_058_sentadilla_sissy`, `ex_076_sentadilla_sumo_con_mancuerna`

**`pushUp`** (+3, total 7): `ex_015_press_pecho_maquina`, `ex_123_flexiones_diamante`, `ex_124_fondos_maquina`

**`curl`** (+12, total 16): `ex_099_curl_barra_z`, `ex_102_curl_predicador_barra_z`, `ex_103_curl_predicador_maquina`, `ex_105_curl_polea_baja`, `ex_106_curl_inclinado_mancuernas`, `ex_108_curl_drag`, `ex_109_curl_martillo_cuerda_polea`, `ex_110_curl_agarre_cerrado`, `ex_111_curl_zottman`, `ex_112_curl_polea_alta`, `ex_113_curl_inverso_barra`, `ex_114_curl_maquina`

**`overheadPress`** (+3, total 7): `ex_082_press_hombros_sentado_mancuernas`, `ex_083_press_hombros_maquina`, `ex_084_press_hombros_polea`

**`hinge`** (+3, total 6): `ex_032_peso_muerto_rumano`, `ex_043_peso_muerto_sumo`, `ex_064_peso_muerto_sumo_con_barra`

**`row`** (+9, total 11): `ex_023_dominadas_pronadas`, `ex_024_dominadas_supinadas`, `ex_025_dominadas_asistidas_banda`, `ex_029_jalon_pecho_agarre_cerrado`, `ex_033_remo_posterior_polea_cuerda`, `ex_045_face_pull_polea`, `ex_046_remo_arrodillado_polea_alta`, `ex_093_remo_menton_barra`, `ex_094_remo_menton_mancuernas`

**`tricepsExtension`** (+4, total 5): `ex_118_pushdown_polea_barra_recta`, `ex_120_extension_mancuernas_dos_manos_sobre_cabeza`, `ex_128_extension_polea_cuerda_tras_nuca`, `ex_133_extension_triceps_maquina`

### Perfiles nuevos

**`lateralRaise`** (2): `ex_085_elevaciones_laterales_mancuernas`, `ex_087_elevaciones_frontales_mancuernas`

**`legExtension`** (1): `ex_054_extension_de_piernas_en_maquina`

**`legCurl`** (1): `ex_056_curl_femoral_sentado`

### Total

24 (fase 2) + 40 nuevos (2+3+12+3+3+9+4+2+1+1) = **64 ejercicios**, de 146 en el catálogo (44%).

Nota de transparencia (revisión post-implementación): una revisión final de toda la rama encontró 9 IDs que habían quedado mapeados pero que en realidad violan los criterios de exclusión que este mismo documento establece (una sola extremidad/alternado, acostado, o apoyado-en-el-pecho con orientación ambigua respecto a la cámara) — el pase original de mapeo los pasó por alto. Se removieron del catálogo: `ex_016_press_pecho_polea_de_pie` (una mano), `ex_044_remo_alto_maquina_palanca` (pecho apoyado, orientación ambigua), `ex_086_elevaciones_laterales_polea` (un brazo), `ex_088_elevaciones_frontales_polea` (un brazo), `ex_107_curl_arana` (pecho apoyado sobre banco inclinado), `ex_115_curl_cruzado_martillo` (alterna brazos), `ex_125_extension_polea_una_mano` (una mano), `ex_126_press_frances_mancuernas` (acostado — la misma razón por la que `ex_116_press_frances_barra_ez` ya estaba excluido), y `ex_127_extension_mancuerna_una_mano_sobre_cabeza` (una mano). El total bajó de 73 a los 64 reflejados arriba.

## Fuera de alcance (con razón técnica)

- **17 ejercicios de "core"** (`ex_134` a `ex_150`): isométricos o sin ángulo articular claro (planchas, giros rusos, vacío abdominal, etc.) — no encajan en el modelo de conteo por repeticiones.
- **Acostado boca arriba/abajo**: todas las variantes de press de banca (`ex_001-007`, `ex_017`, `ex_018`, `ex_122`, `ex_130`, `ex_132`), aperturas en banco (`ex_008-010`, `ex_013`, `ex_014`), pullover (`ex_034`), curl femoral tumbado (`ex_055`), press francés con barra EZ (`ex_116`), empuje/puente de cadera (`ex_068-070`, `ex_074`), remo invertido (`ex_039`), hiperextensiones (`ex_038`, `ex_075`), superman (`ex_042`).
- **Vista lateral o una sola extremidad**: remo a un brazo con mancuerna/kettlebell (`ex_030`, `ex_041`), remo con barra inclinado y remo en T (`ex_026`, `ex_035`, `ex_036` — postura muy inclinada hacia adelante), zancadas y step-ups (`ex_053`, `ex_059`, `ex_061`), patada de tríceps/glúteo (`ex_121`, `ex_071`), peso muerto a una pierna (`ex_077`), prensa de piernas 45° (`ex_050` — el ángulo de la máquina normalmente requiere vista de perfil).
- **Traslación vertical, no ángulo articular**: encogimientos/trapecio (`ex_037`, `ex_096`), elevación de talón (`ex_065-067`).
- **Plano horizontal/rotación, no flexión**: aperturas y cruces de pecho (`ex_011-012`), abducción/aducción de cadera (`ex_072`, `ex_073`), press cubano (`ex_097`), jalón con brazos rectos (`ex_040`), jalón tras nuca (`ex_047`), aperturas posteriores de hombro (`ex_089-091`).

Cualquier ID de `ExercisesSeed.json` que no aparezca ni en la sección de cobertura ni en esta lista de exclusiones queda simplemente sin perfil por ahora (no se reclasificó en esta pasada) — el plan de implementación reconcilia la lista completa contra el catálogo real antes de escribir el código, igual que en la fase 2.

## Testing

- `MovementProfileCatalogTests` se extiende con los 3 perfiles nuevos y las nuevas asignaciones, siguiendo el mismo patrón de la fase 2 (rangos no solapados, IDs verificados contra `ExercisesSeed.json` con un test dedicado, perfiles nuevos comparados contra los triángulos compartidos).
- La selección de voz (`bestAvailableVoice`) se prueba con una `UserDefaults`/lista de voces inyectada donde sea posible; si `AVSpeechSynthesisVoice.speechVoices()` no es fácilmente inyectable, se documenta como no testeable automáticamente y se verifica manualmente en dispositivo (igual que el resto del pipeline de audio).
- Los rangos de los 3 perfiles nuevos son estimaciones de partida — se espera afinarlos contra Vision real en dispositivo físico, igual que los perfiles de fases anteriores.

## Fuera de alcance (esta fase)

- Cubrir aperturas/cruces de pecho, abducción/aducción de cadera, encogimientos o elevación de talón — requieren un tipo de `MovementProfile` nuevo (basado en distancia entre puntos o traslación, no en ángulo) que no existe hoy.
- Zancadas, step-ups y ejercicios de una sola extremidad en general — requieren tracking por extremidad individual, ya excluido desde la fase 1.
- Voces pre-grabadas por humanos reales — se mantiene texto-a-voz nativo, solo se mejora la calidad de voz y los parámetros de habla.
