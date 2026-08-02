# Asistente Inteligente de Ejercicio (Smart Exercise Assistant)

## Contexto

El usuario pidió una nueva función mayor: durante la fase activa de un
set (`setPhase == .runningSet` en `GuidedWorkoutView`), ofrecer un
asistente con cámara en vivo que cuenta repeticiones y da feedback de
forma en tiempo real usando `Vision` (`VNDetectHumanBodyPoseRequest`) y
`AVFoundation`, sin ningún servicio externo — coherente con el
posicionamiento "100% local" ya establecido para la app.

**Timing:** la versión actual de la app ya fue enviada a revisión de
Apple. Esta función se desarrolla en una rama nueva, en paralelo,
dirigida a una versión posterior (1.1) — no bloquea ni modifica el
build ya enviado.

**Aporte del usuario:** el usuario proveyó el spec funcional inicial
completo (workflow de UI, overlay sobre la cámara, integración técnica
recomendada, y una estrategia de 3 etapas graduales para implementarlo
con Claude Code). Este documento formaliza ese spec tras una ronda de
brainstorming que ajustó el diseño técnico del motor de conteo y acotó
el alcance inicial de ejercicios.

## Decisiones (con el usuario, 2026-08-02)

- **Secuencia:** rama aparte (`smart-exercise-assistant` o similar),
  no toca `main` ni el build ya enviado a revisión.
- **Alcance de ejercicios:** un set curado inicial (~8-10 ejercicios),
  no los 146 del catálogo. Se excluyen ejercicios isométricos (plancha,
  hollow hold) porque el conteo de reps no aplica a un hold estático,
  y ejercicios en máquina/polea donde el equipo puede tapar la
  detección de postura.
- **Posición de cámara:** el usuario elige entre cámara frontal o
  trasera dentro del modal (no se impone una sola).
- **Privacidad del video:** 100% efímero. El feed se procesa cuadro a
  cuadro en el dispositivo y se descarta inmediatamente — nunca se
  graba, guarda ni sube. Esto mantiene vigente la politica de
  privacidad actual ("100% local") sin necesitar una seccion nueva de
  retencion de datos.
- **Motor de conteo vs. configuracion por ejercicio:** UN motor
  generico y reusable (deteccion de fase abajo/arriba a partir de un
  angulo, conteo en cada ciclo completo), pero CADA ejercicio tiene su
  propio `MovementProfile` independiente (que articulaciones mirar,
  que rangos de angulo cuentan como cada fase). Nada se comparte entre
  ejercicios salvo el motor que interpreta los perfiles — evita
  duplicar el algoritmo de conteo 12 veces sin perder precision por
  agrupar ejercicios geometricamente distintos (ej. sentadilla
  bulgara, asimetrica, bajo el mismo perfil que una sentadilla
  trasera estandar).
- **Stat "Force (Watt)" de la referencia visual del usuario:**
  EXCLUIDO del diseño real. No es calculable honestamente a partir de
  deteccion de postura por camara (requeriria sensores de fuerza o
  tracking de velocidad de barra). El resto de la referencia visual
  (anillo de progreso, contador de reps, banner de Coach Insight,
  boton Finalizar) si es viable y se implementa.
- **Idiomas:** todo texto visible (nombres de fase, banners de
  feedback, botones, mensajes de error de permiso) sigue el patron ya
  establecido en el proyecto — `String(localized:defaultValue:bundle:
  locale:)` con entradas es/en/fr en `Localizable.xcstrings`. Sin
  excepciones.
- **Idioma del codigo:** identificadores y comentarios del codigo
  nuevo de esta funcion, en ingles (departure del resto del proyecto,
  que tiene comentarios en español) — pedido explicito del usuario
  para este trabajo en adelante.

## Arquitectura

Tres capas, correspondientes a las 3 etapas de implementacion que
pidio el usuario:

