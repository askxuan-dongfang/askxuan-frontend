//
//  AiDivinationView.swift
//  DongFangApp
//
//  AI 问事页面（Tab 2）。对齐产品原型 ai-divination.html。
//  包含：AI头像 Hero / 八字命理精选 / 6术数宫格 / 对话预览 / 最近问事。
//

import SwiftUI

// MARK: - 特性 5：@Animatable 宏 —— 数字平滑插值动画
// 普通视图的 Int 属性无法被 SwiftUI 插值（会跳变）。
// @Animatable 宏（WWDC25 / iOS 26+）自动生成 animatableData，
// 让 Float（VectorArithmetic）属性参与平滑动画 —— 数字从 0 滚动到目标值。
@available(iOS 26.0, *)
@Animatable
struct AnimatedFortuneNumber: View {
    var value: Float

    var body: some View {
        Text(value.formatted(.number.precision(.fractionLength(0))))
    }
}

// MARK: - 术数技能模型

struct DivinationSkill: Identifiable {
    let id: String
    let name: String
    let desc: String
    let icon: String          // SF Symbol
    let iconColor: Color
    let iconBg: Color
}

// MARK: - View

struct AiDivinationView: View {
    @State private var navigateToChat: Bool = false
    // 特性 5：运势指数动画起始值（onAppear 后动画到 88）
    @State private var fortuneValue: Float = 0

    private let skills: [DivinationSkill] = [
        DivinationSkill(id: "yinyuan", name: "姻缘测算", desc: "八字合婚、生肖配对、求签",
                        icon: "heart.circle", iconColor: .brandDefault,
                        iconBg: Color.brandDefault.opacity(0.18)),
        DivinationSkill(id: "tarot", name: "塔罗牌", desc: "随机抽牌、多种牌阵解读",
                        icon: "rectangle.stack", iconColor: .accentDefault,
                        iconBg: Color.accentDefault.opacity(0.18)),
        DivinationSkill(id: "fengshui", name: "风水分析", desc: "住宅方位、阳宅布局分析",
                        icon: "safari", iconColor: .stateSuccess,
                        iconBg: Color.stateSuccess.opacity(0.18)),
        DivinationSkill(id: "qimen", name: "奇门遁甲", desc: "排盘分析、用神格局解读",
                        icon: "square.grid.3x3", iconColor: Color(red: 138/255, green: 106/255, blue: 180/255),
                        iconBg: Color(red: 138/255, green: 106/255, blue: 180/255).opacity(0.18)),
        DivinationSkill(id: "ziwei", name: "紫微斗数", desc: "安星四化、十二宫位分析",
                        icon: "star.circle", iconColor: .brandDefault,
                        iconBg: Color.brandDefault.opacity(0.18)),
        DivinationSkill(id: "liuyao", name: "六爻·梅花", desc: "硬币起卦、体用生克解读",
                        icon: "rectangle.split.3x1", iconColor: .accentDefault,
                        iconBg: Color.accentDefault.opacity(0.18)),
    ]

