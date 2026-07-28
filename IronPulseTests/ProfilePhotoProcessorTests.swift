import XCTest
@testable import IronPulse

final class ProfilePhotoProcessorTests: XCTestCase {
    private func syntheticImage(size: CGSize, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testImagenCuadradaDaResultado512x512() {
        let image = syntheticImage(size: CGSize(width: 800, height: 800))
        let data = resizedProfilePhotoData(from: image)

        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(decoded?.size, CGSize(width: 512, height: 512))
    }

    func testImagenRectangularTambienDaResultado512x512() {
        let image = syntheticImage(size: CGSize(width: 1200, height: 600))
        let data = resizedProfilePhotoData(from: image)

        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(decoded?.size, CGSize(width: 512, height: 512))
    }

    func testTargetSizePersonalizadoSeRespeta() {
        let image = syntheticImage(size: CGSize(width: 300, height: 300))
        let data = resizedProfilePhotoData(from: image, targetSize: 128)

        XCTAssertNotNil(data)
        let decoded = UIImage(data: data!)
        XCTAssertEqual(decoded?.size, CGSize(width: 128, height: 128))
    }

    func testImagenConAnchoOAltoCeroDevuelveNil() {
        let image = syntheticImage(size: CGSize(width: 0, height: 100))
        XCTAssertNil(resizedProfilePhotoData(from: image))
    }
}
