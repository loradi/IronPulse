# Smart Assistant: Esqueleto Virtual + Cámara Gran Angular Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dibujar un esqueleto virtual en tiempo real sobre la cámara del Smart Assistant, coloreado del acento de la app por defecto y con las dos líneas del chequeo secundario de fase 4 en rojo cuando el usuario se sale de forma — más un cambio a cámara gran angular con respaldo automático para que no haga falta alejar el teléfono.

**Architecture:** Toda la señal nueva (`isSecondaryCheckOK`) y todo el mapeo de qué segmentos pintar de rojo (`SkeletonOverlay`) es lógica pura, reutilizando el cálculo de fase 4 ya existente — cero detección nueva. El dibujo real (conversión de coordenadas, `CAShapeLayer`) vive contenido en `CameraPreviewView`, el único archivo que ya conoce `AVCaptureVideoPreviewLayer`.

**Tech Stack:** SwiftUI, AVFoundation/Vision (ya en uso), Swift Testing.

## Global Constraints

- No se agregan articulaciones nuevas ni se cambia lo que Vision detecta — se reutilizan las 12 que ya existen (`BodyJoint`).
- Cero cambio en la lógica de detección de mala forma ya existente (fase 4) — `isSecondaryCheckOK` solo expone el mismo cálculo cuadro a cuadro, no introduce ningún cálculo nuevo.
- Color binario únicamente: acento de la app (`Color.ironAccent`) por defecto, rojo solo en los 2 segmentos del triángulo vigilado cuando `isFormOK == false`. Sin tercer estado.
- Tests usan Swift Testing (`@Test`/`#expect`), igual que todos los archivos existentes en `IronPulseTests/`.
- Los test runs deben pasar `-parallel-testing-enabled NO`.
- El dibujo real del esqueleto (`CAShapeLayer`/`AVCaptureVideoPreviewLayer`) y la selección de lente de cámara dependen de UIKit real y hardware — no son testeables automáticamente, se verifican manualmente en dispositivo, igual que el resto del pipeline de cámara/Vision de fases anteriores.

---

### Task 1: Lógica pura — señal en vivo del engine + mapeo de segmentos del esqueleto

**Files:**
- Modify: `IronPulse/Services/RepCounterEngine.swift`
- Create: `IronPulse/Services/SkeletonOverlay.swift`
- Test: `IronPulseTests/RepCounterEngineTests.swift`
- Test: `IronPulseTests/SkeletonOverlayTests.swift`

**Interfaces:**
- Produces: `RepCounterEngine.isSecondaryCheckOK: Bool` (nueva propiedad pública); `SkeletonOverlay.bones: [SkeletonOverlay.Segment]`, `SkeletonOverlay.failingSegments(for:isFormOK:) -> Set<SkeletonOverlay.Segment>`.

- [ ] **Step 1: Write the failing tests for `isSecondaryCheckOK`**

En `IronPulseTests/RepCounterEngineTests.swift`, agregar estos tests (usa los fixtures `stabilityProfile`/`boundedProfile`/`squatLikeProfile` que ya existen en el archivo):

