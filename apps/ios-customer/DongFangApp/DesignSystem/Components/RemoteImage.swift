//
//  RemoteImage.swift
//  DongFangApp
//
//  图片加载组件：
//  - 有 scheme（http/https）→ AsyncImage 远程加载
//  - /assets/xxx.jpg → 提取 asset 名 xxx，用 Image(name) 加载
//  - 纯 asset 名 → 直接用 Image(name) 加载
//  - 加载失败时显示占位 SF Symbol
//

import SwiftUI

/// 从后端返回的图片路径中提取本地 asset 名
/// - /assets/temple-card-lingyinsi.jpg → temple-card-lingyinsi
/// - temple-card-lingyinsi → temple-card-lingyinsi（已经是 asset 名）
private func extractAssetName(_ urlString: String) -> String {
    var name = urlString
    if name.hasPrefix("/assets/") {
        name = String(name.dropFirst("/assets/".count))
    }
    // 去掉文件扩展名
    for ext in [".jpg", ".jpeg", ".png", ".webp"] {
        if name.lowercased().hasSuffix(ext) {
            name = String(name.dropLast(ext.count))
            break
        }
    }
    return name
}

/// 图片加载（远程 URL 或本地 asset 名）
struct RemoteImage: View {
    let urlString: String?
    var placeholderIcon: String = "photo"
    var contentMode: ContentMode = .fill

    var body: some View {
        if let urlString, !urlString.isEmpty {
            if let url = URL(string: urlString), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                // 无 scheme：/assets/xxx.jpg 或纯 asset 名
                Image(extractAssetName(urlString))
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.bgTertiary
            Image(systemName: placeholderIcon)
                .font(.system(size: 20))
                .foregroundStyle(.textTertiary)
        }
    }
}

/// 圆形头像图片（远程 URL 或本地 asset 名）
struct RemoteAvatar: View {
    let urlString: String?
    var size: CGFloat = 56
    var placeholderIcon: String = "person.circle.fill"

    var body: some View {
        if let urlString, !urlString.isEmpty {
            if let url = URL(string: urlString), url.scheme != nil {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        circlePlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))
                    case .failure:
                        circlePlaceholder
                    @unknown default:
                        circlePlaceholder
                    }
                }
                .frame(width: size, height: size)
            } else {
                // 无 scheme：/assets/xxx.jpg 或纯 asset 名
                Image(extractAssetName(urlString))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))
            }
        } else {
            circlePlaceholder
        }
    }

    private var circlePlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.bgTertiary)
                .frame(width: size, height: size)
            Image(systemName: placeholderIcon)
                .font(.system(size: size * 0.5))
                .foregroundStyle(.accentDefault)
        }
        .overlay(Circle().stroke(Color.accentDefault, lineWidth: 2))
        .frame(width: size, height: size)
    }
}
