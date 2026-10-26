import Foundation
import simd

// Shared catalog coordinates: X follows the cord, Y is up, Z faces outward.
// Procedural preview assets are dimensional illustrations, not merchant scans.
enum DiyGeometry {
    struct Profile: Decodable {
        let pitchRatio, spacingRatio, radialRatio, minX, maxX, minY, maxY, minZ, maxZ: Double
        let file, thumbnail: String
        let anchors: [String: [Double]]
        let connectorRatio: Double?
    }
    private struct Catalog: Decodable {
        struct Variant: Decodable { let matches: [String]; let kind: String }
        let models: [String: Profile]
        let byMaterialId: [String: String]
        let nameVariants: [Variant]
    }
    struct Dimensions {
        let diameterMm, pitchMm, spacingMm, radialMm, centerHeightMm, minZ, maxZ: Double
        let kind: String?
    }
    private static let catalog: Catalog? = {
        guard let root = Bundle.main.url(forResource: "DiyMaterials", withExtension: nil),
              let data = try? Data(contentsOf: root.appendingPathComponent("geometry-catalog.json")) else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }()
    static func kind(shape: String?, category: String?, materialId: Int64, name: String? = nil) -> String? {
        guard let kind = ["three_way", "buddha_head", "pendant", "tassel"].first(where: { shape == $0 || category == $0 }) else { return nil }
        if kind == "pendant" || kind == "tassel" {
            let fallback = kind == "pendant" ? "pendant_generic" : "tassel"
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return catalog?.nameVariants.first(where: { variant in variant.matches.contains(where: { name.contains($0) }) })?.kind ?? fallback
            }
            return catalog?.byMaterialId[String(materialId)] ?? fallback
        }
        return kind
    }
    static func profile(_ kind: String) -> Profile? { catalog?.models[kind] }
    static func dimensions(_ bead: DiyBeadSlot) -> Dimensions {
        let diameter = bead.diameterMm.isFinite ? max(2, min(40, bead.diameterMm)) : 10
        let kind = kind(shape: bead.shape, category: bead.subtype, materialId: bead.materialId, name: bead.materialName)
        if let kind, let model = profile(kind) {
            return .init(diameterMm: diameter, pitchMm: max(2, diameter * model.pitchRatio), spacingMm: diameter * model.spacingRatio,
                         radialMm: diameter * model.radialRatio, centerHeightMm: -model.minY * diameter, minZ: model.minZ * diameter, maxZ: model.maxZ * diameter, kind: kind)
        }
        var pitch = diameter * (bead.shape == "disc" ? 0.45 : bead.shape == "barrel" ? 1.15 : 1)
        if bead.shape == "barrel", let expression = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*[x×*]\s*(\d+(?:\.\d+)?)"#, options: .caseInsensitive),
           let match = expression.firstMatch(in: bead.spec, range: NSRange(bead.spec.startIndex..., in: bead.spec)),
           let range = Range(match.range(at: 2), in: bead.spec), let length = Double(bead.spec[range]) { pitch = max(2, min(80, length)) }
        let radial = diameter * (bead.shape == "barrel" ? 0.85 : 1)
        return .init(diameterMm: diameter, pitchMm: pitch, spacingMm: pitch, radialMm: radial, centerHeightMm: radial / 2, minZ: -radial / 2, maxZ: radial / 2, kind: nil)
    }
    static func textureTurn(_ identity: String) -> Float {
        let hash = identity.utf8.reduce(UInt32(0)) { ($0 &* 31) &+ UInt32($1) }
        return Float(hash) / Float(UInt32.max) * 2 * .pi
    }
    static func cordPoints(slots: [DiyBeadSlot], layout: DiyPhysicalLayout, rotation: Double = 0) -> [SIMD3<Double>] {
        let angles = layout.angles.map { $0 + rotation }
        if slots.isEmpty { return (0...128).map { let angle = Double($0 % 128) / 128 * 2 * .pi; return SIMD3(cos(angle) * layout.radius, 0.4, sin(angle) * layout.radius) } }
        let physical = slots.map(dimensions)
        func attachment(_ index: Int, side: String) -> SIMD3<Double> {
            let size = physical[index], angle = angles[index]
            let local = size.kind.flatMap(profile)?.anchors[side]
            let anchor: SIMD3<Double>
            if let local, local.count == 3 { anchor = SIMD3(local[0], local[1], local[2]) * size.diameterMm }
            else { anchor = SIMD3(side == "left" ? -size.pitchMm / 2 : size.pitchMm / 2, 0, 0) }
            return SIMD3(cos(angle) * layout.radius + sin(angle) * anchor.x + cos(angle) * anchor.z,
                         size.centerHeightMm + anchor.y,
                         sin(angle) * layout.radius - cos(angle) * anchor.x + sin(angle) * anchor.z)
        }
        var points: [SIMD3<Double>] = []
        for index in slots.indices {
            let next = (index + 1) % slots.count
            let start = attachment(index, side: "left"), end = attachment(next, side: "right")
            points.append(attachment(index, side: "right")); points.append(start)
            let from = atan2(start.z, start.x); var to = atan2(end.z, end.x)
            while to <= from { to += 2 * .pi }
            if to - from > .pi * 1.5 && slots.count > 1 { to -= 2 * .pi }
            // Match the shared H5 cubic arcs: tangent-continuous bore exits,
            // split into quarter arcs so sparse bracelets never cut the opening.
            let segments = max(1, Int(ceil(abs(to - from) / (.pi / 2))))
            let r1 = hypot(start.x, start.z), r2 = hypot(end.x, end.z)
            func arcPoint(_ t: Double) -> SIMD3<Double> {
                let angle = from + (to - from) * t, radius = r1 + (r2 - r1) * t
                return SIMD3(cos(angle) * radius, start.y + (end.y - start.y) * t * t * (3 - 2 * t), sin(angle) * radius)
            }
            for segment in 0..<segments {
                let t0 = Double(segment) / Double(segments), t1 = Double(segment + 1) / Double(segments)
                let a0 = from + (to - from) * t0, a1 = from + (to - from) * t1
                let p0 = segment == 0 ? start : arcPoint(t0), p3 = segment + 1 == segments ? end : arcPoint(t1)
                let angle0 = segment == 0 ? angles[index] : a0
                let angle1 = segment + 1 == segments ? angles[next] : a1
                let handle = 4.0 / 3 * tan((a1 - a0) / 4) * (hypot(p0.x, p0.z) + hypot(p3.x, p3.z)) / 2
                let p1 = p0 + SIMD3(-sin(angle0) * handle, 0, cos(angle0) * handle)
                let p2 = p3 - SIMD3(-sin(angle1) * handle, 0, cos(angle1) * handle)
                let samples = max(4, Int(ceil(abs(a1 - a0) / 0.07)))
                for sample in 1...samples {
                    let t = Double(sample) / Double(samples), u = 1 - t
                    let first = p0 * (u * u * u), second = p1 * (3 * u * u * t)
                    let third = p2 * (3 * u * t * t), fourth = p3 * (t * t * t)
                    points.append(first + second + third + fourth)
                }
            }
        }
        if let first = points.first, points.last != first { points.append(first) }
        return points
    }
}


