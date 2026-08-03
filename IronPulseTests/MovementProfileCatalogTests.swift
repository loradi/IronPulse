import Foundation
import Testing
@testable import IronPulse

struct MovementProfileCatalogTests {
    private static let curatedIDs = [
        // squat (8)
        "ex_048_sentadilla_trasera_con_barra",
        "ex_060_sentadilla_goblet_con_mancuerna",
        "ex_057_sentadilla_bulgara_con_mancuernas",
        "ex_049_sentadilla_frontal_con_barra",
        "ex_062_sentadilla_hack_en_maquina",
        "ex_063_sentadilla_en_maquina_smith",
        "ex_058_sentadilla_sissy",
        "ex_076_sentadilla_sumo_con_mancuerna",
        // pushUp (8)
        "ex_021_flexiones_pecho",
        "ex_020_fondos_banco",
        "ex_019_fondos_paralelas",
        "ex_022_flexiones_inclinadas",
        "ex_015_press_pecho_maquina",
        "ex_016_press_pecho_polea_de_pie",
        "ex_123_flexiones_diamante",
        "ex_124_fondos_maquina",
        // curl (18)
        "ex_098_curl_barra_recta",
        "ex_100_curl_alterno_mancuernas",
        "ex_101_curl_martillo_mancuernas",
        "ex_104_curl_concentrado",
        "ex_099_curl_barra_z",
        "ex_102_curl_predicador_barra_z",
        "ex_103_curl_predicador_maquina",
        "ex_105_curl_polea_baja",
        "ex_106_curl_inclinado_mancuernas",
        "ex_107_curl_arana",
        "ex_108_curl_drag",
        "ex_109_curl_martillo_cuerda_polea",
        "ex_110_curl_agarre_cerrado",
        "ex_111_curl_zottman",
        "ex_112_curl_polea_alta",
        "ex_113_curl_inverso_barra",
        "ex_114_curl_maquina",
        "ex_115_curl_cruzado_martillo",
        // overheadPress (7)
        "ex_078_press_militar_barra",
        "ex_079_press_militar_sentado_barra",
        "ex_080_press_hombros_mancuernas",
        "ex_081_press_arnold",
        "ex_082_press_hombros_sentado_mancuernas",
        "ex_083_press_hombros_maquina",
        "ex_084_press_hombros_polea",
        // hinge (6)
        "ex_031_peso_muerto_convencional",
        "ex_051_peso_muerto_rumano_con_barra",
        "ex_052_peso_muerto_rumano_con_mancuernas",
        "ex_032_peso_muerto_rumano",
        "ex_043_peso_muerto_sumo",
        "ex_064_peso_muerto_sumo_con_barra",
        // row (12)
        "ex_027_remo_sentado_polea",
        "ex_028_jalon_pecho_agarre_ancho",
        "ex_023_dominadas_pronadas",
        "ex_024_dominadas_supinadas",
        "ex_025_dominadas_asistidas_banda",
        "ex_029_jalon_pecho_agarre_cerrado",
        "ex_033_remo_posterior_polea_cuerda",
        "ex_044_remo_alto_maquina_palanca",
        "ex_045_face_pull_polea",
        "ex_046_remo_arrodillado_polea_alta",
        "ex_093_remo_menton_barra",
        "ex_094_remo_menton_mancuernas",
        // tricepsExtension (8)
        "ex_117_pushdown_polea_cuerda",
        "ex_118_pushdown_polea_barra_recta",
        "ex_120_extension_mancuernas_dos_manos_sobre_cabeza",
        "ex_125_extension_polea_una_mano",
        "ex_126_press_frances_mancuernas",
        "ex_127_extension_mancuerna_una_mano_sobre_cabeza",
        "ex_128_extension_polea_cuerda_tras_nuca",
        "ex_133_extension_triceps_maquina",
        // lateralRaise (4, new profile)
        "ex_085_elevaciones_laterales_mancuernas",
        "ex_086_elevaciones_laterales_polea",
        "ex_087_elevaciones_frontales_mancuernas",
        "ex_088_elevaciones_frontales_polea",
        // legExtension (1, new profile)
        "ex_054_extension_de_piernas_en_maquina",
        // legCurl (1, new profile)
        "ex_056_curl_femoral_sentado",
    ]

    @Test func unknownExerciseHasNoProfile() {
        #expect(MovementProfileCatalog.profile(forExerciseID: "not_a_real_exercise") == nil)
    }

    @Test func everyCuratedExerciseHasAProfile() {
        for id in Self.curatedIDs {
            #expect(MovementProfileCatalog.profile(forExerciseID: id) != nil, "Missing profile for \(id)")
        }
    }

    @Test func curatedListHasExactlySeventyThreeExercises() {
        #expect(Self.curatedIDs.count == 73)
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

    @Test func everyCuratedIDExistsInTheRealExerciseCatalog() throws {
        let url = try #require(Bundle.main.url(forResource: "ExercisesSeed", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let realIDs = Set(try JSONDecoder().decode([ExerciseSeedDTO].self, from: data).map(\.id))
        for id in Self.curatedIDs {
            #expect(realIDs.contains(id), "\(id) is not a real exercise ID in ExercisesSeed.json")
        }
    }

    @Test func lateralRaiseSharesOverheadPressJointTriangleButHasAShorterRange() {
        let lateralRaise = MovementProfileCatalog.profile(forExerciseID: "ex_085_elevaciones_laterales_mancuernas")!
        let overheadPress = MovementProfileCatalog.profile(forExerciseID: "ex_078_press_militar_barra")!
        let sharedTriangle = JointAngle(proximal: .leftHip, vertex: .leftShoulder, distal: .leftElbow)

        #expect(lateralRaise.primaryAngle == sharedTriangle)
        #expect(overheadPress.primaryAngle == sharedTriangle)
        #expect(lateralRaise.upRange.upperBound < overheadPress.upRange.upperBound)
    }

    @Test func legExtensionAndLegCurlShareSquatsJointTriangleAndTrackOppositeDirections() {
        let legExtension = MovementProfileCatalog.profile(forExerciseID: "ex_054_extension_de_piernas_en_maquina")!
        let legCurl = MovementProfileCatalog.profile(forExerciseID: "ex_056_curl_femoral_sentado")!
        let sharedTriangle = JointAngle(proximal: .leftHip, vertex: .leftKnee, distal: .leftAnkle)

        #expect(legExtension.primaryAngle == sharedTriangle)
        #expect(legCurl.primaryAngle == sharedTriangle)
        // Both ranges represent "leg extended straight" as the opposite end of their own motion.
        #expect(legExtension.upRange.overlaps(legCurl.downRange))
        // Both ranges represent "leg bent" as the opposite end of their own motion.
        #expect(legExtension.downRange.overlaps(legCurl.upRange))
    }
}
