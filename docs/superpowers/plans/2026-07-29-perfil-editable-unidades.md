# Perfil Editable + Sistema de Unidades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer editables Sexo/Altura/Peso en el perfil del usuario y agregar un sistema de unidades (métrico/imperial) que se refleje en perfil, sesión activa de entrenamiento y gráficas.

**Architecture:** Un nuevo enum `UnitSystem` (mismo patrón que `AppLanguage`, `@AppStorage` + `.current` estático) provee las conversiones puras kg↔lbs y cm↔pies/pulgadas. El almacenamiento interno de todos los modelos (`UserProfile.heightCm/weightKg`, `SetLog.weightKg`, `HealthSnapshot.leanBodyMassKg`) sigue siempre en kg/cm — la conversión ocurre solo en la capa de presentación (las vistas leen `UnitSystem.current` y formatean/convierten al mostrar o al escribir un valor ingresado por el usuario). `UserProfile` gana un campo propio `biologicalSex`, independiente del que ya existe en `HealthSnapshot` (importado de Salud).

**Tech Stack:** SwiftUI, SwiftData, XCTest. Cero dependencias externas.

## Global Constraints

- Cero dependencias externas — todo con Foundation/SwiftUI/SwiftData estándar.
- iOS 17+.
- El almacenamiento interno de peso y altura permanece siempre en kg/cm — ningún modelo (`UserProfile`, `SetLog`, `HealthSnapshot`) cambia sus unidades de almacenamiento.
- Todo string nuevo visible al usuario usa el patrón ya establecido: `String(localized: "clave", defaultValue: "Texto es", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)`, con la clave agregada a `IronPulse/Localizable.xcstrings` en es/en/fr (`"extractionState": "manual"`).
- Las unidades "kg"/"lbs" son literales, no se traducen (iguales en los 3 idiomas) — no van al catálogo.
- Peso se muestra siempre con 1 decimal, en cualquier unidad.
- Cualquier test que lea/escriba `UserDefaults` debe restaurar el valor original en un `defer` (patrón ya usado en `AppLanguageBundleTests.swift`).

---

### Task 1: UnitSystem — modelo y conversiones

**Files:**
- Create: `IronPulse/Models/UnitSystem.swift`
- Test: `IronPulseTests/UnitSystemTests.swift`

**Interfaces:**
- Produces: `enum UnitSystem: String, CaseIterable, Identifiable { case metric, imperial }`, `UnitSystem.current: UnitSystem` (static, lee `UserDefaults.standard.string(forKey: "unitSystem")`, default `.metric`), `UnitSystem.displayName: String`, `UnitSystem.kgToLbs(_ kg: Double) -> Double`, `UnitSystem.lbsToKg(_ lbs: Double) -> Double`, `UnitSystem.cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Int)`, `UnitSystem.feetInchesToCm(feet: Int, inches: Int) -> Double`, `UnitSystem.formattedWeight(_ kg: Double, system: UnitSystem) -> String`, `UnitSystem.formattedHeight(_ cm: Double, system: UnitSystem) -> String`. Todas las funciones de conversión son `static`, sin estado. Tasks 3-6 consumen todo esto.

- [ ] **Step 1: Escribir los tests (deben fallar — `UnitSystem` no existe aún)**

