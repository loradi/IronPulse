import Foundation
import Testing
@testable import IronPulse

struct WorkoutGeneratorServiceTests {

    @Test func splitEsFullBodyHastaDosDias() {
        #expect(WorkoutGeneratorService.splitType(for: 1) == .fullBody)
        #expect(WorkoutGeneratorService.splitType(for: 2) == .fullBody)
    }

    @Test func splitEsUpperLowerConTresOCuatroDias() {
        #expect(WorkoutGeneratorService.splitType(for: 3) == .upperLower)
        #expect(WorkoutGeneratorService.splitType(for: 4) == .upperLower)
    }

    @Test func splitEsPushPullLegsConCincoOMas() {
        #expect(WorkoutGeneratorService.splitType(for: 5) == .pushPullLegs)
        #expect(WorkoutGeneratorService.splitType(for: 7) == .pushPullLegs)
    }

    @Test func upperLowerAlternaTorsoYPierna() {
        let templates = WorkoutGeneratorService.dayTemplates(split: .upperLower, dayCount: 4)
        #expect(templates.map(\.title) == ["Torso", "Pierna", "Torso", "Pierna"])
    }

    @Test func pushPullLegsCiclaLosTresDias() {
        let templates = WorkoutGeneratorService.dayTemplates(split: .pushPullLegs, dayCount: 5)
        #expect(templates.map(\.title) == ["Empuje", "Tiron", "Piernas", "Empuje", "Tiron"])
    }

    @Test func fullBodyRepiteElMismoDia() {
        let templates = WorkoutGeneratorService.dayTemplates(split: .fullBody, dayCount: 2)
        #expect(templates.map(\.title) == ["Cuerpo completo", "Cuerpo completo"])
    }

    // MARK: - Helpers

