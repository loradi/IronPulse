# Preparación para App Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preparar todo el contenido/artefactos de repo necesarios para enviar Watt + Weight a revisión de Apple (política de privacidad, Privacy Manifest, capturas de pantalla, texto de ficha de App Store Connect), y dejar un checklist manual para los pasos que requieren la sesión de Apple ID del usuario.

**Architecture:** Cada tarea produce un artefacto de contenido independiente (documento Markdown, archivo de configuración de Xcode, o imágenes). Ninguna tarea depende del código de la app en sí — no hay cambios de comportamiento, solo metadata/documentación/assets para la tienda.

**Tech Stack:** Markdown, plist XML (Privacy Manifest), capturas PNG desde el simulador de iOS.

## Global Constraints

- Bundle ID `com.BERNU.WattWeight` — no cambia.
- App gratis, sin compras dentro de la app — no hay que configurar nada de pagos.
- Cuenta de Apple Developer Program ya activa — no es parte de esta tarea.
- Todo el almacenamiento de la app es local (SwiftData + `UserDefaults`), sin backend propio, sin analítica de terceros — la política de privacidad y la nota para revisores deben reflejar esto con precisión.
- Contacto de soporte: `ldiego900@gmail.com` (confirmado por el usuario al revisar el spec).
- Las capturas de pantalla deben ser de la UI real de la app (no los mockups ilustrativos de `MOCKUPS/`) — Apple no acepta mockups como capturas de ficha.

---

### Task 1: Política de privacidad

**Files:**
- Create: `docs/privacy-policy.md`

- [ ] **Step 1: Escribir el archivo completo**

```markdown
# Política de Privacidad de Watt + Weight

_Última actualización: 29 de julio de 2026_

Watt + Weight ("la app") es una aplicación de entrenamiento y
seguimiento de fuerza. Esta política explica qué datos toca la app y
cómo se manejan.

## Qué datos recopila la app

- **Datos de perfil que tú ingresas**: nombre, edad, sexo, altura,
  peso, nivel de experiencia, objetivo de entrenamiento, y la rutina
  que generes o armes.
- **Datos de Salud (HealthKit)**: si lo autorizas, la app lee (nunca
  escribe) tu peso corporal, altura, fecha de nacimiento y sexo
  biológico desde la app Salud de iOS, únicamente para completar tu
  perfil automáticamente.
- **Foto de perfil**: si eliges tomar una foto o elegir una de tu
  galería, se guarda como datos localmente en tu dispositivo.
- **Datos de entrenamiento**: las rutinas, ejercicios, sets, pesos y
  repeticiones que registras al usar la app.

## Dónde se almacenan tus datos

Todo el almacenamiento de Watt + Weight es **local, en tu propio
dispositivo**. La app no tiene servidor propio, no envía tus datos a
ningún backend, no usa herramientas de analítica de terceros, y no
comparte tu información con nadie.

Si tienes el respaldo de iCloud activado a nivel de sistema operativo,
tus datos podrían incluirse en el respaldo general de tu dispositivo —
esto lo controla iOS directamente, no la app.

## Notificaciones

La app usa notificaciones locales (generadas en tu propio dispositivo,
no notificaciones push desde un servidor) para avisarte cuando termina
tu descanso entre sets durante un entrenamiento. Ninguna información se
envía a servidores externos para esto.

## Cómo eliminar tus datos

- Elimina tu perfil desde dentro de la app — esto borra toda la
  información asociada a ese perfil, incluida cualquier foto guardada.
- Desinstala la app — esto borra por completo el almacenamiento local
  de la app en tu dispositivo.

## Cambios a esta política

Cualquier cambio futuro a esta política se reflejará en esta misma
página, actualizando la fecha al inicio del documento.

## Contacto

Si tienes preguntas sobre esta política de privacidad, escribe a
[ldiego900@gmail.com](mailto:ldiego900@gmail.com).
```

- [ ] **Step 2: Confirmar que el archivo se ve bien renderizado**

Abrir `docs/privacy-policy.md` con el visor de Markdown de tu editor (o
`cat docs/privacy-policy.md`) y confirmar que no hay errores de sintaxis
evidentes (títulos, listas, el link de contacto).

- [ ] **Step 3: Commit**

```bash
git add docs/privacy-policy.md
git commit -m "Agrega politica de privacidad para App Store"
```

---

### Task 2: Privacy Manifest

**Files:**
- Create: `IronPulse/PrivacyInfo.xcprivacy`

**Interfaces:**
- Consumes: ninguno — archivo de configuración estático, sin código.

- [ ] **Step 1: Crear el archivo con el contenido exacto**

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

Guardar en `IronPulse/PrivacyInfo.xcprivacy` (mismo nivel que
`IronPulse.entitlements`) — el proyecto usa
`PBXFileSystemSynchronizedRootGroup` para la carpeta `IronPulse/`, así
que el archivo se incluye automáticamente en el target sin tocar
`project.pbxproj` a mano.

- [ ] **Step 2: Validar que el XML es un plist correcto**

