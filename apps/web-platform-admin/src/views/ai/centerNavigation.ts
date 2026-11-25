import type { InjectionKey, Ref } from 'vue'

interface AgentStep {
  path: string
  title: string
  section: string
}

interface AgentStage {
  title: string
  steps: readonly AgentStep[]
}

export const agentWorkflow: readonly AgentStage[] = [
  { title: '配置', steps: [
    { path: '/ai/agent', title: '职责与模型', section: 'config' },
    { path: '/ai/tools', title: '技能与工具', section: 'skills' },
    { path: '/ai/context', title: '知识与上下文', section: 'context' },
    { path: '/ai/topics', title: '专题配置', section: 'topics' },
  ] },
  { title: '调试与评测', steps: [
    { path: '/ai/debug', title: '单次调试', section: 'debug' },
    { path: '/ai/evaluations', title: '质量评测', section: 'evaluation' },
  ] },
  { title: '发布', steps: [{ path: '/ai/releases', title: '版本与发布', section: 'versions' }] },
  { title: '运行', steps: [{ path: '/ai/runs', title: '运行监控', section: 'runs' }] },
]

export const agentCenterSections = agentWorkflow.flatMap(stage => stage.steps)
export const agentSectionPath = (section: string) => agentCenterSections.find(step => step.section === section)?.path ?? '/ai/agent'

export const agentDraftDirtyKey: InjectionKey<Ref<boolean>> = Symbol('agentDraftDirty')
