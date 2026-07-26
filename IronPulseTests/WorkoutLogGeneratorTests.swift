import Foundation
import Testing
@testable import IronPulse

struct WorkoutLogGeneratorTests {

    private func makeExercise(_ id: String, _ name: String) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: .chest,
            equipment: .barbell,
            instructions: ["Paso uno."],
            gifFileName: "\(id).gif"
        )
    }

    private func makeDay() -> RoutineDay {
        let day = RoutineDay(dayNumber: 1, title: "Torso")
        let ex1 = RoutineExercise(
            exercise: makeExercise("e1", "Press plano"),
            targetSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 90,
            orderIndex: 0
        )
        let ex2 = RoutineExercise(
            exercise: makeExercise("e2", "Remo con barra"),
            targetSets: 2,
            targetRepsMin: 6,
            targetRepsMax: 10,
            restSeconds: 120,
            orderIndex: 1
        )
        day.exercises = [ex1, ex2]
        return day
    }

    private func makeProfile() -> UserProfile {
        UserProfile(name: "Test", age: 30, weightKg: 70, heightCm: 170)
    }

    @Test func generaUnSetLogPorCadaSerieObjetivo() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        #expect(log.completedSets.count == 5)
    }

    @Test func copiaRestSecondsYTargetsDelEjercicio() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())

        let primerEjercicio = log.completedSets.filter { $0.exerciseId == "e1" }
        #expect(primerEjercicio.count == 3)
        #expect(primerEjercicio.allSatisfy { $0.restSeconds == 90 && $0.targetRepsMin == 8 && $0.targetRepsMax == 12 })

        let segundoEjercicio = log.completedSets.filter { $0.exerciseId == "e2" }
        #expect(segundoEjercicio.count == 2)
        #expect(segundoEjercicio.allSatisfy { $0.restSeconds == 120 && $0.targetRepsMin == 6 && $0.targetRepsMax == 10 })
    }

    @Test func setIndexEsCrecienteSinReiniciarPorEjercicio() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        let indices = log.completedSets.sorted { $0.setIndex < $1.setIndex }.map(\.setIndex)
        #expect(indices == [0, 1, 2, 3, 4])
    }

    @Test func copiaNombreDeRutinaYTituloDeDia() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        #expect(log.routineName == "Rutina de prueba")
        #expect(log.dayTitle == "Torso")
    }

    @Test func losSetsArrancanSinCompletarYEnCero() {
        let log = WorkoutLogGenerator.generate(for: makeDay(), routineName: "Rutina de prueba", profile: makeProfile())
        #expect(log.completedSets.allSatisfy { !$0.isCompleted && $0.weightKg == 0 && $0.repsCompleted == 0 })
    }
}
