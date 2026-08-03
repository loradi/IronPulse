import CoreGraphics
import Foundation

/// Pure 2D geometry: the interior angle in degrees formed at `vertex`
/// between the rays to `a` and `b`. No framework dependency beyond
/// CoreGraphics - takes plain points so it is testable without Vision
/// or a camera.
enum AngleCalculator {
    static func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let vectorA = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let vectorB = CGVector(dx: b.x - vertex.x, dy: b.y - vertex.y)

        let dot = vectorA.dx * vectorB.dx + vectorA.dy * vectorB.dy
        let magnitudeA = (vectorA.dx * vectorA.dx + vectorA.dy * vectorA.dy).squareRoot()
        let magnitudeB = (vectorB.dx * vectorB.dx + vectorB.dy * vectorB.dy).squareRoot()

        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }

        let cosTheta = max(-1, min(1, dot / (magnitudeA * magnitudeB)))
        return acos(cosTheta) * 180 / .pi
    }
}
