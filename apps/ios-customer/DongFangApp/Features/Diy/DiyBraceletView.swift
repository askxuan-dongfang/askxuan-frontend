//
//  DiyBraceletView.swift
//  DongFangApp
//
//  DIY 手串入口页：顶部 Banner + 我的创作 + 推荐模板 + 进入编辑器。
//

import SwiftUI

struct DiyBraceletView: View {
    @StateObject private var viewModel = DiyViewModel()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                heroBanner
                quickEntrySection
                myDesignsSection
                templateSection
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.designs.isEmpty { await viewModel.loadDesigns() }
        }
        .refreshable { await viewModel.loadDesigns() }
        .navigationDestination(for: DiyDesign.self) { design in
            DiyDetailView(designId: design.id)
        }
    }

    // MARK: - Hero
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.brandDark, Color.brandDefault.opacity(0.5), Color.accentDark.opacity(0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("DIY 手串定制")
                    .font(.custom(AppFont.serif[0], size: 22).weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                Text("自选材料 · 法师开光加持 · 专属法物")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(AppSpacing.lg)
        }
        .frame(height: 140)
        .cornerRadius(AppRadius.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - 快捷入口
    private var quickEntrySection: some View {
        HStack(spacing: AppSpacing.md) {
            NavigationLink {
                DiyDesignView()
            } label: {
                entryCard(icon: "wand.and.stars", title: "开始设计",
                          subtitle: "自由搭配材料", highlight: true)
            }
            .buttonStyle(.plain)

            NavigationLink {
                DiyDesignView()
            } label: {
                entryCard(icon: "doc.on.doc", title: "我的设计",
                          subtitle: "查看历史创作", highlight: false)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func entryCard(icon: String, title: String, subtitle: String,
                           highlight: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(highlight ? Color.accentDefault.opacity(0.2) : Color.brandDefault.opacity(0.12))
                    .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(highlight ? Color.accentDefault : Color.brandDefault)
            }
            .frame(width: 48, height: 48)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 我的创作
    private var myDesignsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("我的创作")
                    .font(.sectionTitle)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                NavigationLink {
                    DiyDesignView()
                } label: {
                    HStack(spacing: 2) {
                        Text("更多").font(.caption)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentDefault)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.lg)

            if viewModel.designs.isEmpty {
                Text("还没有创作，快去设计一个吧")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.designs) { design in
                            NavigationLink(value: design) { designCard(design) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
        }
    }

    private func designCard(_ design: DiyDesign) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [Color.brandDefault.opacity(0.2), Color.accentDefault.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "circle.grid.2x2.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentDefault)
            }
            .frame(width: 140, height: 100)
            .cornerRadius(AppRadius.md)

            Text(design.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            HStack {
                Text("¥\(Int(design.totalPrice))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
                Spacer()
                Text(design.createTime ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(width: 140)
        .padding(AppSpacing.sm)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.lg)
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
    }

    // MARK: - 推荐模板
    private var templateSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("推荐模板")
                .font(.sectionTitle)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            VStack(spacing: AppSpacing.md) {
                templateRow(name: "平安祈福手串",
                            desc: "星月菩提 + 南红玛瑙 · 祈福消灾",
                            price: 388, icon: "hands.and.sparkles")
                templateRow(name: "本命年化太岁手串",
                            desc: "金刚菩提 + 蜜蜡佛头 · 化解太岁",
                            price: 666, icon: "shield.lefthalf.filled")
                templateRow(name: "事业招财手串",
                            desc: "绿松石 + 黄铜三通 · 招财纳福",
                            price: 488, icon: "yensign.circle.fill")
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func templateRow(name: String, desc: String, price: Double,
                             icon: String) -> some View {
        NavigationLink {
            DiyDesignView()
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(Color.brandDefault.opacity(0.12))
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandDefault)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text("¥\(Int(price))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.brandDefault)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.lg)
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(Color.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { DiyBraceletView() }
        .preferredColorScheme(.dark)
}
