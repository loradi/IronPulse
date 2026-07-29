# Preparación para App Store

## Contexto

Item explícitamente diferido durante toda la sesión ("Preparación para
App Store" — ya anotado como pendiente en `PROGRESS.md`). El usuario
pidió retomarlo ahora que el resto del roadmap (perfil editable +
unidades, sesión guiada de entrenamiento) ya está implementado, revisado
y mergeado a `main`.

Estado actual confirmado por exploración directa del proyecto:

- Bundle ID `com.BERNU.WattWeight`, `DEVELOPMENT_TEAM = 79FR46R3Y5` ya
  configurado en Xcode — **cuenta de Apple Developer Program de pago ya
  activa y lista para publicar** (confirmado por el usuario).
- App Icon: un solo ícono de 1024×1024 cubriendo las 3 variantes
  (claro/oscuro/tintado) — cumple el mínimo de la tienda.
- Permisos ya declarados en el proyecto (`INFOPLIST_KEY_*`):
  `NSCameraUsageDescription`, `NSHealthShareUsageDescription`,
  `NSHealthUpdateUsageDescription` (aunque la app no escribe en Salud, la
  descripción ya lo aclara). Entitlement de HealthKit presente.
- Version `1.0`, build `1`. Deployment target `iOS 26.5` (numeración
  actual de Apple, no un error).
- Precio: **gratis**, sin compras dentro de la app.
- No existe: política de privacidad, Privacy Manifest
  (`PrivacyInfo.xcprivacy`), capturas de pantalla, ni texto de ficha de
  App Store Connect.

## Decisiones (con el usuario, 2026-07-29)

- **Cuenta de desarrollador**: ya lista (membresía de pago activa) — no
  es un bloqueante para esta spec.
- **Precio**: gratis.
- **Política de privacidad**: se aloja en GitHub Pages (gratis, usa el
  repo existente) — yo redacto el texto.
- **Capturas de pantalla**: se generan desde el simulador (no se usan
  los mockups ilustrativos de `MOCKUPS/`, que no reflejan la UI real y
  Apple no los acepta como capturas de la ficha).
- **Texto de la ficha** (nombre/subtítulo/descripción/keywords/soporte):
  yo redacto una propuesta, el usuario la aprueba o ajusta.
- **Camino de publicación**: TestFlight primero, luego revisión pública
  — ambos usan el mismo build subido, solo cambia el paso final.
- **División de responsabilidad**: todo lo que es contenido/artefacto de
  repo lo hago yo (política de privacidad, Privacy Manifest, capturas,
  texto de ficha). Todo lo que requiere la sesión de Apple ID del usuario
  (crear el registro de la app en App Store Connect, subir el build vía
  Xcode Organizer, configurar TestFlight, enviar a revisión) queda como
  un checklist paso a paso para que el usuario lo ejecute — no debo
  manejar sus credenciales de Apple ni hacer submissions en su nombre.

## Política de privacidad

Nuevo archivo `docs/privacy-policy.md` (Markdown, se sirve tal cual vía
GitHub Pages configurando el repo para publicar desde `docs/` — paso que
el usuario hace una vez en la configuración de GitHub, incluido en el
checklist). Contenido:

- Qué datos toca la app: peso/altura/fecha de nacimiento (solo lectura,
  vía HealthKit, nunca se escriben de vuelta); foto de perfil (cámara,
  se guarda como `Data` local en el dispositivo, nunca sale de él).
- No hay backend, no hay servidor propio, no hay analítica ni SDKs de
  terceros — todo el dato vive en el dispositivo del usuario
  (SwiftData local) y en iCloud solo si el usuario mismo tiene
  respaldo de iCloud activado a nivel de sistema (fuera del control de
  la app).
- Cómo eliminar los datos: borrar el perfil desde la app, o desinstalar
  la app (borra el store local completo).
- Contacto para dudas de privacidad: el email de soporte definido en la
  sección de texto de ficha.
- Fecha de última actualización.

## Privacy Manifest

Nuevo archivo `IronPulse/PrivacyInfo.xcprivacy` (formato plist estándar
de Apple), declarando el uso de `NSPrivacyAccessedAPICategoryUserDefaults`
con el reason code `CA92.1` ("acceso para leer/escribir preferencias
propias de la app, no compartidas con terceros ni usadas para tracking")
— la única API "de razón requerida" que el proyecto usa directamente
(`AppLanguage`/`UnitSystem` leen/escriben `UserDefaults.standard`). Sin
third-party SDKs, no hace falta declarar nada más.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

Se agrega al target principal en Xcode (el archivo debe estar incluido
en el bundle de la app — con `PBXFileSystemSynchronizedRootGroup` ya en
uso en este proyecto, colocarlo directo en `IronPulse/` es suficiente,
sin tocar `project.pbxproj` a mano).

## Capturas de pantalla

Usando el simulador ya disponible en este entorno (iPhone 17, que cumple
el tamaño 6.9" requerido), con un perfil de ejemplo ya cargado (rutina
activa, algunos entrenamientos históricos para que Dashboard/Progreso no
se vean vacíos):

1. Dashboard (con racha, volumen, gráfica de progreso).
2. Tab Rutina (con la rutina activa y sus días).
3. Catálogo de ejercicios.
4. Sesión guiada de entrenamiento (un set activo, cronómetro visible).
5. Perfil (con foto, datos físicos editables).

Se guardan en `docs/app-store/screenshots/` (nuevo directorio), 5
archivos PNG. Estas capturas **no se pueden generar completamente sin
interacción** dado el problema de inyección de taps ya documentado
repetidamente en este entorno — el plan debe incluir un paso donde el
usuario mismo navega la app en el simulador mientras yo capturo cada
pantalla con `screenshot`, en vez de depender de taps automatizados para
llegar a cada una.

## Texto de la ficha (borrador, sujeto a aprobación)

- **Nombre**: Watt + Weight
- **Subtítulo** (máx. 30 caracteres): "Rutinas y fuerza en un lugar"
- **Descripción** (máx. 4000 caracteres): párrafo cubriendo generación
  automática de rutinas, seguimiento de progreso, sesión guiada con
  cronómetro por set, integración con Salud, soporte multi-idioma
  (es/en/fr) y sistema de unidades métrico/imperial. Texto completo
  redactado en la tarea correspondiente del plan, no aquí (este es el
  resumen de contenido, no el texto final).
- **Palabras clave** (máx. 100 caracteres, separadas por coma):
  "gimnasio,rutina,fuerza,entrenamiento,fitness,pesas,musculo,workout"
- **Categoría**: Salud y forma física (primaria).
- **Contacto de soporte**: `ldiego900@gmail.com` (el email de la cuenta
  de este usuario ya conocido en la sesión) — el usuario confirma o
  cambia al revisar el spec.
- **Nota de privacidad para revisores de Apple**: aclarar en el campo de
  notas de App Store Connect que la app es completamente local, sin
  backend, para acelerar la revisión de HealthKit.

## Checklist manual (fuera de mi alcance, para el usuario)

1. Confirmar que el repo tiene GitHub Pages habilitado sirviendo desde
   `docs/` (Settings → Pages en GitHub).
2. Crear el registro de la app en App Store Connect (nombre, bundle ID,
   SKU).
3. Completar la ficha con el texto aprobado (sección anterior) y subir
   las capturas generadas.
4. Pegar la URL de la política de privacidad publicada.
5. Archivar el build en Xcode (Product → Archive) y subirlo vía Xcode
   Organizer a App Store Connect.
6. Configurar el grupo de TestFlight (interno o externo) y probar el
   build.
7. Una vez conforme, enviar a revisión desde App Store Connect.

## Fuera de alcance

- Pagar o verificar la membresía de Apple Developer Program — ya
  confirmada activa por el usuario.
- Compras dentro de la app / suscripciones — la app es gratis, sin
  IAP.
- Traducir la ficha de App Store Connect a en/fr — se deja en español
  por ahora (fuera del alcance de esta spec; la app en sí ya soporta
  es/en/fr, pero la ficha de la tienda es un artefacto de marketing
  aparte).
- Capturas de iPad — no requeridas si `TARGETED_DEVICE_FAMILY` no
  prioriza iPad como experiencia principal; se puede agregar después
  sin bloquear el envío inicial.
