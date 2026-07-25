import Foundation

struct WgerPaginatedResponse<Result: Decodable>: Decodable {
    let count: Int
    let next: URL?
    let previous: URL?
    let results: [Result]
}

struct WgerExercise: Decodable, Identifiable, Hashable {
    let id: Int
    let uuid: String?
    let name: String
    let description: String
    let category: Int?
    let muscles: [Int]
    let musclesSecondary: [Int]
    let equipment: [Int]
    var imageURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case name
        case description
        case category
        case muscles
        case musclesSecondary = "muscles_secondary"
        case equipment
    }

    init(
        id: Int,
        uuid: String? = nil,
        name: String,
        description: String,
        category: Int? = nil,
        muscles: [Int] = [],
        musclesSecondary: [Int] = [],
        equipment: [Int] = [],
        imageURL: URL? = nil
    ) {
        self.id = id
        self.uuid = uuid
        self.name = name
        self.description = description
        self.category = category
        self.muscles = muscles
        self.musclesSecondary = musclesSecondary
        self.equipment = equipment
        self.imageURL = imageURL
    }

    var cleanedDescription: String {
        description
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var primaryMuscleGroup: MuscleGroup {
        MuscleGroup.allCases.first { group in
            !group.wgerMuscleIDs.isDisjoint(with: Set(muscles))
        } ?? .fullBody
    }

    var equipmentType: EquipmentType {
        EquipmentType.allCases.first { type in
            !type.wgerEquipmentIDs.isDisjoint(with: Set(equipment))
        } ?? .fullGym
    }
}

struct WgerExerciseImage: Decodable, Identifiable, Hashable {
    let id: Int
    let exercise: Int
    let image: URL?
    let isMain: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case exercise
        case image
        case isMain = "is_main"
    }
}

struct WgerExerciseCategory: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct WgerMuscle: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let isFront: Bool?
    let imageURLMain: URL?
    let imageURLSecondary: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isFront = "is_front"
        case imageURLMain = "image_url_main"
        case imageURLSecondary = "image_url_secondary"
    }
}
