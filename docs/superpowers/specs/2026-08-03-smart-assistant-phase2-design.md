# Smart Assistant Phase 2: Legibilidad, Audio Motivacional y Más Ejercicios

## Contexto

El Smart Exercise Assistant (fase 1) ya está en `main` y desplegado a TestFlight. El usuario lo probó en un dispositivo físico y dio tres piezas de feedback:

1. El texto de feedback ("Buena repetición", "No llegaste al rango completo", etc.) es demasiado chico para leerse a la distancia a la que queda el teléfono propado durante un set.
2. Quiere frases motivacionales variadas cuando la repetición está bien hecha, y que se puedan escuchar por audio (audífonos o parlante), no solo leerse.
3. Quiere ampliar la cantidad de ejercicios soportados más allá de los 8 actuales.

Esta fase NO reemplaza el motor de conteo de reps (`RepCounterEngine`, `AngleCalculator`, `PoseDetectorService`) — todo eso sigue igual. Es una fase de UX/contenido/catálogo sobre la base ya construida.

## 1. Legibilidad del texto de feedback

`SmartAssistantSheet` usa `.wwCaption` (13pt) para el banner de feedback y para "No te vemos bien, ajusta el encuadre". Se cambia a `.wwHeadline` (24pt, bold) — el mismo peso visual que el nombre del ejercicio, y notablemente más grande que antes, sin competir con el contador de reps (`.wwDisplay`, 32pt), que sigue siendo el elemento más grande de la pantalla.

## 2. Frases motivacionales y de corrección + audio

### Selección de frases

Hoy `FormFeedback` tiene 3 casos (`.goodRep`, `.notDeepEnough`, `.tooFast`), cada uno con un solo texto fijo. Se reemplaza por selección aleatoria dentro de un banco de frases por caso, para que no se sienta repetitivo:

- **`.goodRep`**: 20 frases motivacionales.
- **`.notDeepEnough`**: 20 frases de corrección sobre rango de movimiento/ángulo (el caso que describe el usuario: "tu brazo no está en el ángulo correcto").
- **`.tooFast`**: 8 frases de corrección sobre velocidad/control (categoría ya existente, separada de la anterior porque describe un problema distinto — mezclar los dos tipos de corrección en un solo banco produciría mensajes incoherentes, por ejemplo pedir "ve más despacio" cuando el problema real fue no completar el rango).

Todas las frases existen en los 3 idiomas soportados por la app (es/en/fr) y se seleccionan según `AppLanguage.current`, igual que el resto del texto de la app — nunca según el idioma del sistema operativo, sino el idioma que el usuario eligió en su perfil.

**Banco de frases — Repetición bien hecha (`.goodRep`, 20 frases):**

| # | ES | EN | FR |
|---|----|----|----|
| 1 | ¡Bien hecho! | Well done! | Bien joué ! |
| 2 | Excelente repetición | Excellent rep | Excellente répétition |
| 3 | Así se hace | That's how it's done | C'est comme ça qu'il faut faire |
| 4 | Perfecta ejecución | Perfect execution | Exécution parfaite |
| 5 | Sigue así | Keep it up | Continue comme ça |
| 6 | Gran repetición | Great rep | Superbe répétition |
| 7 | Eso es, muy bien | That's it, well done | Voilà, très bien |
| 8 | Forma impecable | Flawless form | Forme impeccable |
| 9 | Rango completo, excelente | Full range, excellent | Amplitude complète, excellent |
| 10 | Lo estás haciendo muy bien | You're doing great | Tu t'en sors très bien |
| 11 | Repetición perfecta | Perfect rep | Répétition parfaite |
| 12 | Buen control del movimiento | Good control of the movement | Bon contrôle du mouvement |
| 13 | Vas muy bien | You're doing well | Tu es sur la bonne voie |
| 14 | Fuerza y técnica, así | Strength and technique, just like that | Force et technique, comme ça |
| 15 | Esa es la técnica correcta | That's the right technique | C'est la bonne technique |
| 16 | Excelente esfuerzo | Excellent effort | Excellent effort |
| 17 | Movimiento limpio | Clean movement | Mouvement propre |
| 18 | Bien controlado | Well controlled | Bien contrôlé |
| 19 | Sigues progresando | You're making progress | Tu progresses |
| 20 | Esa repetición cuenta | That rep counts | Cette répétition compte |

**Banco de frases — Falta de rango/ángulo (`.notDeepEnough`, 20 frases):**

