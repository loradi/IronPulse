import Foundation

enum WorkoutGeneratorService {

    struct DayTemplate {
        let title: String
        let muscleGroups: [MuscleGroup]
    }

    static func splitType(for daysPerWeek: Int) -> SplitType {
        switch daysPerWeek {
        case ...2: return .fullBody
        case 3...4: return .upperLower
        default: return .pushPullLegs
        }
    }

    static func dayTemplates(split: SplitType, dayCount: Int) -> [DayTemplate] {
        let cycle: [DayTemplate]
        switch split {
        case .fullBody:
            cycle = [
                DayTemplate(title: "Cuerpo completo",
                            muscleGroups: [.chest, .back, .legs, .shoulders, .biceps, .triceps, .core])
            ]
        case .upperLower:
            cycle = [
                DayTemplate(title: "Torso",
                            muscleGroups: [.chest, .back, .shoulders, .biceps, .triceps]),
                DayTemplate(title: "Pierna",
                            muscleGroups: [.legs, .glutes, .core])
            ]
        case .pushPullLegs:
            cycle = [
                DayTemplate(title: "Empuje", muscleGroups: [.chest, .shoulders, .triceps]),
                DayTemplate(title: "Tiron", muscleGroups: [.back, .biceps]),
                DayTemplate(title: "Piernas", muscleGroups: [.legs, .glutes, .core])
            ]
        }

        return (0..<max(1, dayCount)).map { cycle[$0 % cycle.count] }
    }
}
