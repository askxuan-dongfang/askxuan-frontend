import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct JourneyDetailView: View {
  let bookingId: String
  var body: some View {
    ScrollView { JourneyRecordPanel(bookingId: bookingId).padding(16) }
      .background(Color.bgPrimary).navigationTitle(JourneyHost.provider ? "服务履约" : "我的服务记录")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink("订单详情") { JourneyHost.orderDetail(bookingId) }
        }
      }
  }
}
struct JourneyRecordPanel: View {
  let bookingId: String
  var onStatusChange: ((String) -> Void)? = nil
  @State private var progress: JourneyProgress?
  @State private var error: String?
  @State private var loadGeneration = 0
  @State private var busy = false
  @State private var wish = ""
  @State private var wishExpanded = false
  @State private var wishID = UUID().uuidString
  @State private var reviewed = false
  @State private var reason = ""
  @State private var completed = false
  @State private var success: String?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let error {
        Text(error).foregroundStyle(Color.red).font(.subheadline)
        Button("重新加载") { Task { await load() } }
      }
      if let progress {
        statusCard(progress)
        wishCard(progress)
        timelineCard(progress)
        if JourneyHost.provider && progress.status == "in_progress" {
          JourneyComposer(bookingId: bookingId, finalReceipt: false) { await load() }
        }
        receiptsCard(progress)
        if JourneyHost.provider && progress.status == "in_progress" {
          JourneyComposer(bookingId: bookingId, finalReceipt: true) { await load() }
        }
        if let success {
          Text(success).font(.subheadline).foregroundStyle(Color.accentDefault)
            .accessibilityAddTraits(.updatesFrequently)
        }
      } else if error == nil {
        ProgressView("正在展开服务记录…").frame(maxWidth: .infinity)
      }
    }.foregroundStyle(Color.textPrimary).tint(Color.brandDefault)
      .task(id: bookingId) {
        await load()
        while !Task.isCancelled {
          do { try await Task.sleep(for: .seconds(15)) } catch { break }
          if scenePhase == .active { await load() }
        }
      }
      .onChange(of: progress?.status) { previous, status in
        if previous != nil, let status { onStatusChange?(status) }
      }
      .sheet(isPresented: $completed) {
        VStack(spacing: 18) {
          Image(systemName: "checkmark.seal").font(.system(size: 56, weight: .light))
            .foregroundStyle(Color.accentDefault)
          Text("这份心意，已有记录").font(.title2).fontDesign(.serif)
          Text("你已确认本次服务回执，完整记录已归档。").font(.subheadline).foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
          Button("留存这份记录") { completed = false }.buttonStyle(.borderedProminent).foregroundStyle(
            Color.textOnBrand)
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.bgPrimary)
          .presentationDetents([.medium]).presentationDragIndicator(.visible)
      }
  }
  private func statusCard(_ progress: JourneyProgress) -> some View {
    JourneyCard {
      HStack {
        Text(JourneyText.status(progress.status)).font(.headline)
        Spacer()
        Image(systemName: "leaf.circle").font(.title).foregroundStyle(Color.accentDefault)
          .accessibilityHidden(true)
      }
      JourneySteps(status: progress.status)
      Text(statusHint(progress.status)).font(.subheadline).foregroundStyle(Color.textSecondary)
      if JourneyHost.provider && ["pending", "confirmed"].contains(progress.status) {
        Button(progress.status == "pending" ? "确认接单" : "开始执行") {
          Task { await advance(progress.status) }
        }.buttonStyle(.borderedProminent).foregroundStyle(Color.textOnBrand).disabled(busy)
      }
    }
  }

  private func wishCard(_ progress: JourneyProgress) -> some View {
    JourneyCard {
      Label(JourneyHost.provider ? "信众的心愿" : "我的心愿", systemImage: "leaf").font(.headline)
      if let latest = progress.records.last(where: { $0.kind == "wish" }) {
        Text(latest.content).font(.title3).fontDesign(.serif).lineSpacing(6)
        Text(latest.createdAt).font(.caption).foregroundStyle(Color.textSecondary)
        if progress.records.filter({ $0.kind == "wish" }).count > 1 {
          DisclosureGroup("之前的心愿") {
            ForEach(progress.records.filter { $0.kind == "wish" && $0.id != latest.id }) {
              row in
              Text(row.content).font(.subheadline)
              Text(row.createdAt).font(.caption2)
            }
          }
        }
      } else {
        Text("本次服务尚未留下心愿。").font(.subheadline).foregroundStyle(Color.textSecondary)
      }
      if !JourneyHost.provider && ["pending", "confirmed"].contains(progress.status) {
        DisclosureGroup("留一句心愿（选填）", isExpanded: $wishExpanded) {
          TextField("写下心意或希望执行方留意的事项", text: $wish, axis: .vertical).lineLimit(3...6)
            .textFieldStyle(.roundedBorder).accessibilityIdentifier("journey.wish")
            .onChange(of: wish) { _, value in
              wish = String(value.prefix(300))
              wishID = UUID().uuidString
            }
          Text("\(wish.count)/300 · 填写与否不影响服务").font(.caption)
          Button("记下心愿") { Task { await publishWish() } }.disabled(
            busy || wish.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
        }
      }
    }
  }

  private func timelineCard(_ progress: JourneyProgress) -> some View {
    JourneyCard {
      Label("一路的进展", systemImage: "list.bullet.clipboard").font(.headline)
      ForEach(timeline(progress)) { row in
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(
            Color.accentDefault
          ).padding(.top, 6)
          VStack(alignment: .leading, spacing: 7) {
            HStack {
              Text(row.title).font(.subheadline.bold())
              Spacer()
              Text(JourneyText.actor(row.actor)).font(.caption2)
            }
            Text(row.date).font(.caption2).foregroundStyle(Color.textSecondary)
            if !row.content.isEmpty { Text(row.content).font(.subheadline) }
            ForEach(row.files) { file in JourneyMediaView(bookingId: bookingId, file: file) }
          }
        }.padding(.vertical, 6)
      }
      if timeline(progress).isEmpty {
        Text("真实执行记录将在这里显示。").font(.subheadline).foregroundStyle(Color.textSecondary)
      }
    }
  }

  private func receiptsCard(_ progress: JourneyProgress) -> some View {
    JourneyCard {
      Label("服务回执 · \(progress.receipts.count) 份留存", systemImage: "doc.text.image").font(
        .headline)
      if progress.receipts.isEmpty {
        Text(
          ["completed", "reviewed"].contains(progress.status) ? "此历史订单未留存回执。" : "执行方尚未提交最终回执。"
        ).font(.subheadline).foregroundStyle(Color.textSecondary)
      }
      ForEach(Array(progress.receipts.enumerated()), id: \.element.id) { index, receipt in
        VStack(alignment: .leading, spacing: 12) {
          Text("回执 \(index+1)").font(.headline)
          Text("\(receipt.createdAt) · \(JourneyText.actor(receipt.operatorType))").font(
            .caption
          ).foregroundStyle(Color.textSecondary)
          Text(receipt.summary).font(.subheadline)
          ForEach(receipt.files) { file in JourneyMediaView(bookingId: bookingId, file: file) }
          DisclosureGroup("回执校验信息") {
            Text(receipt.digest).font(.caption2).textSelection(.enabled)
            Text("SHA-256 用于文件完整性校验，非区块链存证，不代表平台已核实服务现场。").font(.caption2).foregroundStyle(
              Color.textSecondary)
          }
          Divider()
        }
      }
      if !JourneyHost.provider && progress.status == "pending_receipt" {
        Toggle("我已查看回执，确认本次服务已完成。", isOn: $reviewed).font(.subheadline).accessibilityIdentifier(
          "journey.reviewed")
        Button("回执已核对，确认完成") { Task { await accept() } }.buttonStyle(.borderedProminent)
          .foregroundStyle(Color.textOnBrand)
          .disabled(busy || !reviewed).accessibilityIdentifier("journey.accept")
        DisclosureGroup("需要补充回执") {
          TextField("请描述需要补充的内容（至少 5 字）", text: $reason, axis: .vertical).lineLimit(2...5)
            .textFieldStyle(.roundedBorder).onChange(of: reason) { _, v in
              reason = String(v.prefix(200))
            }
          Button("要求补充回执") {
            Task { await action("request-revision", body: ["remark": reason]) }
          }.disabled(busy || reason.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
        }
      }
    }
  }
  private struct TimelineRow: Identifiable {
    let id: String
    let title: String
    let date: String
    let actor: String
    let content: String
    let files: [JourneyMedia]
  }
  private func timeline(_ p: JourneyProgress) -> [TimelineRow] {
    ((p.logs ?? []).map {
      TimelineRow(
        id: "log\($0.id)", title: JourneyText.status($0.toStatus), date: $0.createTime,
        actor: $0.operatorType,
        content: $0.toStatus == "pending_receipt" ? "执行方提交了服务说明与影像，等待核对。" : $0.remark, files: [])
    }
      + p.records.filter { $0.kind == "update" }.map {
        TimelineRow(
          id: $0.id, title: "执行记录", date: $0.createdAt, actor: $0.operatorType, content: $0.content,
          files: $0.files)
      }).sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
  }
  private func statusHint(_ status: String) -> String {
    switch status {
    case "pending": return "预约已送达，等待执行方接单。"
    case "confirmed": return "已接单，等待按预约安排开始服务。"
    case "in_progress": return "服务正在执行，新的阶段记录会同步在这里。"
    case "pending_receipt": return JourneyHost.provider ? "回执已提交，等待信众查看并确认。" : "请查看执行说明与影像，再确认完成。"
    case "cancelled": return "预约已取消，已有记录保留。"
    default: return "服务记录与回执已留存，可随时回看。"
    }
  }
  @MainActor private func load() async {
    loadGeneration += 1
    let generation = loadGeneration
    do {
      let result = try await JourneyAPI.progress(bookingId)
      try Task.checkCancellation()
      guard generation == loadGeneration else { return }
      if result.receipts.count != progress?.receipts.count { reviewed = false }
      progress = result
      error = nil
    } catch is CancellationError {} catch { self.error = error.localizedDescription }
  }
  @MainActor private func action(_ name: String, body: [String: Any] = [:]) async {
    busy = true
    defer { busy = false }
    error = nil
    do {
      try await JourneyAPI.action(bookingId, name, body: body)
      await load()
    } catch { self.error = error.localizedDescription }
  }
  @MainActor private func publishWish() async {
    busy = true
    defer { busy = false }
    error = nil
    do {
      try await JourneyAPI.action(
        bookingId, "progress/wish", body: ["id": wishID, "content": wish, "fileIds": []])
      wish = ""
      wishExpanded = false
      wishID = UUID().uuidString
      success = "心愿已记下，执行方可以查看。"
      await load()
    } catch { self.error = error.localizedDescription }
  }
  @MainActor private func accept() async {
    busy = true
    defer { busy = false }
    error = nil
    do {
      try await JourneyAPI.action(bookingId, "accept-receipt")
      await load()
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { completed = true }
      if !reduceMotion { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    } catch { self.error = error.localizedDescription }
  }
  @MainActor private func advance(_ status: String) async {
    busy = true
    defer { busy = false }
    error = nil
    do {
      try await JourneyAPI.advance(bookingId, status: status)
      await load()
    } catch { self.error = error.localizedDescription }
  }
}

struct JourneyComposer: View {
  let bookingId: String
  let finalReceipt: Bool
  let onSaved: () async -> Void
  @State private var content = ""
  @State private var files: [JourneyMedia] = []
  @State private var requestID = UUID().uuidString
  @State private var busy = false
  @State private var error: String?
  @State private var success: String?
  @State private var importing = false
  @State private var selectedPhoto: PhotosPickerItem?
  var body: some View {
    JourneyCard {
      Text(finalReceipt ? "提交最终回执" : "发布阶段记录").font(.headline)
      Text(finalReceipt ? "附上执行说明和现场影像，提交后等待信众确认。" : "记录实际执行的步骤，最终回执另行提交。").font(.caption)
        .foregroundStyle(Color.textSecondary)
      TextField("执行内容、时间与情况", text: $content, axis: .vertical).lineLimit(3...8).textFieldStyle(
        .roundedBorder
      ).accessibilityIdentifier(finalReceipt ? "journey.receipt.text" : "journey.progress.text")
        .onChange(of: content) { _, v in
          content = String(v.prefix(2000))
          requestID = UUID().uuidString
        }
      HStack {
        PhotosPicker(
          selection: $selectedPhoto, matching: .any(of: [.images, .videos]),
          preferredItemEncoding: .compatible
        ) {
          Label("照片／视频", systemImage: "photo")
        }.disabled(busy || files.count >= 8)
        Button("选取文件") { importing = true }.disabled(busy || files.count >= 8)
      }.font(.subheadline)
      Text("JPG、PNG、WebP、MP4、WebM · 最多 8 个，每个 20 MB").font(.caption2).foregroundStyle(
        Color.textSecondary)
      ForEach(files) { file in
        HStack {
          Text(file.name).font(.caption)
          Spacer()
          Button("移除") {
            files.removeAll { $0.id == file.id }
            requestID = UUID().uuidString
          }.disabled(busy)
        }
      }
      if busy { ProgressView("正在保存…") }
      if let error { Text(error).font(.caption).foregroundStyle(Color.red) }
      if let success { Text(success).font(.caption).foregroundStyle(Color.accentDefault) }
      Button(finalReceipt ? "提交回执，等待信众确认" : "发布真实进展") { Task { await submit() } }.buttonStyle(
        .borderedProminent
      ).foregroundStyle(Color.textOnBrand)
        .disabled(
          busy
            || content.trimmingCharacters(in: .whitespacesAndNewlines).count
              < (finalReceipt ? 5 : 2)
            || (finalReceipt && files.isEmpty))
    }.fileImporter(isPresented: $importing, allowedContentTypes: [.image, .movie]) { result in
      Task {
        do {
          let url = try result.get()
          let scoped = url.startAccessingSecurityScopedResource()
          defer { if scoped { url.stopAccessingSecurityScopedResource() } }
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size <= 20 * 1024 * 1024 else { throw JourneyFailure(message: "每个文件最多 20 MB") }
          let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? ""
          await upload(try Data(contentsOf: url), name: url.lastPathComponent, mime: mime)
        } catch { self.error = error.localizedDescription }
      }
    }.onChange(of: selectedPhoto) { _, item in
      guard let item else { return }
      Task {
        busy = true
        defer {
          busy = false
          selectedPhoto = nil
        }
        do {
          guard let data = try await item.loadTransferable(type: Data.self) else {
            throw JourneyFailure(message: "未能读取所选文件")
          }
          let type = item.supportedContentTypes.first
          await upload(
            data, name: "现场记录.\(type?.preferredFilenameExtension ?? "bin")",
            mime: type?.preferredMIMEType ?? "")
        } catch { self.error = error.localizedDescription }
      }
    }
  }
  @MainActor private func upload(_ data: Data, name: String, mime: String) async {
    guard files.count < 8 else { return }
    busy = true
    error = nil
    defer { busy = false }
    do {
      guard data.count <= 20 * 1024 * 1024 else { throw JourneyFailure(message: "每个文件最多 20 MB") }
      let uploadData: Data
      let uploadName: String
      let uploadMime: String
      if mime.hasPrefix("image/"), !["image/jpeg", "image/png", "image/webp"].contains(mime),
        let image = UIImage(data: data), let jpg = image.jpegData(compressionQuality: 0.9)
      {
        uploadData = jpg
        uploadName = "现场记录.jpg"
        uploadMime = "image/jpeg"
      } else {
        uploadData = data
        uploadName = name
        uploadMime = mime
      }
      files.append(
        try await JourneyAPI.upload(bookingId, data: uploadData, name: uploadName, mime: uploadMime)
      )
      requestID = UUID().uuidString
    } catch { self.error = error.localizedDescription }
  }
  @MainActor private func submit() async {
    busy = true
    error = nil
    success = nil
    defer { busy = false }
    do {
      let body: [String: Any] =
        finalReceipt
        ? ["summary": content, "fileIds": files.map(\.id)]
        : ["id": requestID, "content": content, "fileIds": files.map(\.id)]
      try await JourneyAPI.action(
        bookingId, finalReceipt ? "receipts" : "progress/update", body: body)
      content = ""
      files = []
      requestID = UUID().uuidString
      success = finalReceipt ? "回执已提交，等待信众确认。" : "阶段记录已发布。"
      await onSaved()
    } catch { self.error = error.localizedDescription }
  }
}

struct JourneyMediaView: View {
  let bookingId: String
  let file: JourneyMedia
  @State private var image: UIImage?
  @State private var player: AVPlayer?
  @State private var temporaryURL: URL?
  @State private var error: String?
  @State private var loading = false
  @State private var task: Task<Void, Never>?
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let image {
        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 320).clipShape(
          RoundedRectangle(cornerRadius: 12)
        ).accessibilityLabel(file.name)
      } else if let player {
        VideoPlayer(player: player).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 12))
      } else {
        Button {
          task = Task { await load() }
        } label: {
          Label(
            loading
              ? "正在读取…" : "查看\(file.contentType.hasPrefix("video/") ? "视频":"图片") · \(file.name)",
            systemImage: file.contentType.hasPrefix("video/") ? "play.rectangle" : "photo")
        }.font(.subheadline).disabled(loading)
      }
      if let error { Text(error).font(.caption).foregroundStyle(Color.red) }
    }.onDisappear {
      task?.cancel()
      player?.pause()
      player = nil
      image = nil
      if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
      temporaryURL = nil
    }
  }
  @MainActor private func load() async {
    loading = true
    error = nil
    defer { loading = false }
    do {
      let data = try await JourneyAPI.media(bookingId, file: file)
      try Task.checkCancellation()
      if file.contentType.hasPrefix("video/") {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
          .appendingPathExtension(file.contentType == "video/webm" ? "webm" : "mp4")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        temporaryURL = url
        player = AVPlayer(url: url)
      } else {
        guard let decoded = UIImage(data: data) else { throw JourneyFailure(message: "无法显示此图片") }
        image = decoded
      }
    } catch is CancellationError {} catch { self.error = error.localizedDescription }
  }
}
