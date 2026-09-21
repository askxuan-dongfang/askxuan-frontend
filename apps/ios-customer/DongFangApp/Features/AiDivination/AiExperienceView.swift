import SwiftUI

struct AiExperienceView: View {
    let skill: String
    @Binding var naming: AiNamingInput
    @Binding var decision: AiDecisionInput
    @State private var result: AiExperienceResult?
    @State private var executedInput: AiExperienceInput?
    @State private var favorites = Set<String>()
    @State private var note = ""
    @State private var busy = false
    @State private var error = ""
    @State private var saved: AiExperienceNote?
    @State private var savedRequest: AiNoteSaveRequest?
    @State private var saveIdentity = AiNoteSaveIdentity()
    @FocusState private var editing: Bool
    private var input: AiExperienceInput {
        AiExperienceInput(skill: skill, naming: skill == "naming" ? naming : nil, decision: skill == "decision" ? decision : nil)
    }
    private var stale: Bool { executedInput != input }
    private var savedUnchanged: Bool {
        guard let savedRequest else { return false }
        return savedRequest.input == input && savedRequest.favorites == favorites.sorted() && savedRequest.note == note
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(skill == "naming" ? "让喜欢的字，组成自己的名字" : "把两难摊开，看见自己的取舍")
                    .font(AppTypography.title(26))
                Text(skill == "naming" ? "从字义和审美出发，寻找姓名或笔名的灵感。" : "你来给出感受与权重，工具帮你整理。分数不是成功概率。")
                    .font(.subheadline).foregroundStyle(Color.textSecondary)
                Group { if skill == "naming" { namingForm } else { decisionForm } }.disabled(busy)
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("ai-experience-error") }
                Button { editing = false; Task { await run() } } label: {
                    HStack { if busy { ProgressView() }; Text(busy ? "正在处理…" : result == nil ? "开始整理" : "更新结果") }.frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.borderedProminent).tint(.brandDefault).disabled(busy).accessibilityIdentifier("ai-experience-run")
                if let result, let executedInput {
                    if stale { Label("资料已修改，请更新结果后再保存。", systemImage: "arrow.clockwise").font(.footnote).foregroundStyle(Color.accentDefault) }
                    AiExperienceResultView(input: executedInput, result: result, favorites: $favorites, editable: !busy && !stale)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("留一句给自己的话").font(.headline)
                        TextField("记下此刻的想法（选填）", text: $note, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder).focused($editing).disabled(busy)
                        Text("\(note.count) / 1000").font(.caption).foregroundStyle(note.count > 1000 ? .red : .secondary)
                        Button { Task { await save() } } label: {
                            Label(savedUnchanged ? "已保存到手记" : "保存到我的手记", systemImage: savedUnchanged ? "checkmark.circle" : "bookmark")
                                .frame(maxWidth: .infinity).padding(10)
                        }.buttonStyle(.bordered).disabled(busy || stale || note.count > 1000 || savedUnchanged).accessibilityIdentifier("ai-experience-save")
                        if let saved { NavigationLink("查看已保存手记") { AiSavedNoteView(id: saved.id) } }
                    }
                }
            }.padding(18).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Color.bgPrimary).navigationTitle(skill == "naming" ? "姓名灵感" : "两难梳理")
            .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
    }
    private var namingForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("用途", selection: $naming.purpose) { Text("姓名").tag("name"); Text("笔名").tag("pen") }.pickerStyle(.segmented)
            if naming.purpose == "name" { TextField("姓氏（最多两个汉字，可留空）", text: $naming.surname).textFieldStyle(.roundedBorder).focused($editing) }
            Picker("喜欢的气质", selection: $naming.style) {
                Text("温柔安定").tag("gentle"); Text("自然开阔").tag("nature"); Text("清朗有志").tag("clear")
            }.pickerStyle(.menu)
            TextField("避用字（最多十六个汉字）", text: $naming.avoid).textFieldStyle(.roundedBorder).focused($editing)
            Text("首期收录 16 个字、12 组组合；先比较字义和读音，再结合自己的实际使用场景。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18))
            .onChange(of: naming.purpose) { if naming.purpose == "pen" { naming.surname = "" } }
    }
    private var decisionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("方案 A", text: $decision.a).textFieldStyle(.roundedBorder).focused($editing)
            TextField("方案 B", text: $decision.b).textFieldStyle(.roundedBorder).focused($editing)
            Text("为每个因素设置重要性，再按 0–5 分评价两个方案。0 表示完全不满足，5 表示非常满足。")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(decision.factors.indices, id: \.self) { index in factorEditor(index) }
            HStack {
                Button("添加因素", systemImage: "plus") { decision.factors.append(AiDecisionFactor(label: "", weight: 3, a: 3, b: 3)) }.disabled(decision.factors.count >= 6)
                Spacer(); Text("\(decision.factors.count) / 6 项").font(.caption).foregroundStyle(.secondary)
            }
            Text("不可接受的条件").font(.headline)
            Text("填写后，对应方案会被排除，不因分数较高而推荐。没有则留空。")
                .font(.caption).foregroundStyle(.secondary)
            TextField("方案 A 违反的底线（选填）", text: $decision.constraintA, axis: .vertical).textFieldStyle(.roundedBorder).focused($editing)
            TextField("方案 B 违反的底线（选填）", text: $decision.constraintB, axis: .vertical).textFieldStyle(.roundedBorder).focused($editing)
        }
    }
    private func factorEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("因素名称", text: $decision.factors[index].label).textFieldStyle(.roundedBorder).focused($editing)
                Button(role: .destructive) { decision.factors.remove(at: index) } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                    .disabled(decision.factors.count <= 2).accessibilityLabel("删除因素 \(index + 1)")
            }
            Stepper("重要性：\(decision.factors[index].weight)", value: $decision.factors[index].weight, in: 0...5)
            Stepper("A 满足度：\(decision.factors[index].a)", value: $decision.factors[index].a, in: 0...5)
            Stepper("B 满足度：\(decision.factors[index].b)", value: $decision.factors[index].b, in: 0...5)
        }.font(.subheadline).padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
    }
    private func run() async {
        guard !busy else { return }; busy = true; error = ""
        defer { busy = false }
        let request = input
        do {
            let next: AiExperienceResult = try await APIClient.shared.request(.aiExperienceRun(request))
            try Task.checkCancellation()
            result = next; executedInput = request; favorites = []; saved = nil; savedRequest = nil
        } catch is CancellationError {} catch { self.error = error.localizedDescription + "。资料已保留，可以重试。" }
    }
    private func save() async {
        guard !busy, !stale, result != nil, note.count <= 1000 else { return }
        busy = true; error = ""; defer { busy = false }
        let request = saveIdentity.request(input: input, favorites: Array(favorites), note: note)
        do {
            let next: AiExperienceNote = try await APIClient.shared.request(.aiNoteSave(request))
            try Task.checkCancellation(); saved = next; savedRequest = request
        } catch is CancellationError {} catch { self.error = error.localizedDescription + "。请重试，重复提交不会重复保存。" }
    }
}