1. **UI/Estado** — controla visibilidad del boton, presenta el modal
   de camara, maneja el ciclo de vida del set (inicio, cierre manual,
   cierre automatico al llegar al objetivo).
2. **Captura** — `AVCaptureSession` con camara frontal/trasera
   intercambiable, feed de video en vivo.
3. **Analisis** — `VNDetectHumanBodyPoseRequest` por cuadro (con
   throttle, no cada frame a 30-60fps), motor de conteo de reps
   parametrizado por el `MovementProfile` del ejercicio activo.

## Componentes

- **`SmartAssistantButton`** — visible unicamente cuando
  `setPhase == .runningSet` en `GuidedWorkoutView` Y el ejercicio
  activo tiene un `MovementProfile` definido. Si no esta soportado, el
  boton simplemente no aparece (sin mensaje de "no soportado").
- **`SmartAssistantSheet`** — `fullScreenCover` (no un sheet chico) con
  el overlay: nombre del ejercicio, contador `X/Y` grande, banner de
  feedback de forma, boton "Finalizar set" siempre visible y
  accesible.
- **`CameraPreviewView`** — `UIViewRepresentable` que envuelve el
  preview layer de `AVCaptureSession`.
- **`CameraSessionController`** — gestiona el ciclo de vida de
  `AVCaptureSession`, el toggle frontal/trasera, y expone los cuadros
  de video capturados.
- **`PoseDetectorService`** — corre `VNDetectHumanBodyPoseRequest` por
  cuadro (throttled) y devuelve los puntos clave (joints) detectados.
- **`MovementProfile`** (struct, logica pura) — configuracion
  independiente por ejercicio:

  ```swift
  struct MovementProfile {
      let primaryJoint: JointAngle
      let secondaryJoint: JointAngle?
      let downRange: ClosedRange<Double>
      let upRange: ClosedRange<Double>
      let tracksPerLimb: Bool
  }
  ```

- **`RepCounterEngine`** (logica pura, sin dependencias de
  AVFoundation/Vision) — recibe angulos calculados a partir de los
  joints detectados + un `MovementProfile`, mantiene el estado de fase
  actual, incrementa el contador en cada ciclo completo, y evalua si
  el angulo alcanzado esta dentro de rango para emitir feedback de
  forma.

## Flujo de datos

1. Usuario toca "Start Set" → `setPhase = .runningSet` (ya existe en
   `GuidedWorkoutView`, sin cambios).
2. Si el ejercicio activo tiene `MovementProfile` definido, aparece
   `SmartAssistantButton`.
3. Toca el boton → se abre `SmartAssistantSheet(exercise:,
   targetReps:, profile:, onFinish: (Int) -> Void)`.
4. `CameraSessionController` arranca la captura; cada cuadro →
   `PoseDetectorService` → joints → `RepCounterEngine.update(joints:)`
   actualiza fase y, en una transicion de ciclo completo, incrementa
   el contador y emite un mensaje de feedback.
5. Cierre por objetivo alcanzado (contador == `targetReps`) o boton
   manual "Finalizar" → `onFinish(count)`, se detiene la camara, se
   cierra el modal.
6. De vuelta en `GuidedWorkoutView`: `set.repsCompleted = count`. Si
   `GuidedSessionFlow.canCompleteSet(weightKg:repsCompleted:)` ya es
   `true` (el peso ya estaba cargado), se dispara el mismo flujo que
   el boton "Finish set" existente (marca completado, arranca el
   descanso, notificacion). Si el peso sigue en 0, el set NO se
   completa automaticamente — solo se cargan las reps, y el usuario
   ve la pantalla normal con el boton "Finish set" (ya deshabilitado
   hasta cargar peso, logica existente sin cambios).

## Manejo de errores

- Permiso de camara denegado → mensaje en el modal con link a
  Ajustes, mismo patron ya usado en la app (`CameraPicker`). No
  crashea.
