//
//  MasterTopNavBar.swift
//  MasterApp
//
//  MasterTopNavBar 通用顶部导航栏：毛玻璃 + 返回 + 居中标题。
//  对齐 C 端 DFTopNavBar 设计，使用法师端 design tokens。
//  标题字体：Noto Serif SC bold（对齐原型 font-family: 'Noto Serif SC'; font-weight: 700）。
//  背景延伸至状态栏（ignoresSafeArea(.top)），内容 HStack 固定 44pt 高度。
//

import SwiftUI

struct MasterTopNavBar<Leading: View, Trailing: View>: View {
    let title: String
    let showsBackButton: Bool
    let leading: Leading
    let trailing: Trailing

    init(_ title: String,
         showsBackButton: Bool = true,
         @ViewBuilder leading: () -> Leading,
         @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showsBackButton = showsBackButton
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            if showsBackButton {
                BackButton()
            } else {
                leading
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text(title)
                .font(.custom(AppFont.serif, size: 17).weight(.bold))
                .foregroundStyle(Color.accentDefault)
                .lineLimit(1)

            Spacer()

            trailing
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, AppSpacing.lg)
        .frame(height: AppSpacing.navTop)
        .liquidGlassBackground(0.85)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.borderDivider)
                .frame(height: 1)
        }
    }
}

private struct BackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentDefault)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension MasterTopNavBar where Leading == EmptyView, Trailing == EmptyView {
    init(_ title: String, showsBackButton: Bool = true) {
        self.init(title, showsBackButton: showsBackButton,
                  leading: { EmptyView() },
                  trailing: { EmptyView() })
    }
}