enum DiyPresentationMode: String, CaseIterable {
    case flat, hanging
    var title: String { self == .hanging ? "悬挂" : "平放" }
}

enum DiyPresentation {
    static let settlingDuration = 2.8
    static let swingBound = 0.025
    static func initialHangingRotation(slots: [DiyBeadSlot], angles: [Double]) -> Double {
        let hanging = angles.indices.filter { isSuspended(DiyGeometry.dimensions(slots[$0]).kind) }.map { angles[$0] }
        guard let first = hanging.first else { return 0 }
        let x = hanging.reduce(0) { $0 + cos($1) }, y = hanging.reduce(0) { $0 + sin($1) }
        return .pi / 2 - (hypot(x, y) < 0.000001 ? first : atan2(y, x))
    }
    static func isSuspended(_ kind: String?) -> Bool {
        kind?.hasPrefix("pendant") == true || kind?.hasPrefix("tassel") == true
    }
    static func mode(selection: DiyPresentationMode?, slots: [DiyBeadSlot]) -> DiyPresentationMode {
        selection ?? (slots.contains { isSuspended(DiyGeometry.dimensions($0).kind) } ? .hanging : .flat)
    }
    static func point(_ point: SIMD3<Double>, mode: DiyPresentationMode) -> SIMD3<Double> {
        // Display-only rotation; the physical fit and pricing layout are untouched.
        mode == .hanging ? SIMD3(point.x, -point.z, 0) : point
    }
    static func orientation(angle: Double, kind: String?, mode: DiyPresentationMode) -> simd_quatf {
        let turn = simd_quatf(angle: Float(.pi / 2 - angle), axis: SIMD3(0, 1, 0))
        guard mode == .hanging else { return turn }
        let upright = simd_quatf(angle: .pi / 2, axis: SIMD3(1, 0, 0))
        return isSuspended(kind) ? upright : upright * turn
    }
    struct HangingPlacement {
        let standOffMm, connectorMm, sweepMm: Double
        let bounds: CGRect
    }
    static func hangingPlacements(slots: [DiyBeadSlot], layout: DiyPhysicalLayout, rotation: Double = 0) -> [HangingPlacement?] {
        let sizes = slots.map(DiyGeometry.dimensions), angles = layout.angles.map { $0 + rotation }
        var mainBodies: [(bounds: CGRect, depth: Double, circleRadius: Double)] = []
        for index in sizes.indices where !isSuspended(sizes[index].kind) {
            let size = sizes[index], angle = angles[index]
            let radial = max(abs(size.minZ), abs(size.maxZ)), axial = size.pitchMm / 2
            let halfX = abs(sin(angle)) * axial + abs(cos(angle)) * radial
            let halfY = abs(cos(angle)) * axial + abs(sin(angle)) * radial
            mainBodies.append((CGRect(x: cos(angle) * layout.radius - halfX, y: -sin(angle) * layout.radius - halfY,
                                      width: halfX * 2, height: halfY * 2), size.centerHeightMm,
                               size.kind == nil && (slots[index].shape == "round" || slots[index].shape == nil) ? size.radialMm / 2 : 0))
        }
        var candidates: [(index: Int, connector: Double, sweep: Double, bounds: CGRect, mountY: Double)] = []
        for index in sizes.indices {
            let size = sizes[index]
            guard isSuspended(size.kind), let kind = size.kind, let profile = DiyGeometry.profile(kind) else { continue }
            let mount = profile.anchors["mount"] ?? [0, 0, 0]
            let mountX = mount.count == 3 ? mount[0] : 0, mountY = mount.count == 3 ? mount[1] : 0, mountZ = mount.count == 3 ? mount[2] : 0
            let bodyLength = max(abs(size.minZ - mountZ * size.diameterMm), abs(size.maxZ - mountZ * size.diameterMm))
            let connector = max(profile.connectorRatio ?? 0.12, 0.35) * size.diameterMm
            let width = max(abs(profile.minX - mountX), abs(profile.maxX - mountX)) * size.diameterMm
            let sweep = max(abs(profile.minY - mountY), abs(profile.maxY - mountY)) * size.diameterMm + sin(swingBound) * (bodyLength + width)
            let x = cos(angles[index]) * layout.radius, y = -sin(angles[index]) * layout.radius
            let halfWidth = width + sin(swingBound) * (bodyLength + sweep), verticalSweep = sin(swingBound) * (width + sweep)
            let bounds = CGRect(x: x - halfWidth, y: y - connector - bodyLength - verticalSweep,
                                width: halfWidth * 2, height: bodyLength + verticalSweep * 2)
            candidates.append((index, connector, sweep, bounds, y - connector))
        }
        candidates.sort { $0.mountY == $1.mountY ? $0.index < $1.index : $0.mountY < $1.mountY }
        func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
            a.minX <= b.maxX && a.maxX >= b.minX && a.minY <= b.maxY && a.maxY >= b.minY
        }
        var placed: [HangingPlacement] = [], result = [HangingPlacement?](repeating: nil, count: slots.count)
        for candidate in candidates {
            var connector = candidate.connector, standOff = 0.0, bounds = candidate.bounds
            for _ in 0..<3 {
                let nearDepth = mainBodies.filter { body in
                    if body.circleRadius > 0 {
                        let dx = max(bounds.minX - body.bounds.midX, 0, body.bounds.midX - bounds.maxX)
                        let dy = max(bounds.minY - body.bounds.midY, 0, body.bounds.midY - bounds.maxY)
                        return hypot(dx, dy) <= body.circleRadius
                    }
                    return overlaps(bounds, body.bounds)
                }.map(\.depth).max() ?? 0
                standOff = nearDepth > 0 ? nearDepth + candidate.sweep + 0.6 : 0
                for other in placed where overlaps(bounds, other.bounds) {
                    standOff = max(standOff, other.standOffMm + other.sweepMm + candidate.sweep + 0.6)
                }
                // The short connector reads as hanging cord, not a horizontal bar.
                if connector >= standOff { break }
                let drop = standOff - connector
                connector += drop; bounds.origin.y -= drop
            }
            let placement = HangingPlacement(standOffMm: standOff, connectorMm: connector, sweepMm: candidate.sweep, bounds: bounds)
            placed.append(placement); result[candidate.index] = placement
        }
        return result
    }
    static func swing(elapsed: Double, identity: String, reducedMotion: Bool, dragging: Bool = false) -> SIMD2<Float> {
        guard !reducedMotion, !dragging, elapsed >= 0, elapsed < settlingDuration else { return .zero }
        let phase = Double(DiyGeometry.textureTurn(identity))
        let amplitude = 0.04 * exp(-3.2 * elapsed) * sin(8.8 * elapsed)
        return SIMD2(Float(cos(phase) * amplitude), Float(sin(phase) * amplitude))
    }
}


