import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: String
    var name: String
    var muscleGroup: MuscleGroup
    var secondaryMuscles: [MuscleGroup]
    var equipment: EquipmentType
    var isCompound: Bool
    var instructions: [String]
    var gifFileName: String
    var gifRemoteURLString: String?
    var isCustom: Bool
    var proTip: String?

    init(
        id: String,
        name: String,
        muscleGroup: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        equipment: EquipmentType,
        isCompound: Bool = false,
        instructions: [String],
        gifFileName: String,
        gifRemoteURLString: String? = nil,
        isCustom: Bool = false,
        proTip: String? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCompound = isCompound
        self.instructions = instructions
        self.gifFileName = gifFileName
        self.gifRemoteURLString = gifRemoteURLString
        self.isCustom = isCustom
        self.proTip = proTip
    }
}