```swift
import XCTest
@testable import IronPulse

final class UnitSystemTests: XCTestCase {
    func testKgToLbsConvierteCorrectamente() {
        XCTAssertEqual(UnitSystem.kgToLbs(100), 220.462, accuracy: 0.001)
    }

    func testLbsToKgConvierteCorrectamente() {
        XCTAssertEqual(UnitSystem.lbsToKg(220.462), 100, accuracy: 0.001)
    }

    func testCmToFeetInchesConvierteCorrectamente() {
        let result = UnitSystem.cmToFeetInches(175)
        XCTAssertEqual(result.feet, 5)
        XCTAssertEqual(result.inches, 9)
    }

    func testCmToFeetInchesRedondeaAlPieSiguienteEnElLimiteDe12Pulgadas() {
        // 71.6 pulgadas totales = 5 pies + 11.6" -> redondea a 12" -> debe subir a 6 pies, 0"
        let result = UnitSystem.cmToFeetInches(181.864)
        XCTAssertEqual(result.feet, 6)
        XCTAssertEqual(result.inches, 0)
    }

    func testFeetInchesToCmConvierteCorrectamente() {
        XCTAssertEqual(UnitSystem.feetInchesToCm(feet: 5, inches: 9), 175.26, accuracy: 0.01)
    }

    func testFormattedWeightEnMetricoUsaKgConUnDecimal() {
        XCTAssertEqual(UnitSystem.formattedWeight(68.34, system: .metric), "68.3 kg")
    }

    func testFormattedWeightEnImperialConvierteAyMuestraLbs() {
        XCTAssertEqual(UnitSystem.formattedWeight(100, system: .imperial), "220.5 lbs")
    }

    func testFormattedHeightEnMetricoUsaCm() {
        XCTAssertEqual(UnitSystem.formattedHeight(175, system: .metric), "175 cm")
    }

    func testFormattedHeightEnImperialUsaPiesYPulgadas() {
        XCTAssertEqual(UnitSystem.formattedHeight(175, system: .imperial), "5'9\"")
    }

    func testCurrentSinValorGuardadoDevuelveMetrico() {
        let original = UserDefaults.standard.string(forKey: "unitSystem")
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: "unitSystem")
            } else {
                UserDefaults.standard.removeObject(forKey: "unitSystem")
            }
        }
        UserDefaults.standard.removeObject(forKey: "unitSystem")
        XCTAssertEqual(UnitSystem.current, .metric)
    }

    func testCurrentConValorGuardadoDevuelveElValorGuardado() {
        let original = UserDefaults.standard.string(forKey: "unitSystem")
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: "unitSystem")
            } else {
                UserDefaults.standard.removeObject(forKey: "unitSystem")
            }
        }
        UserDefaults.standard.set("imperial", forKey: "unitSystem")
        XCTAssertEqual(UnitSystem.current, .imperial)
    }
}
```