Run: `plutil -lint IronPulse/PrivacyInfo.xcprivacy`
Expected: `IronPulse/PrivacyInfo.xcprivacy: OK`

- [ ] **Step 3: Confirmar que el build lo recoge sin errores**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add IronPulse/PrivacyInfo.xcprivacy
git commit -m "Agrega Privacy Manifest (uso de UserDefaults, reason CA92.1)"
```

---

### Task 3: Texto de la ficha de App Store Connect

**Files:**
- Create: `docs/app-store/listing-es.md`

- [ ] **Step 1: Escribir el archivo completo**

```markdown
# Ficha de App Store Connect — Watt + Weight (es)

## Nombre
Watt + Weight

## Subtítulo
(máx. 30 caracteres — 29 usados)

Rutinas y fuerza en un lugar

## Descripción
(máx. 4000 caracteres)

Watt + Weight es tu compañero de entrenamiento de fuerza: genera
rutinas automáticas ajustadas a tu nivel y objetivo, te guía set por
set durante el entrenamiento, y lleva el registro de tu progreso a lo
largo del tiempo.

CARACTERÍSTICAS PRINCIPALES

• Rutinas automáticas — genera una rutina completa según tu nivel de
experiencia, objetivo (fuerza, hipertrofia, resistencia) y días
disponibles por semana, o arma la tuya ejercicio por ejercicio.

• Sesión guiada de entrenamiento — un ejercicio a la vez, con
cronómetro por set: empieza el set, márcalo cuando termines, y un
descanso automático (90 segundos en ejercicios compuestos, 60 en
aislamiento) te avisa cuándo seguir. Ajusta la cantidad de sets sobre
la marcha.

• Seguimiento de progreso — gráficas de volumen total, racha de
entrenamientos, y progreso de peso máximo por ejercicio a lo largo del
tiempo.

• Catálogo de ejercicios — más de 140 ejercicios con instrucciones,
grupo muscular trabajado, y tips para ejecutarlos bien.

• Integración con Salud — importa tu peso, altura, fecha de nacimiento
y sexo biológico automáticamente desde la app Salud (opcional, y de
solo lectura — Watt + Weight nunca escribe datos de vuelta a Salud).

• Perfil completo y editable — sexo, altura y peso editables en
cualquier momento, con soporte para sistema métrico (kg/cm) o imperial
(lbs/pies).

• Multi-idioma — disponible en español, inglés y francés.

• 100% privado — todos tus datos se guardan únicamente en tu
dispositivo. Sin cuentas, sin anuncios, sin backend, sin analítica de
terceros.

Empieza hoy tu rutina de fuerza con Watt + Weight.

## Palabras clave
(máx. 100 caracteres, separadas por coma — sin espacios después de la coma)

gimnasio,rutina,fuerza,entrenamiento,fitness,pesas,musculo,workout,salud,ejercicio

## Categoría primaria
Salud y forma física (Health & Fitness)

## Categoría secundaria
Deportes (Sports) — opcional, dejar en blanco si App Store Connect solo permite una

## Contacto de soporte (URL o email)
ldiego900@gmail.com

## URL de política de privacidad
(completar con la URL de GitHub Pages una vez publicada — ver checklist, Task 5)

## Nota para el equipo de revisión de Apple
(campo "Notes" en App Store Connect, no visible al público)

