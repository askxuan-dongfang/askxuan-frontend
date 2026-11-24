import client from './client'

export type ModelRole = 'chat' | 'catalogTranslation' | 'vision' | 'embedding' | 'rerank' | 'document'
export interface LibraryModel {
  id: string; name: string; model: string; provider: string; baseUrl: string
  kind: string; source: string; dimension: number; contextWindow: number; maxOutputTokens: number
  bindings: Partial<Record<ModelRole, string>>
}
export type ModelUses = Record<ModelRole, string>
export type ModelSupplier = 'opencode_go' | 'deepseek'
export interface ModelLibrary {
  list: LibraryModel[]; uses: ModelUses; revision: number; writable: boolean; defaultChat: string; warnings: string[]
  customerModelIds?: string[]
  suppliers?: ModelSupplier[]
}
export interface SupplierImport {
  provider: ModelSupplier
  revision: number
  apiKey?: string
  reuseConnection?: string
}
export interface DiscoveredLanguageModel {
  id: string; name: string; contextWindow: number; maxOutputTokens: number; supportsVision: boolean
}
export const emptyUses = (): ModelUses => ({ chat: '', catalogTranslation: '', vision: '', embedding: '', rerank: '', document: '' })
export const modelRoles: { key: ModelRole; label: string; hint: string }[] = [
  { key: 'chat', label: '聊天', hint: '用户未主动选择模型时使用；智能体已发布的指定模型优先。' },
  { key: 'catalogTranslation', label: '目录翻译', hint: '用于商品等目录的英文翻译。留空时沿用默认文本模型。' },
  { key: 'vision', label: '图片理解', hint: '只显示声明支持图片输入的大模型。' },
  { key: 'embedding', label: '建索引 · Embedding', hint: '作为新建知识库的初始选择，已有索引保留原模型。' },
  { key: 'rerank', label: '重排 · Rerank', hint: '用于检索验证的初始选择；智能体的重排策略需在草稿中选择并发布。' },
  { key: 'document', label: '文档理解', hint: '作为新知识库、实体抽取和 Wiki 生成的初始选择。' },
]
export function providerName(provider: string) {
  if (provider === 'opencode_go') return 'OpenCode Go'
  if (provider === 'deepseek') return 'DeepSeek'
  return provider
}
export function modelOptions(library: ModelLibrary, role: ModelRole) {
  const models = library.list.filter(m => m.bindings[role])
  return models.map(m => {
    const label = m.name === m.model ? m.name : `${m.name} · ${m.model}`
    const ambiguous = models.some(other => other !== m && other.model === m.model)
    const connection = m.source === 'legacy' ? `${providerName(m.provider)}（原有连接）` : providerName(m.provider)
    return { id: m.bindings[role]!, name: ambiguous ? `${label} · ${connection}` : label, libraryId: m.id }
  })
}
export const modelLibraryApi = {
  list: () => client.get<ModelLibrary>('/ai/admin/model-library', { timeout: 35000 }),
  discoverOpenCodeGo: (apiKey: string) =>
    client.post<{ list: DiscoveredLanguageModel[] }>('/ai/admin/model-library/language/discover', { provider: 'opencode_go', apiKey }, { timeout: 35000 }),
  importSupplier: (input: SupplierImport) =>
    client.post<{ added: number; existing: number }>('/ai/admin/model-library/language/import', input, { timeout: 35000 }),
  saveUses: (uses: ModelUses, revision: number, customerModelIds?: string[]) =>
    client.put('/ai/admin/model-library/uses', { uses, revision, customerModelIds }, { timeout: 90000 }),
}
