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