```swift
    @Test func isSecondaryCheckOKDefaultsToTrueBeforeAnyUpdate() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        #expect(engine.isSecondaryCheckOK == true)
    }

    @Test func isSecondaryCheckOKStaysTrueWhileWithinTolerance() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        #expect(engine.isSecondaryCheckOK == true)
        _ = engine.update(angle: 155, secondaryAngle: 45, now: base.addingTimeInterval(0.2)) // drift of 5, within 15
        #expect(engine.isSecondaryCheckOK == true)
    }

    @Test func isSecondaryCheckOKTurnsFalseTheExactFrameToleranceIsExceeded() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        #expect(engine.isSecondaryCheckOK == true)
        _ = engine.update(angle: 155, secondaryAngle: 65, now: base.addingTimeInterval(0.2)) // drift of 25, exceeds 15
        #expect(engine.isSecondaryCheckOK == false)
    }

    @Test func isSecondaryCheckOKTurnsFalseForABoundedViolation() {
        let engine = RepCounterEngine(profile: boundedProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 175, now: base)
        #expect(engine.isSecondaryCheckOK == true)
        _ = engine.update(angle: 85, secondaryAngle: 120, now: base.addingTimeInterval(1)) // torso collapses below 150
        #expect(engine.isSecondaryCheckOK == false)
    }

    @Test func isSecondaryCheckOKReturnsTrueAfterSelfCorrectionEvenThoughTheAttemptStillResolvesAsBadForm() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        _ = engine.update(angle: 155, secondaryAngle: 65, now: base.addingTimeInterval(0.2)) // drift of 25, violates
        #expect(engine.isSecondaryCheckOK == false)
        _ = engine.update(angle: 150, secondaryAngle: 42, now: base.addingTimeInterval(0.3)) // corrects back within tolerance
        #expect(engine.isSecondaryCheckOK == true) // the live signal reflects THIS frame only
        let feedback = engine.update(angle: 45, secondaryAngle: 41, now: base.addingTimeInterval(0.5))
        #expect(feedback == .badForm) // the sticky per-attempt flag still remembers the earlier violation
    }

    @Test func isSecondaryCheckOKResetsToTrueOnEnteringUpPhase() {
        let engine = RepCounterEngine(profile: stabilityProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 40, now: base) // enters down, baseline = 40
        _ = engine.update(angle: 155, secondaryAngle: 65, now: base.addingTimeInterval(0.2)) // drift of 25, violates
        #expect(engine.isSecondaryCheckOK == false)
        _ = engine.update(angle: 45, secondaryAngle: 65, now: base.addingTimeInterval(0.5)) // completes into "up" phase (badForm)
        #expect(engine.isSecondaryCheckOK == true) // nothing actively checked between reps
    }

    @Test func isSecondaryCheckOKStaysTrueForProfilesWithoutASecondaryCheck() {
        let engine = RepCounterEngine(profile: squatLikeProfile)
        let base = Date()
        _ = engine.update(angle: 170, secondaryAngle: 999, now: base)
        #expect(engine.isSecondaryCheckOK == true)
        _ = engine.update(angle: 85, secondaryAngle: -500, now: base.addingTimeInterval(1))
        #expect(engine.isSecondaryCheckOK == true)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/RepCounterEngineTests`
Expected: FAIL (`isSecondaryCheckOK` no existe todavía)

- [ ] **Step 3: Add `isSecondaryCheckOK` to `RepCounterEngine`**

En `IronPulse/Services/RepCounterEngine.swift`, encontrar:

```swift
    let profile: MovementProfile
    private(set) var repCount: Int = 0
```

Reemplazar con:

```swift
    let profile: MovementProfile
    private(set) var repCount: Int = 0
    /// Whether the current profile's secondary check is passing on the
    /// most recently processed frame — unlike `secondaryViolatedThisAttempt`
    /// (sticky for the whole attempt, used for counting), this reflects
    /// only the instant snapshot, for live UI like a virtual skeleton
    /// that should recover the moment the user corrects their form.
    private(set) var isSecondaryCheckOK: Bool = true
```

Encontrar:

```swift
    private func enterUp(now: Date) {
        phase = .up
        phaseEnteredAt = now
        previousDistanceToDown = nil
        reportedNearMissThisAttempt = false
    }
```

Reemplazar con:

```swift
    private func enterUp(now: Date) {
        phase = .up
        phaseEnteredAt = now
        previousDistanceToDown = nil
        reportedNearMissThisAttempt = false
        isSecondaryCheckOK = true
    }
```

Encontrar:

```swift
    private func trackSecondary(_ secondaryAngle: Double?) {
        guard let secondaryAngle, let check = profile.secondaryCheck else { return }
        switch check {
        case .stability(_, let toleranceDegrees):
            // The baseline is normally captured in `enterDown`. If
            // `secondaryAngle` was nil on that exact frame (the joint
            // was briefly occluded/below Vision's confidence floor),
            // capture it here instead, on the first later frame where
            // it's available - rather than leaving the check
            // permanently disabled for the rest of this rep attempt.
            // The frame that captures the baseline can't itself have
            // drifted from it, so this frame never counts as a
            // violation.
            guard let baseline = secondaryBaseline else {
                secondaryBaseline = secondaryAngle
                return
            }
            if abs(secondaryAngle - baseline) > toleranceDegrees {
                secondaryViolatedThisAttempt = true
            }
        case .bounded(_, let allowedRange):
            if !allowedRange.contains(secondaryAngle) {
                secondaryViolatedThisAttempt = true
            }
        }
    }
```

Reemplazar con:

```swift
    private func trackSecondary(_ secondaryAngle: Double?) {
        guard let secondaryAngle, let check = profile.secondaryCheck else {
            isSecondaryCheckOK = true
            return
        }
        switch check {
        case .stability(_, let toleranceDegrees):
            // The baseline is normally captured in `enterDown`. If
            // `secondaryAngle` was nil on that exact frame (the joint
            // was briefly occluded/below Vision's confidence floor),
            // capture it here instead, on the first later frame where
            // it's available - rather than leaving the check
            // permanently disabled for the rest of this rep attempt.
            // The frame that captures the baseline can't itself have
            // drifted from it, so this frame never counts as a
            // violation.
            guard let baseline = secondaryBaseline else {
                secondaryBaseline = secondaryAngle
                isSecondaryCheckOK = true
                return
            }
            let violated = abs(secondaryAngle - baseline) > toleranceDegrees
            isSecondaryCheckOK = !violated
            if violated {
                secondaryViolatedThisAttempt = true
            }
        case .bounded(_, let allowedRange):
            let violated = !allowedRange.contains(secondaryAngle)
            isSecondaryCheckOK = !violated
            if violated {
                secondaryViolatedThisAttempt = true
            }
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/RepCounterEngineTests`
Expected: PASS

- [ ] **Step 5: Write the failing tests for `SkeletonOverlay`**

Crear `IronPulseTests/SkeletonOverlayTests.swift` con:

```swift
import Foundation
import Testing
@testable import IronPulse

struct SkeletonOverlayTests {
    @Test func bonesContainsExactlyTwelveSegments() {
        #expect(SkeletonOverlay.bones.count == 12)
    }

    @Test func segmentIsOrderIndependent() {
        let a = SkeletonOverlay.Segment(.leftShoulder, .leftHip)
        let b = SkeletonOverlay.Segment(.leftHip, .leftShoulder)
        #expect(a == b)
    }

    @Test func failingSegmentsIsEmptyWhenFormIsOK() {
        let angle = JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee)
        #expect(SkeletonOverlay.failingSegments(for: angle, isFormOK: true).isEmpty)
    }

    @Test func failingSegmentsIsEmptyWhenProfileHasNoSecondaryCheck() {
        #expect(SkeletonOverlay.failingSegments(for: nil, isFormOK: false).isEmpty)
    }

    @Test func failingSegmentsResolvesShoulderHipKneeTriangleToItsTwoBones() {
        let angle = JointAngle(proximal: .leftShoulder, vertex: .leftHip, distal: .leftKnee)
        let failing = SkeletonOverlay.failingSegments(for: angle, isFormOK: false)
        #expect(failing == [
            SkeletonOverlay.Segment(.leftShoulder, .leftHip),
            SkeletonOverlay.Segment(.leftHip, .leftKnee),
        ])
    }

    @Test func failingSegmentsResolvesHipShoulderElbowTriangleToItsTwoBones() {
        let angle = JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow)
        let failing = SkeletonOverlay.failingSegments(for: angle, isFormOK: false)
        #expect(failing == [
            SkeletonOverlay.Segment(.leftHip, .leftShoulder),
            SkeletonOverlay.Segment(.leftShoulder, .leftElbow),
        ])
    }

    @Test func failingSegmentsResolvesHipKneeAnkleTriangleToItsTwoBones() {
        let angle = JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle)
        let failing = SkeletonOverlay.failingSegments(for: angle, isFormOK: false)
        #expect(failing == [
            SkeletonOverlay.Segment(.leftHip, .leftKnee),
            SkeletonOverlay.Segment(.leftKnee, .leftAnkle),
        ])
    }

    @Test func everyProfilesSecondaryCheckTriangleResolvesToBonesInTheList() {
        // Every profile's secondaryCheck triangle must resolve to
        // bones that are actually drawn - otherwise a failing check
        // would have nothing to turn red. Same representative IDs as
        // MovementProfileCatalogTests.everyMovementProfileHasANonNilSecondaryCheck.
        let representativeIDs = [
            "ex_048_sentadilla_trasera_con_barra", "ex_021_flexiones_pecho", "ex_098_curl_barra_recta",
            "ex_078_press_militar_barra", "ex_031_peso_muerto_convencional", "ex_027_remo_sentado_polea",
            "ex_117_pushdown_polea_cuerda", "ex_085_elevaciones_laterales_mancuernas",
            "ex_054_extension_de_piernas_en_maquina", "ex_056_curl_femoral_sentado",
        ]
        for id in representativeIDs {
            let profile = MovementProfileCatalog.profile(forExerciseID: id)!
            let failing = SkeletonOverlay.failingSegments(for: profile.secondaryCheck?.angle, isFormOK: false)
            #expect(failing.count == 2, "\(id) did not resolve to exactly 2 failing segments")
            for segment in failing {
                #expect(SkeletonOverlay.bones.contains(segment), "\(id)'s secondary-check segment \(segment) is missing from SkeletonOverlay.bones")
            }
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/SkeletonOverlayTests`
Expected: FAIL (`SkeletonOverlay` no existe todavía)

