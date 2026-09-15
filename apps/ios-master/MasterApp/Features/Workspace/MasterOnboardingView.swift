import SwiftUI
import UniformTypeIdentifiers

private struct WorkProfile: Codable {
 var name: String?; var legalName: String?; var contact: String?; var region: String?
 var belief: String?; var sect: String?; var position: String?; var description: String?
 var evidenceIds: [String]?
}
private struct WorkApplication: Codable {
 var id: Int64; var status: String; var revision: Int; var reviewNote: String; var profile: WorkProfile
}
private struct WorkEnvelope<T: Decodable>: Decodable { let code: Int; let message: String; let data: T? }
private struct WorkSave: Encodable { let profile: WorkProfile; let revision: Int; let submit: Bool }
private struct WorkUpload: Decodable { let id: String; let name: String }
private struct WorkEvent: Decodable { let at: String; let action: String; let note: String }
private struct WorkHistory: Decodable { let list: [WorkEvent] }

struct MasterOnboardingView: View {
 @EnvironmentObject private var auth: AuthStore
 @State private var application: WorkApplication?
 @State private var busy=false
 @State private var message=""
 @State private var error=""
 @State private var importing=false
 @State private var history: [WorkEvent]=[]
 @State private var previewURL: URL?
 private var editable: Bool { ["draft","rejected"].contains(application?.status ?? "") }
 private let labels=["draft":"完善认证资料","submitted":"平台审核中","rejected":"请补充资料","approved":"认证已通过"]
 private func field(_ key: WritableKeyPath<WorkProfile,String?>) -> Binding<String> {
  Binding(get:{ application?.profile[keyPath:key] ?? "" },set:{application?.profile[keyPath:key]=$0})
 }
 var body: some View {
  NavigationStack {
   Form {
    Section {
     Text(labels[application?.status ?? ""] ?? "正在加载").font(.title2.bold())
     Text("提交本人资料，由平台审核。认证通过后开通独立大师工作台。").foregroundStyle(.secondary)
     if let note=application?.reviewNote,!note.isEmpty { Text("审核意见："+note) }
    } header: {Text("独立大师认证")}
    if application != nil && application?.status != "approved" {
     Section("认证资料") {
      TextField("对外称呼／法名",text:field(\.name))
      TextField("本人姓名",text:field(\.legalName))
      TextField("联系电话",text:field(\.contact)).keyboardType(.phonePad)
      TextField("所在地区",text:field(\.region))
      Picker("信仰流派",selection:field(\.belief)) {
       Text("请选择").tag("");Text("汉传佛教").tag("han_buddhism");Text("藏传佛教").tag("tibetan_buddhism");Text("道教").tag("taoism");Text("民间信仰").tag("folk")
      }
      TextField("宗派",text:field(\.sect))
      TextField("身份／职务",text:field(\.position))
      TextField("个人介绍与服务专长",text:field(\.description),axis:.vertical).lineLimit(3...6)
     }.disabled(busy || !editable)
     Section("身份证明及从业资质") {
      ForEach(Array((application?.profile.evidenceIds ?? []).enumerated()),id:\.element) { index,id in
       HStack {
        Button("查看材料 \(index+1)") { Task { await download(id) } }
        Spacer()
        if editable { Button("移除",role:.destructive) { application?.profile.evidenceIds?.removeAll{$0==id} }.disabled(busy) }
       }
      }
      if editable { Button("上传证明材料") {importing=true}.disabled(busy || (application?.profile.evidenceIds?.count ?? 0)>=8) }
      Text("提供本人身份证明及从业资质。支持 PDF、PNG、JPEG，每份不超过 5MB，最多 8 份。仅本人和平台审核人员可访问。").font(.caption).foregroundStyle(.secondary)
     }
     if editable {
      Section { Button("保存草稿") {Task{await save(false)}};Button("提交审核") {Task{await save(true)}} }.disabled(busy)
     }
    }
    if !error.isEmpty { Section {Text(error).foregroundStyle(.red)} }
    if !message.isEmpty { Section {Text(message)} }
    if !history.isEmpty {Section("申请记录"){ForEach(Array(history.enumerated()),id:\.offset){_,e in Text(e.at+" · "+(["save":"保存草稿","submit":"提交审核","rejected":"退回补充","approved":"审核通过"][e.action] ?? e.action)+" "+e.note).font(.caption)}}}
    Section {
     Button("刷新进度") {Task{await load()}}.disabled(busy)
     Button("退出并返回登录") {auth.logout()}.disabled(busy)
    }
   }.navigationTitle("大师认证").task{await load()}
    .fileImporter(isPresented:$importing,allowedContentTypes:[.pdf,.png,.jpeg]) { result in
     switch result {case .success(let url):Task{await upload(url)};case .failure(let e):error=e.localizedDescription}
    }
    .sheet(isPresented:Binding(get:{previewURL != nil},set:{if !$0{if let url=previewURL{try? FileManager.default.removeItem(at:url)};previewURL=nil}})){
     if let url=previewURL {NavigationStack{VStack(spacing:20){Text("材料已安全下载到本机临时目录");ShareLink("查看或保存材料",item:url)}.padding().toolbar{Button("完成"){try? FileManager.default.removeItem(at:url);previewURL=nil}}}}
    }
  }
 }
 private func call<T:Decodable>(_ path:String,body:Data?=nil,contentType:String="application/json") async throws -> T {
  let url=APIClient.shared.baseURL.appendingPathComponent("auth/onboarding/"+path)
  var req=URLRequest(url:url);req.httpMethod=body == nil ? "GET":"POST";req.httpBody=body;req.setValue(contentType,forHTTPHeaderField:"Content-Type")
  let (data,_)=try await APIClient.shared.sessionData(for:req)
  let env=try JSONDecoder().decode(WorkEnvelope<T>.self,from:data)
  guard env.code==0,let value=env.data else {throw NSError(domain:"WorkApplication",code:env.code,userInfo:[NSLocalizedDescriptionKey:env.message])};return value
 }
 private func load() async {
  do {application=try await call("application");error=""} catch {self.error=error.localizedDescription}
  if let id=application?.id {do{var url=URLComponents(url:APIClient.shared.baseURL.appendingPathComponent("auth/onboarding/history"),resolvingAgainstBaseURL:false)!;url.queryItems=[URLQueryItem(name:"id",value:String(id))];let (data,_)=try await APIClient.shared.sessionData(for:URLRequest(url:url.url!));history=try JSONDecoder().decode(WorkEnvelope<WorkHistory>.self,from:data).data?.list ?? []}catch{}}
 }
 private func save(_ submit:Bool) async {
  guard !busy,let app=application else{return};busy=true;defer{busy=false}
  do {application=try await call("application",body:JSONEncoder().encode(WorkSave(profile:app.profile,revision:app.revision,submit:submit)));message=submit ? "申请已提交，请等待平台审核":"草稿已保存";error="";await load()}catch{self.error=error.localizedDescription}
 }
 private func upload(_ url:URL) async {
  guard !busy else{return};busy=true;defer{busy=false}
  let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
  do {
   let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
   guard size>0 && size<=5*1024*1024 else {throw NSError(domain:"WorkApplication",code:1,userInfo:[NSLocalizedDescriptionKey:"每份材料不能超过 5MB"])}
   let file=try Data(contentsOf:url);let boundary="Work-"+UUID().uuidString
   let safeName=url.lastPathComponent.replacingOccurrences(of:"\"",with:"_").replacingOccurrences(of:"\r",with:"").replacingOccurrences(of:"\n",with:"")
   var body=Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(safeName)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8);body.append(file);body.append(Data("\r\n--\(boundary)--\r\n".utf8))
   let value:WorkUpload=try await call("evidence",body:body,contentType:"multipart/form-data; boundary="+boundary)
   application?.profile.evidenceIds=(application?.profile.evidenceIds ?? [])+[value.id];message="材料已上传，请保存或提交申请";error=""
  }catch{self.error=error.localizedDescription}
 }
 private func download(_ id:String) async {
  do {var parts=URLComponents(url:APIClient.shared.baseURL.appendingPathComponent("auth/onboarding/evidence"),resolvingAgainstBaseURL:false)!;parts.queryItems=[URLQueryItem(name:"id",value:id)];let (data,response)=try await APIClient.shared.sessionData(for:URLRequest(url:parts.url!));let ext=response.mimeType=="application/pdf" ? "pdf":response.mimeType=="image/png" ? "png":"jpg";let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+"."+ext);try data.write(to:url,options:.atomic);previewURL=url}catch{self.error=error.localizedDescription}
 }
}
