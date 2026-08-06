import CoreGraphics
import Testing
@testable import IronPulse

struct CameraPreviewViewTests {
    @Test func unrotatedPointMapsPortraitVisualTopLeftToUnrotatedBottomLeft() {
        // Vision's (0, 1) is the visual top-left of the portrait image
        // (x=0 is visual left, y=1 is visual top under Vision's
        // bottom-left/y-up convention).
        #expect(unrotatedPoint(fromPortraitVisionPoint: CGPoint(x: 0, y: 1)) == CGPoint(x: 0, y: 1))
    }

    @Test func unrotatedPointMapsPortraitCenterToUnrotatedCenter() {
        let center = CGPoint(x: 0.5, y: 0.5)
        #expect(unrotatedPoint(fromPortraitVisionPoint: center) == center)
    }

    @Test func unrotatedPointMapsPortraitVisualTopRightToUnrotatedTopLeft() {
        // Vision's (1, 1) is the visual top-right of the portrait image.
        #expect(unrotatedPoint(fromPortraitVisionPoint: CGPoint(x: 1, y: 1)) == CGPoint(x: 0, y: 0))
    }

    @Test func unrotatedPointMapsPortraitVisualBottomLeftToUnrotatedBottomRight() {
        // Vision's (0, 0) is the visual bottom-left of the portrait image.
        #expect(unrotatedPoint(fromPortraitVisionPoint: CGPoint(x: 0, y: 0)) == CGPoint(x: 1, y: 1))
    }
}
