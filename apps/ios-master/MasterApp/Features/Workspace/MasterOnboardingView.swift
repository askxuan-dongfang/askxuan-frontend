import SwiftUI
import UniformTypeIdentifiers

private struct WorkApplication: Codable {
 var id: Int64; var status: String; var revision: Int; var reviewNote: String; var profile: WorkProfile
}
private struct WorkEnvelope<T: Decodable>: Decodable { let code: Int; let message: String; let data: T? }
private struct WorkSave: Encodable { let profile: WorkProfile; let revision: Int; let submit: Bool }
private struct WorkUpload: Decodable { let id: String; let name: String }
private struct WorkEvent: Decodable { let at: String; let action: String; let note: String }
private struct WorkHistory: Decodable { let list: [WorkEvent] }
private struct WorkTraditionList: Decodable { let list: [OnboardingTradition] }

struct MasterOnboardingView: View {
 @EnvironmentObject private var auth: AuthStore
 @State private var application: WorkApplication?
 @State private var busy=false
 @State private var message=""
 @State private var error=""
 @State private var importing=false
 @State private var history: [WorkEvent]=[]
 @State private var previewURL: URL?
 @State private var traditions: [OnboardingTradition] = []
 @State private var catalogReady = false
 @State private var catalogLoading = false
 @State private var catalogError = ""
 @State private var pendingBelief: String?
 private var editable: Bool { ["draft","rejected"].contains(application?.status ?? "") }
 private let labels=["draft":"完善认证资料","submitted":"平台审核中","rejected":"请补充资料","approved":"认证已通过"]
 private func field(_ key: WritableKeyPath<WorkProfile,String?>) -> Binding<String> {
  Binding(get:{ application?.profile[keyPath:key] ?? "" },set:{application?.profile[keyPath:key]=$0})
 }
 private var selectedTraditions: [String] { application?.profile.traditionCodes ?? [] }
 private var belief: String { OnboardingAffiliation.canonical(application?.profile.belief ?? "") }
 private var traditionChoices: [OnboardingTradition] { OnboardingAffiliation.choices(in: traditions, belief: belief) }
 private var conflictingCodes: [String] {
  guard catalogReady else { return [] }
  return selectedTraditions.filter { OnboardingAffiliation.issue(for: $0, belief: belief, catalog: traditions) != nil }
 }
 private var beliefSelection: Binding<String> {
  Binding(get: { belief }, set: { value in
   guard value != belief else { return }
   if selectedTraditions.isEmpty { application?.profile.belief = value }
   else { pendingBelief = value }
  })
 }
 private func toggleTradition(_ code: String) {
  guard editable, !busy else { return }
  var codes = selectedTraditions
  if codes.contains(code) { codes.removeAll { $0 == code } }
  else if codes.count < 12 { codes.append(code) }
  application?.profile.traditionCodes = codes
 }
 private var affiliationSection: some View {
  Section {
   Picker(L10n.text("信仰流派"), selection: beliefSelection) {
    Text(L10n.text("请选择")).tag("")
    ForEach(OnboardingAffiliation.beliefs) { option in Text(L10n.lookup(option.name)).tag(option.code) }
   }.disabled(busy || !editable).accessibilityIdentifier("onboarding.belief")
   Text(L10n.text("宗派／信俗（可多选）")).font(.subheadline.weight(.medium))
   if catalogLoading { ProgressView(L10n.text("正在加载宗派／信俗目录")) }
   if !catalogError.isEmpty {
    Text(L10n.lookup(catalogError)).foregroundStyle(.red)
    Button(L10n.text("重试")) { Task { await loadCatalog() } }.disabled(busy || catalogLoading)
   }
   if catalogReady && belief.isEmpty { Text(L10n.text("请先选择信仰流派")).foregroundStyle(.secondary) }
   if catalogReady && !belief.isEmpty && traditionChoices.isEmpty {
    Text(L10n.text("当前流派暂无可选宗派／信俗，请联系平台")).foregroundStyle(.secondary)
   }
   ForEach(traditionChoices) { tag in
    Button { toggleTradition(tag.code) } label: {
     HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: selectedTraditions.contains(tag.code) ? "checkmark.circle.fill" : "circle")
      Text(L10n.lookup(tag.name)).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
     }.frame(minHeight: 32).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityValue(L10n.text(selectedTraditions.contains(tag.code) ? "已选择" : "未选择"))
    .accessibilityIdentifier("onboarding.tradition.\(tag.code)")
    .disabled(busy || !editable || (!selectedTraditions.contains(tag.code) && selectedTraditions.count >= 12))
   }
   if !conflictingCodes.isEmpty {
    Text(L10n.text(editable ? "以下已选项仍保留在草稿中，提交前请移除并重新选择。" : "已保存的宗派／信俗选择需要补充，请等待平台退回后修改。")).foregroundStyle(.secondary)
    ForEach(Array(conflictingCodes.enumerated()), id: \.offset) { _, code in
     HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
       Text(L10n.lookup(traditions.first(where: { $0.code == code })?.name ?? code))
       Text(L10n.lookup(OnboardingAffiliation.issue(for: code, belief: belief, catalog: traditions) ?? "")).font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      if editable {
       Button(L10n.text("移除"), role: .destructive) { application?.profile.traditionCodes?.removeAll { $0 == code } }.disabled(busy).accessibilityIdentifier("onboarding.remove.\(code)")
      }
     }
    }
   }
   if !catalogReady && !selectedTraditions.isEmpty {
    Text(L10n.text("已保存的宗派／信俗编码：") + selectedTraditions.joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
   }
   if !editable && selectedTraditions.isEmpty {
    Text(L10n.text("尚未选择标准宗派／信俗，如需补充请等待平台退回。")).foregroundStyle(.secondary)
   }
   TextField(L10n.text("宗派补充说明（选填）"), text: field(\.sect)).disabled(busy || !editable).accessibilityIdentifier("onboarding.sect")
  } header: { Text(L10n.text("信仰与宗派／信俗")) }
  footer: { Text(L10n.text("请选择实际归属，最多 12 项。宗派补充说明不会自动转换为标准归属。")) }
 }
 var body: some View {
  NavigationStack {
   Form {
    Section {
     Text(L10n.lookup(labels[application?.status ?? ""] ?? L10n.text("正在加载"))).font(.title2.bold())
     Text(L10n.text("提交本人资料，由平台审核。认证通过后开通独立大师工作台。")).foregroundStyle(.secondary)
     if let note=application?.reviewNote,!note.isEmpty { Text(L10n.lookup(L10n.text("审核意见：") + note)) }
    } header: {Text(L10n.text("独立大师认证"))}
    if application != nil && application?.status != "approved" {
     Section(L10n.text("认证资料")) {
      TextField(L10n.text("对外称呼／法名"),text:field(\.name))
      TextField(L10n.text("本人姓名"),text:field(\.legalName))
      TextField(L10n.text("联系电话"),text:field(\.contact)).keyboardType(.phonePad)
      TextField(L10n.text("所在地区"),text:field(\.region))
      TextField(L10n.text("身份／职务"),text:field(\.position))
      TextField(L10n.text("个人介绍与服务专长"),text:field(\.description),axis:.vertical).lineLimit(3...6)
     }.disabled(busy || !editable)
     affiliationSection
     Section(L10n.text("身份证明及从业资质")) {
      ForEach(Array((application?.profile.evidenceIds ?? []).enumerated()),id:\.element) { index,id in
       HStack {
        Button(L10n.text("查看材料 \(index + 1)")) { Task { await download(id) } }
        Spacer()
        if editable { Button(L10n.text("移除"),role:.destructive) { application?.profile.evidenceIds?.removeAll{$0==id} }.disabled(busy) }
       }
      }
      if editable { Button(L10n.text("上传证明材料")) {importing=true}.disabled(busy || (application?.profile.evidenceIds?.count ?? 0)>=8) }
      Text(L10n.text("提供本人身份证明及从业资质。支持 PDF、PNG、JPEG，每份不超过 5MB，最多 8 份。仅本人和平台审核人员可访问。")).font(.caption).foregroundStyle(.secondary)
     }
     if editable {
      Section {
       Button(L10n.text("保存草稿")) {Task{await save(false)}}.accessibilityIdentifier("onboarding.save")
       Button(L10n.text("提交审核")) {Task{await save(true)}}.accessibilityIdentifier("onboarding.submit")
      }.disabled(busy)
     }
    }
    if !error.isEmpty { Section {Text(L10n.lookup(error)).foregroundStyle(.red).accessibilityIdentifier("onboarding.error")} }
    if !message.isEmpty { Section {Text(L10n.lookup(message)).accessibilityIdentifier("onboarding.notice")} }
    if !history.isEmpty {Section(L10n.text("申请记录")){ForEach(Array(history.enumerated()),id:\.offset){_,e in Text(L10n.lookup(e.at + " · " + (["save":"保存草稿","submit":"提交审核","rejected":"退回补充","approved":"审核通过"][e.action] ?? e.action) + " " + e.note)).font(.caption)}}}
    Section {
     Button(L10n.text("刷新进度")) {Task{await load()}}.disabled(busy)
     Button(L10n.text("退出并返回登录")) {auth.logout()}.disabled(busy)
    }
   }.navigationTitle(L10n.text("大师认证")).task{await load();await loadCatalog()}
    .alert(L10n.text("确认信仰流派变更"), isPresented: Binding(get: { pendingBelief != nil }, set: { if !$0 { pendingBelief = nil } }), presenting: pendingBelief) { value in
     Button(L10n.text("更换并保留已选项")) { application?.profile.belief = value;pendingBelief = nil }
     Button(L10n.text("取消"), role: .cancel) { pendingBelief = nil }
    } message: { _ in Text(L10n.text("更换信仰流派后，已选宗派／信俗仍会保留。请手动移除不匹配项后重新选择，再提交审核。")) }
    .fileImporter(isPresented:$importing,allowedContentTypes:[.pdf,.png,.jpeg]) { result in
     switch result {case .success(let url):Task{await upload(url)};case .failure(let e):error=e.localizedDescription}
    }
    .sheet(isPresented:Binding(get:{previewURL != nil},set:{if !$0{if let url=previewURL{try? FileManager.default.removeItem(at:url)};previewURL=nil}})){
     if let url=previewURL {NavigationStack{VStack(spacing:20){Text(L10n.text("材料已安全下载到本机临时目录"));ShareLink("查看或保存材料",item:url)}.padding().toolbar{Button(L10n.text("完成")){try? FileManager.default.removeItem(at:url);previewURL=nil}}}}
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
  do {var value: WorkApplication=try await call("application");value.profile=value.profile.normalized();application=value;pendingBelief=nil;error=""} catch {self.error=error.localizedDescription}
  if let id=application?.id {do{var url=URLComponents(url:APIClient.shared.baseURL.appendingPathComponent("auth/onboarding/history"),resolvingAgainstBaseURL:false)!;url.queryItems=[URLQueryItem(name:"id",value:String(id))];let (data,_)=try await APIClient.shared.sessionData(for:URLRequest(url:url.url!));history=try JSONDecoder().decode(WorkEnvelope<WorkHistory>.self,from:data).data?.list ?? []}catch{}}
 }
 private func loadCatalog() async {
  guard !catalogLoading else { return }
  catalogLoading = true;catalogReady = false;catalogError = ""
  defer { catalogLoading = false }
  do {
   let value: WorkTraditionList = try await APIClient.shared.request(.directoryTags)
   traditions = value.list;catalogReady = true
  } catch { catalogError = "宗派／信俗目录加载失败，请重试" }
 }
 private func save(_ submit:Bool) async {
  guard !busy,let app=application else{return}
  guard pendingBelief == nil else { error = "请先确认信仰流派变更";return }
  if let issue = OnboardingAffiliation.validationError(profile: app.profile, catalog: traditions, catalogReady: catalogReady, submit: submit) { error = issue;return }
  busy=true;defer{busy=false}
  do {application=try await call("application",body:JSONEncoder().encode(WorkSave(profile:app.profile.normalized(),revision:app.revision,submit:submit)));message=submit ? "申请已提交，请等待平台审核":"草稿已保存";error="";await load()}catch{self.error=error.localizedDescription}
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
