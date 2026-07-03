//
//  TempleListView.swift
//  DongFangApp
//
//  寺院列表页：顶部导航 + 教派标签横滑 + 寺院卡片列表。
//

import SwiftUI

struct TempleListView: View {
    @StateObject private var viewModel = TempleListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航
            DFTopNavBar("找寺院")

            // 教派标签横滑
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.sectOptions, id: \.self) { sect in
                        DFTagPill(title: sect, isSelected: viewModel.selectedSect == sect) {
                            viewModel.selectedSect = sect
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .background(Color.bgPrimary)

            // 内容区
            content
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.temples.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationDestination(for: Temple.self) { temple in
            TempleDetailView(templeId: temple.id, templeName: temple.name)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .tint(.accentDefault)
                .scaleEffect(1.2)
            Spacer()
        } else if viewModel.filteredTemples.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "building.2")
                    .font(.system(size: 40))
                    .foregroundStyle(.textTertiary)
                Text("暂无寺院")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.filteredTemples) { temple in
                        NavigationLink(value: temple) {
                            templeRow(temple)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    /// 寺院卡片行
    private func templeRow(_ temple: Temple) -> some View {
        HStack(spacing: AppSpacing.md) {
            // 缩略图
            Image(temple.assetImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(AppRadius.md)

            VStack(alignment: .leading, spacing: 6) {
                Text(temple.name)
                    .font(.cardTitle)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    Text(temple.region)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }

                HStack(spacing: 6) {
                    Text(temple.type)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentDefault)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentDefault.opacity(0.12))
                        .clipShape(Capsule())
                    Text(temple.sect)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Text("★ \(temple.ratingText)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        TempleListView()
    }
    .preferredColorScheme(.dark)
}
