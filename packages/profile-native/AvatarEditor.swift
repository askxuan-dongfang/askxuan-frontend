import SwiftUI
import PhotosUI
import ImageIO

private struct AvatarFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class AvatarDraftState: ObservableObject {
    @Published var url: String
    @Published private(set) var image: UIImage?
    private var bytes: Data?
    private var cached: (data: Data, url: String, session: UUID)?
    init(url: String = "") { self.url = url }
    func choose(_ image: UIImage, data: Data) { self.image = image; if bytes != data { cached = nil }; bytes = data }
    func clear() { url = ""; image = nil; bytes = nil; cached = nil }
    func resolve() async throws -> String {
        guard let bytes else { return url }
        let context = AuthStore.shared.requestSession
        if let cached, cached.data == bytes, cached.session == context.id { return cached.url }
        let uploaded = try await APIClient.shared.uploadAvatar(bytes, context: context)
        guard AuthStore.shared.requestSession.id == context.id else { throw CancellationError() }
        cached = (bytes, uploaded, context.id)
        return uploaded
    }
}

extension APIClient {
    func uploadAvatar(_ image: Data, context: AuthRequestSession) async throws -> String {
        let boundary = "Avatar-" + UUID().uuidString
        var request = URLRequest(url: baseURL.appendingPathComponent("files/upload"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        body.append(image)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let (data, _) = try await sessionData(for: request, context: context)
        struct Uploaded: Decodable { let url: String }
        struct Envelope: Decodable { let code: Int; let message: String?; let data: Uploaded? }
        let decoder = JSONDecoder()
        let uploaded: Uploaded
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            guard envelope.code == 0 || envelope.code == 200, let value = envelope.data else {
                throw AvatarFailure(message: envelope.message ?? "照片上传失败，请重试")
            }
            uploaded = value
        } else { uploaded = try decoder.decode(Uploaded.self, from: data) }
        guard let resolved = URL(string: uploaded.url, relativeTo: baseURL)?.absoluteURL,
              ["https", "http"].contains(resolved.scheme ?? "") else {
            throw AvatarFailure(message: "照片地址无效，请重试")
        }
        return resolved.absoluteString
    }
}

private struct AvatarPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct AvatarPhotoField: View {
    @ObservedObject var draft: AvatarDraftState
    var disabled = false
    var initialOpen = false
    var compact = false
    var size: CGFloat = 76
    var onSave: ((UIImage, Data) async throws -> Void)? = nil
    @State private var picking = false
    @State private var selection: PhotosPickerItem?
    @State private var source: AvatarPhoto?
    @State private var reading = false
    @State private var failure: String?

    var body: some View {
        HStack(spacing: 18) {
            Button { picking = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = draft.image { Image(uiImage: image).resizable().scaledToFill() }
                        else if let url = URL(string: draft.url), !draft.url.isEmpty {
                            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { placeholder }
                        } else { placeholder }
                    }.frame(width: size, height: size).clipShape(Circle()).overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                    Image(systemName: "camera.fill").font(.system(size: 12)).padding(7)
                        .foregroundStyle(Color.bgPrimary).background(Color.accentDefault, in: Circle())
                }
            }.accessibilityLabel("更换头像")
            if !compact { VStack(alignment: .leading, spacing: 6) {
                Text("个人头像").font(.headline).foregroundStyle(Color.textPrimary)
                Button("选择照片") { picking = true }.frame(minHeight: 44).tint(Color.accentDefault)
                if draft.image != nil || !draft.url.isEmpty { Button("恢复默认") { draft.clear() }.font(.caption).tint(Color.textSecondary) }
                Text(reading ? "正在读取照片…" : draft.image == nil ? "使用照片，或保留默认头像" : "新头像将在保存资料后生效")
                    .font(.caption).foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: 0) }
        }
        .disabled(disabled || reading)
        .photosPicker(isPresented: $picking, selection: $selection, matching: .images)
        .task(id: selection) {
            guard let selection else { return }
            reading = true
            defer { reading = false; self.selection = nil }
            do {
                guard let data = try await selection.loadTransferable(type: Data.self), !data.isEmpty else { throw AvatarFailure(message: "无法读取照片，请重新选择") }
                try Task.checkCancellation()
                guard data.count <= 10 * 1024 * 1024 else { throw AvatarFailure(message: "照片超过 10MB，请选择较小的照片") }
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let width = props[kCGImagePropertyPixelWidth] as? Double,
                      let height = props[kCGImagePropertyPixelHeight] as? Double, width * height <= 40_000_000,
                      let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 4096] as CFDictionary)
                else { throw AvatarFailure(message: "照片无法读取或像素过大，请重新选择") }
                self.source = AvatarPhoto(image: UIImage(cgImage: cg))
            } catch is CancellationError { }
            catch { failure = error.localizedDescription }
        }
        .sheet(item: $source) { photo in AvatarCropView(image: photo.image, savesImmediately: compact) { image, data in
            try await onSave?(image, data)
            draft.choose(image, data: data)
        } }
        .alert("无法使用这张照片", isPresented: .init(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("知道了", role: .cancel) { } } message: { Text(failure ?? "") }
        .task { if initialOpen { picking = true } }
    }
    private var placeholder: some View {
        ZStack { Color.bgTertiary; Image(systemName: "person.crop.circle").font(.system(size: 44)).foregroundStyle(Color.accentDefault) }
    }
}

