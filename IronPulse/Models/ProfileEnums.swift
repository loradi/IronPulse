import Foundation

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner:
            return "Principiante"
        case .intermediate:
            return "Intermedio"
        case .advanced:
            return "Avanzado"
        }
    }
}

enum PrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case hypertrophy
    case strength
    case fatLoss

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hypertrophy:
            return "Hipertrofia"
        case .strength:
            return "Fuerza"
        case .fatLoss:
            return "Perdida de grasa"
        }
    }
}

enum SplitType: String, Codable, CaseIterable, Identifiable {
    case fullBody
    case upperLower
    case pushPullLegs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody:
            return "Cuerpo completo"
        case .upperLower:
            return "Torso / Pierna"
        case .pushPullLegs:
            return "Empuje / Tiron / Pierna"
        }
    }
}

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case notSet
    case female
    case male
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notSet:
            return "No definido"
        case .female:
            return "Femenino"
        case .male:
            return "Masculino"
        case .other:
            return "Otro"
        }
    }
}

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case fullGym
    case dumbbells
    case barbell
    case machines
    case cableMachine
    case bodyweight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullGym:
            return "Gimnasio completo"
        case .dumbbells:
            return "Mancuernas"
        case .barbell:
            return "Barra"
        case .machines:
            return "Maquinas"
        case .cableMachine:
            return "Poleas"
        case .bodyweight:
            return "Calistenia"
        }
    }

    var wgerEquipmentIDs: Set<Int> {
        switch self {
        case .fullGym:
            return [1, 2, 3, 4, 6, 7, 8, 9, 10]
        case .dumbbells:
            return [3]
        case .barbell:
            return [1, 8]
        case .machines:
            return [4, 6, 7]
        case .cableMachine:
            return [7]
        case .bodyweight:
            return [4]
        }
    }
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case biceps
    case triceps
    case core
    case glutes
    case calves
    case fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest:
            return "Pecho"
        case .back:
            return "Espalda"
        case .legs:
            return "Piernas"
        case .shoulders:
            return "Hombros"
        case .arms:
            return "Brazos"
        case .biceps:
            return "Biceps"
        case .triceps:
            return "Triceps"
        case .core:
            return "Core"
        case .glutes:
            return "Gluteos"
        case .calves:
            return "Pantorrillas"
        case .fullBody:
            return "Cuerpo completo"
        }
    }

    var wgerMuscleIDs: Set<Int> {
        switch self {
        case .chest:
            return [4]
        case .back:
            return [9, 12]
        case .legs:
            return [10, 11, 14]
        case .shoulders:
            return [2]
        case .arms:
            return [1, 5, 13]
        case .biceps:
            return [1]
        case .triceps:
            return [5]
        case .core:
            return [6, 14]
        case .glutes:
            return [8]
        case .calves:
            return [7]
        case .fullBody:
            return []
        }
    }
}
