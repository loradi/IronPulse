import CoreVideo
import Foundation
import Vision

/// Wraps `VNDetectHumanBodyPoseRequest` and translates Vision's own
/// joint naming into this app's `BodyJoint` enum, so the counting
/// logic (`RepCounterEngine`, `AngleCalculator`) never imports Vision
/// and stays unit-testable without a camera. This is the ONLY file in
/// the feature that talks to Vision directly.
enum PoseDetectorService {
    static func detectJoints(in pixelBuffer: CVPixelBuffer) -> [BodyJoint: CGPoint] {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return [:]
        }

        guard let observation = request.results?.first,
              let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return [:]
        }

        var joints: [BodyJoint: CGPoint] = [:]
        for (visionName, ourJoint) in jointMapping {
            guard let point = recognizedPoints[visionName], point.confidence > 0.3 else { continue }
            joints[ourJoint] = point.location
        }
        return joints
    }

    private static let jointMapping: [VNHumanBodyPoseObservation.JointName: BodyJoint] = [
        .leftShoulder: .leftShoulder,
        .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow,
        .rightElbow: .rightElbow,
        .leftWrist: .leftWrist,
        .rightWrist: .rightWrist,
        .leftHip: .leftHip,
        .rightHip: .rightHip,
        .leftKnee: .leftKnee,
        .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle,
        .rightAnkle: .rightAnkle,
    ]
}
