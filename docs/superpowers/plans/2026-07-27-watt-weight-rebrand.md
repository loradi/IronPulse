# Rebrand a "Watt + Weight" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Renombrar la app a "Watt + Weight" y aplicar el design system Kinetic Onyx (colores, tipografía, forma, componentes) a las 9 vistas existentes, según `docs/superpowers/specs/2026-07-27-watt-weight-rebrand-design.md`.

**Architecture:** Un layer de tokens en `Theme/CustomColor.swift` (colores planos dark-only + fuentes Inter/JetBrains Mono + constantes de forma/espaciado) + 3 componentes nuevos reutilizables (`TagBadge`, `LabeledProgressBar`, `AvatarPlaceholder`, `MuscleDiagramView`) + una función pura nueva en `WorkoutStatsService` + un campo nuevo opcional en `Exercise`. Todo lo demás es aplicar esos tokens/componentes pantalla por pantalla, sin tocar la arquitectura de tabs ni la lógica de negocio existente.

**Tech Stack:** SwiftUI + SwiftData (iOS 17+), sin dependencias externas. El proyecto usa `PBXFileSystemSynchronizedRootGroup` (Xcode 16): cualquier archivo nuevo colocado bajo `IronPulse/` (Swift, fuentes, assets) se incluye automáticamente en el build — **no hace falta editar `project.pbxproj` para agregar archivos**, solo para bundle id / display name / fuentes registradas (INFOPLIST_KEY_*).

## Global Constraints

- Dark-only: no queda ningún uso de `Color(uiColor: UIColor { traits in ... })` ni de `dynamic(light:dark:)` en `Theme/CustomColor.swift` al terminar.
- Los nombres de los tokens de color existentes (`ironBackground`, `ironCard`, `ironBorder`, `ironTextPrimary`, `ironTextSecondary`, `ironAccent`, `ironDanger`) se mantienen igual — solo cambia su valor hex. Esto significa que la mayoría de las vistas no necesitan tocar sus referencias de color, solo sus fuentes.
- `neonGlow(...)` se elimina por completo (usa `.shadow`, prohibido por el design system: solo bordes, sin sombras). Sus 2 call sites (`CustomColor.swift` interno y `DashboardView.swift:69`) se migran a un cambio de color de borde, no una sombra.
- `.font(.ironTitle)` y `Font.metricDisplay(_:)` se eliminan, reemplazados por los tokens nuevos `.wwDisplay`/`.wwHeadline`/etc. (Task 2).
- Ningún test existente (47 tests en `IronPulseTests`) puede romperse. Correr siempre `xcodebuild test -only-testing:IronPulseTests` (nunca sin ese filtro — el UI test suite tarda 420s).
- Antes de correr en el simulador tras cualquier task que agregue un campo no-opcional a un `@Model` — no aplica en este plan, `Exercise.proTip` es `String?` — no hace falta desinstalar la app del simulador en ningún task de este plan.
- **Simplificación documentada**: `MuscleDiagramView` (Task 5) es un diagrama abstracto de zonas del cuerpo (bloques geométricos simples), no una ilustración anatómica realista ni un par frente/espalda — cubre la intención del mockup (resaltar la zona objetivo) con la complejidad mínima. Ver Task 5 para el mapeo exacto de `MuscleGroup` a zona.
- **Simplificación documentada**: el logo pequeño en headers (`wwLogoMark`) reutiliza la misma imagen 1024×1024 del ícono (círculo + rayo + texto "WATT + WEIGHT"), solo escalada, en vez de un recorte separado sin anillo/texto — evita depender de un recorte manual impreciso de una imagen generada por IA.

---

### Task 1: Identidad de marca — bundle id, display name, App Icon, logo

**Files:**
- Modify: `IronPulse.xcodeproj/project.pbxproj`
- Modify: `IronPulse/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `IronPulse/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- Create: `IronPulse/Assets.xcassets/wwLogoMark.imageset/Contents.json`
- Create: `IronPulse/Assets.xcassets/wwLogoMark.imageset/logo-60.png`, `logo-120.png`, `logo-180.png`

**Interfaces:**
- Produces: `Color("wwLogoMark")`-less usage — se referencia como `Image("wwLogoMark")` desde SwiftUI (usado en Task 9 y Task 10).

- [ ] **Step 1: Generar el PNG del App Icon**

`MOCKUPS/logo/screen.png` ya es 1024×1024 sin canal alpha (verificado con `sips -g pixelWidth -g pixelHeight -g hasAlpha`). Copiarlo tal cual:

```bash
cp MOCKUPS/logo/screen.png IronPulse/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

- [ ] **Step 2: Actualizar `AppIcon.appiconset/Contents.json`**

Reemplazar el archivo completo (los 3 slots de `1024x1024` — `any`, `dark`, `tinted` — apuntan al mismo PNG ya que el diseño ya es full-black; el resto de slots `mac` no se usa en este proyecto iOS-only, pero se mantiene declarado ya que Xcode los ignora sin daño). Escribir:

```json
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

(Se eliminan los slots `mac` del JSON original — este target es iOS-only, `AppIcon.appiconset` no los necesita y su presencia sin archivos asignados generaba advertencias de Xcode.)

- [ ] **Step 3: Generar el logo pequeño para headers (`wwLogoMark`)**

```bash
mkdir -p IronPulse/Assets.xcassets/wwLogoMark.imageset
sips -z 60 60 MOCKUPS/logo/screen.png --out IronPulse/Assets.xcassets/wwLogoMark.imageset/logo-60.png
sips -z 120 120 MOCKUPS/logo/screen.png --out IronPulse/Assets.xcassets/wwLogoMark.imageset/logo-120.png
sips -z 180 180 MOCKUPS/logo/screen.png --out IronPulse/Assets.xcassets/wwLogoMark.imageset/logo-180.png
```

Crear `IronPulse/Assets.xcassets/wwLogoMark.imageset/Contents.json`:

