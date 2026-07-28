import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: String
    var nameEs: String
    var nameEn: String
    var nameFr: String
    var muscleGroup: MuscleGroup
    var secondaryMuscles: [MuscleGroup]
    var equipment: EquipmentType
    var isCompound: Bool
    var instructionsEs: [String]
    var instructionsEn: [String]
    var instructionsFr: [String]
    var gifFileName: String
    var gifRemoteURLString: String?
    var isCustom: Bool
    var proTipEs: String?
    var proTipEn: String?
    var proTipFr: String?

    var name: String {
        switch AppLanguage.current {
        case .spanish: return nameEs
        case .english: return nameEn
        case .french: return nameFr
        }
    }

    var instructions: [String] {
        switch AppLanguage.current {
        case .spanish: return instructionsEs
        case .english: return instructionsEn
        case .french: return instructionsFr
        }
    }

    var proTip: String? {
        switch AppLanguage.current {
        case .spanish: return proTipEs
        case .english: return proTipEn
        case .french: return proTipFr
        }
    }

    init(
        id: String,
        nameEs: String,
        nameEn: String,
        nameFr: String,
        muscleGroup: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        equipment: EquipmentType,
        isCompound: Bool = false,
        instructionsEs: [String],
        instructionsEn: [String],
        instructionsFr: [String],
        gifFileName: String,
        gifRemoteURLString: String? = nil,
        isCustom: Bool = false,
        proTipEs: String? = nil,
        proTipEn: String? = nil,
        proTipFr: String? = nil
    ) {
        self.id = id
        self.nameEs = nameEs
        self.nameEn = nameEn
        self.nameFr = nameFr
        self.muscleGroup = muscleGroup
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructionsEs = instructionsEs
        self.instructionsEn = instructionsEn
        self.instructionsFr = instructionsFr
        self.gifFileName = gifFileName
        self.gifRemoteURLString = gifRemoteURLString
        self.isCustom = isCustom
        self.proTipEs = proTipEs
        self.proTipEn = proTipEn
        self.proTipFr = proTipFr
    }
}