- Sin persona detectada por varios segundos → banner de feedback
  indica que hay que ajustar el encuadre, en vez de quedarse en
  silencio sin explicacion.
- Poca luz / oclusion / angulo dudoso → el motor simplemente no cuenta
  esa repeticion hasta detectar un ciclo completo valido. El boton
  "Finalizar" manual es siempre la salida de emergencia — el usuario
  nunca queda atrapado en el modal.

## Testing

`AVFoundation` y `Vision` no son testeables por unidad (dependen de
hardware real de camara). Pero **el `RepCounterEngine` es logica
pura** — dado un `MovementProfile` y una secuencia sintetica de
angulos, ¿cuenta las repeticiones correctas y emite el feedback
esperado? Esto se testea exhaustivamente con Swift Testing, siguiendo
el mismo patron ya establecido en el proyecto para logica pura
(`GuidedSessionFlow`, `WorkoutGeneratorService`).

Los pasos 2 (feed de camara real) y 3 (Vision real sobre video real)
necesitan verificacion en un dispositivo fisico por parte del
usuario — el simulador no tiene camara, y Vision con deteccion de
pose humana no funciona de forma confiable sobre datos sinteticos.
Esto se documenta explicitamente en el plan de implementacion.

## Ejercicios curados iniciales

Sin ejercicios isometricos ni de maquina/polea (posible oclusion de la
vista). Perfiles (`MovementProfile`) exactos — angulos y rangos — se
definen durante la implementacion de la Etapa 3, no en este spec:

- Sentadilla trasera con barra (`ex_048_sentadilla_trasera_con_barra`)
- Sentadilla goblet con mancuerna (`ex_060_sentadilla_goblet_con_mancuerna`)
- Sentadilla bulgara con mancuernas (`ex_057_sentadilla_bulgara_con_mancuernas`)
- Flexiones de pecho (`ex_021_flexiones_pecho`)
- Fondos en banco (`ex_020_fondos_banco`)
- Curl de biceps con barra recta (`ex_098_curl_barra_recta`)
- Press militar con barra (`ex_078_press_militar_barra`)
- Peso muerto convencional (`ex_031_peso_muerto_convencional`)
- Zancadas caminando con mancuernas (`ex_053_zancadas_caminando_con_mancuernas`)

Lista ampliable despues de esta primera version; no requiere cambios
de arquitectura, solo agregar entradas al diccionario
`[exerciseId: MovementProfile]`.

## Etapas de implementacion (segun lo pedido por el usuario)

1. **Etapa 1 — Estado y UI:** botones, visibilidad condicionada a
   `setPhase == .runningSet`, el modal completo con datos ficticios
   (mock data: contador incrementando solo, sin camara real).
2. **Etapa 2 — Feed de camara:** `AVFoundation` en vivo,
   `NSCameraUsageDescription` actualizado para reflejar el nuevo uso
   (ya no es solo "foto de perfil"), toggle frontal/trasera.
3. **Etapa 3 — Vision y conteo real:** `VNDetectHumanBodyPoseRequest`,
   `RepCounterEngine`, los `MovementProfile` de los 9 ejercicios
   curados, banner de feedback real.

Cada etapa es su propia tarea/PR revisable de forma independiente,
segun el patron ya usado en este proyecto (subagent-driven-development).

## Fuera de alcance

- Los 146 ejercicios del catalogo — solo los 9 curados en esta v1.
- Ejercicios isometricos (plancha, hollow hold, plancha lateral).
- Grabar o guardar cualquier video/imagen de la sesion de camara.
- Stat de "Force (Watt)" u otra metrica de fuerza/potencia no
  derivable honestamente de deteccion de postura.
- Actualizar la politica de privacidad publicada / nota de revision
  de Apple del envio YA hecho — eso se actualiza cuando esta funcion
  este lista para su propio envio (fuera del alcance de este spec de
  diseño, se retoma en su propio ciclo de preparacion para tienda).