```json
{
  "images" : [
    { "filename" : "logo-60.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "logo-120.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "logo-180.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Cambiar el bundle id del target de app**

En `IronPulse.xcodeproj/project.pbxproj`, reemplazar (con `replace_all`, aparece exactamente 2 veces — Debug y Release del target `IronPulse`, no afecta a `IronPulseTests`/`IronPulseUITests` que tienen su propio sufijo):

Buscar: `PRODUCT_BUNDLE_IDENTIFIER = com.BERNU.IronPulse;`
Reemplazar: `PRODUCT_BUNDLE_IDENTIFIER = com.BERNU.WattWeight;`

- [ ] **Step 5: Nombre visible de la app**

En el mismo archivo, con `replace_all` (aparece 2 veces, Debug y Release del target de app):

Buscar: `INFOPLIST_KEY_NSHealthUpdateUsageDescription = "IRON & PULSE no escribe datos en Salud, solo los lee.";`
Reemplazar:
```
INFOPLIST_KEY_NSHealthUpdateUsageDescription = "IRON & PULSE no escribe datos en Salud, solo los lee.";
				INFOPLIST_KEY_CFBundleDisplayName = "Watt + Weight";
```

- [ ] **Step 6: Verificar que compila**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Esperado: `BUILD SUCCEEDED`. Confirmar visualmente que el nuevo bundle id/nombre no rompen la firma de desarrollo local (Xcode re-firma automáticamente en simulador, no requiere certificado).

- [ ] **Step 7: Commit**

```bash
git add IronPulse.xcodeproj/project.pbxproj IronPulse/Assets.xcassets/AppIcon.appiconset IronPulse/Assets.xcassets/wwLogoMark.imageset
git commit -m "Rebrand: bundle id, nombre visible y app icon a Watt + Weight"
```

---

### Task 2: Theme — colores, forma y espaciado (dark-only)

**Files:**
- Modify: `IronPulse/Theme/CustomColor.swift`
- Modify: `IronPulse/Views/Workouts/DashboardView.swift:69` (único call site de `neonGlow`, fuera de esto no se toca nada más de esta vista en este task)

**Interfaces:**
- Produces: `Color.ironBackground/.ironCard/.ironCardElevated/.ironBorder/.ironTextPrimary/.ironTextSecondary/.ironAccent/.ironDanger` (planos, sin `dynamic`), `enum CornerRadius { card, button, chip }`, `enum Spacing { xs, sm, md, lg }`, `.ironCard()` view modifier (sin sombra).
- Consumes: nada nuevo — reemplaza en el lugar los tokens que ya usan las 9 vistas.

- [ ] **Step 1: Reescribir `CustomColor.swift` (parte de colores/forma, sin fuentes — eso es Task 3)**

Reemplazar el contenido completo del archivo (se mantiene `diasLabel` y el `init(hex:)` tal cual, ya que sirven sin cambios):

```swift
import SwiftUI
import UIKit

func diasLabel(_ count: Int) -> String {
    "\(count) \(count == 1 ? "dia" : "dias")"
}

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&value)

        let alpha: UInt64
        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch sanitizedHex.count {
        case 3:
            alpha = 255
            red = (value >> 8) * 17
            green = (value >> 4 & 0xF) * 17
            blue = (value & 0xF) * 17
        case 6:
            alpha = 255
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
        case 8:
            alpha = value >> 24
            red = value >> 16 & 0xFF
            green = value >> 8 & 0xFF
            blue = value & 0xFF
        default:
            alpha = 255
            red = 0
            green = 0
            blue = 0
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    static let ironAccent = Color(hex: "CAF300")
    static let ironDanger = Color(hex: "FF3300")
    static let neonGreen = ironAccent
    static let neonOrange = ironDanger

    static let ironBackground = Color(hex: "121317")
    static let ironCard = Color(hex: "1E1F23")
    static let ironCardElevated = Color(hex: "292A2E")
    static let ironBorder = Color(hex: "343539")
    static let ironTextPrimary = Color(hex: "E3E2E7")
    static let ironTextSecondary = Color(hex: "9A9E86")
}

enum CornerRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 16
    static let chip: CGFloat = .infinity
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

private struct IronCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(Color.ironCard)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                    .stroke(Color.ironBorder, lineWidth: 1)
            }
    }
}

extension View {
    func ironCard() -> some View {
        modifier(IronCardModifier())
    }
}

struct PrimarySportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wwHeadline)
            .foregroundStyle(Color.ironBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ironAccent.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.button, style: .continuous))
    }
}

