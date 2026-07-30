import Foundation

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner:
            return String(localized: "experience_level.beginner", defaultValue: "Principiante", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .intermediate:
            return String(localized: "experience_level.intermediate", defaultValue: "Intermedio", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .advanced:
            return String(localized: "experience_level.advanced", defaultValue: "Avanzado", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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
            return String(localized: "primary_goal.hypertrophy", defaultValue: "Hipertrofia", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .strength:
            return String(localized: "primary_goal.strength", defaultValue: "Fuerza", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .fatLoss:
            return String(localized: "primary_goal.fat_loss", defaultValue: "Perdida de grasa", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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
            return String(localized: "split_type.full_body", defaultValue: "Cuerpo completo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .upperLower:
            return String(localized: "split_type.upper_lower", defaultValue: "Torso / Pierna", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .pushPullLegs:
            return String(localized: "split_type.push_pull_legs", defaultValue: "Empuje / Tiron / Pierna", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }
}

/// Identifica el "slot" de un dia dentro de un split (ej. el dia de Torso
/// de un split Torso/Pierna), independiente del idioma. `RoutineDay.title`
/// guarda el texto ya resuelto (localizado al idioma activo al momento de
/// generar la rutina), pero el generador y el armador manual usan este
/// enum para saber que titulo y que grupos musculares le corresponden.
enum DaySlot: String, Codable, CaseIterable, Identifiable {
    case fullBody
    case upper
    case lower
    case push
    case pull
    case legs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody:
            return String(localized: "day_slot.full_body", defaultValue: "Cuerpo completo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .upper:
            return String(localized: "day_slot.upper", defaultValue: "Torso", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .lower:
            return String(localized: "day_slot.lower", defaultValue: "Pierna", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .push:
            return String(localized: "day_slot.push", defaultValue: "Empuje", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .pull:
            return String(localized: "day_slot.pull", defaultValue: "Tiron", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .legs:
            return String(localized: "day_slot.legs", defaultValue: "Piernas", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }

    var muscleGroups: [MuscleGroup] {
        switch self {
        case .fullBody:
            return [.chest, .back, .legs, .shoulders, .biceps, .triceps, .core]
        case .upper:
            return [.chest, .back, .shoulders, .biceps, .triceps]
        case .lower:
            return [.legs, .glutes, .core]
        case .push:
            return [.chest, .shoulders, .triceps]
        case .pull:
            return [.back, .biceps]
        case .legs:
            return [.legs, .glutes, .core]
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
            return String(localized: "biological_sex.not_set", defaultValue: "No definido", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .female:
            return String(localized: "biological_sex.female", defaultValue: "Femenino", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .male:
            return String(localized: "biological_sex.male", defaultValue: "Masculino", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .other:
            return String(localized: "biological_sex.other", defaultValue: "Otro", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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
            return String(localized: "equipment_type.full_gym", defaultValue: "Gimnasio completo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .dumbbells:
            return String(localized: "equipment_type.dumbbells", defaultValue: "Mancuernas", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .barbell:
            return String(localized: "equipment_type.barbell", defaultValue: "Barra", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .machines:
            return String(localized: "equipment_type.machines", defaultValue: "Maquinas", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .cableMachine:
            return String(localized: "equipment_type.cable_machine", defaultValue: "Poleas", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .bodyweight:
            return String(localized: "equipment_type.bodyweight", defaultValue: "Calistenia", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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
            return String(localized: "muscle_group.chest", defaultValue: "Pecho", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .back:
            return String(localized: "muscle_group.back", defaultValue: "Espalda", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .legs:
            return String(localized: "muscle_group.legs", defaultValue: "Piernas", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .shoulders:
            return String(localized: "muscle_group.shoulders", defaultValue: "Hombros", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .arms:
            return String(localized: "muscle_group.arms", defaultValue: "Brazos", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .biceps:
            return String(localized: "muscle_group.biceps", defaultValue: "Biceps", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .triceps:
            return String(localized: "muscle_group.triceps", defaultValue: "Triceps", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .core:
            return String(localized: "muscle_group.core", defaultValue: "Core", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .glutes:
            return String(localized: "muscle_group.glutes", defaultValue: "Gluteos", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .calves:
            return String(localized: "muscle_group.calves", defaultValue: "Pantorrillas", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .fullBody:
            return String(localized: "muscle_group.full_body", defaultValue: "Cuerpo completo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
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

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .monday: return String(localized: "weekday.monday", defaultValue: "Lunes", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .tuesday: return String(localized: "weekday.tuesday", defaultValue: "Martes", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .wednesday: return String(localized: "weekday.wednesday", defaultValue: "Miercoles", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .thursday: return String(localized: "weekday.thursday", defaultValue: "Jueves", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .friday: return String(localized: "weekday.friday", defaultValue: "Viernes", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .saturday: return String(localized: "weekday.saturday", defaultValue: "Sabado", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .sunday: return String(localized: "weekday.sunday", defaultValue: "Domingo", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }

    var shortDisplayName: String {
        switch self {
        case .monday: return String(localized: "weekday.short.monday", defaultValue: "LUN", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .tuesday: return String(localized: "weekday.short.tuesday", defaultValue: "MAR", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .wednesday: return String(localized: "weekday.short.wednesday", defaultValue: "MIE", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .thursday: return String(localized: "weekday.short.thursday", defaultValue: "JUE", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .friday: return String(localized: "weekday.short.friday", defaultValue: "VIE", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .saturday: return String(localized: "weekday.short.saturday", defaultValue: "SAB", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        case .sunday: return String(localized: "weekday.short.sunday", defaultValue: "DOM", bundle: AppLanguage.current.bundle, locale: AppLanguage.current.locale)
        }
    }

    /// `Calendar.component(.weekday)` devuelve 1=domingo..7=sabado (calendario
    /// gregoriano/US) — se remapea a este enum (1=lunes..7=domingo) para no
    /// heredar esa convencion hacia el resto del codigo.
    static func today(calendar: Calendar = .current, now: Date = Date()) -> Weekday {
        let raw = calendar.component(.weekday, from: now)
        let mondayFirst = (raw + 5) % 7 + 1
        return Weekday(rawValue: mondayFirst)!
    }
}
