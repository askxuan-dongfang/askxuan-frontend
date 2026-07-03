//
//  ServiceRiteView.swift
//  DongFangApp
//
//  法事（超度）服务页：复用 ServiceContainerView，传入 .rite。
//

import SwiftUI

/// 法事（超度）服务页
struct ServiceRiteView: View {
    var body: some View {
        ServiceContainerView(serviceType: .rite)
    }
}

#Preview {
    NavigationStack { ServiceRiteView() }
        .preferredColorScheme(.dark)
}
