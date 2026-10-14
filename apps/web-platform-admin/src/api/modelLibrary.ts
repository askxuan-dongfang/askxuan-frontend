import client from './client'

export type ModelRole = 'chat' | 'vision' | 'embedding' | 'rerank' | 'document'
export interface LibraryModel {
  id: string; name: string; model: string; provider: string; baseUrl: string
  kind: string; source: string; dimension: number; contextWindow: number; maxOutputTokens: number
  bindings: Partial<Record<ModelRole, string>>
}
export type ModelUses = Record<ModelRole, string>
export interface ModelLibrary {
  list: LibraryModel[]; uses: ModelUses; revision: number; writable: boolean; defaultChat: string; warnings: string[]
}
export const emptyUses = (): ModelUses => ({ chat: '', vision: '', embedding: '', rerank: '', document: '' })
export const modelRoles: { key: ModelRole; label: string; hint: string }[] = [
  { key: 'chat', label: '聊天', hint: '用户未主动选择模型时使用；智能体已发布的指定模型优先。' },
  { key: 'vision', label: '图片理解', hint: '只显示声明支持图片输入的大模型。' },
  { key: 'embedding', label: '建索引 · Embedding', hint: '作为新建知识库的初始选择，已有索引保留原模型。' },
  { key: 'rerank', label: '重排 · Rerank', hint: '用于检索验证的初始选择；智能体的重排策略需在草稿中选择并发布。' },
  { key: 'document', label: '文档理解', hint: '作为新知识库、实体抽取和 Wiki 生成的初始选择。' },
]
export function modelOptions(library: ModelLibrary, role: ModelRole) {
  return library.list.filter(m => m.bindings[role]).map(m => ({
    id: m.bindings[role]!, name: m.name === m.model ? m.name : `${m.name} · ${m.model}`, libraryId: m.id,
  }))
}
export const modelLibraryApi = {
  list: () => client.get<ModelLibrary>('/ai/admin/model-library', { timeout: 35000 }),
  saveUses: (uses: ModelUses, revision: number) => client.put('/ai/admin/model-library/uses', { uses, revision }, { timeout: 90000 }),
}