enum HapticFeedback {
    static func setCompleted() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
```

(La sección de `Font`/tipografía se agrega en Task 3 — `.wwHeadline` referenciado arriba en `PrimarySportButtonStyle` recién queda resuelto cuando se complete Task 3; **este task compilará con error hasta que Task 3 esté hecho, por eso Task 3 va inmediatamente después y ambos se revisan juntos si hace falta** — ver nota de secuencia al final de este task.)

- [ ] **Step 2: Migrar el único call site de `neonGlow`**

En `IronPulse/Views/Workouts/DashboardView.swift:69`, buscar:

```
Circle().fill(Color.ironAccent).frame(width: 56, height: 56).neonGlow()
```

Reemplazar por (mismo efecto de "destacado" sin sombra — borde extra):

```
Circle().fill(Color.ironAccent).frame(width: 56, height: 56)
    .overlay(Circle().stroke(Color.ironTextPrimary.opacity(0.3), lineWidth: 2))
```

- [ ] **Step 3: Verificar compilación junto con Task 3**

Este task y Task 3 se implementan como una unidad antes de compilar (ambos tocan el mismo archivo y son interdependientes vía `.wwHeadline`). El implementador de Task 2 debe completar también el Step 1 de Task 3 (agregar los tokens de `Font`) antes de intentar compilar, o coordinar con el implementador de Task 3 si se despachan por separado. **Recomendación: despachar Task 2 y Task 3 juntas a un mismo implementador.**

- [ ] **Step 4: Commit**

```bash
git add IronPulse/Theme/CustomColor.swift IronPulse/Views/Workouts/DashboardView.swift
git commit -m "Theme: tokens de color/forma Kinetic Onyx, dark-only, sin sombras"
```

---

### Task 3: Theme — tipografía (Inter + JetBrains Mono)

**Files:**
- Create: `IronPulse/Resources/Fonts/Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-Bold.ttf`, `Inter-ExtraBold.ttf`, `Inter-LICENSE.txt`
- Create: `IronPulse/Resources/Fonts/JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf`, `JetBrainsMono-LICENSE.txt`
- Modify: `IronPulse.xcodeproj/project.pbxproj` (registrar `UIAppFonts`)
- Modify: `IronPulse/Theme/CustomColor.swift` (agregar extension de `Font`, al final del archivo de Task 2)

**Interfaces:**
- Produces: `Font.wwDisplay`, `.wwHeadline`, `.wwTitle3` (títulos de card, ej. "Sesión A"), `.wwBody`, `.wwCaption` (metadata secundaria, mismo tamaño que `.subheadline`), `.wwLabelCaps` (labels en mayúsculas tipo "STREAK"), `.wwDataMono(_ size: CGFloat = 20)` (pesos/reps/timers).

- [ ] **Step 1: Descargar y colocar las fuentes**

```bash
mkdir -p IronPulse/Resources/Fonts
cd /tmp

curl -sL -o inter.zip "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip"
unzip -o -j inter.zip "extras/ttf/Inter-Regular.ttf" "extras/ttf/Inter-Medium.ttf" "extras/ttf/Inter-Bold.ttf" "extras/ttf/Inter-ExtraBold.ttf" -d /tmp/inter-ttf
cp /tmp/inter-ttf/Inter-Regular.ttf /tmp/inter-ttf/Inter-Medium.ttf /tmp/inter-ttf/Inter-Bold.ttf /tmp/inter-ttf/Inter-ExtraBold.ttf "$OLDPWD/IronPulse/Resources/Fonts/"
unzip -p inter.zip "LICENSE.txt" > "$OLDPWD/IronPulse/Resources/Fonts/Inter-LICENSE.txt"

curl -sL -o jbm.zip "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
unzip -o -j jbm.zip "fonts/ttf/JetBrainsMono-Regular.ttf" "fonts/ttf/JetBrainsMono-Medium.ttf" -d /tmp/jbm-ttf
cp /tmp/jbm-ttf/JetBrainsMono-Regular.ttf /tmp/jbm-ttf/JetBrainsMono-Medium.ttf "$OLDPWD/IronPulse/Resources/Fonts/"
unzip -p jbm.zip "OFL.txt" > "$OLDPWD/IronPulse/Resources/Fonts/JetBrainsMono-LICENSE.txt"

cd "$OLDPWD"
ls IronPulse/Resources/Fonts/
```

Esperado: 6 archivos `.ttf` + 2 archivos de licencia listados.

- [ ] **Step 2: Registrar las fuentes en Info.plist vía build settings**

En `IronPulse.xcodeproj/project.pbxproj`, con `replace_all` (aparece 2 veces — Debug y Release del target de app; si Task 1 ya corrió, este string ya incluye la línea de `CFBundleDisplayName` agregada ahí):

Buscar:
```
				INFOPLIST_KEY_CFBundleDisplayName = "Watt + Weight";
```
Reemplazar:
```
				INFOPLIST_KEY_CFBundleDisplayName = "Watt + Weight";
				INFOPLIST_KEY_UIAppFonts = (
					"Inter-Regular.ttf",
					"Inter-Medium.ttf",
					"Inter-Bold.ttf",
					"Inter-ExtraBold.ttf",
					"JetBrainsMono-Regular.ttf",
					"JetBrainsMono-Medium.ttf",
				);
```

Si Task 1 todavía no corrió (se despachó Task 3 antes), buscar en su lugar el ancla de Task 1 Step 5 (`INFOPLIST_KEY_NSHealthUpdateUsageDescription = "IRON & PULSE no escribe datos en Salud, solo los lee.";`) y agregar ambas líneas nuevas (display name + UIAppFonts) juntas.

- [ ] **Step 3: Agregar los tokens de `Font` a `CustomColor.swift`**

Al final del archivo (después de `PrimarySportButtonStyle`, antes de `HapticFeedback`), agregar:

```swift
extension Font {
    static var wwDisplay: Font { .custom("Inter-ExtraBold", size: 32) }
    static var wwHeadline: Font { .custom("Inter-Bold", size: 24) }
    static var wwTitle3: Font { .custom("Inter-Bold", size: 18) }
    static var wwBody: Font { .custom("Inter-Regular", size: 16) }
    static var wwCaption: Font { .custom("Inter-Regular", size: 13) }
    static var wwLabelCaps: Font { .custom("Inter-Bold", size: 12) }

