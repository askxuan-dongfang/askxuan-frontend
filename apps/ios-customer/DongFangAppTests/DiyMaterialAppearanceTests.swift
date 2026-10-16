import XCTest
import SceneKit
@testable import DongFangApp

@MainActor final class DiyMaterialAppearanceTests: XCTestCase {
    func testBundledReferenceMaterialsAndOpticalSeparation() throws {
        let wood = try XCTUnwrap(DiyMaterialAppearance.profile(id: 1, texture: nil, type: nil, finish: nil)?.1)
        let jade = try XCTUnwrap(DiyMaterialAppearance.profile(id: 4, texture: nil, type: nil, finish: nil)?.1)
        let crystal = try XCTUnwrap(DiyMaterialAppearance.profile(id: 12, texture: nil, type: nil, finish: nil)?.1)
        XCTAssertEqual(wood.transmission, 0)
        XCTAssertGreaterThan(crystal.transmission, jade.transmission + 0.5)
        for id in [Int64(1),3,4,5,6,7,12,21,24,25] {
            let image = try XCTUnwrap(DiyMaterialAppearance.image(id: id, texture: nil, type: nil, finish: nil, color: "#8a6b45"))
            XCTAssertEqual(image.cgImage?.width, 256)
            XCTAssertEqual(image.cgImage?.height, 256)
        }
        let environment = try XCTUnwrap(DiyMaterialAppearance.root?.appendingPathComponent("studio.hdr"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: environment.path))
    }
    func testBoredGeometryRetainsRequestedOutsideSize() {
        for shape in ["round","disc","barrel","faceted","pendant"] {
            let geometry = DiyMaterialAppearance.geometry(radius: 2, shape: shape)
            XCTAssertFalse(geometry.elements.isEmpty)
            XCTAssertGreaterThan(geometry.sources(for: .vertex).first?.vectorCount ?? 0, 100)
            XCTAssertLessThanOrEqual(geometry.boundingBox.max.x, 2.001)
            XCTAssertGreaterThanOrEqual(geometry.boundingBox.min.x, -2.001)
        }
    }
}
