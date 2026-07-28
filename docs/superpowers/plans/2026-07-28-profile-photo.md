# Foto de Perfil Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar foto de perfil real (galería o cámara) a `UserProfile`, mostrada en `ProfileDetailView` y en el header de `DashboardView`, según `docs/superpowers/specs/2026-07-28-profile-photo-design.md`.

**Architecture:** Un campo `Data?` nuevo en `UserProfile`, una función pura de redimensionado/compresión, un componente `CameraPicker` (UIKit envuelto) para la cámara, `AvatarPlaceholder` extendido para dibujar la foto si existe, y un componente nuevo `EditableAvatarView` que encapsula toda la interacción (tocar → menú → galería/cámara/eliminar) para no duplicar esa lógica entre `ProfileDetailView` y `DashboardView`.

**Tech Stack:** SwiftUI + SwiftData + PhotosUI + UIKit (`UIImagePickerController` para cámara), iOS 17+, cero dependencias externas.

## Global Constraints

- Cero dependencias externas — todo con PhotosUI/UIKit nativos.
- `UserProfile.photoData` es `Data?` opcional — no rompe el store existente del simulador, no hace falta desinstalar la app.
- El botón "Tomar foto" debe estar ausente (no solo deshabilitado) si `UIImagePickerController.isSourceTypeAvailable(.camera)` es `false` — siempre el caso en el simulador de desarrollo.
- `PhotosPicker` no necesita `NSPhotoLibraryUsageDescription` (corre fuera del proceso de la app) — no agregar ese permiso, solo `NSCameraUsageDescription`.
- Ningún test existente (59+ en `IronPulseTests`) puede romperse. Correr siempre con `-only-testing:IronPulseTests`.
- La lógica de interacción (menú, picker, cámara, eliminar) vive en un solo componente nuevo (`EditableAvatarView`), no duplicada en `ProfileDetailView` y `DashboardView`.

---

### Task 1: Permiso de cámara + campo `photoData` en `UserProfile`

**Files:**
- Modify: `IronPulse.xcodeproj/project.pbxproj`
- Modify: `IronPulse/Models/UserProfile.swift`

**Interfaces:**
- Produces: `UserProfile.photoData: Data?`, permiso `NSCameraUsageDescription` registrado.

- [ ] **Step 1: Agregar el permiso de cámara**

En `IronPulse.xcodeproj/project.pbxproj`, con `replace_all` (aparece 2 veces — Debug y Release del target de app):

Buscar:
```
				INFOPLIST_KEY_NSHealthShareUsageDescription = "Watt + Weight usa tus datos de Salud (peso, altura, fecha de nacimiento) para completar tu perfil.";
```
Reemplazar:
```
				INFOPLIST_KEY_NSCameraUsageDescription = "Watt + Weight usa la camara para tomar tu foto de perfil.";
				INFOPLIST_KEY_NSHealthShareUsageDescription = "Watt + Weight usa tus datos de Salud (peso, altura, fecha de nacimiento) para completar tu perfil.";
```

- [ ] **Step 2: Agregar `photoData` a `UserProfile`**

En `IronPulse/Models/UserProfile.swift`, agregar `var photoData: Data?` como último `var` de la clase (después de `createdAt`, antes de las `@Relationship`), y `photoData: Data? = nil` como último parámetro escalar del `init` (después de `createdAt: Date = Date()`, antes de los parámetros de relación `healthSnapshots:`/`routines:`/`workoutLogs:`), con `self.photoData = photoData` en el cuerpo del `init` en la misma posición relativa.

- [ ] **Step 3: Verificar que compila**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Esperado: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add IronPulse.xcodeproj/project.pbxproj IronPulse/Models/UserProfile.swift
git commit -m "Agrega permiso de camara y campo photoData a UserProfile"
```

---

### Task 2: `resizedProfilePhotoData` + tests

**Files:**
- Create: `IronPulse/Services/ProfilePhotoProcessor.swift`
- Test: `IronPulseTests/ProfilePhotoProcessorTests.swift`

**Interfaces:**
- Produces: `func resizedProfilePhotoData(from image: UIImage, targetSize: CGFloat = 512) -> Data?`.

- [ ] **Step 1: Escribir el test primero**

```swift
import XCTest
@testable import IronPulse

