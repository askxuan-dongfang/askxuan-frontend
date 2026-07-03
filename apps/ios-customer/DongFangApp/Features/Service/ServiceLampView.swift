//
//  ServiceLampView.swift
//  DongFangApp
//
//  点灯服务页：复用 ServiceContainerView，传入 .lamp。
//

import SwiftUI

/// 点灯（供灯）服务页
struct ServiceLampView: View {
    var body: some View {
        ServiceContainerView(serviceType: .lamp)
    }
}

#Preview {
    NavigationStack { ServiceLampView() }
        .preferredColorScheme(.dark)
}