struct DiyDragEnvelope {
    let hull: [CGPoint]
    init(points: [CGPoint]) {
        let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
        let unique = Set(finite.map { DiyDragPoint(x: $0.x, y: $0.y) })
        let ordered = unique.sorted { a, b in a.x == b.x ? a.y < b.y : a.x < b.x }
        let sorted = ordered.map { CGPoint(x: $0.x, y: $0.y) }
        guard sorted.count > 2 else { hull = sorted; return }
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat { (b.x-a.x)*(c.y-a.y) - (b.y-a.y)*(c.x-a.x) }
        var lower: [CGPoint] = [], upper: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        for point in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        hull = Array(lower.dropLast()) + Array(upper.dropLast())
    }
    func distance(to point: CGPoint) -> CGFloat {
        guard !hull.isEmpty else { return .infinity }
        if hull.count == 1 { return hypot(point.x-hull[0].x, point.y-hull[0].y) }
        var inside = hull.count > 2, nearest = CGFloat.infinity
        for index in hull.indices {
            let a = hull[index], b = hull[(index+1) % hull.count], dx = b.x-a.x, dy = b.y-a.y
            if dx*(point.y-a.y) - dy*(point.x-a.x) < -0.00001 { inside = false }
            let length = dx*dx+dy*dy
            let t = length > 0 ? min(1, max(0, ((point.x-a.x)*dx+(point.y-a.y)*dy)/length)) : 0
            nearest = min(nearest, hypot(point.x-a.x-t*dx, point.y-a.y-t*dy))
        }
        return inside ? 0 : nearest
    }
    private struct DiyDragPoint: Hashable { let x: CGFloat; let y: CGFloat }
}

