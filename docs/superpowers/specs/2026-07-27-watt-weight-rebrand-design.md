# Rebrand a "Watt + Weight" + reskin visual Kinetic Onyx

## Contexto

`MOCKUPS/` contiene un reskin completo generado por IA (paleta, tipografía,
componentes) documentado en `MOCKUPS/kinetic_onyx/DESIGN.md`, más 7 mockups
de pantalla (`biblioteca_de_ejercicios`, `configuraci_n_de_perfil`,
`detalle_de_ejercicio`, `mi_rutina`, `perfil_de_usuario`,
`sesi_n_en_curso`, `sesi_n_en_curso_con_gu_a`) y un logo
(`MOCKUPS/logo/screen.png`, marca "WATT + WEIGHT"). Hasta ahora solo se
había adoptado la estructura de tab bar (Dashboard/Rutina/Ejercicios/
Perfil) de esa referencia; el resto (nombre, colores, tipografía, forma,
contenido nuevo de los mockups) quedó pendiente en `PROGRESS.md` como
"Rebrand visual MOCKUPS/", sin su propio brainstorming.

Esta spec cubre esa vuelta completa: cambio de nombre visible, bundle id,
app icon, y aplicar el design system Kinetic Onyx (colores, tipografía,
espaciado, formas, elevación, componentes) a las 9 vistas existentes de la
app, incluyendo el contenido nuevo que aparece en los mockups cuando es
razonable derivarlo de datos reales.

**Fuera de alcance** (documentado aparte, no tocar acá):
- Selector de idioma / i18n de toda la app.
- Foto de perfil real (subida/almacenamiento/despliegue) — spec futuro
  junto con el idioma.
- `RoutineBuilderView.save()` generando `dayNumber` con huecos — declinado
  explícitamente por el usuario en una sesión anterior.
- Preparación de publicación en App Store (certificados, screenshots,
  privacy manifest, etc.) — pendiente #6 de `PROGRESS.md`, spec propio.

## Decisiones (con el usuario, 2026-07-27)

- **Alcance**: rebrand completo (nombre + reskin), no solo el reskin
  visual.
- **Nombre visible**: solo `CFBundleDisplayName = "Watt + Weight"`. El
  proyecto Xcode, target, scheme, esquema de test y carpetas del repo
  siguen llamándose `IronPulse` — no se renombra nada a nivel de Xcode.
- **Bundle id**: `com.BERNU.IronPulse` → `com.BERNU.WattWeight`. Aún no
  hay ningún registro en App Store Connect, así que este cambio es barato
  ahora y quedaría congelado (no se puede cambiar) una vez publicada la
  app.
- **Modo claro**: se elimina. La app fuerza modo oscuro siempre,
  independiente del ajuste del sistema — Kinetic Onyx está diseñado 100%
  para OLED/negro puro y el mockup nunca definió una variante clara.
- **Tipografía**: se empaquetan `Inter` y `JetBrains Mono` como fuentes
  reales (ambas de licencia libre — SIL OFL y Apache 2.0 respectivamente,
  redistribuibles sin costo). No se aproxima con fuentes del sistema.
- **App Icon**: se genera desde `MOCKUPS/logo/screen.png` (recorte a los
  tamaños de `AppIcon.appiconset`), no se diseña uno nuevo.
- **Fidelidad a mockups**: además del reskin visual, se adopta el
  contenido nuevo que aparece en los mockups cuando es derivable de datos
  ya existentes (badges de `isCompound`, tira semanal desde `WorkoutLog`,
  barra de volumen de sesión, diagrama de músculos, pro tips). Se excluye
  contenido de puro relleno de marketing sin dato real detrás (p. ej.
  "Elite Member", ubicación/"member since" — no existen esos campos ni se
  agregan en esta spec).
- **Foto de perfil**: placeholder visual (iniciales o ícono genérico), sin
  ninguna lógica de carga/almacenamiento — eso es del spec futuro de
  idioma+foto.
