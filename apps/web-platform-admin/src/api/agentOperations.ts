import client from './client'

export interface SkillPolicy { code: string; enabled: boolean; prompt: string; useTool: boolean }
export interface AgentConfig { name: string; instruction: string; model: string; maxOutputTokens: number; skills: SkillPolicy[]; evaluation: EvaluationCase[] }
export interface InputField { key: string; label?: string; type: string; required?: boolean; options?: { value: string; label?: string }[] }
export interface SkillInfo { code: string; name: string; version: string; description: string; inputSchema: { fields?: InputField[] }; toolName: string; toolAvailable: boolean; einoSupported: boolean }
export interface AgentVersion { id: number; actor: string; note: string; createdAt: string }
export interface AgentWorkspace {
  runtimeMode?: 'harness' | 'classic';
  revision: number; draftSaved: boolean; activeVersion: number; draft: AgentConfig; catalog: SkillInfo[]; active: AgentConfig | null
  versions: AgentVersion[]; audit: { id: number; action: string; versionId: number; actor: string; note: string; createdAt: string }[]
  tested: boolean; liveEnabled: boolean; persistentRecovery: boolean; rollout: { versionId: number; stableVersion: number; percentage: number; revision: number }
}
export interface DebugRun {
  id: string; actor: string; revision: number; providerRevision: number; kind: string; skillCode: string; model: string; status: string
  result: string; clarification: string; interruptId: string; error: string; startedAt: string
  events: { stage: string; label: string; at: string }[]; modelAttempts: number; toolAttempts: number
  promptTokens: number | null; completionTokens: number | null
}
export interface ProductionRun { id: number; runNo: string; skillCode: string; skillVersion: string; model: string; status: string; stage: string; startedAt: string; latencyMs: number; promptTokens: number; completionTokens: number; costMicros: number }
export interface ToolTrace { name: string; status: string; latencyMs: number; createdAt: string }
export interface EvaluationCase { id: string; name: string; skillCode: string; question: string; inputs: Record<string, unknown>; minChars: number; contains: string[]; excludes: string[]; expectInvalid: boolean }
export interface EvaluationRun {
  engine?: string; id: string; revision: number; providerRevision: number; status: string; total: number; startedAt: string; error: string; results: { id: string; name: string; skillCode: string; passed: boolean; checks: string[]; latencyMs: number }[] }
const base = '/ai/admin/agent'
export const agentOperationsApi = {
  version: (id: number) => client.get<{ version: AgentVersion; config: AgentConfig }>(`${base}/versions/${id}`),
  setRollout: (revision: number, percentage: number, note: string) => client.post(`${base}/rollout`, { revision, percentage, note }),
  startEvaluation: (revision: number) => client.post<EvaluationRun>(`${base}/evaluations`, { revision }),
  evaluation: (id: string) => client.get<EvaluationRun>(`${base}/evaluations/${encodeURIComponent(id)}`),
  evaluations: () => client.get<{ list: EvaluationRun[] }>(`${base}/evaluations`),
  workspace: () => client.get<AgentWorkspace>(base),
  save: (revision: number, config: AgentConfig) => client.put(base, { revision, config }),
  publish: (revision: number, note: string) => client.post<{ version: number }>(`${base}/publish`, { revision, note }),
  rollback: (revision: number, version: number, note: string) => client.post(`${base}/rollback`, { revision, version, note }),
  start: (data: { revision: number; kind: string; skillCode: string; question: string; inputs: Record<string, unknown> }) => client.post<DebugRun>(`${base}/debug`, data),
  debug: (id: string) => client.get<DebugRun>(`${base}/debug/${encodeURIComponent(id)}`),
  resume: (id: string, interruptId: string, inputs: Record<string, unknown>) => client.post(`${base}/debug/${encodeURIComponent(id)}/resume`, { interruptId, inputs }),
  cancel: (id: string) => client.post(`${base}/debug/${encodeURIComponent(id)}/cancel`),
  debugList: () => client.get<{ list: DebugRun[] }>(`${base}/debug`),
  runs: (page: number, status: string) => client.get<{ list: ProductionRun[]; hasMore: boolean; page: number }>(`${base}/runs`, { params: { page, status } }),
  tools: (id: number) => client.get<{ list: ToolTrace[] }>(`${base}/runs/${id}/tools`),
  models: () => client.get<{ list: { id: string; name: string }[] }>('/ai/models'),
}
