//
//  MasterListView.swift
//  DongFangApp
//
//  师傅列表页：顶部导航 + 教派分类标签 + 师傅卡片列表。
//

import SwiftUI

struct MasterListView: View {
    @StateObject private var viewModel = MasterListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航
            DFTopNavBar("找师傅")

            // 教派分类标签横滑
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.categoryOptions, id: \.self) { category in
                        DFTagPill(title: category, isSelected: viewModel.selectedCategory == category) {
                            viewModel.selectedCategory = category
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
            if viewModel.masters.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationDestination(for: Master.self) { master in
            MasterProfileView(masterId: master.id)
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
        } else if viewModel.filteredMasters.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.system(size: 40))
                    .foregroundStyle(.textTertiary)
                Text("暂无师傅")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            Spacer()
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.filteredMasters) { master in
                        NavigationLink(value: master) {
                            masterRow(master)
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

    /// 师傅卡片
    private func masterRow(_ master: Master) -> some View {
        HStack(spacing: AppSpacing.md) {
            // 头像 72px + 金色边框 + 在线状态
            ZStack {
                Image(master.avatarAssetName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))

                if master.isOnlineDisplay {
                    Circle()
                        .fill(Color.stateSuccess)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.bgSecondary, lineWidth: 2))
                        .offset(x: 24, y: 24)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(master.dharmaName)
                        .font(.cardTitle)
                        .foregroundStyle(Color.textPrimary)
                    Text(master.position)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.brandDefault)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.brandDefault.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(master.templeName)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)

                // 擅长标签
                HStack(spacing: 4) {
                    ForEach(master.specialties.prefix(3), id: \.self) { specialty in
                        Text(specialty)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentDefault)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentDefault.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.accentDefault)
                        Text(master.ratingText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentDefault)
                    }
                    if let price = master.startPriceText {
                        Text(price)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.brandDefault)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.textTertiary)
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
        MasterListView()
    }
    .preferredColorScheme(.dark)
}