final class ProfilePhotoProcessorTests: XCTestCase {
    private func syntheticImage(size: CGSize, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testImagenCuadradaDaResultado512x512() {
        let image = syntheticImage(size: CGSize(width: 800, height: 800))
        let data = resizedProfilePhotoData(from: image)

        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(decoded?.size, CGSize(width: 512, height: 512))
    }

    func testImagenRectangularTambienDaResultado512x512() {
        let image = syntheticImage(size: CGSize(width: 1200, height: 600))
        let data = resizedProfilePhotoData(from: image)

        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(decoded?.size, CGSize(width: 512, height: 512))
    }

    func testTargetSizePersonalizadoSeRespeta() {
        let image = syntheticImage(size: CGSize(width: 300, height: 300))
        let data = resizedProfilePhotoData(from: image, targetSize: 128)

        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(decoded?.size, CGSize(width: 128, height: 128))
    }

    func testImagenConAnchoOAltoCeroDevuelveNil() {
        let image = syntheticImage(size: CGSize(width: 0, height: 100))
        XCTAssertNil(resizedProfilePhotoData(from: image))
    }
}
```

- [ ] **Step 2: Correr y verificar que falla (no existe `resizedProfilePhotoData` todavia)**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/ProfilePhotoProcessorTests
```

Esperado: FAIL, "cannot find 'resizedProfilePhotoData' in scope".

- [ ] **Step 3: Implementar `ProfilePhotoProcessor.swift`**

```swift
import UIKit

func resizedProfilePhotoData(from image: UIImage, targetSize: CGFloat = 512) -> Data? {
    guard image.size.width > 0, image.size.height > 0 else { return nil }

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize, height: targetSize))
    return renderer.jpegData(withCompressionQuality: 0.8) { _ in
        let aspectFillScale = max(targetSize / image.size.width, targetSize / image.size.height)
        let scaledSize = CGSize(
            width: image.size.width * aspectFillScale,
            height: image.size.height * aspectFillScale
        )
        let origin = CGPoint(
            x: (targetSize - scaledSize.width) / 2,
            y: (targetSize - scaledSize.height) / 2
        )
        image.draw(in: CGRect(origin: origin, size: scaledSize))
    }
}
```

`UIImage.draw(in:)` respeta la orientación de la imagen automáticamente (a diferencia de recortar `cgImage` a mano), por eso no hace falta lidiar con `image.imageOrientation` explícitamente — es la razón para dibujar con `UIGraphicsImageRenderer` en vez de manipular el `CGImage` directamente.

- [ ] **Step 4: Correr de nuevo, confirmar verde**

Mismo comando del Step 2. Esperado: 4/4 en verde.

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Services/ProfilePhotoProcessor.swift IronPulseTests/ProfilePhotoProcessorTests.swift
git commit -m "Agrega resizedProfilePhotoData: recorte a cuadrado + compresion JPEG"
```

---

### Task 3: `CameraPicker`

**Files:**
- Create: `IronPulse/Components/CameraPicker.swift`

**Interfaces:**
- Produces: `CameraPicker(onImagePicked: (UIImage) -> Void)` — `UIViewControllerRepresentable`.

- [ ] **Step 1: Implementar**

```swift
import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
```

Sin test unitario — es un wrapper de UIKit sin lógica propia más allá de delegar, se verifica en el simulador (Task 7). Esto NO se puede probar en el simulador de desarrollo (no tiene cámara), así que la verificación real de este componente específico depende de un dispositivo físico — ver la nota en Task 7.

- [ ] **Step 2: Verificar que compila**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 3: Commit**

```bash
git add IronPulse/Components/CameraPicker.swift
git commit -m "Agrega CameraPicker: wrapper de UIImagePickerController para camara"
```

---

### Task 4: `AvatarPlaceholder` — soporte de foto real

**Files:**
- Modify: `IronPulse/Components/AvatarPlaceholder.swift`

**Interfaces:**
- Produces: `AvatarPlaceholder(name: String, photoData: Data? = nil, size: CGFloat = 56)` — sigue siendo un componente de solo-display, sin lógica de interacción (eso vive en `EditableAvatarView`, Task 5).
- Consumes: nada nuevo.

- [ ] **Step 1: Reemplazar el archivo completo**

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
    var photoData: Data? = nil
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.ironAccent, lineWidth: 2))
            } else {
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
    }
}
```

(`import UIKit` no hace falta agregarlo aparte — `UIImage` ya queda disponible transitivamente vía `SwiftUI` en un target iOS, y el resto del archivo no lo necesitaba antes tampoco.)

- [ ] **Step 2: Correr el test existente de iniciales**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests/AvatarPlaceholderTests
```

Esperado: sigue en verde (la función `initials(from:)` no cambió).

- [ ] **Step 3: Commit**

```bash
git add IronPulse/Components/AvatarPlaceholder.swift
git commit -m "AvatarPlaceholder: dibuja la foto real si existe, iniciales si no"
```

---

### Task 5: `EditableAvatarView`

**Files:**
- Create: `IronPulse/Components/EditableAvatarView.swift`

**Interfaces:**
- Produces: `EditableAvatarView(profile: UserProfile, size: CGFloat = 56)`.
- Consumes: `AvatarPlaceholder` (Task 4), `CameraPicker` (Task 3), `resizedProfilePhotoData` (Task 2), `UserProfile.photoData` (Task 1).

- [ ] **Step 1: Implementar**

```swift
import SwiftUI
import PhotosUI

struct EditableAvatarView: View {
    @Bindable var profile: UserProfile
    var size: CGFloat = 56

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingMenu = false

