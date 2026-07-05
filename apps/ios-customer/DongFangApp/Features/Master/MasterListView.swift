//
//  MasterListView.swift
//  DongFangApp
//
//  法师列表页：对齐 master-list.html 原型。
//  顶部导航 + 分类标签 + 两栏布局（左侧可折叠筛选组 + 右侧法师卡片）。
//

import SwiftUI

struct MasterListView: View {
    @StateObject private var viewModel = MasterListViewModel()
    @State private var expandedGroups: Set<String> = ["所属寺院"]

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部导航栏
            DFTopNavBar("找师傅") {
                EmptyView()
            } trailing: {
                Button {
                    // 搜索
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accentDefault)
                }
                .buttonStyle(.plain)
            }

            // 2. 分类标签横滑
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.categoryOptions, id: \.self) { tag in
                        tagPill(title: tag, isSelected: viewModel.selectedCategory == tag) {
                            viewModel.selectedCategory = tag
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
            }
            .background(Color.bgPrimary)

            // 3. 两栏布局
            HStack(spacing: 0) {
                // 左侧筛选面板（80pt，可折叠组）
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.filterGroups, id: \.title) { group in
                            filterGroup(title: group.title, options: group.options)
                        }
                    }
                }
                .frame(width: 80)
                .background(Color.bgSecondary)
                .overlay(Rectangle().fill(Color.borderDivider).frame(width: 1), alignment: .trailing)

                // 右侧法师卡片列表
                if viewModel.isLoading {
                    DFLoadingView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.filteredMasters.isEmpty {
                    DFEmptyState(icon: "person.2", title: "暂无法师", subtitle: "下拉刷新试试")
                        .frame(maxWidth: .infinity)
                } else {
                    masterListContent
                }
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.masters.isEmpty { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: Master.self) { master in
            MasterProfileView(masterId: master.id)
        }
    }

    // MARK: - 法师列表内容
    // 特性 4：iOS 26+ 使用 List + sectionIndexTitles 索引条，低版本回退 ScrollView
    @ViewBuilder
    private var masterListContent: some View {
        let grouped = Dictionary(grouping: viewModel.filteredMasters, by: { $0.sect })
        let sortedSects = grouped.keys.sorted()
        if #available(iOS 26.0, *) {
            List {
                ForEach(sortedSects, id: \.self) { sect in
                    Section {
                        ForEach(grouped[sect] ?? []) { master in
                            NavigationLink(value: master) {
                                masterCard(master)
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        }
                    } header: {
                        Text(sect)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .softScrollEdge(.bottom)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.filteredMasters) { master in
                        NavigationLink(value: master) {
                            masterCard(master)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    // MARK: - 教派标签胶囊
    private func tagPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.white : Color.textTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(isSelected ? Color.brandDefault : Color.bgTertiary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 可折叠筛选组
    @ViewBuilder
    private func filterGroup(title: String, options: [String]) -> some View {
        let isExpanded = expandedGroups.contains(title)
        VStack(spacing: 0) {
            // 组标题
            Button {
                if isExpanded {
                    expandedGroups.remove(title)
                } else {
                    expandedGroups.insert(title)
                }
            } label: {
                HStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isExpanded ? Color.accentDefault : Color.textTertiary)
                        .lineLimit(1)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(isExpanded ? Color.accentDefault : Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // 组选项
            if isExpanded {
                ForEach(options, id: \.self) { option in
                    filterOption(title: option, group: title, isSelected: selectedValue(for: title) == option) {
                        setSelectedValue(option, for: title)
                    }
                }
            }
        }
    }

    // MARK: - 筛选选项
    private func filterOption(title: String, group: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isSelected ? Color.brandDefault : Color.clear)
                    .frame(width: 2)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .background(isSelected ? Color.brandDefault.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 法师卡片（水平布局：头像+信息）
    private func masterCard(_ master: Master) -> some View {
        HStack(spacing: AppSpacing.md) {
            // 头像 + 在线状态
            ZStack(alignment: .bottomTrailing) {
                RemoteImage(urlString: master.avatar, placeholderIcon: "person.circle.fill")
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))

                Circle()
                    .fill(master.isOnline == true ? Color.stateSuccess : Color.textTertiary)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.bgSecondary, lineWidth: 2))
                    .offset(x: -2, y: -2)
            }

            // 信息区
            VStack(alignment: .leading, spacing: 0) {
                Text(master.dharmaName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text("\(master.templeName) · \(master.position)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, 2)

                // 专长标签
                HStack(spacing: 6) {
                    ForEach(master.specialties.prefix(2), id: \.self) { specialty in
                        Text(specialty)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.brandDefault)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.brandDefault.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 4)

                // 评分 + 在线状态 + 价格
                HStack {
                    HStack(spacing: 3) {
                        Text(String(format: "%.1f", master.rating))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentDefault)
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentDefault)
                    }
                    Text(master.isOnline == true ? "在线" : "离线")
                        .font(.system(size: 11))
                        .foregroundStyle(master.isOnline == true ? Color.stateSuccess : Color.textTertiary)
                    Spacer()
                    if let price = master.startPrice {
                        Text("¥\(Int(price))起")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.brandDefault)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 筛选值管理（绑定到 ViewModel）
    private func selectedValue(for group: String) -> String {
        switch group {
        case "所属寺院": return viewModel.selectedTemple
        case "修为等级": return viewModel.selectedLevel
        case "擅长领域": return viewModel.selectedSpecialty
        case "价格区间": return viewModel.selectedPriceRange
        default: return "全部"
        }
    }

    private func setSelectedValue(_ value: String, for group: String) {
        switch group {
        case "所属寺院":   viewModel.selectedTemple = value
        case "修为等级":   viewModel.selectedLevel = value
        case "擅长领域":   viewModel.selectedSpecialty = value
        case "价格区间":   viewModel.selectedPriceRange = value
        default: break
        }
    }
}

#Preview {
    NavigationStack { MasterListView() }
        .preferredColorScheme(.dark)
}