- [ ] **Step 2: Correr los tests, confirmar que fallan**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/UnitSystemTests`
Expected: FAIL — "Cannot find 'UnitSystem' in scope"

- [ ] **Step 3: Implementar `UnitSystem.swift`**

```swift
import Foundation

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
            return String(localized: "unit_system.imperial", defaultValue: "Imperial (lbs/pies)", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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

- [ ] **Step 4: Correr los tests, confirmar que pasan**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/UnitSystemTests`
Expected: PASS, 11/11

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Models/UnitSystem.swift IronPulseTests/UnitSystemTests.swift
git commit -m "Agrega UnitSystem: conversiones kg/lbs y cm/pies-pulgadas"
```

---

### Task 2: UserProfile.biologicalSex

**Files:**
- Modify: `IronPulse/Models/UserProfile.swift`
- Test: `IronPulseTests/UserProfileTests.swift` (nuevo)

**Interfaces:**
- Consumes: `BiologicalSex` (ya existe en `IronPulse/Models/ProfileEnums.swift`, casos `.notSet/.female/.male/.other`).
- Produces: `UserProfile.biologicalSex: BiologicalSex` (propiedad `@Model` nueva, default `.notSet`). Task 3 la consume directo vía `$profile.biologicalSex`.

- [ ] **Step 1: Escribir el test (debe fallar — el campo no existe aún)**

```swift
import XCTest
import SwiftData
@testable import IronPulse

final class UserProfileTests: XCTestCase {
    @MainActor
    func testBiologicalSexPorDefectoEsNotSet() {
        let profile = UserProfile(name: "Test", age: 30, weightKg: 70, heightCm: 170)
        XCTAssertEqual(profile.biologicalSex, .notSet)
    }

    @MainActor
    func testBiologicalSexEsIndependienteDelDeHealthSnapshot() {
        let profile = UserProfile(name: "Test", age: 30, weightKg: 70, heightCm: 170)
        profile.biologicalSex = .female

        let snapshot = HealthSnapshot(biologicalSex: .male, profile: profile)
        profile.healthSnapshots.append(snapshot)

        XCTAssertEqual(profile.biologicalSex, .female)
        XCTAssertEqual(profile.healthSnapshots.first?.biologicalSex, .male)
    }
}
```

- [ ] **Step 2: Correr el test, confirmar que falla**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/UserProfileTests`
Expected: FAIL con "value of type 'UserProfile' has no member 'biologicalSex'"

- [ ] **Step 3: Agregar el campo a `UserProfile`**

En `IronPulse/Models/UserProfile.swift`, agregar la propiedad junto a `var preferredEquipment`:

```swift
    var preferredEquipment: [EquipmentType]
    var biologicalSex: BiologicalSex
    var createdAt: Date
```

Y en el `init`, agregar el parámetro con default junto a `preferredEquipment`:

```swift
        preferredEquipment: [EquipmentType] = [.bodyweight],
        biologicalSex: BiologicalSex = .notSet,
        createdAt: Date = Date(),
```

Y la asignación correspondiente en el cuerpo del `init`:

```swift
        self.preferredEquipment = preferredEquipment
        self.biologicalSex = biologicalSex
        self.createdAt = createdAt
```

- [ ] **Step 4: Correr el test, confirmar que pasa**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/UserProfileTests`
Expected: PASS, 2/2

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Models/UserProfile.swift IronPulseTests/UserProfileTests.swift
git commit -m "Agrega UserProfile.biologicalSex, independiente del importado de Salud"
```

---

### Task 3: ProfileDetailView — Sexo/Altura/Peso editables + selector de unidades

**Files:**
- Modify: `IronPulse/ContentView.swift:86-210` (struct `ProfileDetailView`)
- Modify: `IronPulse/Localizable.xcstrings` (6 claves nuevas)

**Interfaces:**
- Consumes: `UnitSystem` (Task 1), `UserProfile.biologicalSex` (Task 2), `BiologicalSex.allCases`/`.displayName` (ya existentes).
- Produces: ninguna interfaz nueva para otras tasks — Tasks 4/5/6 leen `UnitSystem.current` directamente, no dependen de esta UI.

- [ ] **Step 1: Agregar las 6 claves nuevas a `Localizable.xcstrings`**

Abrir `IronPulse/Localizable.xcstrings` (JSON) y agregar estas 6 entradas al objeto `"strings"` (mismo formato que las claves existentes, `"extractionState": "manual"`):

```json
"unit_system.metric": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Metric (kg/cm)" } },
    "es": { "stringUnit": { "state": "translated", "value": "Metrico (kg/cm)" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Métrique (kg/cm)" } }
  }
},
"unit_system.imperial": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Imperial (lbs/ft)" } },
    "es": { "stringUnit": { "state": "translated", "value": "Imperial (lbs/pies)" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Impérial (lbs/pieds)" } }
  }
},
"profile.field_sex": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Sex" } },
    "es": { "stringUnit": { "state": "translated", "value": "Sexo" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Sexe" } }
  }
},
"profile.field_height": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Height" } },
    "es": { "stringUnit": { "state": "translated", "value": "Altura" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Taille" } }
  }
},
"profile.field_weight": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Weight" } },
    "es": { "stringUnit": { "state": "translated", "value": "Peso" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Poids" } }
  }
},
"profile.unit_system_label": {
  "extractionState": "manual",
  "localizations": {
    "en": { "stringUnit": { "state": "translated", "value": "Unit system" } },
    "es": { "stringUnit": { "state": "translated", "value": "Sistema de unidades" } },
    "fr": { "stringUnit": { "state": "translated", "value": "Système d'unités" } }
  }
}
```

Insertarlas como entradas nuevas del diccionario `"strings"` (junto a las demás claves `profile.*` ya existentes), respetando la coma de separación entre entradas JSON. Después de editar, validar que el archivo sigue siendo JSON válido:

```bash
python3 -c "import json; json.load(open('IronPulse/Localizable.xcstrings'))" && echo "JSON valido"
```

- [ ] **Step 2: Reemplazar la sección "Datos fisicos" en `ProfileDetailView`**

En `IronPulse/ContentView.swift`, reemplazar:

```swift
            Section("Datos fisicos") {
                Stepper("\(profile.age) anos", value: $profile.age, in: 14...99)
                LabeledContent("Sexo", value: latestSnapshot?.biologicalSex.displayName ?? BiologicalSex.notSet.displayName)
                LabeledContent("Altura", value: formatted(profile.heightCm, suffix: "cm"))
                LabeledContent("Peso", value: formatted(profile.weightKg, suffix: "kg"))
            }
```

por:

```swift
            Section("Datos fisicos") {
                Stepper("\(profile.age) anos", value: $profile.age, in: 14...99)

                Picker(sexLabel, selection: $profile.biologicalSex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }

                heightField
                weightField
            }
```

- [ ] **Step 3: Agregar el estado y los campos computados**

Agregar junto a `@AppStorage("appLanguage")`:

```swift
    @AppStorage("unitSystem") private var unitSystemRaw: String = UnitSystem.metric.rawValue

    private var unitSystem: UnitSystem {
        UnitSystem(rawValue: unitSystemRaw) ?? .metric
    }
```

Agregar estas propiedades computadas nuevas a `ProfileDetailView` (junto a `daysPerWeekSliderLabel`, antes del cierre de la struct):

```swift
    private var sexLabel: String {
        String(localized: "profile.field_sex", defaultValue: "Sexo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var heightLabel: String {
        String(localized: "profile.field_height", defaultValue: "Altura", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var weightLabel: String {
        String(localized: "profile.field_weight", defaultValue: "Peso", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private var unitSystemLabel: String {
        String(localized: "profile.unit_system_label", defaultValue: "Sistema de unidades", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
    }

    private func clampedHeight(_ cm: Double) -> Double { min(max(cm, 100), 250) }
    private func clampedWeight(_ kg: Double) -> Double { min(max(kg, 30), 300) }

    private var heightCmBinding: Binding<Double> {
        Binding(
            get: { profile.heightCm },
            set: { profile.heightCm = clampedHeight($0) }
        )
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { UnitSystem.cmToFeetInches(profile.heightCm).feet },
            set: { newFeet in
                let inches = UnitSystem.cmToFeetInches(profile.heightCm).inches
                profile.heightCm = clampedHeight(UnitSystem.feetInchesToCm(feet: newFeet, inches: inches))
            }
        )
    }

    private var heightInchesBinding: Binding<Int> {
        Binding(
            get: { UnitSystem.cmToFeetInches(profile.heightCm).inches },
            set: { newInches in
                let feet = UnitSystem.cmToFeetInches(profile.heightCm).feet
                profile.heightCm = clampedHeight(UnitSystem.feetInchesToCm(feet: feet, inches: newInches))
            }
        )
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { unitSystem == .metric ? profile.weightKg : UnitSystem.kgToLbs(profile.weightKg) },
            set: { newValue in
                let kg = unitSystem == .metric ? newValue : UnitSystem.lbsToKg(newValue)
                profile.weightKg = clampedWeight(kg)
            }
        )
    }

    @ViewBuilder
    private var heightField: some View {
        switch unitSystem {
        case .metric:
            HStack {
                Text(heightLabel)
                Spacer()
                TextField(heightLabel, value: heightCmBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("cm").foregroundStyle(Color.ironTextSecondary)
            }
        case .imperial:
            HStack {
                Text(heightLabel)
                Spacer()
                TextField("ft", value: heightFeetBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                Text("'").foregroundStyle(Color.ironTextSecondary)
                TextField("in", value: heightInchesBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                Text("\"").foregroundStyle(Color.ironTextSecondary)
            }
        }
    }

    private var weightField: some View {
        HStack {
            Text(weightLabel)
            Spacer()
            TextField(weightLabel, value: weightBinding, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unitSystem == .metric ? "kg" : "lbs").foregroundStyle(Color.ironTextSecondary)
        }
    }
```

- [ ] **Step 4: Agregar el Picker de sistema de unidades a la sección "Ajustes"**

Reemplazar:

```swift
            Section("Ajustes") {
                Picker("Idioma", selection: $appLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
            }
```

por:

```swift
            Section("Ajustes") {
                Picker("Idioma", selection: $appLanguageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }

                Picker(unitSystemLabel, selection: $unitSystemRaw) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.displayName).tag(system.rawValue)
                    }
                }
            }
```

- [ ] **Step 5: Eliminar el helper `formatted(_:suffix:)` si quedó sin usos**

Buscar otros usos de `formatted(_:suffix:)` en el archivo:

```bash
grep -n "formatted(profile\|private func formatted" IronPulse/ContentView.swift
```

Si el único call site restante era el que se acaba de reemplazar (Altura/Peso), eliminar la función `formatted(_:suffix:)` completa — ya no se usa. Si `latestSnapshot` tampoco se usa en ningún otro lugar del archivo, eliminarla también (verificar con `grep -n "latestSnapshot" IronPulse/ContentView.swift` — si no queda ninguna otra referencia, es código muerto).

- [ ] **Step 6: Compilar y correr toda la suite**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests`
Expected: todos los tests existentes siguen pasando (ninguno debería romperse — este cambio no toca modelos usados por otros tests salvo el campo agregado en Task 2, ya cubierto).

- [ ] **Step 7: Commit**

```bash
git add IronPulse/ContentView.swift IronPulse/Localizable.xcstrings
git commit -m "Hace editables Sexo/Altura/Peso y agrega selector de sistema de unidades"
```

---

### Task 4: ActiveWorkoutView — Peso por set y Session Volume en el sistema activo

**Files:**
- Modify: `IronPulse/Views/Workouts/ActiveWorkoutView.swift`

**Interfaces:**
- Consumes: `UnitSystem.current`, `UnitSystem.kgToLbs`, `UnitSystem.lbsToKg`, `UnitSystem.formattedWeight` (Task 1).

- [ ] **Step 1: Cambiar `bindingForWeight` para que sea consciente del sistema de unidades**

Reemplazar:

```swift
    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(get: { set.weightKg }, set: { set.weightKg = $0 })
    }
```

por:

```swift
    private func bindingForWeight(_ set: SetLog) -> Binding<Double> {
        Binding(
            get: {
                UnitSystem.current == .metric ? set.weightKg : UnitSystem.kgToLbs(set.weightKg)
            },
            set: { newValue in
                set.weightKg = UnitSystem.current == .metric ? newValue : UnitSystem.lbsToKg(newValue)
            }
        )
    }
```

- [ ] **Step 2: Cambiar la etiqueta de unidad junto al TextField de Peso**

Reemplazar:

```swift
                                    HStack(spacing: 4) {
                                        TextField("Peso", value: bindingForWeight(set), format: .number)
                                            .keyboardType(.decimalPad)
                                            .disabled(isReadOnly)
                                            .frame(width: 60)
                                        Text("kg").font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
                                    }
```

por:

```swift
                                    HStack(spacing: 4) {
                                        TextField("Peso", value: bindingForWeight(set), format: .number)
                                            .keyboardType(.decimalPad)
                                            .disabled(isReadOnly)
                                            .frame(width: 60)
                                        Text(UnitSystem.current == .metric ? "kg" : "lbs").font(.wwCaption).foregroundStyle(Color.ironTextSecondary)
                                    }
```

- [ ] **Step 3: Cambiar el valor de Session Volume**

Reemplazar:

```swift
            LabeledProgressBar(
                label: "Session Volume",
                valueText: "\(Int(sessionVolumeKg)) kg",
                progress: 1.0
            )
```

por:

```swift
            LabeledProgressBar(
                label: "Session Volume",
                valueText: UnitSystem.formattedWeight(sessionVolumeKg, system: UnitSystem.current),
                progress: 1.0
            )
```

- [ ] **Step 4: Compilar**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Verificar en simulador**

Con `UserDefaults` `unitSystem` en `"imperial"` (cambiarlo desde el Picker agregado en Task 3), abrir una sesión activa y confirmar: el campo Peso de cada set muestra/acepta libras, la etiqueta dice "lbs", y "Session Volume" se muestra en libras con 1 decimal. Confirmar que el valor guardado en `SetLog.weightKg` sigue en kg (revisar en modo métrico que el número no cambió).

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Views/Workouts/ActiveWorkoutView.swift
git commit -m "ActiveWorkoutView: Peso por set y Session Volume respetan el sistema de unidades"
```

---

### Task 5: DashboardView — Volumen y Masa magra en el sistema activo

**Files:**
- Modify: `IronPulse/Views/Workouts/DashboardView.swift`

**Interfaces:**
- Consumes: `UnitSystem.current`, `UnitSystem.kgToLbs`, `UnitSystem.formattedWeight` (Task 1).

- [ ] **Step 1: Cambiar la métrica "Volumen"**

Reemplazar (dentro de `metricsRow`):

```swift
            metric(String(localized: "dashboard.metric_volumen", defaultValue: "Volumen", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale), "\(Int(WorkoutStatsService.totalVolumeKg(profile.workoutLogs))) kg")
```

por:

```swift
            metric(String(localized: "dashboard.metric_volumen", defaultValue: "Volumen", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale), UnitSystem.formattedWeight(WorkoutStatsService.totalVolumeKg(profile.workoutLogs), system: UnitSystem.current))
```

- [ ] **Step 2: Cambiar `leanMassCard` para convertir al sistema activo**

Reemplazar:

```swift
    @ViewBuilder
    private var leanMassCard: some View {
        if leanMassEntries.count >= 2,
           let firstValue = leanMassEntries.first?.leanBodyMassKg,
           let lastValue = leanMassEntries.last?.leanBodyMassKg {
            let delta = lastValue - firstValue
            VStack(alignment: .leading, spacing: 4) {
                Text("Masa magra").font(.wwHeadline)
                Text(String(format: "%.1f kg (%@%.1fkg desde que empezaste)", lastValue, delta >= 0 ? "+" : "", delta))
                    .font(.wwBody)
                    .foregroundStyle(Color.ironTextSecondary)
            }
            .ironCard()
        }
    }
```

por:

```swift
    @ViewBuilder
    private var leanMassCard: some View {
        if leanMassEntries.count >= 2,
           let firstValue = leanMassEntries.first?.leanBodyMassKg,
           let lastValue = leanMassEntries.last?.leanBodyMassKg {
            let system = UnitSystem.current
            let deltaKg = lastValue - firstValue
            let displayValue = system == .metric ? lastValue : UnitSystem.kgToLbs(lastValue)
            let displayDelta = system == .metric ? deltaKg : UnitSystem.kgToLbs(deltaKg)
            let unitSuffix = system == .metric ? "kg" : "lbs"
            VStack(alignment: .leading, spacing: 4) {
                Text("Masa magra").font(.wwHeadline)
                Text(String(format: "%.1f \(unitSuffix) (%@%.1f\(unitSuffix) desde que empezaste)", displayValue, displayDelta >= 0 ? "+" : "", displayDelta))
                    .font(.wwBody)
                    .foregroundStyle(Color.ironTextSecondary)
            }
            .ironCard()
        }
    }
```

- [ ] **Step 3: Compilar**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Verificar en simulador**

Con un perfil que tenga entrenamientos registrados, cambiar el sistema de unidades a imperial desde el perfil, volver al Dashboard y confirmar que "Volumen" se muestra en lbs con 1 decimal. Si el perfil tiene 2+ `HealthSnapshot` con `leanBodyMassKg`, confirmar que la tarjeta "Masa magra" también convierte tanto el valor como el delta.

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Views/Workouts/DashboardView.swift
git commit -m "DashboardView: Volumen y Masa magra respetan el sistema de unidades"
```

---

### Task 6: ExerciseProgressView — gráfico en el sistema activo

**Files:**
- Modify: `IronPulse/Views/Workouts/ExerciseProgressView.swift`

**Interfaces:**
- Consumes: `UnitSystem.current`, `UnitSystem.kgToLbs` (Task 1).

- [ ] **Step 1: Agregar `displayPoints` convertido y usarlo en el `Chart`**

Reemplazar:

```swift
    private var points: [(date: Date, maxWeightKg: Double)] {
        WorkoutStatsService.progress(for: exercise.id, in: profile.workoutLogs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.name).font(.wwHeadline)

                if points.isEmpty {
                    ContentUnavailableView(
                        "Sin datos todavia",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Todavia no completaste ningun set de este ejercicio.")
                    )
                } else {
                    Chart(points, id: \.date) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.maxWeightKg))
                            .foregroundStyle(Color.ironAccent)
                        PointMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.maxWeightKg))
                            .foregroundStyle(Color.ironAccent)
                    }
```

por:

```swift
    private var points: [(date: Date, maxWeightKg: Double)] {
        WorkoutStatsService.progress(for: exercise.id, in: profile.workoutLogs)
    }

    private var displayPoints: [(date: Date, displayWeight: Double)] {
        let system = UnitSystem.current
        return points.map { point in
            (date: point.date, displayWeight: system == .metric ? point.maxWeightKg : UnitSystem.kgToLbs(point.maxWeightKg))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.name).font(.wwHeadline)

                if points.isEmpty {
                    ContentUnavailableView(
                        "Sin datos todavia",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Todavia no completaste ningun set de este ejercicio.")
                    )
                } else {
                    Chart(displayPoints, id: \.date) { point in
                        LineMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.displayWeight))
                            .foregroundStyle(Color.ironAccent)
                        PointMark(x: .value("Fecha", point.date), y: .value("Peso maximo", point.displayWeight))
                            .foregroundStyle(Color.ironAccent)
                    }
```

- [ ] **Step 2: Compilar**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Verificar en simulador**

Con un ejercicio que tenga progreso registrado, abrir `ExerciseProgressView` en modo métrico y anotar el rango del eje Y; cambiar a imperial y confirmar que el rango del eje Y cambió a valores convertidos (aprox. ×2.20), no solo la etiqueta.

- [ ] **Step 4: Commit**

```bash
git add IronPulse/Views/Workouts/ExerciseProgressView.swift
git commit -m "ExerciseProgressView: grafico de progreso respeta el sistema de unidades"
```

---

### Task 7: Verificación completa en simulador

**Files:** ninguno (solo verificación manual, sin cambios de código)

- [ ] **Step 1: Correr toda la suite de tests**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests -resultBundlePath /tmp/testresults_perfil_unidades.xcresult`

Run: `xcrun xcresulttool get test-results summary --path /tmp/testresults_perfil_unidades.xcresult`
Expected: `"result": "Passed"`, 0 `failedTests`.

- [ ] **Step 2: Recorrido completo en vivo, modo métrico (default)**

Instalar limpio (`xcrun simctl uninstall <device> com.BERNU.WattWeight` antes de reinstalar, por el gotcha de migración de SwiftData ya conocido). Confirmar:
- En Perfil: Sexo (Picker), Altura, Peso son editables y los cambios persisten al navegar fuera y volver.
- Cambiar Altura/Peso a valores fuera de rango (ej. 999 kg) y confirmar que se clampa a 300 kg.
- Iniciar una sesión de entrenamiento, confirmar que el campo Peso por set y "Session Volume" muestran kg.
- En Dashboard, confirmar que "Volumen" muestra kg.

- [ ] **Step 3: Recorrido completo en vivo, modo imperial**

Cambiar el sistema de unidades a Imperial desde Ajustes. Confirmar:
- Altura se edita con dos campos (pies, pulgadas) y persiste correctamente (verificar que el valor en cm subyacente es razonable: ej. 5'9" ≈ 175 cm).
- Peso se muestra y edita en lbs.
- En una sesión activa, el campo Peso por set y "Session Volume" muestran lbs.
- En Dashboard, "Volumen" (y "Masa magra" si hay datos) se muestran en lbs.
- En `ExerciseProgressView` (si hay un ejercicio con progreso), el eje Y del gráfico está en lbs.

- [ ] **Step 4: Confirmar independencia Sexo manual vs. Salud**

Si el simulador tiene datos de Salud disponibles, importar datos de Salud desde el perfil y confirmar que el `Picker` de Sexo (editado a mano antes) no cambia — sigue mostrando el valor que el usuario eligió manualmente.

- [ ] **Step 5: Actualizar PROGRESS.md**

Solo si el usuario lo pide explícitamente en este punto — no agregarlo de forma proactiva.