- [ ] **Step 7: Create `SkeletonOverlay.swift`**

Crear `IronPulse/Services/SkeletonOverlay.swift` con:

```swift
import Foundation

/// The fixed set of "bones" (joint pairs) drawn for the Smart
/// Assistant's virtual skeleton overlay, and the pure logic that maps
/// a movement profile's secondary-check triangle onto the two bones
/// that should render as a form-failure warning. Kept UIKit/Vision-free
/// so both are unit-testable without a camera or a live view —
/// `CameraPreviewView` is the only place that turns this into pixels.
enum SkeletonOverlay {
    struct Segment: Hashable {
        let a: BodyJoint
        let b: BodyJoint

        init(_ a: BodyJoint, _ b: BodyJoint) {
            // Order-independent, so a segment matches regardless of
            // which endpoint is named first.
            if a.rawValue <= b.rawValue {
                self.a = a
                self.b = b
            } else {
                self.a = b
                self.b = a
            }
        }
    }

    static let bones: [Segment] = [
        Segment(.leftShoulder, .leftElbow),
        Segment(.leftElbow, .leftWrist),
        Segment(.rightShoulder, .rightElbow),
        Segment(.rightElbow, .rightWrist),
        Segment(.leftShoulder, .rightShoulder),
        Segment(.leftHip, .rightHip),
        Segment(.leftShoulder, .leftHip),
        Segment(.rightShoulder, .rightHip),
        Segment(.leftHip, .leftKnee),
        Segment(.leftKnee, .leftAnkle),
        Segment(.rightHip, .rightKnee),
        Segment(.rightKnee, .rightAnkle),
    ]

    /// The (up to) two bones that should render as a form-failure
    /// warning because they form the current profile's secondary-check
    /// triangle. Empty when form is currently OK, or the profile has
    /// no secondary check.
    static func failingSegments(for secondaryCheckAngle: JointAngle?, isFormOK: Bool) -> Set<Segment> {
        guard !isFormOK, let secondaryCheckAngle else { return [] }
        return [
            Segment(secondaryCheckAngle.proximal, secondaryCheckAngle.vertex),
            Segment(secondaryCheckAngle.vertex, secondaryCheckAngle.distal),
        ]
    }
}
```

- [ ] **Step 8: Run tests to verify they pass, then run the full suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests/SkeletonOverlayTests`
Expected: PASS

Then: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add IronPulse/Services/RepCounterEngine.swift IronPulse/Services/SkeletonOverlay.swift IronPulseTests/RepCounterEngineTests.swift IronPulseTests/SkeletonOverlayTests.swift
git commit -m "Agrega senal en vivo isSecondaryCheckOK y mapeo puro de segmentos del esqueleto"
```

---

### Task 2: El esqueleto se dibuja sobre la cámara

**Files:**
- Modify: `IronPulse/Views/Workouts/SmartAssistantModel.swift`
- Modify: `IronPulse/Components/CameraPreviewView.swift`
- Modify: `IronPulse/Views/Workouts/SmartAssistantSheet.swift`

**Interfaces:**
- Consumes: `RepCounterEngine.isSecondaryCheckOK`, `SkeletonOverlay.bones`, `SkeletonOverlay.failingSegments(for:isFormOK:)` (de Task 1).
- Produces: `SmartAssistantModel.latestJoints: [BodyJoint: CGPoint]`, `SmartAssistantModel.isFormOK: Bool`, `SmartAssistantModel.secondaryCheckAngle: JointAngle?`; `CameraPreviewView` gana los parámetros `joints:`, `secondaryCheckAngle:`, `isFormOK:`.

