//
//  ServiceTagsView.swift
//  MasterApp
//
//  我的服务标签：从平台 13 类固定目录（S001-S013）中选择我提供的服务并定价。
//  两类大师通用；野生大师标签即其上架服务。
//

import SwiftUI

struct ServiceTagsView: View {
    // 固定目录（与统一数据字典一致）
    private static let catalog: [(code: String, name: String)] = [
        ("S001", "祈福"), ("S002", "供灯"), ("S003", "上香"), ("S004", "还愿"),
        ("S005", "超度"), ("S006", "开光"), ("S007", "化太岁"), ("S008", "求姻缘"),
        ("S009", "求财运"), ("S010", "求事业"), ("S011", "求风水"), ("S012", "求健康"),
        ("S013", "求学业")
    ]

    @State private var myTags: [String: Double] = [:]   // serviceCode -> price
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveMessage = ""
    @State private var showSaveMessage = false

    var body: some View {
        Group {
            if isLoading && myTags.isEmpty {
                ProgressView("正在加载服务标签")
                    .tint(Color.accentDefault)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        Text("勾选你提供的服务并定价；取消勾选即下架该标签。")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.top, AppSpacing.md)

                        ForEach(Self.catalog, id: \.code) { item in
                            tagRow(item)
                        }
                    }
                    .padding(.bottom, AppSpacing.navBottom + 32)
                }
                .refreshable { await load() }
            }
        }
        .background(Color.bgPrimary)
        .navigationTitle("服务标签")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView().tint(Color.accentDefault)
                    } else {
                        Text("保存").font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.accentDefault)
                    }
                }
                .disabled(isSaving)
            }
        }
        .alert("保存结果", isPresented: $showSaveMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(saveMessage)
        }
        .task { await load() }
    }

    private func tagRow(_ item: (code: String, name: String)) -> some View {
        let enabled = myTags[item.code] != nil
        return HStack(spacing: AppSpacing.md) {
            Button {
                if enabled {
                    myTags.removeValue(forKey: item.code)
                } else {
                    myTags[item.code] = 0
                }
            } label: {
                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(enabled ? Color.brandDefault : Color.textTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                Text(item.code).font(.caption2).foregroundStyle(Color.textTertiary)
            }

            Spacer()

            if enabled {
                HStack(spacing: 4) {
                    Text("¥")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                    TextField("价格", text: Binding(
                        get: { myTags[item.code].map { String(format: "%.0f", $0) } ?? "" },
                        set: { myTags[item.code] = Double($0) ?? 0 }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 88)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.brandDefault)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.bgTertiary)
                .cornerRadius(AppRadius.md)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(Color.bgSecondary)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.borderDivider).frame(height: 1).padding(.leading, 60)
        }
    }

    private func load() async {
        if myTags.isEmpty { isLoading = true }
        errorMessage = nil
        do {
            let resp: MasterServiceTagsResponse = try await APIClient.shared.request(.masterServiceTags)
            var map: [String: Double] = [:]
            for t in resp.list {
                map[t.serviceCode] = t.price
            }
            myTags = map
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save() {
        isSaving = true
        let tags = myTags.map { MasterServiceTagPayload(serviceCode: $0.key, price: $0.value) }
        Task {
            defer { isSaving = false }
            do {
                let _: MasterServiceTagsResponse = try await APIClient.shared.request(
                    .masterServiceTagsUpdate(MasterServiceTagsUpdateRequest(tags: tags)))
                saveMessage = "服务标签已保存"
            } catch {
                saveMessage = error.localizedDescription
            }
            showSaveMessage = true
        }
    }
}
