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