- **Arquitectura de tabs**: no se toca. Los mockups a veces combinan
  pantallas de forma distinta a como quedó la navegación real (p. ej.
  `mi_rutina` mezcla Dashboard+Rutina, `perfil_de_usuario` mezcla
  stats+ajustes). Se toma de cada mockup el estilo y el contenido
  derivable, respetando los límites de tab ya construidos y probados.
- **Enfoque de implementación**: tokens de Theme + un puñado de
  componentes reutilizables nuevos, extendiendo el patrón ya existente en
  el código (`.ironCard()`, `PrimarySportButtonStyle`), no una arquitectura
  de componentes nueva.
- **Pro Tip por ejercicio**: campo nuevo `Exercise.proTip: String?`,
  redactado para los 146 ejercicios del catálogo (no un tip genérico por
  grupo muscular).

## Identidad de marca

- `IronPulse.xcodeproj/project.pbxproj`: en las secciones de build config
  del target de app (Debug y Release), agregar/asegurar
  `INFOPLIST_KEY_CFBundleDisplayName = "Watt + Weight";` y cambiar
  `PRODUCT_BUNDLE_IDENTIFIER = com.BERNU.IronPulse;` →
  `PRODUCT_BUNDLE_IDENTIFIER = com.BERNU.WattWeight;` (solo el target de
  app; los targets de tests — `IronPulseTests`, `IronPulseUITests` —
  mantienen su bundle id actual, no se publican y no importa que sigan
  con el nombre viejo).
- App Icon: generar un PNG 1024×1024 sin canal alpha a partir de
  `MOCKUPS/logo/screen.png` (recorte/relleno a cuadrado si hace falta) y
  asignarlo a los 3 slots de `IronPulse/Assets.xcassets/AppIcon.appiconset`
  (`any`, `dark`, `tinted` — mismo PNG en los 3, el diseño ya es full-black
  así que no hay variante real que hacer).
- Logo dentro de la app: agregar el PNG del logo (recortado a un ícono
  cuadrado simple, sin el anillo/texto — mismo criterio que el ícono) como
  asset `wwLogoMark` en `Assets.xcassets`, usado en el header de
  `ExerciseListView` y en el header de `ActiveWorkoutView` (los dos únicos
  lugares donde los mockups lo muestran).

## Design tokens (`IronPulse/Theme/CustomColor.swift`)

Se reescribe el archivo completo: se elimina `dynamic(light:dark:)` y todo
uso de modo claro.

### Colores

| Token | Hex | Uso |
|---|---|---|
| `ironBackground` | `#121317` | fondo de toda pantalla |
| `ironCard` | `#1E1F23` | cards, filas de lista |
| `ironCardElevated` | `#292A2E` | cards dentro de cards (p. ej. rest banner sobre el fondo de sesión) |
| `ironBorder` | `#343539` | borde 1px de cards/inputs |
| `ironTextPrimary` | `#E3E2E7` | texto principal |
| `ironTextSecondary` | `#9A9E86` | texto secundario/metadata (ajustado desde `outline` `#8F9378` del DESIGN.md para contraste AA sobre `#121317`) |
| `ironAccent` | `#CAF300` | acciones primarias, progreso, valores destacados (reemplaza `neonGreen`) |
| `ironDanger` | `#FF3300` | se mantiene — Kinetic Onyx no define un rojo de acción fuera de su `error-container` (`#93000A`, pensado para fondos de error, no para texto de "descartar") |

`neonGreen`/`neonOrange` quedan como alias de `ironAccent`/`ironDanger`
para no romper otros archivos que los referencien directamente (se
verifica con grep en la implementación y se elimina el alias si no queda
ningún uso).

### Tipografía

Se agregan los archivos de fuente a `IronPulse/Resources/Fonts/`:
`Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-Bold.ttf`,
`Inter-ExtraBold.ttf`, `JetBrainsMono-Regular.ttf`,
`JetBrainsMono-Medium.ttf`, más el archivo de licencia de cada una
(`Inter-LICENSE.txt`, `JetBrainsMono-LICENSE.txt`). Se registran en
`Info.plist` bajo `UIAppFonts` con la ruta relativa.

