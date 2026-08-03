import Foundation
import Testing
@testable import IronPulse

struct MovementProfileCatalogTests {
    private static let curatedIDs = [
        "ex_048_sentadilla_trasera_con_barra",
        "ex_060_sentadilla_goblet_con_mancuerna",
        "ex_057_sentadilla_bulgara_con_mancuernas",
        "ex_021_flexiones_pecho",
        "ex_020_fondos_banco",
        "ex_098_curl_barra_recta",
        "ex_078_press_militar_barra",
        "ex_031_peso_muerto_convencional",
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
}
