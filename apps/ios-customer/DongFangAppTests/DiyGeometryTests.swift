import Foundation
import SceneKit
import Testing
@testable import DongFangApp

@MainActor
struct DiyGeometryTests {
    private func bead(diameter: Double, shape: String, id: Int64 = 1, spec: String? = nil) -> DiyBeadSlot {
        let category = ["pendant","tassel","three_way","buddha_head"].contains(shape) ? shape : "main_bead"
        let material = Material(id: id, name: id == 42 ? "和田玉平安扣" : "尺寸测试材料", spec: spec ?? "\(diameter)mm", unitPrice: 1, unit: "颗", category: category,
                                shape: shape, diameterMm: diameter, image: "", stock: 100, status: "on_shelf")
        return DiyBeadSlot(material: material, position: 0, slotId: "stable-\(id)")
    }
    @Test func everySharedAccessoryLoadsItsMeshAndMatchingThumbnail() throws {
        for kind in ["three_way","buddha_head","pendant_lotus","pendant_gourd","pendant_peace","pendant_woodfish","pendant_generic","tassel"] {
            let profile = try #require(DiyGeometry.profile(kind)), geometry = try #require(DiyMaterialAppearance.accessoryGeometry(kind))
            let image = try #require(DiyMaterialAppearance.accessoryThumbnail(kind))
            #expect((geometry.sources(for: .vertex).first?.vectorCount ?? 0) > 500)
            #expect(image.cgImage?.width == 160)
            #expect(Double(geometry.boundingBox.min.y) >= profile.minY - 0.015)
            #expect(Double(geometry.boundingBox.max.y) <= profile.maxY + 0.015)
            #expect(profile.anchors["left"]?.count == 3 && profile.anchors["right"]?.count == 3)
        }
    }
    @Test func barrelAndPendantDimensionsMatchWebFixtures() {
        #expect(DiyGeometry.dimensions(bead(diameter: 12, shape: "barrel", spec: "12×30mm")).pitchMm == 30)
        #expect(DiyGeometry.dimensions(bead(diameter: 6, shape: "disc")).pitchMm == 2.7)
        let pendant = bead(diameter: 18, shape: "pendant", id: 42)
        #expect(DiyGeometry.dimensions(pendant).kind == "pendant_peace")
        #expect(DiyGeometry.kind(shape: "pendant", category: "pendant", materialId: 11, name: "自定义挂件") == "pendant_generic")
        #expect(DiyGeometry.kind(shape: "pendant", category: "pendant", materialId: 999, name: "蓮花掛件") == "pendant_lotus")
        #expect(DiyGeometry.dimensions(pendant).pitchMm == 2)
        let base = (0..<18).map { _ in bead(diameter: 10, shape: "round") }
        let before = DiyPhysicalLayout(slots: base), after = DiyPhysicalLayout(slots: base + [pendant])
        #expect(after.innerMm > before.innerMm && after.innerMm - before.innerMm < 4)
    }
    @Test func mixedSizesRestOnOnePlaneAndCordFollowsBoreHeight() {
        for count in [0,1,2,6,60] {
            let slots = (0..<count).map { bead(diameter: [6,8,10,12][$0 % 4], shape: "round", id: Int64($0 + 1)) }
            let layout = DiyPhysicalLayout(slots: slots), points = DiyGeometry.cordPoints(slots: slots, layout: layout)
            #expect(points.first == points.last)
            #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            for slot in slots {
                #expect(DiyGeometry.dimensions(slot).centerHeightMm == slot.diameterMm / 2)
                #expect(points.contains { $0.y == slot.diameterMm / 2 })
            }
        }
    }
}