struct DiyBeadDragSession {
    static let activationDistance: CGFloat = 6
    static let removalDistance: CGFloat = 24
    enum Completion: Equatable { case unchanged, move(String, Int), remove(String) }
    let id: String
    let initialIndex: Int
    let pointer: CGPoint
    let anchor: CGPoint
    let envelope: DiyDragEnvelope
    private(set) var targetIndex: Int
    private(set) var hasMoved = false
    private(set) var deletionArmed = false
    init(id: String, initialIndex: Int, pointer: CGPoint, anchor: CGPoint, envelope: DiyDragEnvelope) {
        self.id = id; self.initialIndex = initialIndex; self.pointer = pointer; self.anchor = anchor; self.envelope = envelope
        targetIndex = initialIndex
    }
    func translatedAnchor(pointer current: CGPoint) -> CGPoint { CGPoint(x: anchor.x + current.x-pointer.x, y: anchor.y + current.y-pointer.y) }
    mutating func update(pointer current: CGPoint, targetIndex: Int) {
        hasMoved = hasMoved || hypot(current.x-pointer.x, current.y-pointer.y) >= Self.activationDistance
        self.targetIndex = targetIndex
        deletionArmed = hasMoved && envelope.distance(to: translatedAnchor(pointer: current)) > Self.removalDistance
    }
    func completion(endedNormally: Bool) -> Completion {
        guard endedNormally && hasMoved else { return .unchanged }
        if deletionArmed { return .remove(id) }
        return targetIndex == initialIndex ? .unchanged : .move(id, targetIndex)
    }
}
