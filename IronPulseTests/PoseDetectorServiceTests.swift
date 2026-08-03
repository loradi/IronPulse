import CoreGraphics
import Foundation
import Testing
@testable import IronPulse

struct PoseDetectorServiceTests {
    @Test func primaryAngleReturnsNilWhenAJointIsMissing() {
        let profile = MovementProfile(
            primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            downRange: 70...100,
            upRange: 160...180
        )
        let incompleteJoints: [BodyJoint: CGPoint] = [
            .leftHip: CGPoint(x: 0, y: 0),
            .leftKnee: CGPoint(x: 0, y: 1),
            // .leftAnkle missing
        ]
        #expect(SmartAssistantModel.primaryAngle(joints: incompleteJoints, profile: profile) == nil)
    }

    @Test func primaryAngleComputesFromDetectedJoints() {
        let profile = MovementProfile(
            primaryAngle: JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle),
            downRange: 70...100,
            upRange: 160...180
        )
        let joints: [BodyJoint: CGPoint] = [
            .leftHip: CGPoint(x: 1, y: 0),
            .leftKnee: CGPoint(x: 0, y: 0),
            .leftAnkle: CGPoint(x: 0, y: 1),
        ]
        let angle = SmartAssistantModel.primaryAngle(joints: joints, profile: profile)
        #expect(angle != nil)
        #expect(abs(angle! - 90) < 0.001)
    }
}
