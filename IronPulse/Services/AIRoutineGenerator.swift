import Foundation
import SwiftData

/// Servicio que simula un generador de rutinas con "IA" usando reglas heurísticas
/// basadas en el perfil del usuario y el catálogo de ejercicios de wger.de.
actor AIRoutineGenerator {
    private let wger: WgerAPIService

    init(wger: WgerAPIService = WgerAPIService()) {
        self.wger = wger
    }

    /// Genera y persiste una rutina en el `modelContext` para el perfil dado.
    /// - Parameters:
    ///   - profile: Perfil activo donde guardar la rutina.
    ///   - modelContext: Contexto de SwiftData donde insertar la rutina.
    ///   - days: número de días por semana para la rutina (si nil, usa profile.trainingDaysPerWeek)
    func generateRoutine(for profile: UserProfile, in modelContext: ModelContext, days: Int? = nil) async throws -> WorkoutRoutine {
        let daysCount = days ?? max(1, min(profile.trainingDaysPerWeek, 5))

        // Descargar ejercicios desde wger y aplicar filtros simples
        let exercises = try await wger.fetchExercises()

        // Agrupar por muscle group heurístico disponible en WgerExercise wrapper
        let grouped = Dictionary(grouping: exercises) { $0.primaryMuscleGroup }

        // Crear rutina
        let routineName = "Rutina IA - \(profile.fitnessGoal.displayName)"
        let routine = WorkoutRoutine(name: routineName, goal: profile.fitnessGoal, experienceLevel: profile.experienceLevel, daysPerWeek: daysCount)
        routine.profile = profile

        // Distribuir músculo objetivo por día: priorizar grandes grupos
        let preferredOrder: [MuscleGroup] = [.legs, .back, .chest, .shoulders, .arms, .core, .fullBody]
        var dayIndex = 0

        for i in 0..<daysCount {
            let dayTitle = "Día \(i + 1)"
            let routineDay = RoutineDay(title: dayTitle, dayIndex: i)

            // Seleccionar 4-6 ejercicios por día dependiendo del nivel
            let exercisesPerDay = exercisesPerDayFor(level: profile.experienceLevel)

            // Determinar target muscle for this day
            let targetGroup = preferredOrder[i % preferredOrder.count]
            let candidates = (grouped[targetGroup] ?? []) + (grouped[.fullBody] ?? [])

            // Fill with best matches + fallback random
            var chosen: [WgerExercise] = []
            chosen.append(contentsOf: candidates.shuffled().prefix(exercisesPerDay))
            if chosen.count < exercisesPerDay {
                chosen.append(contentsOf: exercises.shuffled().filter { !chosen.contains($0) }.prefix(exercisesPerDay - chosen.count))
            }

            // Convert chosen into RoutineExercise models
            for (idx, ex) in chosen.enumerated() {
                let repRange = repRangeFor(goal: profile.fitnessGoal, level: profile.experienceLevel)
                let sets = setsFor(goal: profile.fitnessGoal, level: profile.experienceLevel)
                let rest = restFor(level: profile.experienceLevel)
                let rpe = rpeFor(goal: profile.fitnessGoal)

                let routineExercise = RoutineExercise(
                    wgerExerciseID: ex.id,
                    name: ex.name,
                    muscleGroup: ex.primaryMuscleGroup,
                    equipment: ex.equipmentType,
                    sets: sets,
                    repRange: repRange,
                    targetRPE: rpe,
                    restSeconds: rest,
                    instructions: ex.cleanedDescription,
                    demoImageURL: ex.imageURL?.absoluteString,
                    orderIndex: idx
                )

                routineDay.exercises.append(routineExercise)
            }

            routine.days.append(routineDay)
            dayIndex += 1
        }

        // Persistir en el model context
        modelContext.insert(routine)
        profile.routines.append(routine)

        try modelContext.save()

        return routine
    }

    // MARK: - Heuristics

    private func exercisesPerDayFor(level: ExperienceLevel) -> Int {
        switch level {
        case .beginner: return 4
        case .intermediate: return 5
        case .advanced: return 6
        }
    }

    private func setsFor(goal: FitnessGoal, level: ExperienceLevel) -> Int {
        switch (goal, level) {
        case (.strength, .advanced): return 5
        case (.strength, _): return 4
        case (.muscleGain, _): return 3
        default: return 3
        }
    }

    private func repRangeFor(goal: FitnessGoal, level: ExperienceLevel) -> String {
        switch goal {
        case .strength: return "3-6"
        case .muscleGain: return "6-12"
        case .fatLoss: return "8-15"
        default: return "6-12"
        }
    }

    private func restFor(level: ExperienceLevel) -> Int {
        switch level {
        case .beginner: return 60
        case .intermediate: return 90
        case .advanced: return 120
        }
    }

    private func rpeFor(goal: FitnessGoal) -> Int {
        switch goal {
        case .strength: return 8
        case .muscleGain: return 7
        case .fatLoss: return 6
        default: return 7
        }
    }
}
