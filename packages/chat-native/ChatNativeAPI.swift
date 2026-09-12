import Foundation
@MainActor enum ChatNativeAPI {
    private struct Envelope<T: Decodable>: Decodable { let code: Int; let message: String?; let data: T? }
    static func get<T: Decodable>(_ path:String, query:[URLQueryItem]=[]) async throws -> T {
        guard NativeChatNotifications.shared.identity() != nil else { throw CancellationError() }
        var parts=URLComponents(url:AppConfig.baseURL.appendingPathComponent(path),resolvingAgainstBaseURL:false)!
        parts.queryItems=query.isEmpty ? nil : query
        let request=URLRequest(url:parts.url!)
        let (data,response)=try await APIClient.shared.sessionData(for:request)
        guard response.statusCode == 200 else {throw URLError(.badServerResponse)}
        let envelope=try JSONDecoder().decode(Envelope<T>.self,from:data)
        guard envelope.code==0,let result=envelope.data else {throw NSError(domain:"Chat",code:envelope.code,userInfo:[NSLocalizedDescriptionKey:envelope.message ?? "会话暂时无法加载"])}
        return result
    }
    static func conversations<T:Decodable>(page:Int,query:String="") async throws -> T {
        try await get("chats",query:[URLQueryItem(name:"page",value:String(page)),URLQueryItem(name:"size",value:"30"),URLQueryItem(name:"query",value:query)])
    }
}
