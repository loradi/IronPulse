# Perfil editable + sistema de unidades

## Contexto

Tras revisar la app en el simulador, el usuario reportó 7 items entre bugs
y features nuevas, repartidos en dos pantallas: `ProfileDetailView` y
`ActiveWorkoutView`/`DashboardView`. Son dos subsistemas independientes —
esta spec cubre solo el primero (edición de perfil); el rediseño de la
sesión activa de entrenamiento queda como spec propio, después.

Hoy, en la sección "Datos fisicos" de `ProfileDetailView` (dentro de
`ContentView.swift`), Sexo/Altura/Peso se muestran con `LabeledContent`
— de solo lectura. Además:

- **Altura y Peso** ya viven en `UserProfile` (`heightCm`, `weightKg`),
  pero no hay forma de editarlos a mano.
- **Sexo** no vive en `UserProfile` en absoluto — solo existe en
  `HealthSnapshot.biologicalSex`, que se llena únicamente al importar
  datos de Salud (HealthKit). No hay hoy ningún campo editable a mano
  para esto.

Durante el brainstorm el usuario pidió además soporte de sistema de
unidades (kg/lbs, cm/pies), aplicado a toda la app — no solo al perfil.

## Decisiones (con el usuario, 2026-07-29)

- **Sexo**: se agrega como campo propio y editable de `UserProfile`
  (`biologicalSex: BiologicalSex`), independiente del
  `HealthSnapshot.biologicalSex` importado de Salud. Ninguno sobreescribe
  al otro automáticamente.
- **Altura/Peso**: edición vía `TextField` numérico decimal (mismo patrón
  que el campo Peso en `ActiveWorkoutView`), no Stepper.
- **Sistema de unidades**: alcance completo — aplica en perfil, registro
  de entrenamiento (`ActiveWorkoutView`) y gráficas
  (`DashboardView`, `ExerciseProgressView`). El almacenamiento interno
  **siempre** sigue en kg/cm (sin cambios en `SetLog`, `HealthSnapshot`,
  ni en ningún modelo existente) — la conversión ocurre solo en la capa de
  presentación.
- **Altura en imperial**: formato pies+pulgadas (`5'9"`), no pies
  decimales.
- **Input de altura en imperial**: dos campos separados (pies, pulgadas),
  no un solo TextField parseando el formato completo.
- **Peso**: siempre 1 decimal, sea kg o lbs.

## Modelo de datos

`IronPulse/Models/UserProfile.swift`: agregar
`var biologicalSex: BiologicalSex = .notSet` (sin migración real, mismo
patrón que otros campos opcionales agregados antes — ver
`photoData: Data?`). Se agrega también al `init`, con default `.notSet`.

`BiologicalSex` ya existe en `IronPulse/Models/ProfileEnums.swift` (4
casos: `.notSet/.female/.male/.other`) y ya está localizado — se reusa
tal cual, sin cambios.

## Sistema de unidades (nuevo)

Nuevo archivo `IronPulse/Models/UnitSystem.swift`:

```swift
enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    static var current: UnitSystem {
        UnitSystem(rawValue: UserDefaults.standard.string(forKey: "unitSystem") ?? "") ?? .metric
    }

    var displayName: String {
        switch self {
        case .metric:
            return String(localized: "unit_system.metric", defaultValue: "Metrico (kg/cm)", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .imperial:
            return String(localized: "unit_system.imperial", defaultValue: "Imperial (lbs/ft)", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }
}

extension UnitSystem {
    static func kgToLbs(_ kg: Double) -> Double { kg * 2.2046226218 }
    static func lbsToKg(_ lbs: Double) -> Double { lbs / 2.2046226218 }

    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int((totalInches - Double(feet) * 12).rounded())
        return inches == 12 ? (feet + 1, 0) : (feet, inches)
    }

    static func feetInchesToCm(feet: Int, inches: Int) -> Double {
        (Double(feet) * 12 + Double(inches)) * 2.54
    }

    static func formattedWeight(_ kg: Double, system: UnitSystem) -> String {
        let value = system == .metric ? kg : kgToLbs(kg)
        let suffix = system == .metric ? "kg" : "lbs"
        return value.formatted(.number.precision(.fractionLength(1))) + " " + suffix
    }

    static func formattedHeight(_ cm: Double, system: UnitSystem) -> String {
        switch system {
        case .metric:
            return cm.formatted(.number.precision(.fractionLength(0...1))) + " cm"
        case .imperial:
            let (feet, inches) = cmToFeetInches(cm)
            return "\(feet)'\(inches)\""
        }
    }
}
```

