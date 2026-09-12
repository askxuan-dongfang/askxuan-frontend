import SwiftUI
struct ChatDetailView: View {
 let conversation: ChatConversation
 @ObservedObject var viewModel: ChatViewModel
 @ObservedObject private var auth = AuthStore.shared
 var body: some View {
  ChatExperienceView(conversationID: conversation.id, role: "customer", accountID: auth.userId,
   userID: auth.userId, token: auth.accessToken ?? "", nickname: auth.nickname)
   .onDisappear { Task { await viewModel.loadConversations(silent: true) } }
 }
}
