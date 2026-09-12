import client from './client'
export interface AIProviderValues {
  provider: string; baseUrl: string; defaultModel: string; visionModel: string; enabledModels: string[]
  thinkingEnabled: boolean; reasoningEffort: string; maxOutputTokens: number
}
export interface AIProviderSettings extends AIProviderValues {
  revision: number; hasApiKey: boolean; writable: boolean; source: 'environment' | 'platform'
  history: { revision: number; actor: string; at: string; fields: string[] }[]
}
export interface AIProviderUpdate extends AIProviderValues { revision: number; apiKey: string }
export interface AIModelOption { id: string; name: string; description: string; supportsVision: boolean }
export const aiSettingsApi = {
  get: () => client.get<AIProviderSettings>('/ai/admin/provider'),
  test: (data: AIProviderUpdate) => client.post<{ list: AIModelOption[]; defaultModel: string }>('/ai/admin/provider/test', data, { timeout: 20000 }),
  save: (data: AIProviderUpdate) => client.put<AIProviderSettings>('/ai/admin/provider', data, { timeout: 20000 }),
}
