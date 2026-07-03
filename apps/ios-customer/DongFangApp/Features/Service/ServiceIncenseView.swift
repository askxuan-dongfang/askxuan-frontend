//
//  ServiceIncenseView.swift
//  DongFangApp
//
//  敬香服务页：复用 ServiceContainerView，传入 .incense。
//

import SwiftUI

/// 敬香服务页
struct ServiceIncenseView: View {
    var body: some View {
        ServiceContainerView(serviceType: .incense)
    }
}

#Preview {
    NavigationStack { ServiceIncenseView() }
        .preferredColorScheme(.dark)
}