/// The profile avatar opens Photos directly. Pending uploads never replace the visible avatar.
struct AvatarPhotoButton: View {
    let url: String
    var size: CGFloat = 56
    let onSave: (String) async throws -> Void
    @StateObject private var displayDraft = AvatarDraftState()
    @StateObject private var uploadDraft = AvatarDraftState()
    var body: some View {
        AvatarPhotoField(draft: displayDraft, compact: true, size: size) { image, data in
            uploadDraft.choose(image, data: data)
            let uploaded = try await uploadDraft.resolve()
            try await onSave(uploaded)
        }
        .onChange(of: url, initial: true) { _, value in displayDraft.clear(); displayDraft.url = value }
    }
}

private struct AvatarCropView: View {
    let image: UIImage
    var savesImmediately = false
    let onUse: (UIImage, Data) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var zoom: Double = 1
    @State private var offset = CGSize.zero
    @State private var dragStart: CGSize?
    @State private var zoomStart: Double?
    @State private var failure: String?
    private let side: CGFloat = 280
    private var base: CGFloat { max(side / image.size.width, side / image.size.height) }
    private func clamped(_ value: CGSize, zoom: Double) -> CGSize {
        let maxX = max(0, (image.size.width * base * zoom - side) / 2)
        let maxY = max(0, (image.size.height * base * zoom - side) / 2)
        return CGSize(width: min(maxX, max(-maxX, value.width)), height: min(maxY, max(-maxY, value.height)))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("拖动或双指缩放，调整圆形区域内的画面").font(.callout).foregroundStyle(Color.textSecondary)
                    ZStack {
                        Color.bgTertiary
                        Image(uiImage: image).resizable().frame(width: image.size.width * base, height: image.size.height * base).scaleEffect(zoom).offset(offset)
                        Circle().stroke(.white.opacity(0.8), lineWidth: 2).padding(1).allowsHitTesting(false)
                    }
                    .frame(width: side, height: side).clipShape(Circle()).contentShape(Circle())
                    .gesture(DragGesture().onChanged { value in
                        if dragStart == nil { dragStart = offset }
                        offset = clamped(CGSize(width: (dragStart?.width ?? 0) + value.translation.width, height: (dragStart?.height ?? 0) + value.translation.height), zoom: zoom)
                    }.onEnded { _ in dragStart = nil })
                    .simultaneousGesture(MagnifyGesture().onChanged { value in
                        if zoomStart == nil { zoomStart = zoom }
                        zoom = min(3, max(1, (zoomStart ?? 1) * value.magnification)); offset = clamped(offset, zoom: zoom)
                    }.onEnded { _ in zoomStart = nil })
                    .accessibilityLabel("头像裁剪预览")
                    Slider(value: $zoom, in: 1...3).accessibilityLabel("缩放头像").tint(Color.accentDefault)
                        .onChange(of: zoom) { _, value in offset = clamped(offset, zoom: value) }
                    HStack {
                        pan("左", symbol: "arrow.left", x: -14, y: 0)
                        pan("上", symbol: "arrow.up", x: 0, y: -14)
                        pan("下", symbol: "arrow.down", x: 0, y: 14)
                        pan("右", symbol: "arrow.right", x: 14, y: 0)
                        Button("复位") { zoom = 1; offset = .zero }.frame(minWidth: 44, minHeight: 44)
                    }.tint(Color.accentDefault)
                    if let failure { Text(failure).foregroundStyle(Color.stateError).font(.callout) }
                    Button(saving ? "正在保存…" : savesImmediately ? "保存头像" : "使用这张照片", action: export).buttonStyle(.borderedProminent).tint(Color.brandDefault).frame(minHeight: 44)
                }.padding(20).disabled(saving)
            }
            .background(Color.bgPrimary).navigationTitle("调整头像").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(saving) } }
        }.presentationDetents([.large]).interactiveDismissDisabled(saving)
    }
    private func pan(_ label: String, symbol: String, x: CGFloat, y: CGFloat) -> some View {
        Button { offset = clamped(CGSize(width: offset.width + x, height: offset.height + y), zoom: zoom) } label: { Image(systemName: symbol).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("向\(label)调整")
    }
    private func export() {
        guard !saving else { return }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let factor = 512 / side
        let cropped = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            let size = CGSize(width: image.size.width * base * zoom, height: image.size.height * base * zoom)
            image.draw(in: CGRect(x: ((side - size.width) / 2 + offset.width) * factor, y: ((side - size.height) / 2 + offset.height) * factor, width: size.width * factor, height: size.height * factor))
        }
        guard let data = cropped.jpegData(compressionQuality: 0.88) else { failure = "照片处理失败，请重试"; return }
        saving = true; failure = nil
        Task {
            defer { saving = false }
            do { try await onUse(cropped, data); dismiss() }
            catch { failure = error.localizedDescription }
        }
    }
}
