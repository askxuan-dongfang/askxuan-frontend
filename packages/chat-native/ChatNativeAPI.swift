import Foundation
@MainActor enum ChatNativeAPI {
    private struct Envelope<T: Decodable>: Decodable { let code: Int; let message: String?; let data: T? }
    static func get<T: Decodable>(_ path:String, query:[URLQueryItem]=[]) async throws -> T {
        guard let identity=NativeChatNotifications.shared.identity() else { throw URLError(.userAuthenticationRequired) }
        var parts=URLComponents(url:AppConfig.baseURL.appendingPathComponent(path),resolvingAgainstBaseURL:false)!
        parts.queryItems=query.isEmpty ? nil : query
        var request=URLRequest(url:parts.url!);request.setValue("Bearer \(identity.token)",forHTTPHeaderField:"Authorization")
        let (data,response)=try await URLSession.shared.data(for:request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {throw URLError(.badServerResponse)}
        let envelope=try JSONDecoder().decode(Envelope<T>.self,from:data)
        guard envelope.code==0,let result=envelope.data else {throw NSError(domain:"Chat",code:envelope.code,userInfo:[NSLocalizedDescriptionKey:envelope.message ?? "会话暂时无法加载"])}
        return result
    }
    static func conversations<T:Decodable>(page:Int,query:String="") async throws -> T {
        try await get("chats",query:[URLQueryItem(name:"page",value:String(page)),URLQueryItem(name:"size",value:"30"),URLQueryItem(name:"query",value:query)])
    }
}
