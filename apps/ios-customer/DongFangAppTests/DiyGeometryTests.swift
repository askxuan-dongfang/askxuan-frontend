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
    @Test func gravityUsesShortMountsAndLeavesPhysicalFitUnchanged() throws {
        let slots = [bead(diameter: 10, shape: "round"), bead(diameter: 18, shape: "pendant", id: 42)]
        let layout = DiyPhysicalLayout(slots: slots)
        for name in ["中国结流苏", "中國結流蘇"] {
            #expect(DiyGeometry.kind(shape: "tassel", category: "tassel", materialId: 44, name: name) == "tassel_knot")
        }
        let profile = try #require(DiyGeometry.profile("tassel_knot"))
        #expect(profile.anchors["mount"]?[2] == profile.minZ)
        #expect(profile.connectorRatio == 0.12)
        #expect(DiyPhysicalLayout(slots: slots).innerMm == layout.innerMm)
    }
    @Test func gravityKeepsEightShortConnectorsDuringArbitraryRotation() {
        var simulation = DiyGravity.Simulation()
        let anchors = (0..<8).map { index in SIMD3<Double>(cos(Double(index) * 0.16) * 1.65, -1.3, sin(Double(index) * 0.16) * 0.2) }
        simulation.chains = anchors.enumerated().map { index, anchor in
            DiyGravity.Chain(id: "part-\(index)", anchor: anchor, connector: 0.08, bodyLength: index < 3 ? 0.55 : 1.1, radius: 0.15, flexible: index >= 3)
        }
        for frame in 0..<150 {
            let turn = simd_quatd(angle: sin(Double(frame) / 45) * 1.8, axis: simd_normalize(SIMD3(1, 0.4, 0.2)))
            for index in anchors.indices { simulation.chains[index].anchor = turn.act(anchors[index]) }
            simulation.wake(); simulation.advance(delta: 1.0 / 60, colliders: [])
            for chain in simulation.chains {
                #expect(abs(simd_distance(chain.points[0], chain.points[1]) - 0.08) < 0.000001)
                #expect(chain.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
                if !chain.flexible { #expect(abs(simd_distance(chain.points[1], chain.points[3]) - chain.bodyLength) < 0.000001) }
            }
        }
    }
    @Test func tasselBendsWithInertiaThenSettlesTowardWorldGravity() {
        var simulation = DiyGravity.Simulation()
        simulation.chains = [.init(id: "tassel", anchor: .zero, connector: 0.08, bodyLength: 1.2, radius: 0.12, flexible: true)]
        simulation.chains[0].anchor = SIMD3(0.6, 0.3, 0.25)
        simulation.advance(delta: 1.0 / 60, colliders: [])
        let moving = simulation.chains[0]
        #expect(abs(moving.points.last!.x - moving.anchor.x) > 0.1)
        let head = DiyGravity.direction(moving.points[2] - moving.points[1]), tail = DiyGravity.direction(moving.points[5] - moving.points[4])
        #expect(simd_length(simd_cross(head, tail)) > 0.01)
        for _ in 0..<1200 { simulation.advance(delta: 1.0 / 60, colliders: []) }
        let resting = simulation.chains[0]
        #expect(simulation.settled)
        #expect(abs(resting.points.last!.x - resting.anchor.x) < 0.015)
        #expect(abs(resting.points.last!.z - resting.anchor.z) < 0.015)
        #expect(resting.points.last!.y < resting.anchor.y - 1.2)
    }
    @Test func gravityContactPushesBodiesApartWithoutLengtheningTethers() {
        var simulation = DiyGravity.Simulation()
        simulation.chains = [-0.08, 0.08].enumerated().map { index, x in
            DiyGravity.Chain(id: "pendant-\(index)", anchor: SIMD3(x, 0, 0), connector: 0.08, bodyLength: 0.6, radius: 0.12, flexible: false)
        }
        for _ in 0..<300 { simulation.advance(delta: 1.0 / 60, colliders: [.init(center: SIMD3(-0.1, -0.4, 0), radius: 0.18)]) }
        for chain in simulation.chains {
            #expect(abs(simd_distance(chain.points[0], chain.points[1]) - 0.08) < 0.000001)
        }
        #expect(simd_distance(simulation.chains[0].points[2], simulation.chains[1].points[2]) > 0.20)
    }
    @Test func fixedStepsAreFrameRateIndependentAndReducedMotionSettles() {
        let chain = DiyGravity.Chain(id: "tassel", anchor: .zero, connector: 0.08, bodyLength: 1.2, radius: 0.12, flexible: true)
        var fast = DiyGravity.Simulation(), slow = DiyGravity.Simulation()
        fast.chains = [chain]; slow.chains = [chain]
        fast.chains[0].anchor.x = 0.4; slow.chains[0].anchor.x = 0.4
        for _ in 0..<60 { fast.advance(delta: 1.0 / 60, colliders: []) }
        for _ in 0..<30 { slow.advance(delta: 1.0 / 30, colliders: []) }
        #expect(zip(fast.chains[0].points, slow.chains[0].points).allSatisfy { pair in simd_distance(pair.0, pair.1) < 0.000001 })
        var previousError = abs(fast.chains[0].points.last!.x - fast.chains[0].anchor.x)
        for _ in 0..<180 {
            fast.advance(delta: 1.0 / 60, colliders: [], reducedMotion: true)
            let chain = fast.chains[0], error = abs(fast.chains[0].points.last!.x - fast.chains[0].anchor.x)
            // Match the solver sleep precision while rejecting visible rebound or equilibrium crossing.
            #expect(error <= previousError + 0.00008)
            #expect(chain.points.last!.x >= chain.anchor.x)
            #expect(chain.points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            for index in chain.lengths.indices { #expect(abs(simd_distance(chain.points[index], chain.points[index + 1]) - chain.lengths[index]) < 0.000001) }
            previousError = error
        }
        #expect(fast.settled)
        let points = fast.chains[0].points
        fast.advance(delta: .nan, colliders: [])
        #expect(fast.chains[0].points == points)
    }
    @Test func framingContainsLargeAccessoriesAcrossEveryOrientation() {
        let slots = [bead(diameter: 40, shape: "round"), bead(diameter: 40, shape: "tassel", id: 13), bead(diameter: 40, shape: "pendant", id: 42)]
        let layout = DiyPhysicalLayout(slots: slots), bound = DiyGravity.framingRadius(slots: slots, layout: layout)
        let scale = 1.65 / layout.radius
        for (index, slot) in slots.enumerated() {
            let size = DiyGeometry.dimensions(slot), anchor = SIMD3(cos(layout.angles[index]) * 1.65, size.centerHeightMm * scale, sin(layout.angles[index]) * 1.65)
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.1) {
                let turn = simd_quatd(angle: angle, axis: simd_normalize(SIMD3(1, 0.3, 0.7)))
                if let kind = size.kind, let profile = DiyGeometry.profile(kind) {
                    let length = size.diameterMm * scale * ((profile.connectorRatio ?? 0.12) + profile.maxZ - (profile.anchors["mount"]?.last ?? profile.minZ))
                    #expect(simd_length(turn.act(anchor) + SIMD3(0, -length, 0)) < bound)
                } else { #expect(simd_length(turn.act(anchor)) + size.radialMm * scale / 2 < bound) }
            }
        }
    }
    @Test func pendantFacingFollowsYawWithDampingAndPreservesGravityAxis() {
        let down = SIMD3<Float>(0, -1, 0), front = SIMD3<Float>(0, 0, 1), side = SIMD3<Float>(1, 0, 0)
        let first = DiyGravity.facing(previous: front, direction: down, target: side, delta: 1.0 / 30, reducedMotion: false)
        #expect(first.normal.x > 0 && first.normal.z > 0)
        #expect(abs(simd_dot(first.normal, down)) < 0.000001)
        var normal = first.normal
        for _ in 0..<60 { normal = DiyGravity.facing(previous: normal, direction: down, target: side, delta: 1.0 / 30, reducedMotion: false).normal }
        #expect(simd_distance(normal, side) < 0.001)
        let singular = DiyGravity.facing(previous: front, direction: down, target: down, delta: 1.0 / 30, reducedMotion: false)
        #expect(singular.normal == front)
        #expect(DiyGravity.facing(previous: front, direction: down, target: side, delta: 1.0 / 30, reducedMotion: true).remaining == 0)
    }
    @Test func sparseCordPreservesOpeningAndVerticalTubeHasFiniteVertices() {
        let slots = [bead(diameter: 10, shape: "round")], layout = DiyPhysicalLayout(slots: [bead(diameter: 10, shape: "round")])
        let points = DiyGeometry.cordPoints(slots: slots, layout: layout)
        #expect(points.allSatisfy { hypot($0.x, $0.z) > layout.radius * 0.95 })
        let paths: [[SIMD3<Double>]] = [[.zero, .zero, SIMD3(0, -5, 0)], points.map { SIMD3($0.x, -$0.z, $0.y) }]
        for path in paths {
            let tube = DiyMaterialAppearance.cordGeometry(points: path, scale: 0.1)
            let vertices = DiyMaterialAppearance.vertices(of: tube)
            #expect(!vertices.isEmpty)
            #expect(vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            #expect(tube.elements.allSatisfy { $0.primitiveCount > 0 })
        }
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
