import Foundation
import Testing
@testable import IronPulse

struct MovementProfileCatalogTests {
    private static let curatedIDs = [
        "ex_048_sentadilla_trasera_con_barra",
        "ex_060_sentadilla_goblet_con_mancuerna",
        "ex_057_sentadilla_bulgara_con_mancuernas",
        "ex_049_sentadilla_frontal_con_barra",
        "ex_062_sentadilla_hack_en_maquina",
        "ex_063_sentadilla_en_maquina_smith",
        "ex_021_flexiones_pecho",
        "ex_020_fondos_banco",
        "ex_019_fondos_paralelas",
        "ex_022_flexiones_inclinadas",
        "ex_098_curl_barra_recta",
        "ex_100_curl_alterno_mancuernas",
        "ex_101_curl_martillo_mancuernas",
        "ex_104_curl_concentrado",
        "ex_078_press_militar_barra",
        "ex_079_press_militar_sentado_barra",
        "ex_080_press_hombros_mancuernas",
        "ex_081_press_arnold",
        "ex_031_peso_muerto_convencional",
        "ex_051_peso_muerto_rumano_con_barra",
        "ex_052_peso_muerto_rumano_con_mancuernas",
        "ex_027_remo_sentado_polea",
        "ex_028_jalon_pecho_agarre_ancho",
        "ex_117_pushdown_polea_cuerda",
    ]

    @Test func unknownExerciseHasNoProfile() {
        #expect(MovementProfileCatalog.profile(forExerciseID: "not_a_real_exercise") == nil)
    }

    @Test func everyCuratedExerciseHasAProfile() {
        for id in Self.curatedIDs {
            #expect(MovementProfileCatalog.profile(forExerciseID: id) != nil, "Missing profile for \(id)")
        }
    }

    @Test func everyCuratedProfileHasNonOverlappingDownAndUpRanges() {
        for id in Self.curatedIDs {
            let profile = MovementProfileCatalog.profile(forExerciseID: id)!
            #expect(!profile.downRange.overlaps(profile.upRange), "\(id) has overlapping down/up ranges")
        }
    }

    @Test func rowAndTricepsExtensionShareCurlsJointTriangleButHaveDifferentRanges() {
        let row = MovementProfileCatalog.profile(forExerciseID: "ex_027_remo_sentado_polea")!
        let tricepsExtension = MovementProfileCatalog.profile(forExerciseID: "ex_117_pushdown_polea_cuerda")!
        let sharedTriangle = JointAngle(proximal: .leftShoulder, vertex: .leftElbow, distal: .leftWrist)

        #expect(row.primaryAngle == sharedTriangle)
        #expect(tricepsExtension.primaryAngle == sharedTriangle)
        #expect(row.downRange != tricepsExtension.downRange)
    }
}
