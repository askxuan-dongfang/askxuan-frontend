import SwiftUI

struct JourneyCard<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 14) { content }
      .frame(maxWidth: .infinity, alignment: .leading).padding(18)
      .background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.accentDefault.opacity(0.18)))
  }
}
struct JourneySteps: View {
  let status: String
  private let states = ["confirmed", "in_progress", "pending_receipt", "completed"]
  var body: some View {
    if status == "cancelled" {
      Text("预约已取消，已有记录保留。").font(.caption).foregroundStyle(Color.textSecondary)
    } else {
      let current = states.firstIndex(of: status == "reviewed" ? "completed" : status) ?? -1
      HStack(alignment: .top, spacing: 4) {
        ForEach(Array(["已接单", "执行中", "已交回执", "已完成"].enumerated()), id: \.offset) { index, title in
          VStack(spacing: 8) {
            Image(
              systemName: index < current || status == "completed" || status == "reviewed"
                ? "checkmark.circle.fill" : "\(index+1).circle"
            )
            .font(.title3).foregroundStyle(
              index <= current ? Color.accentDefault : Color.textSecondary.opacity(0.45))
            Text(title).font(.caption2).foregroundStyle(
              index == current ? Color.textPrimary : Color.textSecondary)
          }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
            .accessibilityLabel(
              "\(title)，\(index < current ? "已完成" : index == current ? "当前阶段" : "待进行")")
        }
      }.padding(.vertical, 8)
    }
  }
}
struct JourneyEntryView: View {
  var home = false
  @State private var data: JourneyIndex?
  @State private var error: String?
  private var current: JourneyItem? {
    data?.list.first {
      ["pending", "confirmed", "in_progress", "pending_receipt"].contains($0.status)
    }
  }
  var body: some View {
    Group {
      if !home || current != nil || error != nil {
        JourneyCard {
          NavigationLink {
            if home, let current {
              JourneyDetailView(bookingId: current.id)
            } else {
              JourneyCenterView()
            }
          } label: {
            HStack(spacing: 14) {
              Image(systemName: "leaf.circle").font(.title).foregroundStyle(Color.accentDefault)
              VStack(alignment: .leading, spacing: 5) {
                Text(
                  home
                    ? "\(current?.providerName ?? "") · \(current?.serviceName ?? "服务进度")"
                    : JourneyHost.provider ? "履约工作台" : "服务进度"
                ).font(.headline)
                if let error {
                  Text(error).font(.caption)
                } else if let data {
                  Text(
                    home
                      ? JourneyText.status(current?.status ?? "")
                      : JourneyHost.provider
                        ? "\(data.counts.pending) 待接单 · \(data.counts.executing) 执行中 · \(data.counts.revision) 待补充"
                        : "\(data.counts.active) 进行中 · \(data.counts.receipt) 待我确认 · \(data.counts.complete) 已完成"
                  ).font(.caption).foregroundStyle(Color.textSecondary)
                } else {
                  ProgressView()
                }
              }
              Spacer(minLength: 0)
              Image(systemName: "chevron.right").font(.caption)
            }.foregroundStyle(Color.textPrimary)
          }.buttonStyle(.plain)
          if error != nil { Button("重新加载") { Task { await load() } } }
        }
      }
    }.task { await load() }
  }
  @MainActor private func load() async {
    do {
      data = try await JourneyAPI.index()
      error = nil
    } catch is CancellationError {} catch { self.error = "进度暂时无法加载" }
  }
}
struct JourneyCenterView: View {
  @State private var data: JourneyIndex?
  @State private var filter = "all"
  @State private var query = ""
  @State private var submittedQuery = ""
  @State private var draftFrom = ""
  @State private var draftTo = ""
  @State private var from = ""
  @State private var to = ""
  @State private var page = 1
  @State private var error: String?
  @State private var loading = false
  @Environment(\.scenePhase) private var scenePhase
  private var requestKey: String { "\(filter)|\(page)|\(submittedQuery)|\(from)|\(to)" }
  private var filters: [(String, String)] {
    JourneyHost.provider
      ? [
        ("all", "全部"), ("pending", "待接单"), ("confirmed", "待执行"), ("in_progress", "执行中"),
        ("revision", "需补充"), ("receipt", "待信众确认"), ("complete", "已完成"),
      ] : [("all", "全部"), ("active", "进行中"), ("receipt", "待我确认"), ("complete", "已完成")]
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 8) {
            Text("心有所寄，事有所应").font(.caption).foregroundStyle(Color.accentDefault)
            Text(filter == "archive" ? "留存每一份回执" : JourneyHost.provider ? "把每一次托付做好" : "看见心愿的每一步")
              .font(.title2).fontDesign(.serif)
            Text("接单、执行、回执，真实进展在这里。").font(.caption).foregroundStyle(Color.textSecondary)
          }
          Spacer()
          Image(systemName: "leaf.circle").font(.system(size: 42, weight: .ultraLight))
            .foregroundStyle(Color.accentDefault).accessibilityHidden(true)
        }.padding(.vertical, 8)
        Picker(
          "视图",
          selection: Binding(
            get: { filter == "archive" },
            set: {
              filter = $0 ? "archive" : "all"
              page = 1
            })
        ) {
          Text("服务进度").tag(false)
          Text("回执档案").tag(true)
        }.pickerStyle(.segmented)
        if filter != "archive" {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack {
              ForEach(filters, id: \.0) { value, title in
                Button(title) {
                  filter = value
                  page = 1
                }.buttonStyle(.bordered).tint(
                  filter == value ? Color.brandDefault : Color.textSecondary
                )
                .accessibilityAddTraits(filter == value ? .isSelected : [])
              }
            }
          }
        }
        HStack {
          TextField("搜索寺院、大师或服务", text: $query).textFieldStyle(.roundedBorder).submitLabel(.search)
            .onSubmit { search() }
          Button("查找", action: search)
        }
        if filter == "archive" {
          HStack {
            TextField("起始日期 YYYY-MM-DD", text: $draftFrom).textFieldStyle(.roundedBorder)
              .keyboardType(
                .numbersAndPunctuation
              ).accessibilityLabel("预约起始日期")
            TextField("结束日期 YYYY-MM-DD", text: $draftTo).textFieldStyle(.roundedBorder)
              .keyboardType(
                .numbersAndPunctuation
              ).accessibilityLabel("预约结束日期")
          }.font(.caption)
          Button("应用日期") {
            from = draftFrom.trimmingCharacters(in: .whitespaces)
            to = draftTo.trimmingCharacters(in: .whitespaces)
            page = 1
          }
        }
        if let error {
          Text(error).foregroundStyle(Color.red)
          Button("重新加载") { Task { await load() } }
        }
        if loading && data == nil { ProgressView("正在读取服务记录…") }
        if let data, error == nil {
          if data.list.isEmpty {
            ContentUnavailableView(
              "这里还没有服务记录", systemImage: "doc.text", description: Text("新的预约与回执会在这里留存。"))
          }
          ForEach(data.list) { row in
            JourneyCard {
              HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                  Text(row.providerName).font(.headline)
                  Text(row.serviceName).font(.subheadline).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                Text(row.needsRevision > 0 ? "待补充回执" : JourneyText.status(row.status)).font(
                  .caption
                ).foregroundStyle(Color.accentDefault)
              }
              Text("\(row.bookingDate) · \(row.timeSlot)").font(.caption).foregroundStyle(
                Color.textSecondary)
              JourneySteps(status: row.status)
              if !row.latest.isEmpty { Text(row.latest).font(.subheadline).lineLimit(3) }
              if filter == "archive" {
                ForEach(row.preview) { file in JourneyMediaView(bookingId: row.id, file: file) }
              }
              Text(row.updatedAt).font(.caption2).foregroundStyle(Color.textSecondary)
              HStack {
                Text("\(row.receiptCount) 份回执留存").font(.caption)
                Spacer()
                NavigationLink("\(row.status == "pending_receipt" ? "查看回执" : "查看完整过程") ↗") {
                  JourneyDetailView(bookingId: row.id)
                }.font(.subheadline)
              }
            }
          }
          if data.total > 20 {
            HStack {
              Button("上一页") { page -= 1 }.disabled(page <= 1 || loading)
              Spacer()
              Text("\(page) / \((data.total+19)/20)")
              Spacer()
              Button("下一页") { page += 1 }.disabled(page * 20 >= data.total || loading)
            }
          }
        }
      }.padding(16)
    }.background(Color.bgPrimary).foregroundStyle(Color.textPrimary).tint(Color.brandDefault)
      .navigationTitle(JourneyHost.provider ? "履约工作台" : "服务进度").navigationBarTitleDisplayMode(
        .inline
      )
      .task(id: requestKey) { await load() }.refreshable { await load() }
      .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
  }
  private func search() {
    submittedQuery = String(query.prefix(60))
    page = 1
  }
  @MainActor private func load() async {
    let key = requestKey
    loading = true
    do {
      let result = try await JourneyAPI.index(
        filter: filter, page: page, query: submittedQuery, from: from, to: to)
      try Task.checkCancellation()
      guard key == requestKey else { return }
      data = result
      error = nil
    } catch is CancellationError {} catch {
      if key == requestKey { self.error = error.localizedDescription }
    }
    if key == requestKey { loading = false }
  }
}