    private func makeExercise(
        _ id: String,
        _ name: String,
        _ group: MuscleGroup,
        compound: Bool
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            muscleGroup: group,
            equipment: .barbell,
            isCompound: compound,
            instructions: ["Paso uno."],
            gifFileName: "\(id).gif"
        )
    }

    private func makeCatalog() -> [Exercise] {
        [
            makeExercise("c1", "Press plano", .chest, compound: true),
            makeExercise("c2", "Press inclinado", .chest, compound: true),
            makeExercise("c3", "Aperturas", .chest, compound: false),
            makeExercise("b1", "Remo con barra", .back, compound: true),
            makeExercise("b2", "Jalon al pecho", .back, compound: true),
            makeExercise("b3", "Pullover", .back, compound: false),
            makeExercise("l1", "Sentadilla", .legs, compound: true),
            makeExercise("l2", "Prensa", .legs, compound: true),
            makeExercise("l3", "Extension de piernas", .legs, compound: false),
            makeExercise("s1", "Press militar", .shoulders, compound: true),
            makeExercise("s2", "Elevaciones laterales", .shoulders, compound: false),
            makeExercise("bi1", "Curl con barra", .biceps, compound: false),
            makeExercise("tr1", "Extension de triceps", .triceps, compound: false),
            makeExercise("g1", "Puente de gluteos", .glutes, compound: true),
            makeExercise("co1", "Plancha", .core, compound: false),
            makeExercise("co2", "Crunch", .core, compound: false)
        ]
    }

    private func makeProfile(
        level: ExperienceLevel = .intermediate,
        goal: PrimaryGoal = .hypertrophy,
        days: Int = 4
    ) -> UserProfile {
        UserProfile(
            name: "Test",
            age: 30,
            weightKg: 70,
            heightCm: 170,
            experienceLevel: level,
            primaryGoal: goal,
            workoutDaysPerWeek: days
        )
    }

    // MARK: - Prescripcion

    @Test func fuerzaUsaSeriesAltasYRepsBajas() {
        let p = WorkoutGeneratorService.prescription(goal: .strength, level: .intermediate)
        #expect(p.sets == 4)
        #expect(p.repsMin == 3)
        #expect(p.repsMax == 6)
        #expect(p.restSeconds == 150)
    }

    @Test func fuerzaAvanzadoSumaUnaSerie() {
        let p = WorkoutGeneratorService.prescription(goal: .strength, level: .advanced)
        #expect(p.sets == 5)
    }

    @Test func hipertrofiaUsaRango8a12() {
        let p = WorkoutGeneratorService.prescription(goal: .hypertrophy, level: .beginner)
        #expect(p.repsMin == 8)
        #expect(p.repsMax == 12)
        #expect(p.restSeconds == 75)
    }

    @Test func perdidaDeGrasaUsaRepsAltasYDescansoCorto() {
        let p = WorkoutGeneratorService.prescription(goal: .fatLoss, level: .intermediate)
        #expect(p.sets == 3)
        #expect(p.repsMin == 12)
        #expect(p.repsMax == 15)
        #expect(p.restSeconds == 40)
    }

    // MARK: - Generacion completa

    @Test func generaUnDiaPorCadaDiaDeEntrenamiento() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(days: 4), catalog: makeCatalog()
        )
        #expect(routine.days.count == 4)
        #expect(routine.splitType == .upperLower)
    }

    @Test func cantidadDeEjerciciosPorDiaSegunNivel() {
        let catalog = makeCatalog()
        let principiante = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .beginner), catalog: catalog
        )
        let avanzado = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced), catalog: catalog
        )
        #expect(principiante.days[0].exercises.count == 4)
        #expect(avanzado.days[0].exercises.count == 6)
    }

    @Test func noRepiteEjerciciosDentroDelMismoDia() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced), catalog: makeCatalog()
        )
        for day in routine.days {
            let ids = day.exercises.map(\.exercise.id)
            #expect(ids.count == Set(ids).count)
        }
    }

    @Test func losCompuestosVanAntesQueLosDeAislamiento() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced, days: 3), catalog: makeCatalog()
        )
        for day in routine.days {
            let ordenados = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
            // Ignorando core (que siempre va al final), ningun aislamiento precede a un compuesto.
            let sinCore = ordenados.filter { $0.exercise.muscleGroup != .core }
            let primerAislamiento = sinCore.firstIndex(where: { !$0.exercise.isCompound })
            #expect(primerAislamiento != nil, "el dia deberia tener al menos un ejercicio de aislamiento")
            if let primerAislamiento {
                let despues = sinCore[primerAislamiento...]
                #expect(despues.allSatisfy { !$0.exercise.isCompound })
            }
        }
    }

    @Test func elCoreVaAlFinalDelDia() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(level: .advanced, days: 3), catalog: makeCatalog()
        )
        // days: 3 -> split upperLower -> ciclo Torso, Pierna, Torso. Solo Pierna
        // incluye .core en su template, asi que solo ahi exigimos que aparezca.
        let templates = WorkoutGeneratorService.dayTemplates(split: .upperLower, dayCount: 3)
        for (day, template) in zip(routine.days, templates) {
            let ordenados = day.exercises.sorted { $0.orderIndex < $1.orderIndex }
            let primerCore = ordenados.firstIndex(where: { $0.exercise.muscleGroup == .core })
            if template.muscleGroups.contains(.core) {
                #expect(primerCore != nil, "el dia deberia incluir al menos un ejercicio de core")
            }
            if let primerCore {
                let despues = ordenados[primerCore...]
                #expect(despues.allSatisfy { $0.exercise.muscleGroup == .core })
            }
        }
    }

    @Test func laPrescripcionDelObjetivoSeAplicaACadaEjercicio() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(goal: .fatLoss), catalog: makeCatalog()
        )
        let todos = routine.days.flatMap(\.exercises)
        #expect(!todos.isEmpty)
        #expect(todos.allSatisfy { $0.targetSets == 3 && $0.targetRepsMin == 12 && $0.restSeconds == 40 })
    }

    @Test func elNombreDeLaRutinaNoMencionaIA() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(goal: .strength), catalog: makeCatalog()
        )
        #expect(routine.name == "Rutina personalizada - Fuerza")
        #expect(!routine.name.contains("IA"))
    }

    @Test func catalogoVacioDevuelveRutinaSinEjercicios() {
        let routine = WorkoutGeneratorService.generateRoutine(
            for: makeProfile(), catalog: []
        )
        #expect(routine.days.count == 4)
        #expect(routine.days.allSatisfy { $0.exercises.isEmpty })
    }

    @Test func todosLosGruposDelTemplateAparecenConElCatalogoReal() throws {
        let catalog = try loadRealCatalog()
        for split in SplitType.allCases {
            for level in ExperienceLevel.allCases {
                let days = split == .fullBody ? 2 : (split == .upperLower ? 4 : 6)
                let profile = makeProfile(level: level, days: days)
                let routine = WorkoutGeneratorService.generateRoutine(for: profile, catalog: catalog)
                // dayCount: days (no 1) para que el ciclo completo se alinee con routine.days
                // por posicion - con dayCount: 1 siempre se compara contra el primer template
                // del ciclo y dias como "Pierna"/"Piernas" (los que incluyen core) nunca se verifican.
                let templates = WorkoutGeneratorService.dayTemplates(split: split, dayCount: days)
                let limit = WorkoutGeneratorService.exercisesPerDay(for: level)
                for (day, template) in zip(routine.days, templates) {
                    // Si el template pide mas grupos musculares que cupos disponibles, es
                    // matematicamente imposible cubrirlos todos - no es un defecto del fix.
                    guard template.muscleGroups.count <= limit else { continue }
                    let gruposPresentes = Set(day.exercises.map(\.exercise.muscleGroup))
                    let gruposEsperados = Set(template.muscleGroups)
                    let faltantes = gruposEsperados.subtracting(gruposPresentes)
                    #expect(faltantes.isEmpty, "\(template.title): faltan los grupos \(faltantes) con nivel \(level)")
                }
            }
        }
    }

    private func loadRealCatalog() throws -> [Exercise] {
        let url = try #require(Bundle.main.url(forResource: "ExercisesSeed", withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ExerciseSeedDTO].self, from: data).map { $0.toModel() }
    }

    // MARK: - Dias de la semana

    @Test func weekdaysForCountDevuelveLaTablaCorrecta() {
        #expect(WorkoutGeneratorService.weekdaysForCount(1) == [.monday])
        #expect(WorkoutGeneratorService.weekdaysForCount(2) == [.monday, .thursday])
        #expect(WorkoutGeneratorService.weekdaysForCount(3) == [.monday, .wednesday, .friday])
        #expect(WorkoutGeneratorService.weekdaysForCount(4) == [.monday, .tuesday, .thursday, .friday])
        #expect(WorkoutGeneratorService.weekdaysForCount(5) == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(WorkoutGeneratorService.weekdaysForCount(6) == [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
        #expect(WorkoutGeneratorService.weekdaysForCount(7) == Weekday.allCases)
    }

    @Test func cadaCountDevuelveLaCantidadDeDiasPedida() {
        for count in 1...7 {
            #expect(WorkoutGeneratorService.weekdaysForCount(count).count == count)
        }
    }

    @Test func generateRoutineAsignaLosWeekdaysEnOrden() {
        let routine = WorkoutGeneratorService.generateRoutine(for: makeProfile(days: 3), catalog: makeCatalog())
        let sortedDays = routine.days.sorted { $0.dayNumber < $1.dayNumber }
        #expect(sortedDays.map(\.weekday) == [.monday, .wednesday, .friday])
    }
}
