import Foundation
import Testing
@testable import IronPulse

struct WorkoutStatsServiceTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeSet(exerciseId: String, weightKg: Double, reps: Int, completed: Bool = true) -> SetLog {
        SetLog(
            exerciseId: exerciseId,
            setIndex: 0,
            weightKg: weightKg,
            repsCompleted: reps,
            restSeconds: 60,
            targetRepsMin: 8,
            targetRepsMax: 12,
            isCompleted: completed
        )
    }

    private func makeLog(start: Date, finished: Bool, sets: [SetLog]) -> WorkoutLog {
        let log = WorkoutLog(startDate: start, endDate: finished ? start : nil, routineName: "R", dayTitle: "D")
        log.completedSets = sets
        return log
    }

    // MARK: - totalVolumeKg / workoutCount

    @Test func sumaSoloSetsCompletadosDeSesionesTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [
                makeSet(exerciseId: "e1", weightKg: 100, reps: 5),
                makeSet(exerciseId: "e1", weightKg: 50, reps: 10, completed: false)
            ]),
            makeLog(start: day(2026, 7, 2), finished: false, sets: [
                makeSet(exerciseId: "e1", weightKg: 999, reps: 999)
            ])
        ]
        #expect(WorkoutStatsService.totalVolumeKg(logs) == 500)
    }

    @Test func sinLogsElVolumenYElConteoSonCero() {
        #expect(WorkoutStatsService.totalVolumeKg([]) == 0)
        #expect(WorkoutStatsService.workoutCount([]) == 0)
    }

    @Test func workoutCountSoloCuentaSesionesTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: []),
            makeLog(start: day(2026, 7, 2), finished: true, sets: []),
            makeLog(start: day(2026, 7, 3), finished: false, sets: [])
        ]
        #expect(WorkoutStatsService.workoutCount(logs) == 2)
    }

    // MARK: - currentStreak

    @Test func sinDiasAsignadosLaRachaEsCero() {
        #expect(WorkoutStatsService.currentStreak(scheduledWeekdays: [], logs: [], today: day(2026, 7, 27)) == 0)
    }

    @Test func rachaPerfectaCuentaLosDiasAsignadosCompletados() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: []),
            makeLog(start: day(2026, 7, 29), finished: true, sets: []),
            makeLog(start: day(2026, 7, 31), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: logs,
            today: day(2026, 7, 31),
            calendar: calendar
        )
        #expect(streak == 3)
    }

    @Test func diaAsignadoSinSesionCortaLaRacha() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: []),
            makeLog(start: day(2026, 7, 31), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: logs,
            today: day(2026, 7, 31),
            calendar: calendar
        )
        #expect(streak == 1)
    }

    @Test func diaDeDescansoNoAsignadoNoCortaLaRacha() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday],
            logs: logs,
            today: day(2026, 7, 28),
            calendar: calendar
        )
        #expect(streak == 1)
    }

    @Test func diaAsignadoDeHoySinSesionNoRompeLaRachaPrevia() {
        let logs = [
            makeLog(start: day(2026, 7, 27), finished: true, sets: []),
            makeLog(start: day(2026, 7, 29), finished: true, sets: [])
        ]
        let streak = WorkoutStatsService.currentStreak(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: logs,
            today: day(2026, 7, 31),
            calendar: calendar
        )
        #expect(streak == 2)
    }

    // MARK: - dailyVolume

    @Test func dailyVolumeSiempreDevuelveLaCantidadDeDiasPedida() {
        let points = WorkoutStatsService.dailyVolume([], lastDays: 30, today: day(2026, 7, 31), calendar: calendar)
        #expect(points.count == 30)
        #expect(points.allSatisfy { $0.volumeKg == 0 })
    }

    @Test func dailyVolumeSumaVariasSesionesElMismoDia() {
        let logs = [
            makeLog(start: day(2026, 7, 31), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 100, reps: 5)]),
            makeLog(start: day(2026, 7, 31), finished: true, sets: [makeSet(exerciseId: "e2", weightKg: 50, reps: 10)])
        ]
        let points = WorkoutStatsService.dailyVolume(logs, lastDays: 7, today: day(2026, 7, 31), calendar: calendar)
        #expect(points.last?.volumeKg == 1000)
        #expect(points.last?.date == day(2026, 7, 31))
    }

    // MARK: - progress(for:in:)

    @Test func progresoTomaElPesoMaximoDelDia() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [
                makeSet(exerciseId: "e1", weightKg: 60, reps: 8),
                makeSet(exerciseId: "e1", weightKg: 65, reps: 6),
                makeSet(exerciseId: "otro", weightKg: 999, reps: 1)
            ])
        ]
        let points = WorkoutStatsService.progress(for: "e1", in: logs, calendar: calendar)
        #expect(points.count == 1)
        #expect(points.first?.maxWeightKg == 65)
    }

    @Test func progresoIgnoraSesionesNoTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: false, sets: [
                makeSet(exerciseId: "e1", weightKg: 999, reps: 1)
            ])
        ]
        #expect(WorkoutStatsService.progress(for: "e1", in: logs).isEmpty)
    }

    // MARK: - weekStrip

    @Test func testTiraSemanalMarcaCompletadoPendienteYNoProgramado() {
        // "hoy" fijo: miercoles 2026-07-29 (Weekday.wednesday = 3)
        let today = day(2026, 7, 29)
        let monday = day(2026, 7, 27)
        let log = makeLog(start: monday, finished: true, sets: [])

        let result = WorkoutStatsService.weekStrip(
            scheduledWeekdays: [.monday, .wednesday, .friday],
            logs: [log],
            today: today,
            calendar: calendar
        )

        #expect(result.count == 7)
        #expect(result[0].weekday == .monday)
        #expect(result[0].status == .completed)
        #expect(result[1].status == .notScheduled) // martes, no programado
        #expect(result[2].weekday == .wednesday)
        #expect(result[2].status == .pending) // hoy, programado, sin log
        #expect(result[2].isToday)
        #expect(result[4].weekday == .friday)
        #expect(result[4].status == .pending) // futuro, programado, sin log todavia
        #expect(result[5].status == .notScheduled) // sabado
    }

    @Test func testTiraSemanalSinDiasProgramadosQuedaTodaVacia() {
        let result = WorkoutStatsService.weekStrip(scheduledWeekdays: [], logs: [])
        #expect(result.allSatisfy { $0.status == .notScheduled })
    }

    // MARK: - todaysCompletedLog

    @Test func todaysCompletedLogEncuentraElLogDeHoyTerminado() {
        let today = Date()
        let log = WorkoutLog(startDate: today, endDate: today, routineName: "R", dayTitle: "D")
        #expect(WorkoutStatsService.todaysCompletedLog(logs: [log], today: today, calendar: calendar) != nil)
    }

    @Test func todaysCompletedLogIgnoraLogsSinTerminar() {
        let today = Date()
        let log = WorkoutLog(startDate: today, endDate: nil, routineName: "R", dayTitle: "D")
        #expect(WorkoutStatsService.todaysCompletedLog(logs: [log], today: today, calendar: calendar) == nil)
    }

    @Test func todaysCompletedLogIgnoraLogsDeOtroDia() {
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let log = WorkoutLog(startDate: yesterday, endDate: yesterday, routineName: "R", dayTitle: "D")
        #expect(WorkoutStatsService.todaysCompletedLog(logs: [log], today: today, calendar: calendar) == nil)
    }

    // MARK: - mostRecentWeights

    @Test func mostRecentWeightsTomaElPesoDeLaSesionMasReciente() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 40, reps: 8)]),
            makeLog(start: day(2026, 7, 8), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 45, reps: 8)])
        ]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == 45)
    }

    @Test func mostRecentWeightsIgnoraSesionesNoTerminadas() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [makeSet(exerciseId: "e1", weightKg: 40, reps: 8)]),
            makeLog(start: day(2026, 7, 8), finished: false, sets: [makeSet(exerciseId: "e1", weightKg: 999, reps: 8)])
        ]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == 40)
    }

    @Test func mostRecentWeightsIgnoraSetsNoCompletadosOEnCero() {
        let logs = [
            makeLog(start: day(2026, 7, 1), finished: true, sets: [
                makeSet(exerciseId: "e1", weightKg: 999, reps: 8, completed: false),
                makeSet(exerciseId: "e1", weightKg: 0, reps: 8)
            ])
        ]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == nil)
    }

    @Test func mostRecentWeightsSinHistorialQuedaVacio() {
        #expect(WorkoutStatsService.mostRecentWeights(in: []).isEmpty)
    }

    @Test func mostRecentWeightsUsaElPrimerSetPorSetIndexDeLaSesionMasReciente() {
        let sets = [
            makeSet(exerciseId: "e1", weightKg: 50, reps: 6),
            makeSet(exerciseId: "e1", weightKg: 45, reps: 8)
        ]
        sets[0].setIndex = 1
        sets[1].setIndex = 0
        let logs = [makeLog(start: day(2026, 7, 1), finished: true, sets: sets)]
        #expect(WorkoutStatsService.mostRecentWeights(in: logs)["e1"] == 45)
    }
}
