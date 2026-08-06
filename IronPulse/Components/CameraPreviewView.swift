import AVFoundation
import QuartzCore
import SwiftUI

/// Undoes the 90° clockwise rotation `CameraSessionController` applies
/// to camera buffers (`connection.videoRotationAngle = 90`) before
/// Vision ever sees them, converting a Vision-space point (normalized,
/// origin bottom-left, y-up, relative to that already-portrait-rotated
/// buffer) into AVFoundation's "unrotated picture" coordinate space
/// (normalized, origin top-left). That unrotated space is what
/// `AVCaptureVideoPreviewLayer`'s point/rect conversion APIs always
/// expect on their input side — Apple's own header comment on
/// `metadataOutputRectOfInterestForRect:` says so explicitly ("on an
/// unrotated picture"), regardless of any connection's current rotation
/// angle. The rear camera's native/unrotated sensor image needs a 90°
/// clockwise rotation to appear portrait-upright (the same relationship
/// `UIImage.Orientation.right` encodes for unrotated rear-camera
/// photos), so undoing that to recover the unrotated frame is the
/// inverse: 90° counterclockwise. Pure geometry, no AVFoundation/UIKit
/// dependency, so it's unit-testable without a camera — unlike the
/// `layerRectConverted` call itself.
func unrotatedPoint(fromPortraitVisionPoint visionPoint: CGPoint) -> CGPoint {
    let portraitPoint = CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
    return CGPoint(x: portraitPoint.y, y: 1 - portraitPoint.x)
}

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

        /// Converts a Vision-space joint point into this layer's own
        /// point space: first undo the buffer rotation (see
        /// `unrotatedPoint(fromPortraitVisionPoint:)`), then hand the
        /// result to `layerRectConverted(fromMetadataOutputRect:)`,
        /// which accounts for mirroring, the preview's current display
        /// rotation, and `.resizeAspectFill`'s crop.
        private func viewPoint(for visionPoint: CGPoint) -> CGPoint {
            let metadataPoint = unrotatedPoint(fromPortraitVisionPoint: visionPoint)
            return videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(origin: metadataPoint, size: .zero)).origin
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
                let path = failingSegments.contains(segment) ? badFormPath : accentPath
                path.move(to: viewPoint(for: pointA))
                path.addLine(to: viewPoint(for: pointB))
            }

            for point in joints.values {
                let dot = viewPoint(for: point)
                accentPath.addEllipse(in: CGRect(x: dot.x - 3, y: dot.y - 3, width: 6, height: 6))
            }

            // CAShapeLayer has no delegate here, so implicit `path`
            // actions are enabled by default (unlike a UIView's own
            // backing layer). Without disabling them, every frame's path
            // change animates in over CoreAnimation's default 0.25s,
            // and — since the frame rate here (~10fps) is faster than
            // that — successive animations overlap, making the skeleton
            // visibly lag/smear behind the real body instead of tracking
            // it live.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            accentLayer.path = accentPath
            badFormLayer.path = badFormPath
            CATransaction.commit()
        }
    }
}