struct AiExperienceResultView: View {
    let input: AiExperienceInput
    let result: AiExperienceResult
    @Binding var favorites: Set<String>
    var editable: Bool
    @State private var compare = Set<String>()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.summary).font(.headline).textSelection(.enabled)
            if let naming = input.naming {
                Text("当时选择：\(naming.purpose == "pen" ? "笔名" : "姓名") · \(styleName(naming.style))")
                    .font(.caption).foregroundStyle(.secondary)
                if !naming.surname.isEmpty { Text("姓氏：" + naming.surname).font(.caption) }
                if !naming.avoid.isEmpty { Text("避用字：" + naming.avoid).font(.caption) }
            }
            if let candidates = result.candidates {
                ForEach(candidates) { candidate in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(candidate.name).font(AppTypography.title(26)); Spacer()
                            if editable {
                                Button { if favorites.contains(candidate.id) { favorites.remove(candidate.id) } else { favorites.insert(candidate.id) } } label: {
                                    Image(systemName: favorites.contains(candidate.id) ? "heart.fill" : "heart").frame(width: 44, height: 44)
                                }.accessibilityLabel((favorites.contains(candidate.id) ? "取消收藏" : "收藏") + candidate.name)
                            } else if favorites.contains(candidate.id) { Label("已收藏", systemImage: "heart.fill").font(.caption) }
                        }
                        Text(candidate.idea).font(.subheadline)
                        ForEach(candidate.characters.indices, id: \.self) { i in
                            let character = candidate.characters[i]
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(character.text) · \(character.reading)").font(.subheadline.weight(.medium))
                                Text(character.meaning).font(.caption).foregroundStyle(.secondary)
                                if let url = URL(string: character.source), url.scheme == "https", url.host == "www.zdic.net" { Link("核对字义 · 汉典", destination: url).font(.caption) }
                            }
                        }
                        Button(compare.contains(candidate.id) ? "移出比较" : "加入比较") {
                            if compare.contains(candidate.id) { compare.remove(candidate.id) } else { compare.insert(candidate.id) }
                        }.font(.caption).disabled(!compare.contains(candidate.id) && compare.count >= 2)
                    }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18))
                }
                if compare.count == 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("两个名字，一起看看").font(.headline)
                        ForEach(candidates.filter { compare.contains($0.id) }) { candidate in
                            Text(candidate.name + " · " + candidate.characters.map(\.reading).joined(separator: " ")).font(.subheadline.weight(.semibold))
                            Text(candidate.idea).font(.subheadline)
                        }
                        Text("连同姓氏多念几遍，留意谐音、辨识度和真实使用感受。").font(.caption).foregroundStyle(.secondary)
                    }.padding(16).background(Color.brandDefault.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            if let comparison = result.comparison, let decision = input.decision {
                VStack(alignment: .leading, spacing: 12) {
                    score(decision.a, comparison.scoreA, comparison.eligibleA)
                    score(decision.b, comparison.scoreB, comparison.eligibleB)
                    if !decision.constraintA.isEmpty { Text("A 的底线：" + decision.constraintA).font(.subheadline) }
                    if !decision.constraintB.isEmpty { Text("B 的底线：" + decision.constraintB).font(.subheadline) }
                    Divider()
                    ForEach(comparison.factors.indices, id: \.self) { i in
                        let factor = comparison.factors[i]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(factor.label + " · 重要性 \(factor.weight)").font(.subheadline.weight(.medium))
                            Text("满足度 A \(factor.a) / B \(factor.b) · 加权贡献 A \(factor.contributionA, specifier: "%.1f") / B \(factor.contributionB, specifier: "%.1f")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(16).background(Color.bgSecondary, in: RoundedRectangle(cornerRadius: 18))
            }
            Text(result.basis).font(.footnote).foregroundStyle(.secondary)
            ForEach(result.nextSteps, id: \.self) { Text("· " + $0).font(.subheadline) }
            Text("规则版本 " + result.version).font(.caption2).foregroundStyle(.secondary)
        }.onChange(of: result.version + result.summary + (result.candidates ?? []).map(\.name).joined()) { compare = [] }
    }
    private func score(_ label: String, _ value: Double, _ eligible: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(label); Spacer(); Text(eligible ? String(format: "%.1f / 100", value) : "不满足底线") }
                .font(.subheadline.weight(.semibold))
            ProgressView(value: value, total: 100).tint(eligible ? Color.brandDefault : Color.textTertiary)
        }
    }
    private func styleName(_ value: String) -> String { ["gentle": "温柔安定", "nature": "自然开阔", "clear": "清朗有志"][value] ?? value }
}
