import Foundation
import Testing
@testable import IronPulse

struct GuidedSessionFlowTests {

    private func makeSet(_ index: Int) -> SetLog {
        SetLog(
            exerciseId: "e1",
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
}
