//
//  TempleListView.swift
//  DongFangApp
//
//  寺院列表页：顶部导航 + 教派标签横滑 + 左侧服务筛选 + 寺院卡片。
//

import SwiftUI

struct TempleListView: View {
    @StateObject private var viewModel: TempleListViewModel

    init(initialSect: String? = nil) {
        _viewModel = StateObject(wrappedValue: TempleListViewModel(initialSect: initialSect))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部导航栏
            DFTopNavBar("找寺院") {
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

            // 2. 教派标签横滑
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.sectOptions, id: \.self) { tag in
                        tagPill(title: tag, isSelected: viewModel.selectedSect == tag) {
                            viewModel.selectedSect = tag
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
            }
            .background(Color.bgPrimary)

            HStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(viewModel.serviceFilters, id: \.self) { filter in
                            filterOption(title: filter, isSelected: viewModel.selectedService == filter) {
                                viewModel.selectedService = filter
                            }
                        }
                    }
                }
                .frame(width: 80)
                .background(Color.bgSecondary)
                .overlay(Rectangle().fill(Color.borderDivider).frame(width: 1), alignment: .trailing)

                if viewModel.isLoading {
                    DFLoadingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredTemples.isEmpty {
                    DFEmptyState(icon: "building.2", title: "暂无寺院", subtitle: "下拉刷新试试")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    templeListContent
                }
            }
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.temples.isEmpty { await viewModel.load() }
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(for: Temple.self) { temple in
            TempleDetailView(templeId: temple.id, templeName: temple.name)
        }
    }

    // MARK: - 寺院列表内容
    private var templeListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(viewModel.filteredTemples) { temple in
                    NavigationLink(value: temple) {
                        templeCard(temple)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CardPressButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.navBottom + 32)
        }
        .softScrollEdge(.bottom)
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

    // MARK: - 左侧筛选选项
    private func filterOption(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(isSelected ? Color.brandDefault : Color.clear)
                    .frame(width: 2)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.brandDefault : Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .background(isSelected ? Color.brandDefault.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 寺院卡片（垂直布局：图片+body）
    private func templeCard(_ temple: Temple) -> some View {
        VStack(spacing: 0) {
            RemoteImage(urlString: temple.coverImage, placeholderIcon: "building.2")
                .frame(height: 136)
                .frame(maxWidth: .infinity)
                .clipped()

            // 卡片 body
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text(temple.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.textPrimary)
                    HStack(spacing: 4) {
                        Text(temple.type)
                        Text(temple.sect)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(categoryBadgeColor(for: temple.type))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(categoryBadgeColor(for: temple.type).opacity(0.12))
                    .clipShape(Capsule())
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentDefault)
                        Text(String(format: "%.1f", temple.rating))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentDefault)
                    }
                }

                // 位置 + 价格
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    Text(temple.region)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                    Text(startPriceText(for: temple))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(priceColor(for: temple))
                }
                .padding(.top, 4)

                // 服务标签 + 服务数量
                HStack {
                    HStack(spacing: 6) {
                        ForEach((temple.serviceTags ?? []).prefix(4), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentDefault.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }
                    Spacer()
                    if let count = temple.serviceCount {
                        Text("\(count)项服务")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.brandDefault)
                    }
                }
                .padding(.top, 8)
                .padding(.top, 8)
                .overlay(Rectangle().fill(Color.borderDivider).frame(height: 1), alignment: .top)
            }
            .padding(10)
        }
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.md)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(Color.borderDefault, lineWidth: 1))
        .contentShape(Rectangle())
    }

    // MARK: - 辅助
    private func categoryBadgeColor(for type: String) -> Color {
        switch type {
        case "道教": return Color(red: 158/255, green: 143/255, blue: 178/255)
        case "藏传佛教": return Color(red: 100/255, green: 60/255, blue: 150/255)
        default: return Color.brandDefault
        }
    }

    private func startPriceText(for temple: Temple) -> String {
        // 灵隐寺免费，其他显示起价
        if temple.name == "灵隐寺" { return "免费" }
        return "¥\(Int(temple.rating * 10))起"
    }

    private func priceColor(for temple: Temple) -> Color {
        if temple.name == "灵隐寺" { return Color.stateSuccess }
        return Color.brandDefault
    }
}

#Preview {
    NavigationStack { TempleListView() }
        .preferredColorScheme(.dark)
}
