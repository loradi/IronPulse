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

    @Test func shouldSpeakAlwaysReturnsTrueForCorrectiveFeedback() {
        #expect(SmartAssistantModel.shouldSpeak(for: .notDeepEnough, repCount: 3, targetReps: 10))
        #expect(SmartAssistantModel.shouldSpeak(for: .tooFast, repCount: 7, targetReps: 10))
        #expect(SmartAssistantModel.shouldSpeak(for: .badForm, repCount: 5, targetReps: 10))
    }

    @Test func shouldSpeakForGoodRepOnlyOnFirstMiddleAndLastRep() {
        let targetReps = 10
        for repCount in 1...targetReps {
            let expected = (repCount == 1 || repCount == 5 || repCount == targetReps)
            #expect(
                SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: repCount, targetReps: targetReps) == expected,
                "repCount \(repCount)"
            )
        }
    }

    @Test func shouldSpeakHandlesSmallTargetsWithoutCrashing() {
        #expect(SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: 1, targetReps: 1))
        #expect(SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: 1, targetReps: 2))
        #expect(SmartAssistantModel.shouldSpeak(for: .goodRep, repCount: 2, targetReps: 2))
    }
}
