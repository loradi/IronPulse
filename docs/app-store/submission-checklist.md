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
      clave, categoría, contacto de soporte). Opcionalmente, agrega
      localizaciones adicionales en App Store Connect ("Add
      Localization") usando `docs/app-store/listing-en.md` (English) y
      `docs/app-store/listing-fr.md` (Français) — la app ya soporta
      es/en/fr en el catálogo de ejercicios y el resto de la interfaz.
- [ ] 4. Pega la URL de la política de privacidad (del paso 1) en el
      campo correspondiente de App Store Connect.
- [ ] 5. Sube las 5 capturas de `docs/app-store/screenshots/` en la
      sección de capturas de pantalla de iPhone.
- [ ] 6. En la sección "App Privacy" (Privacidad de la app) de la
      ficha, completa el cuestionario de recopilación de datos.
      Selecciona "Data Not Collected" ("No se recopilan datos"): la app
      no envía datos personales del usuario a servidores externos; la
      única llamada de red que hace es para descargar imágenes de
      demostración de ejercicios desde una base de datos pública en
      GitHub, y no incluye datos del usuario.
- [ ] 7. Completa el cuestionario de "Clasificación por edad" (Age
      Rating). La app no tiene contenido generado por usuarios,
      violencia, ni contenido objetable, así que selecciona "Ninguno"
      en todas las categorías.
- [ ] 8. En la sección "Precios y disponibilidad", configura el precio
      como Gratis y selecciona los territorios donde quieres publicar
      la app.
- [ ] 9. En Xcode, selecciona el esquema de dispositivo genérico ("Any
      iOS Device"), y ve a Product → Archive.
- [ ] 10. Cuando termine el archivo, usa el botón "Distribute App" del
       Organizer de Xcode → "App Store Connect" → sigue el asistente
       para subir el build.
- [ ] 11. Durante el asistente de subida del paso anterior, Xcode/App
       Store Connect te preguntará sobre cumplimiento de exportación
       (export compliance). Como la app solo usa HTTPS estándar, esto
       califica como exento: responde "No" o selecciona la exención
       estándar, sin necesitar un documento de cumplimiento de
       exportación.
- [ ] 12. En App Store Connect, ve a la sección TestFlight de la app y
       confirma que el build recién subido aparece (puede tardar unos
       minutos en procesarse).
- [ ] 13. Crea un grupo de prueba interno en TestFlight, agrégate a ti
       mismo (u otros testers), y prueba el build instalado vía
       TestFlight en un dispositivo real.
- [ ] 14. Cuando estés conforme con las pruebas, en la sección
       "App Store" de App Store Connect selecciona el build subido,
       pega la nota para el equipo de revisión (del archivo
       `docs/app-store/listing-es.md`), y envía a revisión.
