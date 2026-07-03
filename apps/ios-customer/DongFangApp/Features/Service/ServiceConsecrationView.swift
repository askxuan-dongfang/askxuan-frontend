//
//  ServiceConsecrationView.swift
//  DongFangApp
//
//  开光服务页：复用 ServiceContainerView，传入 .consecration。
//

import SwiftUI

/// 开光服务页
struct ServiceConsecrationView: View {
    var body: some View {
        ServiceContainerView(serviceType: .consecration)
    }
}

#Preview {
    NavigationStack { ServiceConsecrationView() }
        .preferredColorScheme(.dark)
}
