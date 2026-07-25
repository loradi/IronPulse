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
}
