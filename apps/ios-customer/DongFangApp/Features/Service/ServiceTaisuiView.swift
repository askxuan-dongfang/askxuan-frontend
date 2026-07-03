//
//  ServiceTaisuiView.swift
//  DongFangApp
//
//  化太岁服务页：复用 ServiceContainerView，传入 .taisui。
//

import SwiftUI

/// 化太岁服务页
struct ServiceTaisuiView: View {
    var body: some View {
        ServiceContainerView(serviceType: .taisui)
    }
}

#Preview {
    NavigationStack { ServiceTaisuiView() }
        .preferredColorScheme(.dark)
}