Sin tests nuevos en este paso — es código de View/UIKit puro (dibujo real, conversión de coordenadas de cámara), que este proyecto no prueba automáticamente por la misma razón que el resto del pipeline de cámara/Vision no lo está (depende de hardware real). Se verifica manualmente en dispositivo (Task 4).

- [ ] **Step 1: Exponer `latestJoints`, `isFormOK` y `secondaryCheckAngle` en `SmartAssistantModel`**

En `IronPulse/Views/Workouts/SmartAssistantModel.swift`, encontrar:

```swift
    private(set) var repCount = 0
    private(set) var feedbackMessage: String?
    private(set) var personVisible = true

    private let engine: RepCounterEngine?
    private let movementProfile: MovementProfile?
    private(set) var didFinish = false
    private let onComplete: (Int) -> Void
```

Reemplazar con:

```swift
    private(set) var repCount = 0
    private(set) var feedbackMessage: String?
    private(set) var personVisible = true
    private(set) var latestJoints: [BodyJoint: CGPoint] = [:]

    private let engine: RepCounterEngine?
    private let movementProfile: MovementProfile?
    private(set) var didFinish = false
    private let onComplete: (Int) -> Void

    /// Whether the current profile's secondary form check (fase 4) is
    /// passing on the most recently processed frame — drives the
    /// virtual skeleton's color. Defaults to `true` when there's no
    /// engine yet or the profile has no secondary check.
    var isFormOK: Bool { engine?.isSecondaryCheckOK ?? true }

    /// The joint triangle the current profile's secondary check
    /// watches, if any — `CameraPreviewView` uses this to know which
    /// two skeleton segments to highlight when `isFormOK` is false.
    var secondaryCheckAngle: JointAngle? { movementProfile?.secondaryCheck?.angle }
```

Encontrar:

```swift
    private func handleDetectedJoints(_ joints: [BodyJoint: CGPoint]) {
        guard !didFinish else { return }

        guard let profile = movementProfile, let engine else { return }
```

Reemplazar con:

```swift
    private func handleDetectedJoints(_ joints: [BodyJoint: CGPoint]) {
        guard !didFinish else { return }

        latestJoints = joints

        guard let profile = movementProfile, let engine else { return }
```

- [ ] **Step 2: Reemplazar `CameraPreviewView.swift` completo**

```swift
import AVFoundation
import QuartzCore
import SwiftUI

/// Thin UIKit bridge for the live camera preview layer, plus the
/// virtual skeleton overlay drawn on top of it. All AVFoundation
/// coordinate-space handling (converting Vision's normalized joint
/// points into the preview layer's own point space, respecting
/// `.resizeAspectFill`'s crop) stays contained in this one file — the
/// segment list and triangle-to-red-segments mapping it draws from
/// live in `SkeletonOverlay.swift` as plain, UIKit-free data/logic.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let joints: [BodyJoint: CGPoint]
    let secondaryCheckAngle: JointAngle?
    let isFormOK: Bool

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.updateSkeleton(joints: joints, secondaryCheckAngle: secondaryCheckAngle, isFormOK: isFormOK)
    }

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        private let accentLayer = CAShapeLayer()
        private let badFormLayer = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            for shapeLayer in [accentLayer, badFormLayer] {
                shapeLayer.lineWidth = 4
                shapeLayer.lineCap = .round
                layer.addSublayer(shapeLayer)
            }
            accentLayer.strokeColor = UIColor(Color.ironAccent).cgColor
            accentLayer.fillColor = UIColor(Color.ironAccent).cgColor
            badFormLayer.strokeColor = UIColor.red.cgColor
            badFormLayer.fillColor = nil
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            accentLayer.frame = bounds
            badFormLayer.frame = bounds
        }

        /// Rebuilds both shape layers' paths from scratch every call —
        /// cheap at ~10 processed frames/sec (see `SmartAssistantModel`'s
        /// frame-skip), and far simpler than diffing the previous
        /// frame's joints.
        func updateSkeleton(joints: [BodyJoint: CGPoint], secondaryCheckAngle: JointAngle?, isFormOK: Bool) {
            let failingSegments = SkeletonOverlay.failingSegments(for: secondaryCheckAngle, isFormOK: isFormOK)
            let accentPath = CGMutablePath()
            let badFormPath = CGMutablePath()

            for segment in SkeletonOverlay.bones {
                guard let pointA = joints[segment.a], let pointB = joints[segment.b] else { continue }
                let viewA = videoPreviewLayer.layerPointConverted(fromCaptureDevicePointOfInterest: pointA)
                let viewB = videoPreviewLayer.layerPointConverted(fromCaptureDevicePointOfInterest: pointB)
                let path = failingSegments.contains(segment) ? badFormPath : accentPath
                path.move(to: viewA)
                path.addLine(to: viewB)
            }

            for point in joints.values {
                let viewPoint = videoPreviewLayer.layerPointConverted(fromCaptureDevicePointOfInterest: point)
                accentPath.addEllipse(in: CGRect(x: viewPoint.x - 3, y: viewPoint.y - 3, width: 6, height: 6))
            }

            accentLayer.path = accentPath
            badFormLayer.path = badFormPath
        }
    }
}
```

