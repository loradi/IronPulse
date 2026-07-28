# Foto de perfil

## Contexto

`PROGRESS.md` tenía anotado un pendiente combinado "idioma + foto de
perfil", separado en su momento de la spec de tendencias de perfil para no
inflarla, pero marcado ahí mismo como "subsistemas independientes" (i18n
cross-cutting vs. almacenamiento de imagen). Al arrancar esta sesión se
confirmó separarlos en dos specs propias: esta cubre solo la foto de
perfil. El selector de idioma queda como su propio spec, a hacerse
después.

Hoy `AvatarPlaceholder` (agregado durante el rebrand a Watt + Weight)
dibuja un círculo con las iniciales del perfil — un placeholder
deliberado, sin ninguna lógica de imagen real. Esta spec le agrega esa
lógica.

## Decisiones (con el usuario, 2026-07-28)

- **Origen de la foto**: galería (`PhotosPicker` nativo) y cámara
  (`UIImagePickerController` envuelto), ambos nativos, cero dependencias
  externas.
- **Almacenamiento**: `Data` directo en `UserProfile` (`photoData: Data?`),
  redimensionada a 512×512 y comprimida a JPEG antes de guardar — no un
  archivo en disco con referencia por nombre. Al borrar el perfil, la foto
  se borra sola (es parte del mismo registro SwiftData).
- **Dónde se muestra**: `ProfileDetailView` (ya la muestra hoy vía
  `AvatarPlaceholder`) y el header de `DashboardView` (hoy un círculo
  decorativo sin iniciales) — mismo componente reusado en los 2 lugares.
- **Quitar la foto**: sí, con una opción explícita "Eliminar foto" que
  vuelve a mostrar las iniciales.
- **Interacción**: tocar el avatar abre un `.confirmationDialog` con
  "Elegir de galería" / "Tomar foto" / "Eliminar foto" (esta última solo
  si ya hay foto).
- **Permisos**: `PhotosPicker` no necesita `NSPhotoLibraryUsageDescription`
  (corre fuera del proceso de la app). La cámara sí necesita
  `NSCameraUsageDescription`. El botón "Tomar foto" se oculta si
  `UIImagePickerController.isSourceTypeAvailable(.camera)` es `false`
  (siempre el caso en simulador).

## Modelo de datos

`IronPulse/Models/UserProfile.swift`: agregar `var photoData: Data?`
(opcional, sin migración real — mismo patrón que
`HealthSnapshot.leanBodyMassKg`), con default `nil` en el `init`.

## Redimensionado

Función pura nueva, en un archivo nuevo `IronPulse/Services/ProfilePhotoProcessor.swift`
(o similar — un solo archivo pequeño, no un servicio con estado):

```swift
func resizedProfilePhotoData(from image: UIImage, targetSize: CGFloat = 512) -> Data?
```

- Recorta al cuadrado más grande centrado si la imagen no es cuadrada.
- Redimensiona a `targetSize × targetSize`.
- Comprime a JPEG, calidad ~0.8.
- Devuelve `nil` si la imagen de entrada es inválida/no se puede procesar
  (sin crashear).

## Componentes

### `AvatarPlaceholder` (extender el existente)

Hoy: `AvatarPlaceholder(name: String, size: CGFloat)`, siempre dibuja
iniciales. Se extiende a:

```swift
struct AvatarPlaceholder: View {
    let name: String
    var photoData: Data? = nil
    var size: CGFloat = 56
    var onTap: (() -> Void)? = nil
    // si photoData != nil -> Image(uiImage:) recortada en circulo
    // si no -> iniciales, como hoy
    // si onTap != nil -> .onTapGesture { onTap!() }
}
```

Los call sites existentes (`ProfileDetailView`) y el nuevo
(`DashboardView`'s header circle) pasan `photoData: profile.photoData` y
un `onTap` que activa el `.confirmationDialog`.

### `CameraPicker` (nuevo)

`UIViewControllerRepresentable` envolviendo `UIImagePickerController` con
`sourceType = .camera`, delegando `imagePickerController(_:didFinishPickingMediaWithInfo:)`
a un closure `onImagePicked: (UIImage) -> Void`.

### El menú de acciones

En `ProfileDetailView` (y análogo en `DashboardView`), un
`.confirmationDialog("Foto de perfil", isPresented: $showingPhotoMenu)`
con:

- `PhotosPicker` embebido como el botón "Elegir de galería" (usa la API de
  `PhotosPicker` con `selection:` + `.onChange` para cargar los datos).
- Botón "Tomar foto" — oculto si `!UIImagePickerController.isSourceTypeAvailable(.camera)` —
  presenta `CameraPicker` en un `.sheet`.
- Botón "Eliminar foto", rol `.destructive`, visible solo si
  `profile.photoData != nil` — pone `profile.photoData = nil`.

Ambos flujos de selección (galería/cámara) corren la `UIImage` resultante
por `resizedProfilePhotoData(from:)` antes de asignar
`profile.photoData`.

## Testing

- `resizedProfilePhotoData(from:)`: XCTest con una `UIImage` sintética
  (un cuadrado de color generado con `UIGraphicsImageRenderer`), verifica
  que el `Data` resultante decodifica a una imagen de exactamente 512×512
  y no es `nil`. Caso adicional con una imagen rectangular (no cuadrada)
  confirmando que el resultado sigue siendo 512×512 (recorte correcto).
- Resto es UI, verificado en simulador: elegir foto de galería, confirmar
  que aparece en `ProfileDetailView` y `DashboardView`; confirmar que
  "Tomar foto" no aparece en el simulador (sin cámara); eliminar la foto y
  confirmar que vuelve a las iniciales. Sin tests de UI automatizados
  (misma razón que el resto del proyecto: la suite de UI tests tarda
  420s).

## Fuera de alcance

- Selector de idioma — spec propio, aparte.
- Subida/sincronización a ningún backend (no existe backend en la app).
- Edición/recorte manual de la foto por el usuario (el recorte a cuadrado
  es automático, centrado, sin UI de ajuste).
