//
//  TagPill.swift
//  DongFangApp
//
//  DFTagPill 胶囊标签：选中朱砂红 / 默认深灰背景。
//

import SwiftUI

struct DFTagPill: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.textTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isSelected ? Color.brandDefault : Color.bgTertiary)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                action?()
            }
    }
}
