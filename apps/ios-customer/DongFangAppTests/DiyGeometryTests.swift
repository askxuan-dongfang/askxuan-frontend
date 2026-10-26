import Foundation
import SceneKit
import simd
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
        for kind in ["three_way","buddha_head","pendant_lotus","pendant_gourd","pendant_peace","pendant_woodfish","pendant_generic","tassel","tassel_knot"] {
            let profile = try #require(DiyGeometry.profile(kind)), geometry = try #require(DiyMaterialAppearance.accessoryGeometry(kind))
            let image = try #require(DiyMaterialAppearance.accessoryThumbnail(kind))
            #expect((geometry.sources(for: .vertex).first?.vectorCount ?? 0) > 500)
            #expect(image.cgImage?.width == 160)
            #expect(Double(geometry.boundingBox.min.y) >= profile.minY - 0.015)
            #expect(Double(geometry.boundingBox.max.y) <= profile.maxY + 0.015)
            #expect(profile.anchors["left"]?.count == 3 && profile.anchors["right"]?.count == 3)
        }
    }
    @Test func dragEnvelopeUsesCurvedMeshInsteadOfRotatedBoxCorners() throws {
        let sphere = DiyMaterialAppearance.geometry(radius: 1, shape: "round")
        let vertices = DiyMaterialAppearance.vertices(of: sphere)
        #expect(vertices.count == sphere.sources(for: .vertex).first?.vectorCount)
        let projected = vertices.map { CGPoint(x: CGFloat(($0.x + $0.y) / sqrt(2)) * 100, y: CGFloat($0.z) * 100) }
        let envelope = DiyDragEnvelope(points: projected)
        #expect(envelope.distance(to: CGPoint(x: 125, y: 0)) > 24)
        let box = sphere.boundingBox
        let corners = [box.min.x, box.max.x].flatMap { x in [box.min.y, box.max.y].flatMap { y in [box.min.z, box.max.z].map { z in
            CGPoint(x: CGFloat((x + y) / sqrt(2)) * 100, y: CGFloat(z) * 100)
        } } }
        #expect(DiyDragEnvelope(points: corners).distance(to: CGPoint(x: 125, y: 0)) == 0)
        for kind in ["pendant_peace", "pendant_lotus", "three_way", "buddha_head", "tassel"] {
            let mesh = try #require(DiyMaterialAppearance.accessoryGeometry(kind))
            #expect(DiyMaterialAppearance.vertices(of: mesh).count == mesh.sources(for: .vertex).first?.vectorCount)
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
    @Test func hangingKeepsGravityIndependentOfSlotAndLeavesPhysicalFitUnchanged() throws {
        let slots = [bead(diameter: 10, shape: "round"), bead(diameter: 18, shape: "pendant", id: 42)]
        let layout = DiyPhysicalLayout(slots: slots)
        #expect(DiyPresentation.mode(selection: nil, slots: slots) == .hanging)
        #expect(DiyPresentation.mode(selection: nil, slots: [slots[0]]) == .flat)
        #expect(DiyPresentation.mode(selection: .flat, slots: slots) == .flat)
        #expect(DiyPresentation.mode(selection: .hanging, slots: [slots[0]]) == .hanging)
        for angle in stride(from: 0.0, to: 2 * .pi, by: 0.3) {
            for kind in ["pendant_peace", "tassel", "tassel_knot"] {
                let down = DiyPresentation.orientation(angle: angle, kind: kind, mode: .hanging).act(SIMD3<Float>(0, 0, 1))
                #expect(simd_distance(down, SIMD3(0, -1, 0)) < 0.00001)
            }
        }
        let points = DiyGeometry.cordPoints(slots: slots, layout: layout).map { DiyPresentation.point($0, mode: .hanging) }
        #expect(points.allSatisfy { $0.z == 0 })
        #expect(DiyPhysicalLayout(slots: slots).innerMm == layout.innerMm)
        for name in ["中国结流苏", "中國結流蘇"] {
            #expect(DiyGeometry.kind(shape: "tassel", category: "tassel", materialId: 44, name: name) == "tassel_knot")
        }
        let profile = try #require(DiyGeometry.profile("tassel_knot"))
        #expect(profile.anchors["mount"]?[2] == profile.minZ)
        #expect(profile.connectorRatio == 0.12)
    }
    @Test func hangingSwingSettlesAndHonorsReducedMotionAndDragging() {
        let active = DiyPresentation.swing(elapsed: 0.1, identity: "stable-44", reducedMotion: false)
        #expect(simd_length(active) > 0)
        for time in stride(from: 0.0, to: 3.1, by: 0.01) {
            #expect(simd_length(DiyPresentation.swing(elapsed: time, identity: "stable-44", reducedMotion: false)) <= Float(DiyPresentation.swingBound))
        }
        #expect(DiyPresentation.swing(elapsed: 2.8, identity: "stable-44", reducedMotion: false) == .zero)
        #expect(DiyPresentation.swing(elapsed: 0.1, identity: "stable-44", reducedMotion: true) == .zero)
        #expect(DiyPresentation.swing(elapsed: 0.1, identity: "stable-44", reducedMotion: false, dragging: true) == .zero)
    }
    @Test func sparseCordPreservesOpeningAndVerticalTubeHasFiniteVertices() {
        let slots = [bead(diameter: 10, shape: "round")], layout = DiyPhysicalLayout(slots: [bead(diameter: 10, shape: "round")])
        let points = DiyGeometry.cordPoints(slots: slots, layout: layout)
        #expect(points.allSatisfy { hypot($0.x, $0.z) > layout.radius * 0.95 })
        let paths: [[SIMD3<Double>]] = [[.zero, .zero, SIMD3(0, -5, 0)], points.map { DiyPresentation.point($0, mode: .hanging) }]
        for path in paths {
            let tube = DiyMaterialAppearance.cordGeometry(points: path, scale: 0.1)
            let vertices = DiyMaterialAppearance.vertices(of: tube)
            #expect(!vertices.isEmpty)
            #expect(vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            #expect(tube.elements.allSatisfy { $0.primitiveCount > 0 })
        }
    }

    @Test func naturalHangingCentersAccessoriesDownAndKeepsConnectorsVertical() throws {
        let slots = [bead(diameter: 12, shape: "round"), bead(diameter: 18, shape: "pendant", id: 42), bead(diameter: 18, shape: "pendant", id: 43)]
        let layout = DiyPhysicalLayout(slots: slots)
        let rotation = DiyPresentation.initialHangingRotation(slots: slots, angles: layout.angles)
        let x = [1, 2].reduce(0.0) { $0 + cos(layout.angles[$1] + rotation) }
        let y = [1, 2].reduce(0.0) { $0 + sin(layout.angles[$1] + rotation) }
        #expect(abs(x) < 0.00001 && y > 0)
        let placements = DiyPresentation.hangingPlacements(slots: slots, layout: layout, rotation: rotation)
        #expect(placements[0] == nil)
        for placement in placements.compactMap({ $0 }) {
            #expect(placement.connectorMm >= placement.standOffMm)
            #expect(placement.standOffMm >= 0)
        }
        let solo = [slots[0], slots[1]], soloLayout = DiyPhysicalLayout(slots: [slots[0], slots[1]])
        let soloRotation = DiyPresentation.initialHangingRotation(slots: solo, angles: soloLayout.angles)
        let pendant = try #require(DiyPresentation.hangingPlacements(slots: solo, layout: soloLayout, rotation: soloRotation)[1])
        #expect(pendant.standOffMm == 0)
        #expect(abs(pendant.connectorMm - 18 * 0.35) < 0.00001)
        #expect(DiyGeometry.cordPoints(slots: solo, layout: soloLayout, rotation: soloRotation).allSatisfy { $0.x.isFinite && $0.z.isFinite })
    }
    @Test func thinBodyHitToleranceReachesStrandGapsButLeavesDistantCanvasFree() {
        // The mount is at y=100, while actual long tassel strands reach y=230.
        // Picking the body must not depend on distance to that remote mount.
        let strands = [(id: "tassel", points: [CGPoint(x: 96, y: 230), CGPoint(x: 104, y: 230)])]
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 100, y: 232), bodies: strands) == "tassel")
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 122, y: 230), bodies: strands) == "tassel")
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 122.01, y: 230), bodies: strands) == nil)
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 160, y: 230), bodies: strands) == nil)
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 100, y: 100), bodies: strands) == nil)
        let other = (id: "bead", points: [CGPoint(x: 130, y: 230)])
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 116, y: 230), bodies: strands + [other]) == "tassel")
        #expect(DiyProjectedHit.nearest(to: CGPoint(x: 128, y: 230), bodies: strands + [other]) == "bead")
    }

}
