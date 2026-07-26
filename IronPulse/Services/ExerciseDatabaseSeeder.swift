import Foundation
import SwiftData

struct ExerciseSeedDTO: Codable {
    let id: String
    let name: String
    let muscleGroup: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: EquipmentType
    let isCompound: Bool
    let instructions: [String]
    let gifFileName: String
    let gifRemoteURLString: String?

    func toModel() -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: muscleGroup,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            isCompound: isCompound,
            instructions: instructions,
            gifFileName: gifFileName,
            gifRemoteURLString: gifRemoteURLString,
            isCustom: false
        )
    }
}

enum ExerciseDatabaseSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return }
        guard let url = Bundle.main.url(forResource: "ExercisesSeed", withExtension: "json") else {
            assertionFailure("ExercisesSeed.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let seedDTOs = try JSONDecoder().decode([ExerciseSeedDTO].self, from: data)
            seedDTOs.forEach { context.insert($0.toModel()) }
            try context.save()
        } catch {
            assertionFailure("Failed to seed exercises: \(error)")
        }
    }
}
