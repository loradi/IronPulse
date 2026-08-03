import Foundation
import Testing
@testable import IronPulse

struct AngleCalculatorTests {
    @Test func rightAngleMeasuresNinetyDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let a = CGPoint(x: 1, y: 0)
        let b = CGPoint(x: 0, y: 1)
        #expect(abs(AngleCalculator.angle(at: vertex, from: a, to: b) - 90) < 0.001)
    }

    @Test func straightLineMeasuresOneHundredEightyDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let a = CGPoint(x: -1, y: 0)
        let b = CGPoint(x: 1, y: 0)
        #expect(abs(AngleCalculator.angle(at: vertex, from: a, to: b) - 180) < 0.001)
    }

    @Test func sameDirectionMeasuresZeroDegrees() {
        let vertex = CGPoint(x: 0, y: 0)
        let a = CGPoint(x: 1, y: 0)
        let b = CGPoint(x: 2, y: 0)
        #expect(abs(AngleCalculator.angle(at: vertex, from: a, to: b)) < 0.001)
    }

    @Test func degenerateSamePointReturnsZeroInsteadOfCrashing() {
        let point = CGPoint(x: 5, y: 5)
        #expect(AngleCalculator.angle(at: point, from: point, to: point) == 0)
    }
}
