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


enum DiyGravity {
    static let step = 1.0 / 120
    static func initialOrientation(slots: [DiyBeadSlot] = [], angles: [Double] = []) -> simd_quatf {
        let attachments = angles.indices.filter { $0 < slots.count && isSuspended(DiyGeometry.dimensions(slots[$0]).kind) }.map { angles[$0] }
        let x = attachments.reduce(0) { $0 + cos($1) }, y = attachments.reduce(0) { $0 + sin($1) }
        let rotation = attachments.isEmpty ? 0 : Double.pi / 2 - (hypot(x, y) < 0.000001 ? attachments[0] : atan2(y, x))
        return simd_quatf(angle: 1.15, axis: SIMD3(1, 0, 0)) * simd_quatf(angle: Float(-rotation), axis: SIMD3(0, 1, 0))
    }
    static func framingRadius(slots: [DiyBeadSlot], layout: DiyPhysicalLayout) -> Double {
        let scale = 1.65 / layout.radius
        return slots.reduce(1.65) { result, slot in
            let size = DiyGeometry.dimensions(slot), diameter = size.diameterMm * scale
            let center = hypot(1.65, size.centerHeightMm * scale)
            guard let kind = size.kind, let profile = DiyGeometry.profile(kind) else {
                return max(result, center + hypot(size.radialMm, size.pitchMm) * scale / 2)
            }
            let x = max(abs(profile.minX), abs(profile.maxX)), y = max(abs(profile.minY), abs(profile.maxY))
            if isSuspended(kind) {
                let body = profile.maxZ - (profile.anchors["mount"]?.last ?? profile.minZ)
                return max(result, center + max(0.025, diameter * (profile.connectorRatio ?? 0.12)) + diameter * (body + hypot(x, y)))
            }
            let z = max(abs(profile.minZ), abs(profile.maxZ))
            return max(result, center + sqrt(x*x + y*y + z*z) * diameter)
        }
    }
    static func transportedFacing(_ facing: SIMD3<Float>, direction: SIMD3<Float>) -> SIMD3<Float> {
        let projected = facing - direction * simd_dot(facing, direction)
        if simd_length_squared(projected) > 0.000001 { return simd_normalize(projected) }
        let reference = abs(direction.z) < 0.9 ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(1, 0, 0)
        return simd_normalize(reference - direction * simd_dot(reference, direction))
    }
    static func facing(previous: SIMD3<Float>, direction: SIMD3<Float>, target: SIMD3<Float>, delta: Double, reducedMotion: Bool) -> (normal: SIMD3<Float>, remaining: Float) {
        let current = transportedFacing(previous, direction: direction)
        let projected = target - direction * simd_dot(target, direction)
        guard simd_length_squared(projected) >= 0.01 else { return (current, 0) }
        let goal = simd_normalize(projected)
        let angle = atan2(simd_dot(direction, simd_cross(current, goal)), simd_dot(current, goal))
        if abs(angle) <= 0.001 { return (goal, 0) }
        let fraction: Float = reducedMotion ? 1 : Float(1 - exp(-6 * max(0, min(delta, 0.05))))
        return (simd_quatf(angle: angle * fraction, axis: direction).act(current), abs(angle * (1 - fraction)))
    }
    static func isSuspended(_ kind: String?) -> Bool {
        kind?.hasPrefix("pendant") == true || kind?.hasPrefix("tassel") == true
    }
    static func direction(_ vector: SIMD3<Double>, fallback: SIMD3<Double> = SIMD3(0, -1, 0)) -> SIMD3<Double> {
        let length = simd_length(vector)
        return length > 0.0000001 ? vector / length : fallback
    }
    struct Collider {
        let center: SIMD3<Double>
        let radius: Double
    }
    struct Chain {
        let id: String
        let lengths: [Double]
        let radii: [Double]
        let flexible: Bool
        var points: [SIMD3<Double>]
        var previous: [SIMD3<Double>]
        var anchor: SIMD3<Double>
        init(id: String, anchor: SIMD3<Double>, connector: Double, bodyLength: Double, radius: Double, flexible: Bool, headFraction: Double = 0.35) {
            self.id = id; self.anchor = anchor; self.flexible = flexible
            precondition(anchor.x.isFinite && anchor.y.isFinite && anchor.z.isFinite && connector.isFinite && connector > 0 && bodyLength.isFinite && bodyLength > 0 && radius.isFinite && radius > 0)
            let body = bodyLength, tether = connector, headFraction = min(0.8, max(0.15, headFraction))
            lengths = flexible ? [tether, body * headFraction] + Array(repeating: body * (1 - headFraction) / 3, count: 3) : [tether, body / 2, body / 2]
            radii = flexible ? [0, radius * 0.18, radius * 0.42, radius * 0.62, radius * 0.78, radius * 0.55] : [0, radius * 0.18, radius, radius * 0.35]
            var positions = [anchor]
            for length in lengths { positions.append(positions.last! + SIMD3(0, -length, 0)) }
            points = positions; previous = positions
        }
        var bodyLength: Double { lengths.dropFirst().reduce(0, +) }
        mutating func constrain(_ a: Int, _ b: Int, length: Double) {
            let delta = points[b] - points[a], actual = simd_length(delta)
            guard actual > 0.0000001 else { points[b] = points[a] + SIMD3(0, -length, 0); return }
            let correction = delta * ((actual - length) / actual)
            if a == 0 { points[b] -= correction }
            else { points[a] += correction * 0.5; points[b] -= correction * 0.5 }
        }
        mutating func constrainLengths() {
            points[0] = anchor
            if flexible {
                for index in lengths.indices.reversed() { constrain(index, index + 1, length: lengths[index]) }
                constrain(0, 1, length: lengths[0])
            } else {
                constrain(0, 1, length: lengths[0])
                points[3] = points[1] + DiyGravity.direction(points[3] - points[1]) * bodyLength
                points[2] = (points[1] + points[3]) * 0.5
            }
        }
        mutating func push(_ point: Int, delta: SIMD3<Double>) {
            if flexible { points[point] += delta }
            else { for index in 1..<points.count { points[index] += delta } }
        }
    }
    struct Simulation {
        var chains: [Chain] = []
        private var accumulator = 0.0
        private var quietSteps = 0
        private var lastColliders: [Collider] = []
        private(set) var settled = false
        mutating func wake() { quietSteps = 0; settled = false }
        private func separation(_ a: SIMD3<Double>, _ b: SIMD3<Double>, gap: Double, shared: Bool, fallback: Double = 1) -> SIMD3<Double>? {
            let delta = a - b, squared = simd_length_squared(delta)
            guard squared < gap * gap else { return nil }
            let length = sqrt(squared), normal = length > 0.0000001 ? delta / length : SIMD3(0, 0, fallback)
            return normal * ((gap - length) * (shared ? 0.5 : 1))
        }
        private mutating func integrate(colliders: [Collider], damping: Double) {
            for chain in chains.indices {
                for point in 1..<chains[chain].points.count {
                    let position = chains[chain].points[point]
                    let velocity = (position - chains[chain].previous[point]) * damping
                    chains[chain].previous[point] = position
                    chains[chain].points[point] = position + velocity + SIMD3(0, -18 * DiyGravity.step * DiyGravity.step, 0)
                }
            }
            for _ in 0..<12 {
                let bounds = chains.map { chain -> (min: SIMD3<Double>, max: SIMD3<Double>) in
                    var low = SIMD3<Double>(repeating: .infinity), high = SIMD3<Double>(repeating: -.infinity)
                    for index in 1..<chain.points.count {
                        let radius = SIMD3<Double>(repeating: chain.radii[index])
                        low = simd_min(low, chain.points[index] - radius); high = simd_max(high, chain.points[index] + radius)
                    }
                    return (low, high)
                }
                // shortcut: sphere samples approximate decorative contact; use authored mesh colliders if clasp interlocking becomes an editing requirement.
                for chain in chains.indices {
                    for point in 1..<chains[chain].points.count {
                        for collider in colliders {
                            if let delta = separation(chains[chain].points[point], collider.center, gap: chains[chain].radii[point] + collider.radius, shared: false) {
                                chains[chain].push(point, delta: delta)
                            }
                        }
                        for other in 0..<chain {
                            let firstBounds = bounds[chain], secondBounds = bounds[other]
                            if firstBounds.max.x < secondBounds.min.x || firstBounds.min.x > secondBounds.max.x
                                || firstBounds.max.y < secondBounds.min.y || firstBounds.min.y > secondBounds.max.y
                                || firstBounds.max.z < secondBounds.min.z || firstBounds.min.z > secondBounds.max.z { continue }
                            for second in 1..<chains[other].points.count {
                                let gap = chains[chain].radii[point] + chains[other].radii[second]
                                if let delta = separation(chains[chain].points[point], chains[other].points[second], gap: gap, shared: true, fallback: (chain + point + second) % 2 == 1 ? 1 : -1) {
                                    chains[chain].push(point, delta: delta); chains[other].push(second, delta: -delta)
                                }
                            }
                        }
                    }
                }
                for index in chains.indices { chains[index].constrainLengths() }
            }
            for index in chains.indices where chains[index].flexible {
                for point in 1..<chains[index].points.count {
                    chains[index].points[point] = chains[index].points[point - 1] + DiyGravity.direction(chains[index].points[point] - chains[index].points[point - 1]) * chains[index].lengths[point - 1]
                }
            }
            var movement = 0.0
            for chain in chains {
                for point in 1..<chain.points.count { movement = max(movement, simd_distance(chain.points[point], chain.previous[point])) }
            }
            quietSteps = movement < 0.00008 ? quietSteps + 1 : 0
            settled = quietSteps >= 40
            if settled {
                accumulator = 0
                for index in chains.indices { chains[index].previous = chains[index].points }
            }
        }
        mutating func advance(delta: Double, colliders: [Collider], reducedMotion: Bool = false) {
            guard delta.isFinite, delta >= 0 else { return }
            let moved = chains.contains { simd_distance($0.anchor, $0.points[0]) > 0.0000001 }
                || colliders.count != lastColliders.count
                || zip(colliders, lastColliders).contains { pair in simd_distance(pair.0.center, pair.1.center) > 0.0000001 || pair.0.radius != pair.1.radius }
            if moved {
                wake(); lastColliders = colliders
                for index in chains.indices { chains[index].points[0] = chains[index].anchor }
            }
            guard !settled else { return }
            if delta == 0 {
                if moved { for _ in 0..<12 { for index in chains.indices { chains[index].constrainLengths() } } }
                return
            }
            if reducedMotion {
                for _ in 0..<8 {
                    integrate(colliders: colliders, damping: 0.5)
                    if settled { break }
                }
                return
            }
            accumulator += min(delta, 1.0 / 15)
            var steps = 0
            while accumulator >= DiyGravity.step && steps < 8 && !settled {
                accumulator -= DiyGravity.step; steps += 1
                integrate(colliders: colliders, damping: exp(-4 * DiyGravity.step))
            }
        }
    }

}


enum DiyProjectedHit {
    static func nearest(to point: CGPoint, bodies: [(id: String, points: [CGPoint])], tolerance: CGFloat = 18) -> String? {
        var nearestID: String?, nearestDistance = CGFloat.infinity
        for body in bodies {
            for vertex in body.points {
                let distance = hypot(vertex.x - point.x, vertex.y - point.y)
                if distance < nearestDistance { nearestID = body.id; nearestDistance = distance }
            }
        }
        return nearestDistance <= tolerance ? nearestID : nil
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