Tokens nuevos en `Font`, reemplazando `ironTitle`/`metricDisplay(_:)`:

```swift
extension Font {
    static var wwDisplay: Font { .custom("Inter-ExtraBold", size: 32) }
    static var wwHeadline: Font { .custom("Inter-Bold", size: 24) }
    static var wwBody: Font { .custom("Inter-Regular", size: 16) }
    static var wwLabelCaps: Font { .custom("Inter-Bold", size: 12) }

    static func wwDataMono(_ size: CGFloat = 20) -> Font {
        .custom("JetBrainsMono-Medium", size: size)
    }
}
```

Todos los usos actuales de `.ironTitle` y `.metricDisplay(_:)` en las 9
vistas se reemplazan por estos tokens durante el paso pantalla por
pantalla (sección siguiente).

### Forma, espaciado y elevación

```swift
enum CornerRadius {
    static let card: CGFloat = 16
    static let button: CGFloat = 16
    static let chip: CGFloat = .infinity // pill
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}
```

`IronCardModifier` pierde su uso de sombra (si lo tuviera) y mantiene
únicamente fondo `ironCard` + borde 1px `ironBorder`, `cornerRadius:
CornerRadius.card`. `neonGlow(...)` se elimina (usaba `.shadow`, prohibido
por el DESIGN.md — "avoids traditional drop shadows"); sus 2-3 call sites
pasan a un cambio de color de borde en estado activo/presionado en su
lugar (p. ej. borde `ironBorder` → `ironAccent` al presionar, no sombra).

## Componentes compartidos nuevos

Todos en `IronPulse/Theme/` o `IronPulse/Components/` (junto a
`GIFImageView.swift`, que ya vive ahí).

- **`TagBadge`**: `Text` en mayúsculas, `wwLabelCaps`, padding pequeño,
  borde 1px del color que se le pase, fondo transparente. Uso: badge
  "COMPOUND" en listado/detalle de ejercicio (desde `Exercise.isCompound`,
  texto "COMPOUND" si es `true`, sin badge si es `false` — no se inventa
  un badge "ISOLATION"). Reemplaza también el estilo visual de
  `FilterChip` (mismo componente, estado activo con fondo `ironAccent`).
- **`LabeledProgressBar`**: label a la izquierda, valor formateado a la
  derecha, barra debajo (`ironCardElevated` de fondo, `ironAccent` de
  relleno, sin extremos redondeados más allá de `CornerRadius.chip`). Uso:
  volumen de sesión en `ActiveWorkoutView` (dato: suma de
  `peso × reps` de los sets completados de la sesión activa, cálculo
  nuevo y pequeño, no requiere `WorkoutStatsService` porque es solo de la
  sesión en curso, no histórico).
- **`AvatarPlaceholder`**: círculo `ironCardElevated` con borde
  `ironAccent`, iniciales del `profile.name` centradas en `wwHeadline` (o
  ícono `person.fill` si el nombre está vacío). Sin gesto de tap, sin
  navegación — es puramente decorativo hasta que exista el spec de foto.
- **`MuscleDiagramView`**: `Shape`/`Path` de SwiftUI con una silueta
  humana simple de frente (cabeza, torso, brazos, piernas como formas
  geométricas básicas — no una ilustración importada), donde cada región
  se colorea `ironAccent` si su `MuscleGroup` coincide con
  `exercise.muscleGroup`, `ironTextSecondary` si coincide con algún
  elemento de `exercise.secondaryMuscles`, y `ironBorder` si no aplica.
  Recibe `primary: MuscleGroup` y `secondary: [MuscleGroup]`.

## Contenido nuevo por dato existente