    static func wwDataMono(_ size: CGFloat = 20) -> Font {
        .custom("JetBrainsMono-Medium", size: size)
    }
}
```

- [ ] **Step 4: Reemplazar los 2 usos de `.ironTitle`**

`IronPulse/Views/Workouts/ExerciseProgressView.swift:15`: `Text(exercise.name).font(.ironTitle)` → `Text(exercise.name).font(.wwHeadline)`

`IronPulse/Views/Workouts/DashboardView.swift:61`: `Text(profile.name).font(.ironTitle)` → `Text(profile.name).font(.wwHeadline)`

- [ ] **Step 5: Verificar que compila y que las fuentes cargan**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Esperado: `BUILD SUCCEEDED`. Luego correr en el simulador y confirmar visualmente que el texto usa Inter (más condensada/geométrica que el San Francisco del sistema) en al menos una pantalla — si aparece el system font de fallback, revisar que el nombre PostScript de la fuente (`Inter-Regular` etc.) coincide exactamente con el registrado; usar `po UIFont.familyNames` en el debugger o imprimir `UIFont.fontNames(forFamilyName:)` si hace falta diagnosticar.

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Resources/Fonts IronPulse.xcodeproj/project.pbxproj IronPulse/Theme/CustomColor.swift IronPulse/Views/Workouts/ExerciseProgressView.swift IronPulse/Views/Workouts/DashboardView.swift
git commit -m "Theme: bundlea Inter + JetBrains Mono y agrega tokens de Font"
```

---

### Task 4: Componentes compartidos — TagBadge, LabeledProgressBar, AvatarPlaceholder

**Files:**
- Create: `IronPulse/Components/TagBadge.swift`
- Create: `IronPulse/Components/LabeledProgressBar.swift`
- Create: `IronPulse/Components/AvatarPlaceholder.swift`
- Test: `IronPulseTests/AvatarPlaceholderTests.swift` (solo la lógica de iniciales, no la vista)

**Interfaces:**
- Produces: `TagBadge(text: String, color: Color = .ironAccent)`, `LabeledProgressBar(label: String, valueText: String, progress: Double)`, `AvatarPlaceholder(name: String, size: CGFloat = 56)`, `func initials(from name: String) -> String` (función pura, testeable, usada por `AvatarPlaceholder`).

- [ ] **Step 1: `TagBadge`**

```swift
import SwiftUI

struct TagBadge: View {
    let text: String
    var color: Color = .ironAccent

    var body: some View {
        Text(text.uppercased())
            .font(.wwLabelCaps)
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.chip, style: .continuous)
                    .stroke(color, lineWidth: 1)
            }
    }
}
```

- [ ] **Step 2: `LabeledProgressBar`**

```swift
import SwiftUI

struct LabeledProgressBar: View {
    let label: String
    let valueText: String
    /// 0...1
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(label.uppercased())
                    .font(.wwLabelCaps)
                    .foregroundStyle(Color.ironTextSecondary)
                Spacer()
                Text(valueText)
                    .font(.wwDataMono(14))
                    .foregroundStyle(Color.ironAccent)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ironCardElevated)
                    Capsule()
                        .fill(Color.ironAccent)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 8)
        }
    }
}
```

- [ ] **Step 3: `AvatarPlaceholder` + función pura de iniciales**

```swift
import SwiftUI

func initials(from name: String) -> String {
    let words = name
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .prefix(2)

    let letters = words.compactMap { $0.first }
    return letters.isEmpty ? "?" : String(letters).uppercased()
}

struct AvatarPlaceholder: View {
    let name: String
    var size: CGFloat = 56

    var body: some View {
        Circle()
            .fill(Color.ironCardElevated)
            .overlay(Circle().stroke(Color.ironAccent, lineWidth: 2))
            .overlay {
                Text(initials(from: name))
                    .font(.wwHeadline)
                    .foregroundStyle(Color.ironTextPrimary)
            }
            .frame(width: size, height: size)
    }
}
```

- [ ] **Step 4: Test de `initials(from:)`**

```swift
import XCTest
@testable import IronPulse

final class AvatarPlaceholderTests: XCTestCase {
    func testDosPalabrasDevuelveDosIniciales() {
        XCTAssertEqual(initials(from: "Diego Lora"), "DL")
    }

    func testUnaPalabraDevuelveUnaInicial() {
        XCTAssertEqual(initials(from: "Diego"), "D")
    }

    func testNombreVacioDevuelveSignoDePregunta() {
        XCTAssertEqual(initials(from: "   "), "?")
    }

    func testTresPalabrasUsaSoloLasDosPrimeras() {
        XCTAssertEqual(initials(from: "Diego Andres Lora"), "DA")
    }
}
```

- [ ] **Step 5: Correr los tests**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IronPulseTests/AvatarPlaceholderTests
```

Esperado: 4/4 tests en verde.

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Components/TagBadge.swift IronPulse/Components/LabeledProgressBar.swift IronPulse/Components/AvatarPlaceholder.swift IronPulseTests/AvatarPlaceholderTests.swift
git commit -m "Agrega componentes compartidos: TagBadge, LabeledProgressBar, AvatarPlaceholder"
```

---

### Task 5: `MuscleDiagramView`

**Files:**
- Create: `IronPulse/Components/MuscleDiagramView.swift`
- Test: `IronPulseTests/MuscleDiagramZoneTests.swift`

**Interfaces:**
- Produces: `MuscleDiagramView(primary: MuscleGroup, secondary: [MuscleGroup])`, `enum DiagramZone: CaseIterable`, `func zones(primary: MuscleGroup, secondary: [MuscleGroup]) -> (highlighted: Set<DiagramZone>, dimmed: Set<DiagramZone>)` (función pura, testeable).
- Consumes: `MuscleGroup` (`IronPulse/Models/ProfileEnums.swift`, 11 casos: `chest, back, legs, shoulders, arms, biceps, triceps, core, glutes, calves, fullBody`).

Es un diagrama abstracto de 5 zonas (hombros, pecho, brazos, core, piernas), no una silueta anatómica realista ni un par frente/espalda — ver "Simplificación documentada" en Global Constraints. Mapeo fijo de los 11 `MuscleGroup` a las 5 zonas:

| MuscleGroup | Zona |
|---|---|
| `.shoulders` | `.shoulders` |
| `.chest`, `.back` | `.chest` |
| `.arms`, `.biceps`, `.triceps` | `.arms` |
| `.core` | `.core` |
| `.legs`, `.glutes`, `.calves` | `.legs` |
| `.fullBody` | las 5 a la vez |

- [ ] **Step 1: Escribir el test de zonas primero**

```swift
import XCTest
@testable import IronPulse

final class MuscleDiagramZoneTests: XCTestCase {
    func testPechoResaltaSoloZonaChest() {
        let result = zones(primary: .chest, secondary: [])
        XCTAssertEqual(result.highlighted, [.chest])
        XCTAssertEqual(result.dimmed, [])
    }

    func testEspaldaMapeaAZonaChest() {
        let result = zones(primary: .back, secondary: [])
        XCTAssertEqual(result.highlighted, [.chest])
    }

    func testSecundariosSeAtenuanSinDuplicarLaPrincipal() {
        // press de banca: principal pecho, secundarios triceps + hombros anteriores
        let result = zones(primary: .chest, secondary: [.triceps, .shoulders])
        XCTAssertEqual(result.highlighted, [.chest])
        XCTAssertEqual(result.dimmed, [.arms, .shoulders])
    }

    func testGluteosYPantorrillasMapeanAZonaLegs() {
        XCTAssertEqual(zones(primary: .glutes, secondary: []).highlighted, [.legs])
        XCTAssertEqual(zones(primary: .calves, secondary: []).highlighted, [.legs])
    }

    func testFullBodyResaltaTodasLasZonas() {
        let result = zones(primary: .fullBody, secondary: [])
        XCTAssertEqual(result.highlighted, Set(DiagramZone.allCases))
        XCTAssertEqual(result.dimmed, [])
    }
}
```

- [ ] **Step 2: Correr el test y verificar que falla (no existe `zones` todavia)**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IronPulseTests/MuscleDiagramZoneTests
```

Esperado: FAIL, "cannot find 'zones' in scope".

- [ ] **Step 3: Implementar `MuscleDiagramView.swift`**

```swift
import SwiftUI

enum DiagramZone: CaseIterable {
    case shoulders, chest, arms, core, legs
}

private extension MuscleGroup {
    var diagramZone: DiagramZone {
        switch self {
        case .shoulders: return .shoulders
        case .chest, .back: return .chest
        case .arms, .biceps, .triceps: return .arms
        case .core: return .core
        case .legs, .glutes, .calves: return .legs
        case .fullBody: return .chest // no se usa: fullBody se maneja aparte en zones(primary:secondary:)
        }
    }
}

func zones(primary: MuscleGroup, secondary: [MuscleGroup]) -> (highlighted: Set<DiagramZone>, dimmed: Set<DiagramZone>) {
    if primary == .fullBody {
        return (Set(DiagramZone.allCases), [])
    }
    let highlighted: Set<DiagramZone> = [primary.diagramZone]
    let dimmed = Set(secondary.map(\.diagramZone)).subtracting(highlighted)
    return (highlighted, dimmed)
}

struct MuscleDiagramView: View {
    let primary: MuscleGroup
    let secondary: [MuscleGroup]

