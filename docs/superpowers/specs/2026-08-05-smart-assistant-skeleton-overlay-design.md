# Smart Assistant: Esqueleto Virtual + Cámara Gran Angular

## Contexto

Feedback de uso real: al Smart Assistant "le cuesta leer las repeticiones" y el usuario no tiene forma de saber, mientras entrena, si la cámara lo está siguiendo bien o si su movimiento se está saliendo del rango esperado — hoy solo se entera al final de la repetición, vía texto/audio. La solución: un esqueleto virtual dibujado en tiempo real sobre la imagen de la cámara, que refleja visualmente el estado del chequeo de forma de la fase 4 (balanceo/rango) cuadro a cuadro, no solo al completar la repetición.

Además, el usuario señaló que probablemente no se pare lo bastante lejos del teléfono como para que la lente normal cubra todo el cuerpo — se aprovecha esta misma fase para cambiar a la lente gran angular (donde exista) y así el encuadre necesite menos distancia.

## 1. Señal en tiempo real: `isSecondaryCheckOK`

`RepCounterEngine` ya calcula, cuadro a cuadro durante la fase "abajo" del movimiento, si el chequeo secundario (`.stability`/`.bounded` de la fase 4) se viola — pero hoy ese resultado solo se acumula en una bandera privada (`secondaryViolatedThisAttempt`) y se expone recién al completar la repetición (`.badForm`). Se agrega una nueva propiedad pública `private(set) var isSecondaryCheckOK: Bool = true`, actualizada dentro de `trackSecondary(_:)` con el mismo cálculo que ya existe (sin lógica nueva de detección) — solo se expone también el resultado instantáneo de este cuadro, no solo el acumulado.

Fuera de la fase "abajo" (fase "arriba", entre repeticiones, donde `trackSecondary` no se llama) se resetea a `true` en `enterUp(now:)` — no hay nada activamente vigilado en ese momento, así que el esqueleto no debe quedarse en rojo de forma colgada entre repeticiones.

`SmartAssistantModel` expone esto como `var isFormOK: Bool { engine?.isSecondaryCheckOK ?? true }`.

## 2. El esqueleto se dibuja en `CameraPreviewView`

`SmartAssistantModel` ya recibe `[BodyJoint: CGPoint]` en cada cuadro procesado (`handleDetectedJoints`) pero los descarta después de calcular los ángulos. Gana una nueva propiedad `private(set) var latestJoints: [BodyJoint: CGPoint] = [:]`, actualizada al inicio de `handleDetectedJoints` con el diccionario crudo de ese cuadro (independientemente de si el cálculo de ángulos tiene éxito), para que la vista pueda dibujarlo.

`CameraPreviewView` (el bridge UIKit que ya envuelve `AVCaptureVideoPreviewLayer`) gana dos entradas nuevas: `joints: [BodyJoint: CGPoint]` e `isFormOK: Bool`. Internamente agrega una `CAShapeLayer` como sublayer de la capa de preview, actualizada en `updateUIView` cada vez que cambian los joints. Esto mantiene toda la complejidad de coordenadas de AVFoundation contenida en este único archivo, igual que ya hace hoy con el preview mismo.

**Conversión de coordenadas:** cada punto de Vision (normalizado, espacio del dispositivo de captura) se convierte al espacio real de la vista con `videoPreviewLayer.layerPointConverted(fromCaptureDevicePointOfInterest:)` — el método nativo de Apple para esto, que maneja automáticamente el recorte de `.resizeAspectFill` sin que este código tenga que reimplementar esa matemática.

**Huesos dibujados** (solo se traza una línea si Vision detectó AMBAS articulaciones de ese segmento en el cuadro actual — si la cámara solo alcanza a ver tren superior, no aparecen líneas de piernas fantasma):

- Brazo izquierdo: hombro-codo, codo-muñeca
- Brazo derecho: hombro-codo, codo-muñeca
- Línea de hombros: hombro izquierdo-hombro derecho
- Línea de caderas: cadera izquierda-cadera derecha
- Torso: hombro izquierdo-cadera izquierda, hombro derecho-cadera derecha
- Pierna izquierda: cadera-rodilla, rodilla-tobillo
- Pierna derecha: cadera-rodilla, rodilla-tobillo

(11 segmentos en total, más un punto/círculo pequeño en cada articulación detectada.)

**Color:** por defecto (`isFormOK == true`), TODO el esqueleto se pinta del color de acento de la app (`Color.ironAccent`, el mismo tono ya usado en el resto del Smart Assistant). Cuando `isFormOK == false`, solo los DOS segmentos que forman el triángulo del chequeo secundario de este perfil (`profile.secondaryCheck?.angle` — ya definido por perfil desde la fase 4) se pintan de rojo; el resto del esqueleto se queda en `ironAccent`. Como el triángulo siempre usa el lado izquierdo (`JointAngle` de cada perfil ya usa joints `.left*` exclusivamente, igual que el ángulo primario), esto siempre corresponde a exactamente 2 de los 11 segmentos ya listados arriba — no hace falta ningún segmento nuevo:

| Triángulo del chequeo secundario | Segmentos que se ponen rojos |
|---|---|
| hombro-cadera-rodilla (squat, pushUp, overheadPress, row, lateralRaise, legExtension, legCurl) | hombro izq-cadera izq, cadera izq-rodilla izq |
| cadera-hombro-codo (curl, tricepsExtension) | cadera izq-hombro izq (mismo segmento que "torso" arriba), hombro izq-codo izq |
| cadera-rodilla-tobillo (hinge) | cadera izq-rodilla izq, rodilla izq-tobillo izq |

## 3. Cámara gran angular con respaldo automático

En `CameraSessionController.reconfigureInput(position:)`, el dispositivo de captura se resuelve probando primero `.builtInUltraWideCamera`; si no existe en este dispositivo/posición (`AVCaptureDevice.default` devuelve `nil`), cae a `.builtInWideAngleCamera` (el comportamiento actual). Aplica igual a cámara trasera y frontal — en la mayoría de iPhones la frontal no tiene gran angular, así que ahí siempre cae al respaldo de forma transparente, sin necesitar una rama de código separada por posición.

## Testing

- `isSecondaryCheckOK`: se prueba igual que el resto de `RepCounterEngineTests` (secuencias de ángulos sintéticas) — casos: `true` mientras no hay violación, pasa a `false` en el cuadro exacto donde se viola el chequeo, vuelve a `true` al entrar a la fase "arriba" (nueva repetición limpia), se mantiene en `true` para perfiles sin `secondaryCheck`.
- La lista de "huesos" y el mapeo triángulo→segmentos-rojos es lógica pura (no depende de Vision/AVFoundation en sí) y se puede probar de forma aislada: dado un `profile.secondaryCheck?.angle`, confirmar que resuelve exactamente a los 2 segmentos esperados de la tabla de arriba.
- El dibujo real del esqueleto (`CameraPreviewView`/`CAShapeLayer`) y la selección de lente de cámara no son testeables automáticamente (dependen de UIKit real y hardware de cámara) — se verifican manualmente en dispositivo, igual que el resto del pipeline de cámara/Vision de fases anteriores.

## Fuera de alcance

- No se agregan articulaciones nuevas ni se cambia lo que Vision detecta — se reutilizan las mismas 12 que ya existen.
- No hay una tercera categoría de color (ej. amarillo/advertencia) — solo verde (acento)/rojo, binario, igual que el chequeo secundario ya es binario.
- No se resuelve aquí la selección automática de zoom/distancia óptima — el gran angular ayuda a que se necesite menos distancia, pero no hay guía activa de encuadre más allá del banner existente de "no te vemos bien".
