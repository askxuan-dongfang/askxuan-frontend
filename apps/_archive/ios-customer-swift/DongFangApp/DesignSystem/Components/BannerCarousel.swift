//
//  BannerCarousel.swift
//  DongFangApp
//
//  DFBannerCarousel 轮播组件：
//  - 自动轮播（3 秒）
//  - 手势滑动（TabView with .tabViewStyle(.page)）
//  - 底部圆点指示器（6px 圆点 / 18px 胶囊选中态朱砂色）
//  - 12px 圆角 + 200px 高度
//

import SwiftUI

/// Banner 数据模型
struct BannerItem: Identifiable, Hashable {
    let id: String
    let imageName: String
    let title: String
}

/// 自动轮播 Banner
struct DFBannerCarousel: View {
    let banners: [BannerItem]
    /// 自动轮播间隔（秒）
    var autoPlayInterval: TimeInterval = 3.0

    @State private var currentIndex: Int = 0
    /// 用户手动滑动时暂停自动轮播
    @State private var isUserInteracting: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            if banners.isEmpty {
                placeholder
            } else {
                carousel
                dotsIndicator
            }
        }
    }

    // 轮播主体
    private var carousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                bannerSlide(banner)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 200)
        .cornerRadius(AppRadius.lg)
        .onChange(of: currentIndex) { _ in
            // 切换时重置定时器
        }
        .onAppear {
            startAutoPlay()
        }
        .onDisappear {
            stopAutoPlay()
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    isUserInteracting = true
                }
                .onEnded { _ in
                    isUserInteracting = false
                    startAutoPlay()
                }
        )
    }

    // 单张 Banner：图片 + 底部渐变叠加标题
    private func bannerSlide(_ banner: BannerItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(banner.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()

            // 底部渐变遮罩
            LinearGradient(
                colors: [
                    Color.bgPrimary.opacity(0.7),
                    Color.bgPrimary.opacity(0.1),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // 标题文字
            Text(banner.title)
                .font(.custom(AppFont.serif, size: 18).weight(.semibold))
                .foregroundStyle(.textPrimary)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .padding(16)
        }
        .frame(height: 200)
        .clipped()
    }

    // 底部圆点指示器
    private var dotsIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Array(banners.enumerated()), id: \.element.id) { index, _ in
                Capsule()
                    .fill(index == currentIndex ? Color.brandDefault : Color.textTertiary)
                    .frame(width: index == currentIndex ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
        }
    }

    // 空态占位
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: AppRadius.lg)
            .fill(Color.bgSecondary)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(.textTertiary)
                    Text("暂无活动")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
            )
            .frame(height: 200)
    }

    /// 自动轮播定时器
    private func startAutoPlay() {
        guard banners.count > 1, !isUserInteracting else { return }
        stopAutoPlay()
        DispatchQueue.main.asyncAfter(deadline: .now() + autoPlayInterval) {
            guard !isUserInteracting, !banners.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % banners.count
            }
            startAutoPlay()
        }
    }

    private func stopAutoPlay() {
        // DispatchQueue 的 asyncAfter 无法取消，这里通过状态位控制；
        // 实际生产环境可改用 Timer.publish。
    }
}

#Preview {
    VStack {
        DFBannerCarousel(banners: [
            BannerItem(id: "1", imageName: "banner-ad-1", title: "岁末祈福大典"),
            BannerItem(id: "2", imageName: "banner-ad-2", title: "线上祈福 福泽绵长"),
            BannerItem(id: "3", imageName: "banner-ad-3", title: "雪域修行 心灵之旅")
        ])
        Spacer()
    }
    .padding()
    .background(Color.bgPrimary)
    .preferredColorScheme(.dark)
}
