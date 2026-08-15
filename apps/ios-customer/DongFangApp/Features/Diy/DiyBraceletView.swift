//
//  DiyBraceletView.swift
//  DongFangApp
//
//  DIY 手串入口页：顶部 Banner + 开始设计/我的设计入口 + 推荐模板。
//

import SwiftUI

struct DiyBraceletView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.lg) {
                backBar
                heroBanner
                quickEntrySection
                templateSection
                Spacer(minLength: AppSpacing.xl)
            }
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: DiyDesign.self) { design in
            DiyDetailView(designId: design.id)
        }
    }

    // MARK: - 返回栏（导航栏隐藏后提供返回首页入口）
    private var backBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 36, height: 36)
                    .background(Color.bgPrimary.opacity(0.6))
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.borderDefault, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
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
                DiyMyDesignsView()
            } label: {
                entryCard(icon: "doc.on.doc", title: "我的设计",
                          subtitle: "草稿与已下单手串", highlight: false)
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
