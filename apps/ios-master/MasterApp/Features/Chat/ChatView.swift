import SwiftUI
struct ChatView: View {
 let conversation: MasterBookingChatConversation
 @ObservedObject private var auth = AuthStore.shared
 var body: some View {
  ChatExperienceView(conversationID: conversation.id, role: "master", accountID: auth.masterId ?? "",
   userID: auth.userId ?? "", token: auth.token ?? "", nickname: auth.nickname ?? "")
 }
}