- **Tira semanal del Dashboard**: 7 columnas Lun-Dom. Para cada
  `Weekday`, se busca si hay un `RoutineDay` de la rutina activa asignado
  a ese día (`weekday` ya existe desde la spec anterior); si lo hay y cae
  antes o en hoy, se marca completado (✓, `ironAccent`) si existe un
  `WorkoutLog` terminado ese día calendario, pendiente (círculo hueco) si
  no, y "hoy" se resalta con un borde extra sin importar su estado. Días
  sin `RoutineDay` asignado quedan vacíos/atenuados. Cálculo nuevo,
  pequeño, vive como función pura en `WorkoutStatsService` (mismo patrón
  que `currentStreak`) para poder testearlo sin UI.
- **`Exercise.proTip: String?`**: campo opcional nuevo (sin migración
  real, mismo patrón que `gifRemoteURLString`). Se redactan los 146 tips
  del catálogo (`ExercisesSeed.json`) como parte de la tarea de datos del
  plan — un consejo corto y específico por ejercicio, en español, en el
  mismo tono técnico que ya usan las `instructions` existentes.

## Pantalla por pantalla

| Vista | Mockup de referencia | Cambios |
|---|---|---|
| `DashboardView` | `mi_rutina` | Tokens completos + tira semanal Lun-Dom nueva |
| `ExerciseListView` | `biblioteca_de_ejercicios` | Tokens + `TagBadge` reemplaza estilo de `FilterChip`, logo en header |
| `ExerciseDetailView` | `detalle_de_ejercicio` | Tokens + `TagBadge` "COMPOUND" + `MuscleDiagramView` + caja de Pro Tip (`exercise.proTip`) |
| `ActiveWorkoutView` | `sesi_n_en_curso(_con_gu_a)` | Tokens + `LabeledProgressBar` de volumen de sesión, logo en header |
| `ProfileDetailView` (`ContentView.swift`) | `perfil_de_usuario` + `configuraci_n_de_perfil` | Tokens + `AvatarPlaceholder`; `Stepper` de días/semana → `Slider` 1...7 con el mismo binding |
| `RoutineTabView` | — | Solo tokens |
| `RoutineBuilderView` | — | Solo tokens |
| `WorkoutHistoryView` | — | Solo tokens |
| `ExercisePickerSheet` | — | Solo tokens |
| `ExerciseProgressView` | — | Solo tokens (ya usa `Chart`, mantiene `.allowsHitTesting(false)`) |
| `MainTabView`, `ContentView` (lista de perfiles) | tab bar / logo | Solo tokens + logo pequeño donde corresponda |

## Testing

Sin lógica nueva de negocio salvo dos piezas puras, testeadas con XCTest
igual que el resto del código de servicios:

- `WorkoutStatsService`: función nueva para la tira semanal (día → estado
  completado/pendiente/vacío), casos: día sin `RoutineDay` asignado, día
  futuro, día de hoy sin entrenar, día pasado completado, día pasado no
  completado.
- `MuscleDiagramView`: no es lógica de negocio (es una vista), no lleva
  test unitario — se verifica visualmente en el simulador.

El resto es 100% visual: se verifica corriendo la app en el simulador y
comparando cada una de las 9 vistas contra su mockup (cuando aplica), más
`xcodebuild test -only-testing:IronPulseTests` para confirmar que el
suite existente (47 tests + los nuevos de la tira semanal) sigue en
verde — el cambio de bundle id y de fuentes no debería afectar tests que
no tocan UI, pero se corre igual como red de seguridad.

## Riesgos conocidos

- Cambiar `PRODUCT_BUNDLE_IDENTIFIER` invalida cualquier perfil de
  provisioning/certificado ya generado para `com.BERNU.IronPulse` en la
  cuenta de Apple Developer del usuario, si existiera alguno — no afecta
  nada en git ni en Xcode más allá de tener que re-firmar en el próximo
  build a dispositivo/TestFlight.
- Los 146 `proTip` son contenido redactado por el asistente, no revisado
  por un entrenador — están pensados como copy de producto, no como
  consejo médico/de seguridad certificado.
