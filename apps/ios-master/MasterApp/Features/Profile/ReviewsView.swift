//
//  ReviewsView.swift
//  MasterApp
//
//  评价管理（页面 14）。
//  GET admin/masters/reviews
//

import SwiftUI

@MainActor
final class ReviewsViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var ratingFilter: Int = 0     // 0 全部 / 1-5 对应星级
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var total: Int64 = 0

    private let apiClient: APIClient
    private var page: Int = 1
    private let size: Int = 20
    private var hasMore: Bool = true

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map { $0.rating }.reduce(0, +)) / Double(reviews.count)
    }

    func load(reset: Bool = true) async {
        if reset {
            page = 1
            hasMore = true
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let resp: ReviewListResponse = try await apiClient.request(
                .masterReviews(rating: ratingFilter > 0 ? ratingFilter : nil, page: page, size: size)
            )
            if reset {
                reviews = resp.list
            } else {
                reviews.append(contentsOf: resp.list)
            }
            total = resp.total
            hasMore = reviews.count < Int(total)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        page += 1
        await load(reset: false)
    }

    func switchRating(_ rating: Int) async {
        ratingFilter = rating
        await load(reset: true)
    }
}

struct ReviewsView: View {
    @StateObject private var viewModel = ReviewsViewModel()

    private let filters: [(Int, String)] = [
        (0, "全部"), (5, "5星"), (4, "4星"), (3, "3星"), (2, "2星"), (1, "1星")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 评分概览
            summaryHeader

            // 筛选条
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(filters, id: \.0) { item in
                        let isActive = viewModel.ratingFilter == item.0
                        Text(item.1)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? .white : .textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 6)
                            .background(isActive ? AnyShapeStyle(LinearGradient(colors: [.brandDefault, .brandLight], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.bgTertiary))
                            .cornerRadius(AppRadius.md)
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.bottom, AppSpacing.md)
            }
            .background(Color.bgPrimary)

            reviewList
        }
        .background(Color.bgPrimary)
        .navigationTitle("评价管理")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var summaryHeader: some View {
        HStack(spacing: AppSpacing.lg) {
            VStack(spacing: 2) {
                Text(String(format: "%.1f", viewModel.averageRating))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.accentDefault)
                Text("平均评分")
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
            }
            .frame(width: 100)
            Divider().background(Color.borderDivider).frame(height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("共 \(viewModel.total) 条评价")
                    .font(.cardTitle)
                    .foregroundStyle(.textPrimary)
                Text("星级筛选可查看具体评分")
                    .font(.micro)
                    .foregroundStyle(.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.pageHorizontal)
        .padding(.vertical, AppSpacing.md)
        .background(Color.bgSecondary)
    }

    @ViewBuilder
    private var reviewList: some View {
        if viewModel.isLoading && viewModel.reviews.isEmpty {
            LoadingView(fullScreen: true)
        } else if viewModel.reviews.isEmpty {
            EmptyState(icon: "star.slash",
                       title: "暂无评价",
                       message: viewModel.errorMessage) {
                Task { await viewModel.load() }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.reviews) { review in
                        reviewCard(review)
                            .onAppear {
                                if review.id == viewModel.reviews.last?.id {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                    }
                    if viewModel.isLoading {
                        LoadingView(message: "加载更多...")
                    }
                }
                .padding(.horizontal, AppSpacing.pageHorizontal)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        MasterCard(padding: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text(review.ratingText)
                        .font(.system(size: 14))
                        .foregroundStyle(.stateWarning)
                    Spacer()
                    Text(review.targetTypeText)
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.bgTertiary)
                        .cornerRadius(AppRadius.sm)
                }
                Text(review.content.isEmpty ? "（用户未填写评价内容）" : review.content)
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !review.imageUrls.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(Array(review.imageUrls.prefix(3).enumerated()), id: \.offset) { _, url in
                            AsyncImage(url: URL(string: url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.bgTertiary
                            }
                            .frame(width: 56, height: 56)
                            .cornerRadius(AppRadius.sm)
                        }
                    }
                }

                HStack {
                    Text("信众：\(review.userId.isEmpty ? "匿名" : review.userId)")
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                    Spacer()
                    Text(DFDateFormatter.friendly(review.createTime))
                        .font(.micro)
                        .foregroundStyle(.textTertiary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewsView()
    }
    .preferredColorScheme(.dark)
}