- [ ] **Step 3: Pasar los nuevos parámetros desde `SmartAssistantSheet.swift`**

Encontrar:

```swift
            switch model.cameraController.authorizationState {
            case .authorized:
                CameraPreviewView(session: model.cameraController.session)
                    .ignoresSafeArea()
```

Reemplazar con:

```swift
            switch model.cameraController.authorizationState {
            case .authorized:
                CameraPreviewView(
                    session: model.cameraController.session,
                    joints: model.latestJoints,
                    secondaryCheckAngle: model.secondaryCheckAngle,
                    isFormOK: model.isFormOK
                )
                .ignoresSafeArea()
```

- [ ] **Step 4: Build para verificar que compila**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

Luego correr el suite completo una vez para confirmar que nada de Task 1 se rompió:

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add IronPulse/Views/Workouts/SmartAssistantModel.swift IronPulse/Components/CameraPreviewView.swift IronPulse/Views/Workouts/SmartAssistantSheet.swift
git commit -m "Dibuja el esqueleto virtual sobre la camara del Smart Assistant"
```

---

### Task 3: Cámara gran angular con respaldo automático

**Files:**
- Modify: `IronPulse/Components/CameraSessionController.swift`

**Interfaces:** ninguna nueva — cambio interno de `reconfigureInput(position:)`.

Sin tests nuevos — depende de `AVCaptureDevice` real (qué lentes existen en el dispositivo), no es testeable automáticamente. Se verifica manualmente en dispositivo (Task 4).

- [ ] **Step 1: Preferir gran angular con respaldo a la lente normal**

En `IronPulse/Components/CameraSessionController.swift`, encontrar:

```swift
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
```

Reemplazar con:

```swift
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        // Ultra-wide first so the phone doesn't need to be propped far
        // away to fit a whole body in frame; falls back to the
        // standard wide lens on devices/positions without one (most
        // front cameras, older/cheaper iPhones).
        let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: avPosition)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition)
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
```

- [ ] **Step 2: Build para verificar que compila**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add IronPulse/Components/CameraSessionController.swift
git commit -m "Usa camara gran angular con respaldo automatico a la lente normal"
```

---

### Task 4: Verificación completa

**Files:** ninguno (solo verificación)

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project IronPulse.xcodeproj -scheme IronPulse -destination 'platform=iOS Simulator,name=iPhone 17e' -parallel-testing-enabled NO -only-testing:IronPulseTests`
Expected: `** TEST SUCCEEDED **`, incluyendo todos los tests nuevos de Task 1 más todos los preexistentes.

- [ ] **Step 2: Build para dispositivo real**

Run: `xcodebuild build -project IronPulse.xcodeproj -scheme IronPulse -destination 'generic/platform=iOS'`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Nota de verificación manual**

Documentar (en el reporte, no en código) que lo siguiente necesita probarse en dispositivo real:

- El esqueleto se dibuja alineado con el cuerpo real en cámara (no desplazado), tanto con cámara trasera como frontal, y sobrevive el toggle entre ambas.
- Con encuadre parcial (solo tren superior visible), no aparecen líneas fantasma de piernas.
- El color por defecto es el acento de la app; al salirse de forma (ej. balancear el peso en un curl), exactamente 2 líneas se ponen rojas y el resto se queda en acento; al corregir, vuelve a acento sin esperar a que termine la repetición.
- La cámara trasera usa gran angular (más campo de visión que antes) donde el dispositivo lo soporte; en dispositivos/cámara frontal sin gran angular, sigue funcionando igual que antes (respaldo transparente, sin crash ni cámara negra).
