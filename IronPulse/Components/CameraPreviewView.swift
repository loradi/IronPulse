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

        /// Converts a Vision-space joint point (normalized, origin
        /// bottom-left, y-up — relative to the already-portrait-rotated
        /// buffer `PoseDetectorService` runs Vision on, see that file's
        /// `.up` orientation comment) into this layer's own point space.
        /// Deliberately NOT `layerPointConverted(fromCaptureDevicePoint:)`
        /// — that method's input space is AVCaptureDevice's raw,
        /// un-rotated sensor frame (used for focus/exposure points of
        /// interest), a different space than what Vision returns here.
        /// `layerRectConverted(fromMetadataOutputRect:)` is the correct
        /// counterpart: its input space DOES track the capture
        /// connection's own rotation/mirroring setting and automatically
        /// accounts for `.resizeAspectFill`'s crop, so only the Y-axis
        /// flip (Vision's bottom-left/y-up vs. CoreGraphics' top-left/
        /// y-down) is needed before handing it off.
        private func viewPoint(for visionPoint: CGPoint) -> CGPoint {
            let metadataPoint = CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
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
