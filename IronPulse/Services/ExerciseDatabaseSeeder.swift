import Foundation
import SwiftData

struct LocalizedString: Codable {
    let es: String
    let en: String
    let fr: String
    /// Identificador estable usado para buscar el clip de audio
    /// pre-grabado de esta frase (`<id>_<idioma>.mp3`) en
    /// `SmartAssistantAudioAnnouncer`. Vacío para los `LocalizedString`
    /// que no lo necesitan (nombres/instrucciones de ejercicios en
    /// `ExercisesSeed.json`, que es anterior a este campo y nunca lo trae).
    let id: String

    init(es: String, en: String, fr: String, id: String = "") {
        self.es = es
        self.en = en
        self.fr = fr
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case es, en, fr, id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        es = try container.decode(String.self, forKey: .es)
        en = try container.decode(String.self, forKey: .en)
        fr = try container.decode(String.self, forKey: .fr)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
    }
}

struct LocalizedStringArray: Codable {
    let es: [String]
    let en: [String]
    let fr: [String]
}

struct ExerciseSeedDTO: Codable {
    let id: String
    let name: LocalizedString
    let muscleGroup: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: EquipmentType
    let isCompound: Bool
    let instructions: LocalizedStringArray
    let gifFileName: String
    let gifRemoteURLString: String?
    let proTip: LocalizedString?

    func toModel() -> Exercise {
        Exercise(
            id: id,
            nameEs: name.es,
            nameEn: name.en,
            nameFr: name.fr,
            muscleGroup: muscleGroup,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            isCompound: isCompound,
            instructionsEs: instructions.es,
            instructionsEn: instructions.en,
            instructionsFr: instructions.fr,
            gifFileName: gifFileName,
            gifRemoteURLString: gifRemoteURLString,
            isCustom: false,
            proTipEs: proTip?.es,
            proTipEn: proTip?.en,
            proTipFr: proTip?.fr
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