| # | ES | EN | FR |
|---|----|----|----|
| 1 | No completaste el rango de movimiento | You didn't complete the full range of motion | Tu n'as pas fait toute l'amplitude |
| 2 | Baja un poco más | Go a little lower | Descends un peu plus |
| 3 | Estira el brazo por completo | Fully extend your arm | Étends complètement le bras |
| 4 | No llegaste al ángulo correcto | You didn't reach the right angle | Tu n'as pas atteint le bon angle |
| 5 | Completa el movimiento hasta el final | Finish the movement all the way | Termine le mouvement jusqu'au bout |
| 6 | Un poco más de profundidad | A bit more depth | Un peu plus de profondeur |
| 7 | Casi, pero falta rango | Almost, but you need more range | Presque, mais il manque de l'amplitude |
| 8 | Extiende completamente la articulación | Fully extend the joint | Étends complètement l'articulation |
| 9 | No te quedes a medio camino | Don't stop halfway | Ne t'arrête pas à mi-chemin |
| 10 | Baja más para activar el músculo | Go lower to fully engage the muscle | Descends plus bas pour bien engager le muscle |
| 11 | Tu postura necesita más rango | Your posture needs more range | Ta posture a besoin de plus d'amplitude |
| 12 | Repite con mayor amplitud | Repeat with more amplitude | Répète avec plus d'amplitude |
| 13 | No se ve el rango completo | I can't see the full range | Je ne vois pas toute l'amplitude |
| 14 | Ajusta el ángulo del brazo | Adjust your arm angle | Ajuste l'angle de ton bras |
| 15 | Falta llegar al punto final | You need to reach the end point | Il manque d'atteindre le point final |
| 16 | Profundiza más el movimiento | Go deeper into the movement | Approfondis davantage le mouvement |
| 17 | Tu rango de movimiento es corto | Your range of motion is short | Ton amplitude de mouvement est courte |
| 18 | Lleva la articulación al límite | Take the joint to its limit | Amène l'articulation à sa limite |
| 19 | Necesitas más extensión | You need more extension | Tu as besoin de plus d'extension |
| 20 | Esa repetición no cuenta, falta rango | That rep doesn't count, not enough range | Cette répétition ne compte pas, pas assez d'amplitude |

**Banco de frases — Muy rápido (`.tooFast`, 8 frases):**

| # | ES | EN | FR |
|---|----|----|----|
| 1 | Vas muy rápido, controla el movimiento | You're going too fast, control the movement | Tu vas trop vite, contrôle le mouvement |
| 2 | Más lento, controla el descenso | Slow down, control the descent | Plus lentement, contrôle la descente |
| 3 | Baja el ritmo | Slow the pace down | Ralentis le rythme |
| 4 | Controla la fase negativa | Control the negative phase | Contrôle la phase négative |
| 5 | Hazlo con más control | Do it with more control | Fais-le avec plus de contrôle |
| 6 | Menos velocidad, más técnica | Less speed, more technique | Moins de vitesse, plus de technique |
| 7 | Frena un poco el movimiento | Slow the movement down a bit | Ralentis un peu le mouvement |
| 8 | Tómate tu tiempo en cada repetición | Take your time on each rep | Prends ton temps sur chaque répétition |

Nota de honestidad técnica: el motor solo mide UN ángulo articular por ejercicio (definido en `MovementProfile.primaryAngle`) contra dos rangos (`downRange`/`upRange`). No hay detección de postura general, alineación de espalda, ni múltiples articulaciones a la vez — así que estas frases son variaciones de tono sobre la misma señal ya detectada (rango incompleto / demasiado rápido), no diagnósticos nuevos. Por eso varias frases usan lenguaje genérico ("la articulación", "el movimiento") en vez de nombrar una parte del cuerpo específica que el sistema no puede confirmar visualmente para todos los ejercicios.

### Audio

- `SmartAssistantModel` reproduce el texto de feedback seleccionado con `AVSpeechSynthesizer`, usando `AVSpeechSynthesisVoice(language:)` acorde al idioma actual (es-ES/en-US/fr-FR).
- La sesión de audio (`AVAudioSession`) se configura con categoría `.playback` y opción `.mixWithOthers`, para no interrumpir música o podcasts que el usuario esté escuchando mientras entrena.
- Si llega una nueva frase mientras la anterior se sigue hablando (reps muy seguidas), se cancela la anterior (`synthesizer.stopSpeaking(at: .immediate)`) y se habla la nueva — la frase más reciente siempre tiene prioridad sobre una que ya quedó desactualizada.
- Botón de mute: ícono de altavoz (`speaker.wave.2.fill` / `speaker.slash.fill`) junto al botón de cambiar cámara en `SmartAssistantSheet`. Estado persistido en `UserDefaults` (`smart_assistant.audio_muted`, default `false`) para que se recuerde entre sesiones. Al estar muteado, el texto en pantalla se sigue mostrando normalmente — solo se omite la llamada a `AVSpeechSynthesizer`.