    private var computed: (highlighted: Set<DiagramZone>, dimmed: Set<DiagramZone>) {
        zones(primary: primary, secondary: secondary)
    }

    private func color(for zone: DiagramZone) -> Color {
        if computed.highlighted.contains(zone) { return .ironAccent }
        if computed.dimmed.contains(zone) { return .ironTextSecondary }
        return .ironBorder
    }

    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(Color.ironBorder)
                .frame(width: 28, height: 28)

            HStack(spacing: 30) {
                Circle().fill(color(for: .shoulders)).frame(width: 16, height: 16)
                Circle().fill(color(for: .shoulders)).frame(width: 16, height: 16)
            }

            HStack(spacing: 4) {
                Capsule().fill(color(for: .arms)).frame(width: 14, height: 90)

                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: .chest))
                        .frame(width: 44, height: 30)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color(for: .core))
                        .frame(width: 38, height: 24)
                }

                Capsule().fill(color(for: .arms)).frame(width: 14, height: 90)
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color(for: .legs))
                    .frame(width: 20, height: 56)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color(for: .legs))
                    .frame(width: 20, height: 56)
            }
        }
        .frame(width: 120, height: 190)
    }
}
```

- [ ] **Step 4: Correr el test de nuevo**

Mismo comando del Step 2. Esperado: 5/5 en verde.

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Components/MuscleDiagramView.swift IronPulseTests/MuscleDiagramZoneTests.swift
git commit -m "Agrega MuscleDiagramView: diagrama abstracto de zonas musculares"
```

---

### Task 6: `WorkoutStatsService` — tira semanal del Dashboard

**Files:**
- Modify: `IronPulse/Services/WorkoutStatsService.swift`
- Test: `IronPulseTests/WorkoutStatsServiceTests.swift` (agregar casos nuevos al archivo existente)

**Interfaces:**
- Produces: `enum WeekdayStatus: Equatable { case notScheduled, pending, completed }`, `static func weekStrip(scheduledWeekdays: Set<Weekday>, logs: [WorkoutLog], today: Date = Date(), calendar: Calendar = .current) -> [(weekday: Weekday, status: WeekdayStatus, isToday: Bool)]`.
- Consumes: `Weekday` (`Models/ProfileEnums.swift`, ya tiene `.today(calendar:now:)`), `finishedLogs`/privados ya existentes en el archivo.

- [ ] **Step 1: Agregar los tests primero**

Al final de `IronPulseTests/WorkoutStatsServiceTests.swift` (dentro de la clase existente), agregar:

```swift
    func testTiraSemanalMarcaCompletadoPendienteYNoProgramado() {
        // "hoy" fijo: miercoles 2026-07-29 (Weekday.wednesday = 3)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29))!

        let monday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 27))!
        let log = WorkoutLog(
            startDate: monday,
            endDate: monday.addingTimeInterval(3600),
            routineName: "Test",
            dayTitle: "Dia 1"
        )

        let result = WorkoutStatsService.weekStrip(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: [log],
            today: today,
            calendar: calendar
        )

        XCTAssertEqual(result.count, 7)
        XCTAssertEqual(result[0].weekday, .monday)
        XCTAssertEqual(result[0].status, .completed)
        XCTAssertEqual(result[1].status, .notScheduled) // martes, no programado
        XCTAssertEqual(result[2].weekday, .wednesday)
        XCTAssertEqual(result[2].status, .pending) // hoy, programado, sin log
        XCTAssertTrue(result[2].isToday)
        XCTAssertEqual(result[4].weekday, .friday)
        XCTAssertEqual(result[4].status, .pending) // futuro, programado, sin log todavia
        XCTAssertEqual(result[5].status, .notScheduled) // sabado
    }

    func testTiraSemanalSinDiasProgramadosQuedaTodaVacia() {
        let result = WorkoutStatsService.weekStrip(scheduledWeekdays: [], logs: [])
        XCTAssertTrue(result.allSatisfy { $0.status == .notScheduled })
    }
```

- [ ] **Step 2: Correr y verificar que fallan**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IronPulseTests/WorkoutStatsServiceTests
```

- [ ] **Step 3: Implementar `weekStrip` en `WorkoutStatsService.swift`**

Agregar antes del `private static func finishedLogs`:

```swift
    enum WeekdayStatus: Equatable {
        case notScheduled
        case pending
        case completed
    }

    static func weekStrip(
        scheduledWeekdays: Set<Weekday>,
        logs: [WorkoutLog],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [(weekday: Weekday, status: WeekdayStatus, isToday: Bool)] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        let completedDays = Set(finishedLogs(logs).map { calendar.startOfDay(for: $0.startDate) })
        let todayWeekday = Weekday.today(calendar: calendar, now: today)

        let days = (0..<7).compactMap { offset -> (weekday: Weekday, status: WeekdayStatus, isToday: Bool)? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let weekday = Weekday.today(calendar: calendar, now: date)

            guard scheduledWeekdays.contains(weekday) else {
                return (weekday, .notScheduled, weekday == todayWeekday)
            }

            let status: WeekdayStatus = completedDays.contains(calendar.startOfDay(for: date)) ? .completed : .pending
            return (weekday, status, weekday == todayWeekday)
        }

        return days.sorted { $0.weekday.rawValue < $1.weekday.rawValue }
    }

