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
                let viewA = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: pointA)
                let viewB = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: pointB)
                let path = failingSegments.contains(segment) ? badFormPath : accentPath
                path.move(to: viewA)
                path.addLine(to: viewB)
            }

            for point in joints.values {
                let viewPoint = videoPreviewLayer.layerPointConverted(fromCaptureDevicePoint: point)
                accentPath.addEllipse(in: CGRect(x: viewPoint.x - 3, y: viewPoint.y - 3, width: 6, height: 6))
            }

            accentLayer.path = accentPath
            badFormLayer.path = badFormPath
        }
    }
}
