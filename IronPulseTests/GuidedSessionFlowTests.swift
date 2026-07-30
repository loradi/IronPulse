import Foundation
import Testing
@testable import IronPulse

struct GuidedSessionFlowTests {

    private func makeSet(_ index: Int, exerciseId: String = "e1") -> SetLog {
        SetLog(
            exerciseId: exerciseId,
            setIndex: index,
            weightKg: 0,
            repsCompleted: 0,
            restSeconds: 60,
            targetRepsMin: 8,
            targetRepsMax: 12
        )
    }

    @Test func compuestoDescansaNoventaSegundos() {
        #expect(GuidedSessionFlow.restSeconds(isCompound: true) == 90)
    }

    @Test func aislamientoDescansaSesentaSegundos() {
        #expect(GuidedSessionFlow.restSeconds(isCompound: false) == 60)
    }

    @Test func avanzaAlSiguienteSetEnOrden() {
        let sets = [makeSet(0), makeSet(1), makeSet(2)]
        #expect(GuidedSessionFlow.nextSetID(after: sets[0].id, in: sets) == sets[1].id)
    }

    @Test func elUltimoSetNoTieneSiguiente() {
        let sets = [makeSet(0), makeSet(1)]
        #expect(GuidedSessionFlow.nextSetID(after: sets[1].id, in: sets) == nil)
    }

    @Test func sinSetActivoNoHaySiguiente() {
        let sets = [makeSet(0), makeSet(1)]
        #expect(GuidedSessionFlow.nextSetID(after: nil, in: sets) == nil)
    }

    @Test func idQueNoEstaEnLaListaNoTieneSiguiente() {
        let sets = [makeSet(0), makeSet(1)]
        let otro = makeSet(99)
        #expect(GuidedSessionFlow.nextSetID(after: otro.id, in: sets) == nil)
    }

    @Test func groupedSetsAgrupaPorEjercicioEnOrdenDeAparicion() {
        let sets = [makeSet(0, exerciseId: "a"), makeSet(1, exerciseId: "a"), makeSet(2, exerciseId: "b")]
        let groups = GuidedSessionFlow.groupedSets(sets)
        #expect(groups.map(\.exerciseId) == ["a", "b"])
        #expect(groups[0].sets.count == 2)
        #expect(groups[1].sets.count == 1)
    }

    @Test func groupedSetsOrdenaPorSetIndexAntesDeAgrupar() {
        let sets = [makeSet(2, exerciseId: "b"), makeSet(0, exerciseId: "a"), makeSet(1, exerciseId: "a")]
        let groups = GuidedSessionFlow.groupedSets(sets)
        #expect(groups.map(\.exerciseId) == ["a", "b"])
    }

    @Test func renumberedDejaLosSetIndexContiguosPorEjercicio() {
        let sets = [makeSet(0, exerciseId: "a"), makeSet(1, exerciseId: "a"), makeSet(2, exerciseId: "b")]
        let nuevo = SetLog(exerciseId: "a", setIndex: 99, weightKg: 0, repsCompleted: 0, restSeconds: 60, targetRepsMin: 8, targetRepsMax: 12)
        let todos = sets + [nuevo]
        GuidedSessionFlow.renumbered(todos, groupedBy: ["a", "b"])
        let ordenadosA = todos.filter { $0.exerciseId == "a" }.sorted { $0.setIndex < $1.setIndex }
        #expect(ordenadosA.map(\.setIndex) == [0, 1, 2])
        let ordenadosB = todos.filter { $0.exerciseId == "b" }
        #expect(ordenadosB.first?.setIndex == 3)
    }

    @Test func renumberedConUnSoloEjercicioYUnSoloSet() {
        let sets = [makeSet(5, exerciseId: "a")]
        GuidedSessionFlow.renumbered(sets, groupedBy: ["a"])
        #expect(sets[0].setIndex == 0)
    }

    @Test func canCompleteSetRequierePesoYRepsPositivos() {
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 20, repsCompleted: 10) == true)
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 0, repsCompleted: 10) == false)
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 20, repsCompleted: 0) == false)
        #expect(GuidedSessionFlow.canCompleteSet(weightKg: 0, repsCompleted: 0) == false)
    }

    @Test func elapsedSecondsCalculaDesdeElInicioHastaAhora() {
        let start = Date()
        let now = start.addingTimeInterval(12)
        #expect(GuidedSessionFlow.elapsedSeconds(since: start, now: now) == 12)
    }

    @Test func elapsedSecondsSobreviveUnaAppSuspendidaLargoTiempo() {
        // Simula la app suspendida en background durante 5 minutos: el
        // calculo debe reflejar el tiempo real transcurrido, no congelarse.
        let start = Date()
        let now = start.addingTimeInterval(300)
        #expect(GuidedSessionFlow.elapsedSeconds(since: start, now: now) == 300)
    }

    @Test func elapsedSecondsNuncaEsNegativo() {
        let start = Date()
        let now = start.addingTimeInterval(-5)
        #expect(GuidedSessionFlow.elapsedSeconds(since: start, now: now) == 0)
    }

    @Test func remainingSecondsCalculaHastaElFinal() {
        let now = Date()
        let end = now.addingTimeInterval(45)
        #expect(GuidedSessionFlow.remainingSeconds(until: end, now: now) == 45)
    }

    @Test func remainingSecondsSobreviveUnaAppSuspendidaMasAllaDelFinal() {
        // Si la app estuvo suspendida mas alla del fin del descanso, el
        // restante debe ser 0, no un valor negativo ni un valor congelado.
        let now = Date()
        let end = now.addingTimeInterval(-30)
        #expect(GuidedSessionFlow.remainingSeconds(until: end, now: now) == 0)
    }

    @Test func remainingSecondsRedondeaHaciaArriba() {
        let now = Date()
        let end = now.addingTimeInterval(10.2)
        #expect(GuidedSessionFlow.remainingSeconds(until: end, now: now) == 11)
    }
}