Watt + Weight es una app completamente local: no tiene servidor propio,
no envía datos a ningún backend, y no usa SDKs de analítica de
terceros. El permiso de HealthKit se usa únicamente para LEER peso,
altura, fecha de nacimiento y sexo biológico al importar datos de
Salud — la app nunca escribe datos de vuelta a Salud
(`NSHealthUpdateUsageDescription` está declarado por requisito de
Apple, pero no hay ningún write real en el código). El permiso de
cámara se usa únicamente para la foto de perfil, guardada como `Data`
local en el dispositivo del usuario. No se requiere ninguna cuenta de
prueba — todas las funciones son accesibles creando un perfil local
directamente en la app, sin login.
```

- [ ] **Step 2: Commit**

```bash
git add docs/app-store/listing-es.md
git commit -m "Agrega texto de ficha de App Store Connect (borrador)"
```

---

### Task 4: Capturas de pantalla

**Files:**
- Create: `docs/app-store/screenshots/01-dashboard.png`
- Create: `docs/app-store/screenshots/02-rutina.png`
- Create: `docs/app-store/screenshots/03-ejercicios.png`
- Create: `docs/app-store/screenshots/04-sesion-guiada.png`
- Create: `docs/app-store/screenshots/05-perfil.png`

Este task requiere interacción en vivo — el problema de inyección de
taps documentado en este entorno impide navegar la app de punta a punta
de forma automática. El controlador (quien ejecuta este plan) debe:

- [ ] **Step 1: Build + instalación limpia en el simulador de iPhone 17 Pro Max (6.9")**

```bash
xcrun simctl boot 69C8C09B-CE31-4403-A43F-7CDACCA86CB5
xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
xcrun simctl uninstall 69C8C09B-CE31-4403-A43F-7CDACCA86CB5 com.BERNU.WattWeight
```
Instalar y lanzar el build resultante (ruta impresa por el build) en ese simulador. Si ese UDID ya no existe en este entorno (simuladores disponibles cambian con el tiempo), correr `xcrun simctl list devices | grep "iPhone.*Pro Max"` y usar el UDID de un iPhone Pro Max disponible en su lugar — debe ser un modelo con pantalla de 6.9" (resolución nativa 1320×2868), no un iPhone estándar más chico.

- [ ] **Step 2: Poblar datos de ejemplo**

Crear un perfil con datos representativos (nombre, nivel, objetivo,
altura/peso), generar una rutina automática, y completar al menos 2-3
sesiones de entrenamiento en días distintos (para que el Dashboard
muestre racha, volumen y una gráfica de progreso con datos reales, no
vacía). Dado el problema de tap-injection, esto se hace con el usuario
interactuando directamente en el panel del simulador — el controlador
no debe intentar automatizar esta parte con taps.

- [ ] **Step 3: Capturar las 5 pantallas**

Con los datos de ejemplo ya cargados, navegar (el usuario, en vivo) a
cada pantalla y usar la herramienta de captura del simulador en cada
una:
1. Dashboard (con racha, volumen, gráfica de progreso visibles).
2. Tab Rutina (con la rutina activa y sus días).
3. Catálogo de ejercicios (lista con filtros visibles).
4. Sesión guiada de entrenamiento (un set activo, cronómetro corriendo
   o el botón "Empezar set" visible).
5. Perfil (con foto de perfil y los campos de datos físicos editables
   visibles).

Guardar cada captura en `docs/app-store/screenshots/` con los nombres
exactos listados arriba.

- [ ] **Step 4: Verificar el tamaño de cada captura**

Run: `sips -g pixelWidth -g pixelHeight docs/app-store/screenshots/*.png`
Expected: `pixelWidth: 1320` y `pixelHeight: 2868` para cada una de las 5
imágenes (resolución nativa del iPhone 17 Pro Max en portrait, el
tamaño de 6.9" que Apple exige como mínimo obligatorio). Si algún
archivo no coincide, fue capturado en un dispositivo distinto —
repetir la captura de ese archivo en el simulador correcto.

- [ ] **Step 5: Commit**

```bash
git add docs/app-store/screenshots/
git commit -m "Agrega capturas de pantalla para la ficha de App Store"
```

---

### Task 5: Checklist manual de envío (documentación final)

**Files:**
- Create: `docs/app-store/submission-checklist.md`

- [ ] **Step 1: Escribir el checklist completo**

```markdown
# Checklist de envío a App Store — Watt + Weight

Estos pasos requieren tu sesión de Apple ID / GitHub y no se pueden
automatizar — hazlos en este orden.

- [ ] 1. En GitHub, ve a Settings → Pages del repo, y habilita "Pages"
      sirviendo desde la carpeta `docs/` de la rama `main`. Confirma la
      URL resultante (algo como
      `https://loradi.github.io/IronPulse/privacy-policy`).
- [ ] 2. En [App Store Connect](https://appstoreconnect.apple.com), crea
      un nuevo registro de app:
      - Nombre: Watt + Weight
      - Bundle ID: com.BERNU.WattWeight
      - SKU: el que prefieras (ej. `wattweight-001`)
      - Idioma principal: Español
- [ ] 3. Completa la ficha con el contenido de
      `docs/app-store/listing-es.md` (subtítulo, descripción, palabras
      clave, categoría, contacto de soporte).
- [ ] 4. Pega la URL de la política de privacidad (del paso 1) en el
      campo correspondiente de App Store Connect.
- [ ] 5. Sube las 5 capturas de `docs/app-store/screenshots/` en la
      sección de capturas de pantalla de iPhone.
- [ ] 6. En Xcode, selecciona el esquema de dispositivo genérico ("Any
      iOS Device"), y ve a Product → Archive.
- [ ] 7. Cuando termine el archivo, usa el botón "Distribute App" del
      Organizer de Xcode → "App Store Connect" → sigue el asistente
      para subir el build.
- [ ] 8. En App Store Connect, ve a la sección TestFlight de la app y
      confirma que el build recién subido aparece (puede tardar unos
      minutos en procesarse).
- [ ] 9. Crea un grupo de prueba interno en TestFlight, agrégate a ti
      mismo (u otros testers), y prueba el build instalado vía
      TestFlight en un dispositivo real.
- [ ] 10. Cuando estés conforme con las pruebas, en la sección
       "App Store" de App Store Connect selecciona el build subido,
       pega la nota para el equipo de revisión (del archivo
       `docs/app-store/listing-es.md`), y envía a revisión.
```

- [ ] **Step 2: Commit**

```bash
git add docs/app-store/submission-checklist.md
git commit -m "Agrega checklist manual de envio a App Store"
```