```

- [ ] **Step 4: Correr de nuevo, confirmar verde**

Mismo comando del Step 2.

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/WorkoutStatsService.swift IronPulseTests/WorkoutStatsServiceTests.swift
git commit -m "WorkoutStatsService: agrega weekStrip para la tira semanal del Dashboard"
```

---

### Task 7: `Exercise.proTip` + contenido para las 146 entradas del catálogo

**Files:**
- Modify: `IronPulse/Models/Exercise.swift`
- Modify: `IronPulse/Resources/ExercisesSeed.json`

**Interfaces:**
- Produces: `Exercise.proTip: String?` (nuevo campo opcional, sin migración real — mismo patrón que `gifRemoteURLString`).

- [ ] **Step 1: Agregar el campo al modelo**

En `IronPulse/Models/Exercise.swift`, agregar `var proTip: String?` como último `var` de la clase (después de `isCustom`, línea 15), y `proTip: String? = nil` como último parámetro del `init` (después de `isCustom: Bool = false`, línea 27), con `self.proTip = proTip` como última línea del cuerpo del `init`.

- [ ] **Step 2: Redactar un `proTip` para cada una de las 146 entradas de `ExercisesSeed.json`**

Agregar el campo `"proTip"` a cada objeto del JSON. Requisitos por entrada (no una plantilla genérica por grupo muscular — un tip por ejercicio):
- 1-2 oraciones, en español, mismo tono técnico y directo que las `instructions` existentes del propio ejercicio (leerlas antes de escribir el tip).
- Debe referenciar algo específico y accionable de ESE ejercicio (un cue de forma, un error común a evitar, o un foco de tensión muscular) — no una frase motivacional genérica ni algo que aplicaría igual a cualquier ejercicio del mismo grupo muscular.
- Derivar el contenido de los campos ya existentes de esa entrada (`name`, `muscleGroup`, `secondaryMuscles`, `equipment`, `isCompound`, `instructions`) — son la única fuente de verdad, no inventar datos biomecánicos que las `instructions` no respalden.
- Sin comillas dobles sin escapar dentro del string (JSON válido).

- [ ] **Step 3: Verificar cobertura y unicidad con un script**

```bash
python3 -c "
import json
with open('IronPulse/Resources/ExercisesSeed.json') as f:
    data = json.load(f)
missing = [e['id'] for e in data if not e.get('proTip', '').strip()]
tips = [e['proTip'] for e in data]
duplicates = len(tips) - len(set(tips))
print(f'Total ejercicios: {len(data)}')
print(f'Sin proTip: {len(missing)} {missing[:5]}')
print(f'Tips duplicados: {duplicates}')
"
```

Esperado: `Sin proTip: 0`, `Tips duplicados: 0`, `Total ejercicios: 146`.

- [ ] **Step 4: Verificar que la app sigue seedeando bien el catálogo**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IronPulseTests
```

Esperado: los 47+ tests existentes en verde (ninguno depende de `proTip`, pero confirman que el JSON sigue siendo válido y `ExerciseDatabaseSeeder` sigue funcionando).

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Models/Exercise.swift IronPulse/Resources/ExercisesSeed.json
git commit -m "Agrega Exercise.proTip y redacta un consejo por ejercicio para las 146 entradas del catalogo"
```

---

### Task 8: `DashboardView` — tokens + tira semanal

**Files:**
- Modify: `IronPulse/Views/Workouts/DashboardView.swift`
- Modify: `IronPulse/Models/ProfileEnums.swift` (agregar `Weekday.shortDisplayName`)

**Interfaces:**
- Consumes: `WorkoutStatsService.weekStrip` (Task 6), `Font.wwHeadline/.wwBody/.wwCaption/.wwLabelCaps/.wwDataMono` (Task 3), `Color.iron*` (Task 2, ya resueltos por nombre).

- [ ] **Step 1: Leer el archivo completo actual antes de editar**

`DashboardView.swift` ya tiene `header`, `todaysCard`, `metricsRow`, `progressChart`, `leanMassCard`, `exerciseProgressSection`, `historyLink`. Este task NO cambia su estructura ni su lógica — solo:
1. Reemplaza cada `.font(.headline)` → `.wwHeadline`, `.font(.subheadline)` → `.wwBody`, `.font(.caption)` → `.wwCaption`, `.font(.title3).fontWeight(.black)` (línea del valor de cada métrica en `metricsRow`) → `.font(.wwDataMono(22))`.
2. Agrega una nueva sub-vista `weekStrip` (7 columnas Lun-Dom) entre `header` y `todaysCard`.

- [ ] **Step 2: Agregar la sub-vista de tira semanal**

```swift
    private var weekStrip: some View {
        let statuses = WorkoutStatsService.weekStrip(
            scheduledWeekdays: Set((profile.activeRoutine?.days ?? []).map(\.weekday)),
            logs: profile.workoutLogs
        )

        return HStack(spacing: Spacing.xs) {
            ForEach(statuses, id: \.weekday) { entry in
                VStack(spacing: 4) {
                    Text(entry.weekday.shortDisplayName)
                        .font(.wwLabelCaps)
                        .foregroundStyle(Color.ironTextSecondary)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(entry.status == .completed ? Color.ironAccent : Color.ironCard)
                            .frame(height: 44)

                        if entry.status == .completed {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.ironBackground)
                        } else if entry.status == .pending {
                            Circle()
                                .fill(Color.ironTextSecondary)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .overlay {
                        if entry.isToday {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.ironAccent, lineWidth: 2)
                        }
                    }
                }
            }
        }
    }
```

`profile.activeRoutine?.days` (`UserProfile.activeRoutine`, `Models/UserProfile.swift:26`) y `profile.workoutLogs` (`Models/UserProfile.swift:24`) ya son los nombres reales — es el mismo acceso que ya usa `todaysCard` en este archivo.

`Weekday.displayName` (en `IronPulse/Models/ProfileEnums.swift:208`) devuelve el nombre completo ("Lunes"). Agregar un `shortDisplayName` nuevo junto a `displayName`, mismo patrón `switch self`, 3 letras mayúsculas sin acentos: `.monday → "LUN"`, `.tuesday → "MAR"`, `.wednesday → "MIE"`, `.thursday → "JUE"`, `.friday → "VIE"`, `.saturday → "SAB"`, `.sunday → "DOM"`.