    var body: some View {
        AvatarPlaceholder(name: profile.name, photoData: profile.photoData, size: size)
            .contentShape(Circle())
            .onTapGesture { showingMenu = true }
            .confirmationDialog("Foto de perfil", isPresented: $showingMenu) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("Elegir de galeria")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Tomar foto") {
                        showingCamera = true
                    }
                }

                if profile.photoData != nil {
                    Button("Eliminar foto", role: .destructive) {
                        profile.photoData = nil
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    profile.photoData = resizedProfilePhotoData(from: uiImage)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker { image in
                    profile.photoData = resizedProfilePhotoData(from: image)
                    showingCamera = false
                }
            }
    }
}
```

- [ ] **Step 2: Verificar que compila**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [ ] **Step 3: Commit**

```bash
git add IronPulse/Components/EditableAvatarView.swift
git commit -m "Agrega EditableAvatarView: menu de galeria/camara/eliminar sobre AvatarPlaceholder"
```

---

### Task 6: Integrar `EditableAvatarView` en `ProfileDetailView` y `DashboardView`

**Files:**
- Modify: `IronPulse/ContentView.swift`
- Modify: `IronPulse/Views/Workouts/DashboardView.swift`

**Interfaces:**
- Consumes: `EditableAvatarView` (Task 5).

- [ ] **Step 1: `ProfileDetailView`**

En `IronPulse/ContentView.swift`, reemplazar:
```swift
                HStack {
                    Spacer()
                    AvatarPlaceholder(name: profile.name, size: 72)
                    Spacer()
                }
```
por:
```swift
                HStack {
                    Spacer()
                    EditableAvatarView(profile: profile, size: 72)
                    Spacer()
                }
```

- [ ] **Step 2: `DashboardView`**

En `IronPulse/Views/Workouts/DashboardView.swift`, dentro de la sub-vista `header`, reemplazar:
```swift
            Circle().fill(Color.ironAccent).frame(width: 56, height: 56)
                .overlay(Circle().stroke(Color.ironTextPrimary.opacity(0.3), lineWidth: 2))
```
por:
```swift
            EditableAvatarView(profile: profile, size: 56)
```

- [ ] **Step 3: Verificar que compila y corre la suite completa**

```bash
xcodebuild -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests
```

Esperado: `BUILD SUCCEEDED`, todos los tests en verde.

- [ ] **Step 4: Commit**

```bash
git add IronPulse/ContentView.swift IronPulse/Views/Workouts/DashboardView.swift
git commit -m "Integra EditableAvatarView en ProfileDetailView y DashboardView"
```

---

### Task 7: Verificación completa en simulador

**Files:** ninguno (solo verificación manual + automatizada)

- [ ] **Step 1: Suite de tests completo**

```bash
xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:IronPulseTests
```

Esperado: todos los tests en verde (suite existente + los 4 nuevos de `ProfilePhotoProcessorTests`).

- [ ] **Step 2: Recorrido visual en simulador**

- Abrir `ProfileDetailView`, tocar el avatar: confirmar que aparece el menú con "Elegir de galería" (y **sin** "Tomar foto", ya que el simulador no tiene cámara).
- Elegir una foto de galería: confirmar que aparece recortada en círculo, tanto en `ProfileDetailView` como en el header del `Dashboard`.
- Tocar el avatar de nuevo: confirmar que ahora aparece la opción "Eliminar foto"; tocarla y confirmar que vuelve a mostrar las iniciales en ambos lugares.
- **Cámara real**: esto requiere un dispositivo físico (el simulador no tiene cámara) — si no hay uno disponible en esta sesión, dejarlo anotado como pendiente de verificación manual por el usuario, no fabricar una verificación que no se pudo hacer.

- [ ] **Step 3: Actualizar `PROGRESS.md`**

Documentar esta tanda (foto de perfil): qué se hizo, y mover el pendiente correspondiente de "Siguientes pasos" a completado, dejando claro que el selector de idioma queda como su propio pendiente separado (spec futura, no tocada en esta tanda).

- [ ] **Step 4: Commit**

```bash
git add PROGRESS.md
git commit -m "Documenta la foto de perfil en PROGRESS.md"
```
