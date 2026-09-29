import type { AgentConfig, SkillInfo } from '../../api/agentOperations'

export type CapabilityKind = 'mcp' | 'builtin' | 'skill'
export function capabilityKind(info?: SkillInfo): CapabilityKind {
  if (!info?.toolName) return 'skill'
  return info.toolServer === 'builtin' ? 'builtin' : 'mcp'
}
export function addCapability(config: AgentConfig, info: SkillInfo): boolean {
  if (info.sourceStatus === 'disabled' || config.skills.some(s => s.code === info.code)) return false
  config.skills.push({ code: info.code, enabled: true, prompt: info.defaultPrompt ?? `你是${info.name}助手。${info.description}仅解释实际工具结果，资料不足时补问。`, useTool: info.toolAvailable && info.einoSupported })
  return true
}
// Caller confirms affected evaluation cases before mutating the draft.
export function changeCapability(config: AgentConfig, code: string, action: 'remove' | 'disable' | 'enable'): boolean {
  const policy = config.skills.find(s => s.code === code)
  if (!policy || (code === 'general' && action !== 'enable')) return false
  if (action === 'remove') config.skills = config.skills.filter(s => s.code !== code)
  else policy.enabled = action === 'enable'
  if (action !== 'enable') config.evaluation = (config.evaluation || []).filter(c => c.skillCode !== code)
  return true
}