- [ ] **Step 3: Insertar `weekStrip` en el `body`**

Ubicarlo entre `header` y `todaysCard` en el `VStack`/`ScrollView` principal del `body`.

- [ ] **Step 4: Verificar en el simulador**

Correr la app, abrir un perfil con rutina activa, confirmar que la tira semanal muestra check en días completados, punto en el día de hoy si está programado, y celdas vacías en días sin `RoutineDay`. Confirmar que **todos los botones y NavigationLinks del Dashboard siguen respondiendo al toque** (regresión conocida de esta sesión: cualquier `Chart` decorativo debe llevar `.allowsHitTesting(false)` — `weekStrip` no usa `Chart` así que no aplica, pero verificar igual que `progressChart` sigue teniendo el modificador).

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Views/Workouts/DashboardView.swift IronPulse/Models/ProfileEnums.swift
git commit -m "DashboardView: aplica tokens Kinetic Onyx y agrega tira semanal"
```

---

### Task 9: `ExerciseListView` + `ExerciseDetailView` — tokens + badge + diagrama + pro tip

**Files:**
- Modify: `IronPulse/Views/Exercises/ExerciseListView.swift`

**Interfaces:**
- Consumes: `TagBadge`, `MuscleDiagramView` (Task 4/5), `Exercise.proTip` (Task 7), `Image("wwLogoMark")` (Task 1).

- [ ] **Step 1: Tokens generales**

Reemplazar fuentes de sistema por los tokens `.ww*` en ambas vistas del archivo (lista y detalle), mismo criterio que Task 8 Step 1.

- [ ] **Step 2: Logo en el header de la lista**

En `ExerciseListView`, agregar `Image("wwLogoMark").resizable().frame(width: 28, height: 28).clipShape(Circle())` junto al título de la navegación (`.navigationTitle` no soporta vistas custom directamente — usar `.toolbar { ToolbarItem(placement: .principal) { HStack { Image("wwLogoMark")...; Text("Watt + Weight").font(.wwHeadline) } } }` en lugar de `.navigationTitle`, si el mockup lo pide en el header en vez del título nativo).

- [ ] **Step 3: Badge "COMPOUND" en cada fila de la lista**

Dentro del `NavigationLink` que renderiza cada `Exercise` (buscar el `VStack`/`HStack` de cada fila), agregar `if exercise.isCompound { TagBadge(text: "Compound") }` junto al nombre/grupo muscular, replicando la posición del mockup `biblioteca_de_ejercicios` (a la derecha del nombre).

- [ ] **Step 4: `ExerciseDetailView` — badge, diagrama y pro tip**

Dentro del `VStack` existente (después del `GIFImageView`, antes o junto a la línea de `muscleGroup`/`equipment`):

```swift
                if exercise.isCompound {
                    TagBadge(text: "Compound")
                }

                MuscleDiagramView(primary: exercise.muscleGroup, secondary: exercise.secondaryMuscles)
                    .frame(maxWidth: .infinity)

                if let proTip = exercise.proTip {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(Color.ironAccent)
                        Text(proTip)
                            .font(.wwBody)
                            .italic()
                            .foregroundStyle(Color.ironTextPrimary)
                    }
                    .ironCard()
                }
