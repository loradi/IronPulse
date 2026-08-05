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