Sigue el mismo patrón que `AppLanguage` (`@AppStorage("unitSystem")` +
`.current` estático leyendo `UserDefaults`), no un `@Observable` ni
singleton con estado.

## Pantallas afectadas

### `ProfileDetailView` (dentro de `ContentView.swift`)

Sección "Datos fisicos":

- `LabeledContent("Sexo", ...)` → `Picker("Sexo", selection: $profile.biologicalSex)`
  con `BiologicalSex.allCases`, mismo patrón que los Pickers de
  Nivel/Objetivo ya existentes ahí mismo.
- `LabeledContent("Altura", ...)` → si `UnitSystem.current == .metric`,
  un `TextField` decimal (cm); si `.imperial`, dos `TextField` numéricos
  enteros (pies, pulgadas, con `.keyboardType(.numberPad)`) — ambos
  escriben a `profile.heightCm` vía conversión, nunca guardan pies/pulgadas
  por separado.
- `LabeledContent("Peso", ...)` → `TextField` decimal, sufijo según
  `UnitSystem.current`, convierte a kg antes de escribir en
  `profile.weightKg`.
- Rango de validación (en cm/kg, independiente del sistema mostrado):
  Altura 100–250 cm, Peso 30–300 kg.

Sección "Ajustes": nuevo `Picker("Sistema de unidades", selection: $unitSystemRaw)`
con `@AppStorage("unitSystem")`, junto al Picker de Idioma ya existente.

### `ActiveWorkoutView`

- El campo Peso por set (`TextField("Peso", value: bindingForWeight(set), format: .number)`)
  muestra/acepta el valor en el sistema activo — el binding convierte
  a/desde kg al leer/escribir `set.weightKg` (que sigue almacenando
  siempre en kg).
- La etiqueta "Session Volume" (`sessionVolumeKg`) se formatea con
  `UnitSystem.formattedWeight`.

### `DashboardView`

- Métrica "Volumen" (`WorkoutStatsService.totalVolumeKg`) y "Masa magra"
  (`leanMassCard`) se formatean con `UnitSystem.formattedWeight`.

### `ExerciseProgressView`

- El gráfico de peso máximo por sesión (`maxWeightKg`) convierte sus
  valores plotted al sistema activo antes de pasarlos a `LineMark`/`PointMark`
  (para que el eje Y muestre números correctos en el sistema elegido, no
  solo la etiqueta).

## i18n

Nuevas claves en `Localizable.xcstrings` (es/en/fr), siguiendo el patrón
existente (`String(localized:defaultValue:bundle:locale:)`):

- `unit_system.metric` / `unit_system.imperial`
- Etiquetas de campo que hoy están hardcodeadas y ni siquiera están en el
  catálogo: "Sexo" → `profile.field_sex`, "Altura" → `profile.field_height`,
  "Peso" → `profile.field_weight`, "Sistema de unidades" →
  `profile.unit_system_label`.
- "kg"/"lbs" no necesitan traducción (son unidades, iguales en los 3
  idiomas) — se usan literales, no van al catálogo.

## Testing

- `UnitSystemTests.swift` (nuevo): XCTest puros sobre las funciones de
  conversión — `kgToLbs`/`lbsToKg` en un valor conocido (ej. 100kg ≈
  220.5lbs), `cmToFeetInches`/`feetInchesToCm` en un valor conocido (ej.
  175cm ≈ 5'9"), incluyendo el caso borde de redondeo a 12 pulgadas
  (`cmToFeetInches` debe subir el pie, no devolver "5'12\"").
- `ProfileEditingTests.swift` (nuevo o extendiendo un archivo existente
  de tests de perfil si lo hay): verifica que asignar
  `profile.biologicalSex` persiste y que es independiente de
  `HealthSnapshot.biologicalSex`.
- Resto (edición en vivo de los campos, toggle de unidades reflejado en
  las 4 pantallas) se verifica en simulador — mismo patrón que el resto
  del proyecto.

## Fuera de alcance

- Rediseño de la sesión activa de entrenamiento (items 2-7 del reporte
  original del usuario: cierre automático de rutina del día, auto-guardar
  y volver al Dashboard al terminar, bloqueo de completar sin reps/peso,
  editar cantidad de sets, ícono de info del ejercicio, cronómetro por
  set) — spec propio, después de este.
- GIFs de ejercicios — descartado explícitamente por el usuario, se queda
  el ícono placeholder actual.
- Cualquier otro campo de `HealthSnapshot` (masa magra, pasos, energía
  activa, etc.) — no se tocan, siguen siendo solo-lectura, importados de
  Salud.
