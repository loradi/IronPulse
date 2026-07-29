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