```

- [ ] **Step 5: Verificar en el simulador**

Abrir la lista de ejercicios y el detalle de "Press de Banca" (o cualquier `isCompound == true`): confirmar badge, diagrama con pecho/hombros/tríceps coloreados según corresponda, y la caja de pro tip con el texto redactado en Task 7.

- [ ] **Step 6: Commit**

```bash
git add IronPulse/Views/Exercises/ExerciseListView.swift
git commit -m "ExerciseListView/ExerciseDetailView: tokens, badge Compound, diagrama de musculos y pro tip"
```

---

### Task 10: `ActiveWorkoutView` — tokens + barra de volumen de sesión

**Files:**
- Modify: `IronPulse/Views/Workouts/ActiveWorkoutView.swift`

**Interfaces:**
- Consumes: `LabeledProgressBar` (Task 4), `Image("wwLogoMark")` (Task 1).

- [ ] **Step 1: Tokens generales**

Mismo criterio de reemplazo de fuentes que Task 8 Step 1, sobre las 190 líneas de esta vista.

- [ ] **Step 2: Barra de volumen de sesión**

Calcular `sessionVolumeKg` como la suma de `peso × reps` de los `SetLog` completados de `workoutLog` (el log de la sesión activa, ya disponible en esta vista — reusar el mismo cálculo que `WorkoutStatsService`'s `volumeKg(of:)` privado, duplicando la expresión inline ya que ese helper es privado del service y esto es solo la sesión en curso, no requiere el service completo). Insertar arriba de la lista de ejercicios/sets, debajo del header de duración:

```swift
LabeledProgressBar(
    label: "Session Volume",
    valueText: "\(Int(sessionVolumeKg)) kg",
    progress: min(sessionVolumeKg / max(targetVolumeKg, 1), 1)
)
.ironCard()
```

Si no existe ya un `targetVolumeKg` (volumen objetivo de la sesión) en el modelo/vista actual, usar `progress: 1.0` fijo (barra siempre llena, ya que no hay objetivo real que medir — no inventar un campo de "meta" nuevo solo para esta barra, eso sería agregar alcance fuera de lo pedido en el spec).

- [ ] **Step 3: Verificar en el simulador**

Iniciar una sesión guiada, completar 2-3 sets, confirmar que el número de la barra sube y el fill de la barra avanza (o queda lleno si se usó el `progress: 1.0` fijo).

- [ ] **Step 4: Commit**

```bash
git add IronPulse/Views/Workouts/ActiveWorkoutView.swift
git commit -m "ActiveWorkoutView: aplica tokens y agrega barra de volumen de sesion"
```

---

### Task 11: `ProfileDetailView` — tokens + avatar + slider

**Files:**
- Modify: `IronPulse/ContentView.swift`

**Interfaces:**
- Consumes: `AvatarPlaceholder` (Task 4).

- [ ] **Step 1: Tokens generales**

Mismo criterio que Task 8 Step 1, aplicado a `ContentView` (lista de perfiles) y `ProfileDetailView` (form de ajustes) dentro del mismo archivo. El `navigationTitle("IronPulse")` de `ContentView` (línea 36) pasa a `navigationTitle("Watt + Weight")`.

- [ ] **Step 2: `AvatarPlaceholder` en `ProfileDetailView`**

Al principio del `Form`, agregar una `Section` sin título con `AvatarPlaceholder(name: profile.name, size: 72)` centrado (`HStack { Spacer(); AvatarPlaceholder(...); Spacer() }`), antes de la sección "Perfil".

- [ ] **Step 3: `Stepper` de días/semana → `Slider`**

Reemplazar:
```swift
Stepper("\(diasLabel(profile.workoutDaysPerWeek)) por semana", value: $profile.workoutDaysPerWeek, in: 1...7)
```
por:
```swift
VStack(alignment: .leading) {
    Text(diasLabel(profile.workoutDaysPerWeek) + " por semana")
        .font(.wwBody)
    Slider(
        value: Binding(
            get: { Double(profile.workoutDaysPerWeek) },
            set: { profile.workoutDaysPerWeek = Int($0.rounded()) }
        ),
        in: 1...7,
        step: 1
    )
    .tint(Color.ironAccent)
}
```

- [ ] **Step 4: Verificar en el simulador**

Abrir un perfil, confirmar avatar con iniciales correctas y que el slider mueve `workoutDaysPerWeek` de 1 a 7 correctamente (comparar contra el valor mostrado).

- [ ] **Step 5: Commit**

```bash
git add IronPulse/ContentView.swift
git commit -m "ProfileDetailView/ContentView: tokens, avatar placeholder y slider de dias/semana"
```

---

### Task 12: Resto de pantallas — solo tokens

**Files:**
- Modify: `IronPulse/Views/Workouts/RoutineTabView.swift`
- Modify: `IronPulse/Views/Workouts/RoutineBuilderView.swift`
- Modify: `IronPulse/Views/Workouts/WorkoutHistoryView.swift`
- Modify: `IronPulse/Views/Exercises/ExercisePickerSheet.swift`
- Modify: `IronPulse/Views/Workouts/ExerciseProgressView.swift`
- Modify: `IronPulse/Views/MainTabView.swift`

Ninguna de estas 6 vistas tiene mockup propio ni contenido nuevo — solo se les aplica la regla mecánica de tokens (mismo criterio que Task 8 Step 1), sin tocar su lógica, estructura ni tests:

| Reemplazar | Por |
|---|---|
| `.font(.largeTitle)` / `.font(.title)` | `.font(.wwDisplay)` |
| `.font(.title2)` / `.font(.title3)` | `.font(.wwHeadline)` |
| `.font(.headline)` | `.font(.wwHeadline)` (si es un título de sección/card) o `.font(.wwTitle3)` (si es un título de fila/ítem de lista, más chico que un título de sección) |
| `.font(.subheadline)` / `.font(.body)` | `.font(.wwBody)` |
| `.font(.caption)` / `.font(.caption2)` / `.font(.footnote)` | `.font(.wwCaption)` |
| Cualquier número aislado que represente peso/reps/tiempo (ej. "100 kg", "8 reps", "01:59") | `.font(.wwDataMono(_:))` con el tamaño que ya tuviera |

`ExerciseProgressView.swift` ya tiene su `.font(.ironTitle)` resuelto en Task 3 — en este task solo se tocan sus demás fuentes de sistema, si tiene.

`MainTabView.swift` solo necesita el `.tint(Color.ironAccent)` que ya tiene (sin cambios de color, el nombre del token no cambió) — revisar si algún `Label` de `tabItem` usa `.font()` explícito (no debería, el tab bar usa su fuente de sistema fija de iOS, no se toca).

- [ ] **Step 1: Aplicar la tabla anterior a las 6 vistas**

- [ ] **Step 2: Verificar en el simulador**

Navegar las 6 pantallas, confirmar visualmente que ninguna quedó con texto de tamaño/peso incorrecto ni con la fuente de sistema en vez de Inter.

- [ ] **Step 3: Commit**

```bash
git add IronPulse/Views/Workouts/RoutineTabView.swift IronPulse/Views/Workouts/RoutineBuilderView.swift IronPulse/Views/Workouts/WorkoutHistoryView.swift IronPulse/Views/Exercises/ExercisePickerSheet.swift IronPulse/Views/Workouts/ExerciseProgressView.swift IronPulse/Views/MainTabView.swift
git commit -m "Aplica tokens tipograficos Kinetic Onyx al resto de las vistas"
```

---

### Task 13: Verificación completa en simulador

**Files:** ninguno (solo verificación manual + automatizada)

- [ ] **Step 1: Suite de tests completo**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:IronPulseTests
```

Esperado: todos los tests en verde (47 anteriores + los nuevos de `AvatarPlaceholderTests`, `MuscleDiagramZoneTests`, y los casos nuevos de `WorkoutStatsServiceTests`).

- [ ] **Step 2: Recorrido visual completo**

Correr la app en el simulador y, para cada una de las 9 vistas, comparar contra su mockup (cuando aplica) o simplemente confirmar tokens correctos (cuando no): Dashboard (tira semanal + gráfico), Rutina, Ejercicios (lista + detalle con badge/diagrama/pro tip), Constructor de rutina, Historial, Sesión activa (barra de volumen + auto-avance + descanso — no romper el flujo ya construido en la sesión anterior), Progreso por ejercicio, Perfil (avatar + slider), lista de perfiles. Confirmar también:
- Nombre "Watt + Weight" visible en el home screen del simulador y en el navigation title de la lista de perfiles.
- App Icon nuevo visible (no el ícono genérico gris de Xcode).
- **Ningún botón/NavigationLink queda sin responder al toque** (regresión conocida de la sesión anterior con `Chart` — revisar especialmente `DashboardView` después de agregar `weekStrip`).

- [ ] **Step 3: Actualizar `PROGRESS.md`**

Documentar la tanda completa (rebrand + reskin), igual que se hizo con la tanda de tendencias/sesión guiada: qué se hizo, decisiones clave, cualquier hallazgo del review final, y mover el pendiente #1 de "Siguientes pasos" a completado.

- [ ] **Step 4: Commit**

```bash
git add PROGRESS.md
git commit -m "Documenta el rebrand a Watt + Weight en PROGRESS.md"
```