    private let histories: [(String, String, String, String)] = [
        ("八字命理分析", "日主丙火 · 五行偏旺", "clock", "2小时前"),
        ("姻缘配对", "六合大吉 · 东南方位", "heart", "昨天"),
        ("塔罗牌 · 三牌阵", "星星正位 · 事业方向", "star", "3天前"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                featuredSkillCard
                skillGridSection
                chatPreviewSection
                historySection
            }
            .padding(.bottom, AppSpacing.navBottom + 16)
        }
        .background(Color.bgPrimary)
        .navigationBarHidden(true)
        .onAppear {
            // 特性 5：触发运势指数数字滚动动画（0 → 88）
            withAnimation(.easeOut(duration: 1.2)) {
                fortuneValue = 88
            }
        }
        .navigationDestination(isPresented: $navigateToChat) {
            ChatDetailView(
                conversation: ChatConversation(
                    id: "ai", masterId: "ai", masterName: "玄学AI助手",
                    masterAvatar: "", templeName: "AI智能",
                    lastMessage: "您好，我是玄学AI助手，可为您解读八字、塔罗、风水等",
                    lastTime: "", unreadCount: 0, isOnline: true
                ),
                viewModel: ChatViewModel()
            )
        }
    }

    // MARK: - 1. Hero Section

    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("AI问事")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundStyle(Color.accentDefault)

            Text("融合古籍经典 · 智能玄学解读")
                .font(.system(size: 10))
                .foregroundStyle(Color.textTertiary)

            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.brandDefault, Color(hex: "D97B4A"), .accentDefault, .brandDefault],
                            center: .center
                        )
                    )
                    .frame(width: 86, height: 86)
                    .shadow(color: .brandDefault.opacity(0.4), radius: 12)

                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 80, height: 80)

                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentDefault, .brandDefault],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.top, 16)

            Text("玄学AI助手")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(Color.textPrimary)
                .padding(.top, 8)

            Text("7大术数方向 · 古籍知识库驱动")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)

            // Online indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.stateSuccess)
                    .frame(width: 6, height: 6)
                Text("在线中")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.stateSuccess)
            }
            .padding(.top, 4)

            // 特性 5：今日运势指数 —— @Animatable 数字从 0 平滑滚动到 88
            if #available(iOS 26.0, *) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("今日运势指数")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    AnimatedFortuneNumber(value: fortuneValue)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentDefault, .brandDefault],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .animation(.easeOut(duration: 1.2), value: fortuneValue)
                    Text("分")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RadialGradient(
                colors: [Color.brandDefault.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 160
            )
        )
    }

    // MARK: - 2. Featured Skill (八字命理)

    private var featuredSkillCard: some View {
        Button {
            navigateToChat = true
        } label: {
            HStack(spacing: 14) {
                // Icon
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.brandDefault.opacity(0.2), Color.accentDefault.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.accentDefault)
                    )

                // Body
                VStack(alignment: .leading, spacing: 3) {
                    Text("八字命理 · 综合测算")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)

                    Text("自动排出四柱八字，基于经典古籍分析日主五行、流年大运，多轮追问逻辑连贯")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        skillTag("四柱排盘")
                        skillTag("五行分析")
                        skillTag("流年运势")
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(16)
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func skillTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(Color.brandDefault)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.brandDefault.opacity(0.1))
            .cornerRadius(10)
    }

    // MARK: - 3. Skill Grid (6 skills)

    private var skillGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("术数方向")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("古籍知识库驱动")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(skills) { skill in
                    Button {
                        navigateToChat = true
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(skill.iconBg)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: skill.icon)
                                        .font(.system(size: 24))
                                        .foregroundStyle(skill.iconColor)
                                )

                            Text(skill.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)

                            Text(skill.desc)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textTertiary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.bgSecondary)
                        .cornerRadius(AppRadius.xl)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.xl)
                                .stroke(Color.borderDefault, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }

    // MARK: - 4. Chat Preview

    private var chatPreviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("示例对话")
                .font(.system(size: 13))
                .foregroundStyle(Color.textTertiary)

            // User bubble
            HStack {
                Spacer()
                Text("帮我测一下姻缘，我属蛇，对方属兔")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.brandDefault)
                    .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                    .frame(maxWidth: 270, alignment: .trailing)
            }

            // AI bubble
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentDefault)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("玄学AI")
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(Color.accentDefault)

                    Text("巳蛇与卯兔六合，属相配对为大吉。从八字合婚来看，火木相生，感情基础稳固。建议在东南方位摆放红色饰品，有助于增进感情和谐。")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                        .lineSpacing(4)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.bgPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
            .cornerRadius(16, corners: [.topLeft, .topRight, .bottomRight])

            // CTA Button
            DFPrimaryButton(title: "开始AI问事", icon: "sparkles") {
                navigateToChat = true
            }
        }
        .padding(16)
        .background(Color.bgSecondary)
        .cornerRadius(AppRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(Color.borderDefault, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - 5. History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近问事")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("查看全部")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentDefault)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(histories.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.brandDefault.opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: item.2)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.brandDefault)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                            Text(item.1)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        Text(item.3)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .overlay(
                        // Bottom divider except last
                        item.0 == histories.last?.0 ? AnyView(EmptyView()) : AnyView(
                            Rectangle()
                                .fill(Color.borderDivider)
                                .frame(height: 1)
                                .padding(.leading, 64)
                        )
                    )
                }
            }
            .background(Color.bgSecondary)
            .cornerRadius(AppRadius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .stroke(Color.borderDefault, lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .padding(.top, 20)
    }
}

// MARK: - RoundedCorner Helper

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

#Preview {
    AiDivinationView()
        .preferredColorScheme(.dark)
}
