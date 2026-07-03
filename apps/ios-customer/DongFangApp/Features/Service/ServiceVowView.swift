//
//  ServiceVowView.swift
//  DongFangApp
//
//  许愿（还愿）服务页：复用 ServiceContainerView，传入 .vow。
//

import SwiftUI

/// 许愿（还愿）服务页
struct ServiceVowView: View {
    var body: some View {
        ServiceContainerView(serviceType: .vow)
    }
}

#Preview {
    NavigationStack { ServiceVowView() }
        .preferredColorScheme(.dark)
}
