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

    @Test func fillMatchingWeightsRellenaLosSetsEnCeroDelMismoEjercicio() {
        let editado = makeSet(0)
        let vacio1 = makeSet(1)
        let vacio2 = makeSet(2)
        let sets = [editado, vacio1, vacio2]
        GuidedSessionFlow.fillMatchingWeights(40, previousValue: 0, in: sets, editedSetID: editado.id)
        #expect(vacio1.weightKg == 40)
        #expect(vacio2.weightKg == 40)
    }

    @Test func fillMatchingWeightsNoSobreescribeUnSetConValorPropio() {
        let editado = makeSet(0)
        let dropSet = makeSet(1)
        dropSet.weightKg = 25
        let sets = [editado, dropSet]
        GuidedSessionFlow.fillMatchingWeights(40, previousValue: 0, in: sets, editedSetID: editado.id)
        #expect(dropSet.weightKg == 25)
    }

    @Test func fillMatchingWeightsNoTocaElSetEditado() {
        let editado = makeSet(0)
        editado.weightKg = 999
        GuidedSessionFlow.fillMatchingWeights(999, previousValue: 999, in: [editado], editedSetID: editado.id)
        #expect(editado.weightKg == 999)
    }

    @Test func fillMatchingWeightsRellenaSetsQueCompartianElPesoAnterior() {
        // Simula una sesion precargada con historial: los 3 sets ya
        // arrancan en 40 (no en 0). El usuario sube el set 1 a 45; los
        // sets 2 y 3, que seguian en 40 (el peso anterior del set
        // editado), deben subir tambien.
        let editado = makeSet(0)
        editado.weightKg = 40
        let hermano1 = makeSet(1)
        hermano1.weightKg = 40
        let hermano2 = makeSet(2)
        hermano2.weightKg = 40
        let sets = [editado, hermano1, hermano2]
        GuidedSessionFlow.fillMatchingWeights(45, previousValue: 40, in: sets, editedSetID: editado.id)
        #expect(hermano1.weightKg == 45)
        #expect(hermano2.weightKg == 45)
    }

    @Test func fillMatchingWeightsNoTocaUnDropSetQueYaEraDistintoDelPesoAnterior() {
        // El set 3 ya fue bajado a 30 (drop set) antes de este cambio -
        // no coincide con el peso anterior (40) del set editado, asi
        // que debe quedarse en 30.
        let editado = makeSet(0)
        editado.weightKg = 40
        let hermano = makeSet(1)
        hermano.weightKg = 40
        let dropSet = makeSet(2)
        dropSet.weightKg = 30
        let sets = [editado, hermano, dropSet]
        GuidedSessionFlow.fillMatchingWeights(45, previousValue: 40, in: sets, editedSetID: editado.id)
        #expect(hermano.weightKg == 45)
        #expect(dropSet.weightKg == 30)
    }

    @Test func commonWeightDevuelveElValorSiTodosCoinciden() {
        let a = makeSet(0)
        a.weightKg = 40
        let b = makeSet(1)
        b.weightKg = 40
        #expect(GuidedSessionFlow.commonWeight(of: [a, b]) == 40)
    }

    @Test func commonWeightEsNilSiNoTodosCoinciden() {
        let a = makeSet(0)
        a.weightKg = 40
        let b = makeSet(1)
        b.weightKg = 35
        #expect(GuidedSessionFlow.commonWeight(of: [a, b]) == nil)
    }

    @Test func commonWeightEsNilSiNingunoTienePeso() {
        #expect(GuidedSessionFlow.commonWeight(of: [makeSet(0), makeSet(1)]) == nil)
    }

    @Test func commonWeightEsNilConListaVacia() {
        #expect(GuidedSessionFlow.commonWeight(of: []) == nil)
    }
}
