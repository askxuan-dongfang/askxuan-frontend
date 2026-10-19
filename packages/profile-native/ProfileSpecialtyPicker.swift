import SwiftUI

struct ProfileSpecialtyPicker: View {
    @Binding var selection: [String]
    @State private var custom = ""
    @State private var error: String?
    private let suggestions = ["祈福", "供灯", "上香", "还愿", "超度", "开光", "化太岁", "求姻缘", "求财运", "求事业", "求风水", "求健康", "求学业"]
    private var options: [String] { suggestions + selection.filter { !suggestions.contains($0) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.text("擅长领域")).font(.headline).foregroundStyle(Color.textPrimary)
            Text(L10n.text("点选适合自己的领域，也可以添加其他专长。服务项目和价格请在服务设置中管理。"))
                .font(.caption).foregroundStyle(Color.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(options, id: \.self) { item in
                    Button { if selection.contains(item) { selection.removeAll { $0 == item } } else { selection.append(item) } } label: {
                        HStack(spacing: 4) { Image(systemName: selection.contains(item) ? "checkmark" : "plus"); Text(L10n.lookup(item)) }.font(.callout).frame(maxWidth: .infinity, minHeight: 44)
                            .background(selection.contains(item) ? Color.accentDefault.opacity(0.12) : Color.bgTertiary, in: RoundedRectangle(cornerRadius: 10))
                    }.foregroundStyle(selection.contains(item) ? Color.accentDefault : Color.textSecondary)
                    .accessibilityAddTraits(selection.contains(item) ? .isSelected : [])
                }
            }
            HStack {
                TextField(L10n.text("其他专长"), text: $custom).textFieldStyle(.roundedBorder).onSubmit(add)
                Button(L10n.text("添加"), action: add).frame(minWidth: 44, minHeight: 44).disabled(custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error { Text(L10n.lookup(error)).font(.caption).foregroundStyle(Color.stateError) }
        }.tint(Color.accentDefault)
    }
    private func add() {
        let value = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard value.count <= 24, value.rangeOfCharacter(from: CharacterSet(charactersIn: "、,，")) == nil else { error = "请每次添加一项，最多 24 个字"; return }
        if !selection.contains(value) { selection.append(value) }
        custom = ""; error = nil
    }
}
