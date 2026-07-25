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

    struct Prescription {
        let sets: Int
        let repsMin: Int
        let repsMax: Int
        let restSeconds: Int
    }

    static func prescription(goal: PrimaryGoal, level: ExperienceLevel) -> Prescription {
        switch goal {
        case .strength:
            return Prescription(sets: level == .advanced ? 5 : 4, repsMin: 3, repsMax: 6, restSeconds: 150)
        case .hypertrophy:
            return Prescription(sets: level == .beginner ? 3 : 4, repsMin: 8, repsMax: 12, restSeconds: 75)
        case .fatLoss:
            return Prescription(sets: 3, repsMin: 12, repsMax: 15, restSeconds: 40)
        }
    }

    static func exercisesPerDay(for level: ExperienceLevel) -> Int {
        switch level {
        case .beginner: return 4
        case .intermediate: return 5
        case .advanced: return 6
        }
    }

    static func generateRoutine(for profile: UserProfile, catalog: [Exercise]) -> WorkoutRoutine {
        let split = splitType(for: profile.workoutDaysPerWeek)
        let templates = dayTemplates(split: split, dayCount: profile.workoutDaysPerWeek)
        let plan = prescription(goal: profile.primaryGoal, level: profile.experienceLevel)
        let perDay = exercisesPerDay(for: profile.experienceLevel)

        let routine = WorkoutRoutine(
            name: "Rutina personalizada - \(profile.primaryGoal.displayName)",
            splitType: split,
            isGeneratedByAI: false,
            isActive: true
        )

        for (index, template) in templates.enumerated() {
            let picked = selectExercises(for: template, from: catalog, limit: perDay)
            let day = RoutineDay(dayNumber: index + 1, title: template.title)

            // Solo se asigna el lado "coleccion" de cada relacion: SwiftData completa
            // el inverso (RoutineExercise.day, RoutineDay.routine) al insertar.
            // Setear ambos lados a mano puede duplicar entradas.
            day.exercises = picked.enumerated().map { position, exercise in
                RoutineExercise(
                    exercise: exercise,
                    targetSets: plan.sets,
                    targetRepsMin: plan.repsMin,
                    targetRepsMax: plan.repsMax,
                    restSeconds: plan.restSeconds,
                    orderIndex: position
                )
            }

            routine.days.append(day)
        }

        return routine
    }

    /// Compuestos primero, aislamiento despues, y todo el core al final del dia
    /// sin importar si el movimiento es compuesto.
    private static func selectExercises(
        for template: DayTemplate,
        from catalog: [Exercise],
        limit: Int
    ) -> [Exercise] {
        let candidates = catalog.filter { template.muscleGroups.contains($0.muscleGroup) }

        let compounds = candidates.filter { $0.isCompound && $0.muscleGroup != .core }.shuffled()
        let isolation = candidates.filter { !$0.isCompound && $0.muscleGroup != .core }.shuffled()
        let core = candidates.filter { $0.muscleGroup == .core }.shuffled()

        return Array((compounds + isolation + core).prefix(limit))
    }
}
