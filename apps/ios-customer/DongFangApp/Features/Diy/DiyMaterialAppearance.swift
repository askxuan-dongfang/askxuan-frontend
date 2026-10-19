import SwiftUI
import SceneKit
import simd

// The JSON and source images are shared byte-for-byte with H5. UIKit thumbnails
// and SceneKit consume the same cropped, color-calibrated reference surface.
struct DiyAppearanceProfile: Decodable {
    let roughness, clearcoat, metalness, transmission, ior, normalStrength, contrast: Double
    let tint: Bool
    let source: String
    let crop: [Double]
    var brightness: Double?
}

@MainActor enum DiyMaterialAppearance {
    private struct Catalog: Decodable {
        let profiles: [String: DiyAppearanceProfile]
        let byMaterialId, byTexture, byType: [String: String]
    }
    static var root: URL? { Bundle.main.url(forResource: "DiyMaterials", withExtension: nil) }
    private static let catalog: Catalog? = {
        guard let url = root?.appendingPathComponent("appearance.json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Catalog.self, from: data)
    }()
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>(); cache.countLimit = 96; cache.totalCostLimit = 24 * 1024 * 1024; return cache
    }()
    static func profile(id: Int64, texture: String?, type: String?, finish: String?) -> (String, DiyAppearanceProfile)? {
        guard let catalog else { return nil }
        var key = catalog.byMaterialId[String(id)] ?? catalog.byTexture[texture ?? ""] ?? catalog.byType[type ?? ""] ?? "fallback"
        if key == "wood", finish == "natural" { key = "wood-natural" }
        return catalog.profiles[key].map { (key, $0) }
    }
    static func profile(_ bead: DiyBeadSlot) -> (String, DiyAppearanceProfile)? {
        profile(id: bead.materialId, texture: bead.textureKey, type: bead.materialType, finish: bead.finish)
    }
    static func image(id: Int64, texture: String?, type: String?, finish: String?, color: String?, channel: String = "color") -> UIImage? {
        guard let (key, profile) = profile(id: id, texture: texture, type: type, finish: finish), let root else { return nil }
        let name = channel == "color" ? profile.source : key.hasPrefix("wood") ? (channel == "normal" ? "rosewood-nor_gl.jpg" : "rosewood-Rough.jpg") : ""
        if name.isEmpty {
            return channel == "color" ? fallbackImage(color: color, texture: texture, type: type) : nil
        }
        let cacheKey = "\(key):\(channel):\(color ?? "")" as NSString
        if let cached = images.object(forKey: cacheKey) { return cached }
        guard let source = UIImage(contentsOfFile: root.appendingPathComponent(name).path)?.cgImage else { return nil }
        let crop = profile.crop
        guard crop.count == 4, let patch = source.cropping(to: CGRect(x: Double(source.width) * crop[0], y: Double(source.height) * crop[1], width: Double(source.width) * crop[2], height: Double(source.height) * crop[3])),
              let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 256 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        context.interpolationQuality = .high; context.draw(patch, in: CGRect(x: 0, y: 0, width: 256, height: 256))
        if channel == "color", profile.tint {
            let value = UInt32((color ?? "93795B").replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x93795B
            let rgb = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)]
            var mean = 0.0
            for i in stride(from: 0, to: 256 * 256 * 4, by: 4) { mean += (Double(bytes[i]) * 0.2126 + Double(bytes[i+1]) * 0.7152 + Double(bytes[i+2]) * 0.0722) / (256 * 256) }
            for i in stride(from: 0, to: 256 * 256 * 4, by: 4) {
                let light = Double(bytes[i]) * 0.2126 + Double(bytes[i+1]) * 0.7152 + Double(bytes[i+2]) * 0.0722
                let modulation = max(0.4, min(1.45, 1 + profile.contrast * (light / max(1, mean) - 1))) * (profile.brightness ?? 1)
                for c in 0..<3 { bytes[i+c] = UInt8(max(0, min(255, (rgb[c] * modulation).rounded()))) }
            }
        }
        guard let output = context.makeImage() else { return nil }
        let image = UIImage(cgImage: output); images.setObject(image, forKey: cacheKey, cost: 256 * 256 * 4); return image
    }
    static func image(_ bead: DiyBeadSlot, channel: String = "color") -> UIImage? {
        image(id: bead.materialId, texture: bead.textureKey, type: bead.materialType, finish: bead.finish, color: bead.colorHex, channel: channel)
    }
    static func fallbackImage(color: String?, texture: String?, type: String?) -> UIImage? {
        let key = "fallback:\(color ?? ""):\(texture ?? ""):\(type ?? "")" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 128 * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let value = UInt32((color ?? "93795B").replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x93795B
        let rgb = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)]
        let kind = (texture ?? "") + " " + (type ?? "")
        func random(_ x: Double, _ y: Double) -> Double { let n = sin(x * 127.1 + y * 311.7) * 43758.5453; return n - floor(n) }
        func noise(_ x: Double, _ y: Double) -> Double {
            let ix = floor(x), iy = floor(y), fx = x - ix, fy = y - iy
            let u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy)
            return (random(ix,iy) * (1-u) + random(ix+1,iy) * u) * (1-v) + (random(ix,iy+1) * (1-u) + random(ix+1,iy+1) * u) * v
        }
        for y in 0..<128 { for x in 0..<128 {
            let dx = Double(x), dy = Double(y), cloud = noise(dx/28,dy/28)*0.55 + noise(dx/12,dy/12)*0.3 + noise(dx/4,dy/4)*0.15
            let grain = noise(dx/2.5+cloud*1.4,dy/55), speck = random(dx,dy)
            var light = 0.91 + cloud * 0.18
            if kind.contains("wood") { light = 0.79 + grain*0.28 + speck*0.025 }
            else if kind.contains("seed") || kind.contains("bodhi") { light = 0.88 + cloud*0.17 - (speck > 0.995 ? 0.3 : 0) }
            else if ["agate","amber","tiger"].contains(where: kind.contains) { light = 0.83 + cloud*0.32 + noise(dx/40,dy/8)*0.08 }
            else if ["lapis","turquoise"].contains(where: kind.contains) { light = 0.78 + cloud*0.38 + (speck > 0.997 ? 0.4 : 0) }
            else if ["crystal","jade","glass"].contains(where: kind.contains) { light = 0.92 + cloud*0.16 }
            let i = (y * 128 + x) * 4
            for c in 0..<3 { pixels[i+c] = UInt8(max(0,min(255,(rgb[c] * light).rounded()))) }; pixels[i+3] = 255
        } }
        guard let output = context.makeImage() else { return nil }; let image = UIImage(cgImage: output)
        images.setObject(image, forKey: key, cost: 128*128*4); return image
    }
    static func apply(_ bead: DiyBeadSlot, to material: SCNMaterial) {
        guard let (_, profile) = profile(bead) else { return }
        material.metalness.contents = profile.metalness
        material.roughness.contents = profile.metalness > 0.5 && bead.finish == "brushed" ? max(0.4, profile.roughness) : profile.roughness
        material.clearCoat.contents = profile.clearcoat
        material.clearCoatRoughness.contents = max(0.18, profile.roughness)
        material.normal.intensity = profile.normalStrength
        for (channel, property) in [("color", material.diffuse), ("normal", material.normal), ("roughness", material.roughness)] {
            if let image = image(bead, channel: channel) {
                property.contents = image; property.wrapS = .mirror
                property.contentsTransform = SCNMatrix4MakeScale(2, 1, 1)
                if channel == "roughness" { property.intensity = profile.roughness }
            }
        }
        // SceneKit has no volume-transmission property. Keep reflected lighting
        // and use two transparent surfaces with angle-dependent optical density;
        // this is a native approximation, not a claim of volumetric refraction.
        let transmission = profile.transmission > 0 ? max(0, min(1, bead.translucency ?? profile.transmission)) : 0
        if transmission > 0.1 {
            material.transparencyMode = .dualLayer
            material.fresnelExponent = 5
            material.setValue(NSNumber(value: transmission), forKey: "diyTransmission")
            material.shaderModifiers = [.surface: """
                uniform float diyTransmission;
                #pragma transparent
                #pragma body
                float facing = abs(dot(normalize(_surface.normal), normalize(_surface.view)));
                float fresnel = pow(1.0 - facing, 5.0);
                float density = 1.0 - diyTransmission * 0.72 * (1.0 - fresnel);
                _surface.diffuse.a *= density;
                """]
        }
    }
    private struct Mesh: Decodable {
        let positions, normals, uv: [Float]
        let indices: [Int32]
    }
    private static var accessoryMeshes: [String: SCNGeometry] = [:]
    static func accessoryGeometry(_ kind: String) -> SCNGeometry? {
        if let cached = accessoryMeshes[kind] { return cached.copy() as? SCNGeometry }
        guard let profile = DiyGeometry.profile(kind), let url = root?.appendingPathComponent(profile.file),
              let data = try? Data(contentsOf: url), let mesh = try? JSONDecoder().decode(Mesh.self, from: data),
              mesh.positions.count % 3 == 0, mesh.normals.count == mesh.positions.count, mesh.uv.count == mesh.positions.count / 3 * 2 else { return nil }
        let vertices = stride(from: 0, to: mesh.positions.count, by: 3).map { SCNVector3(mesh.positions[$0], mesh.positions[$0+1], mesh.positions[$0+2]) }
        let normals = stride(from: 0, to: mesh.normals.count, by: 3).map { SCNVector3(mesh.normals[$0], mesh.normals[$0+1], mesh.normals[$0+2]) }
        let uv = stride(from: 0, to: mesh.uv.count, by: 2).map { CGPoint(x: CGFloat(mesh.uv[$0]), y: CGFloat(mesh.uv[$0+1])) }
        let geometry = SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals), .init(textureCoordinates: uv)], elements: [.init(indices: mesh.indices, primitiveType: .triangles)])
        accessoryMeshes[kind] = geometry; return geometry.copy() as? SCNGeometry
    }
    static func accessoryThumbnail(_ kind: String) -> UIImage? {
        guard let profile = DiyGeometry.profile(kind), let url = root?.appendingPathComponent(profile.thumbnail) else { return nil }
        let key = "geometry:\(kind)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        images.setObject(image, forKey: key, cost: 160 * 160 * 4); return image
    }
    static func cordGeometry(points: [SIMD3<Double>], scale: Double) -> SCNGeometry {
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], indices: [Int32] = []
        let sides = 6
        for index in points.indices {
            let before = points[max(0, index-1)], after = points[min(points.count-1, index+1)]
            let direction = after - before, tangent = simd_normalize(SIMD3<Float>(Float(direction.x), Float(direction.y), Float(direction.z)))
            let normal = simd_normalize(simd_cross(tangent, SIMD3<Float>(0,1,0))), binormal = simd_cross(tangent, normal)
            for side in 0..<sides {
                let angle = Float(side) / Float(sides) * 2 * .pi, n = cos(angle) * normal + sin(angle) * binormal
                let p = points[index] * scale
                let radius = Float(0.4 * scale)
                vertices.append(SCNVector3(Float(p.x) + n.x * radius, Float(p.y) + n.y * radius, Float(p.z) + n.z * radius)); normals.append(SCNVector3(n))
                if index < points.count-1 {
                    let a = Int32(index*sides+side), b = Int32(index*sides+(side+1)%sides), c = a + Int32(sides), d = b + Int32(sides)
                    indices.append(contentsOf: [a,b,c,b,d,c])
                }
            }
        }
        return SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals)], elements: [.init(indices: indices, primitiveType: .triangles)])
    }
    static func geometry(radius: CGFloat, shape: String, axialLength: CGFloat? = nil) -> SCNGeometry {
        let r = Float(radius), hole = r * (shape == "pendant" ? 0.3 : 0.13)
        var profile: [(Float, Float)] = []
        if shape == "disc" || shape == "barrel" {
            let half = axialLength.map { Float($0 / 2) } ?? r * (shape == "disc" ? 0.45 : 1.15), width = r * (shape == "barrel" ? 0.85 : 1)
            profile = [(hole,-half),(width*0.92,-half),(width,-half*0.8),(width,half*0.8),(width*0.92,half),(hole,half),(hole,-half)]
        } else {
            let limit = acos(hole / r)
            for i in 0...32 { let angle = -limit + 2 * limit * Float(i) / 32; profile.append((r * cos(angle), r * sin(angle))) }
            profile.append(profile[0])
        }
        let segments = shape == "faceted" ? 12 : 48
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], uv: [CGPoint] = [], indices: [Int32] = []
        for i in 0...segments {
            let angle = Float(i) / Float(segments) * 2 * .pi, sinA = sin(angle), cosA = cos(angle)
            for j in profile.indices {
                let point = profile[j], before = profile[max(0, j-1)], after = profile[min(profile.count-1,j+1)]
                let dx = after.0 - before.0, dy = after.1 - before.1, length = max(0.00001, hypot(dx, dy))
                vertices.append(SCNVector3(point.0 * sinA, point.1, point.0 * cosA))
                normals.append(SCNVector3(dy / length * sinA, -dx / length, dy / length * cosA))
                uv.append(CGPoint(x: Double(i) / Double(segments), y: Double(j) / Double(profile.count - 1)))
                if i < segments, j < profile.count - 1 {
                    let a = Int32(i * profile.count + j), b = a + Int32(profile.count)
                    indices.append(contentsOf: [a,b,a+1,b,b+1,a+1])
                }
            }
        }
        return SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals), .init(textureCoordinates: uv)], elements: [.init(indices: indices, primitiveType: .triangles)])
    }
}