## 3. Expansión del catálogo de ejercicios

### Reutilizando los 5 perfiles existentes (solo mapeo de IDs, cero código de ángulos nuevo)

Se agregan estas variantes del catálogo de 146 ejercicios a los perfiles ya construidos (IDs verificados contra `ExercisesSeed.json`, no inventados):

- **`squat`**: agrega `ex_049_sentadilla_frontal_con_barra`, `ex_062_sentadilla_hack_en_maquina`, `ex_063_sentadilla_en_maquina_smith`
- **`pushUp`**: agrega `ex_019_fondos_paralelas`, `ex_022_flexiones_inclinadas` — se eligen variantes de peso corporal, no press de banca con barra/mancuerna (que se hace acostado y no encaja con un teléfono propado de frente, a diferencia de las flexiones/fondos ya soportados)
- **`curl`**: agrega `ex_100_curl_alterno_mancuernas`, `ex_101_curl_martillo_mancuernas`, `ex_104_curl_concentrado`
- **`overheadPress`**: agrega `ex_079_press_militar_sentado_barra`, `ex_080_press_hombros_mancuernas`, `ex_081_press_arnold`
- **`hinge`**: agrega `ex_051_peso_muerto_rumano_con_barra`, `ex_052_peso_muerto_rumano_con_mancuernas`

### 2 perfiles nuevos

Ambos reutilizan el mismo ángulo hombro-codo-muñeca (`JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist)`) que ya usan `pushUp` y `curl` — no se necesita ningún ángulo ni joint nuevo en `AngleCalculator` ni `PoseDetectorService`. La diferencia entre perfiles es solo qué rango cuenta como "down" y cuál como "up".

- **`row`** (remo/espalda — cubre por primera vez el grupo muscular "back", 25 ejercicios en el catálogo, ninguno soportado hoy): ángulo del codo de extendido (~170°, brazo estirado hacia el peso) a flexionado (~60-80°, jalado hacia el torso). Exercises iniciales: `ex_027_remo_sentado_polea`, `ex_028_jalon_pecho_agarre_ancho` — ambos se hacen de frente a la cámara, a diferencia de remos inclinados/con mancuerna a un brazo que requieren vista lateral y quedan fuera de esta fase.
- **`tricepsExtension`** (tríceps — cubre por primera vez ese grupo muscular, 16 ejercicios, ninguno soportado hoy): ángulo del codo de flexionado (~70-90°, antebrazo arriba) a extendido (~170-180°, brazo recto) — es la dirección opuesta a `curl`. Exercise inicial: `ex_117_pushdown_polea_cuerda` (extensión en polea con cuerda, de frente a la cámara).

Esto sube la cobertura de 8 a 24 ejercicios (8 actuales + 13 nuevos en los 5 perfiles existentes + 3 nuevos entre `row`/`tricepsExtension`), agregando por primera vez espalda y tríceps. Los ángulos de `row` y `tricepsExtension` son valores de partida razonables — igual que los 5 perfiles de la fase 1, se espera afinarlos contra Vision real en dispositivo físico.

## Fuera de alcance (esta fase)

- Ejercicios que requieren vista lateral de la cámara (remo con mancuerna a un brazo, peso muerto convencional visto de perfil, fondos de tríceps en banco vistos de perfil) — el diseño asume cámara de frente, como en la fase 1.
- Detección de múltiples articulaciones o postura general (alineación de espalda, posición de rodillas respecto a los pies, etc.) — sigue siendo un ángulo por ejercicio.
- Voces distintas por sexo/tono, o control de velocidad/volumen de la voz — se usa la voz por defecto del sistema para el idioma.
- Ejercicios de core (planchas, etc.) — son ejercicios de tiempo, no de repeticiones, y no encajan en el modelo de conteo actual.

## Testing

- `RepCounterEngineTests`/`MovementProfileCatalogTests` existentes se extienden para cubrir `row` y `tricepsExtension` con la misma cobertura que los 5 perfiles actuales (rangos no solapados, angulos de prueba).
- Nueva suite para la selección aleatoria de frases: verificar que cada caso de `FormFeedback` siempre devuelve una frase no vacía perteneciente a su banco correspondiente, y que el banco tiene el tamaño esperado (20/20/8) en los 3 idiomas.
- El componente de audio (`AVSpeechSynthesizer`) no es testeable de forma significativa en unit tests (requiere hardware/simulador con audio) — se verifica manualmente en dispositivo físico, igual que la Vision pose detection de la fase 1.
