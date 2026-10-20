import Foundation

// Shared catalog coordinates: X follows the cord, Y is up, Z faces outward.
// Procedural preview assets are dimensional illustrations, not merchant scans.
enum DiyGeometry {
    struct Profile: Decodable {
        let pitchRatio, spacingRatio, radialRatio, minY, maxY, minZ, maxZ: Double
        let file, thumbnail: String
        let anchors: [String: [Double]]
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
        if kind == "pendant" {
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return catalog?.nameVariants.first(where: { variant in variant.matches.contains(where: { name.contains($0) }) })?.kind ?? "pendant_generic"
            }
            return catalog?.byMaterialId[String(materialId)] ?? "pendant_generic"
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
    static func cordPoints(slots: [DiyBeadSlot], layout: DiyPhysicalLayout) -> [SIMD3<Double>] {
        if slots.isEmpty { return (0...128).map { let angle = Double($0 % 128) / 128 * 2 * .pi; return SIMD3(cos(angle) * layout.radius, 0.4, sin(angle) * layout.radius) } }
        let physical = slots.map(dimensions)
        var points: [SIMD3<Double>] = []
        for i in slots.indices {
            let next = (i + 1) % slots.count, angle = layout.angles[i], nextAngle = layout.angles[next]
            let x = cos(angle) * layout.radius, z = sin(angle) * layout.radius
            let half = physical[i].pitchMm / 2, nextHalf = physical[next].pitchMm / 2
            let start = SIMD3(x - sin(angle) * half, physical[i].centerHeightMm, z + cos(angle) * half)
            let end = SIMD3(cos(nextAngle) * layout.radius + sin(nextAngle) * nextHalf, physical[next].centerHeightMm, sin(nextAngle) * layout.radius - cos(nextAngle) * nextHalf)
            points.append(SIMD3(x + sin(angle) * half, physical[i].centerHeightMm, z - cos(angle) * half)); points.append(start)
            let from = atan2(start.z, start.x); var to = atan2(end.z, end.x)
            while to <= from { to += 2 * .pi }
            if to - from > .pi * 1.5 && slots.count > 1 { to -= 2 * .pi }
            let steps = max(2, Int(ceil(abs(to - from) / 0.1))), r1 = hypot(start.x, start.z), r2 = hypot(end.x, end.z)
            for step in 1..<steps {
                let t = Double(step) / Double(steps), a = from + (to - from) * t, r = r1 + (r2 - r1) * t
                points.append(SIMD3(cos(a) * r, start.y + (end.y - start.y) * t, sin(a) * r))
            }
        }
        if let first = points.first { points.append(first) }; return points
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
