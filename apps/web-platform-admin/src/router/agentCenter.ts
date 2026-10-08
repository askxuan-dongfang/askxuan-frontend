import type { RouteRecordRaw } from 'vue-router'
import { agentCenterSections } from '@/views/ai/centerNavigation'
const meta = { parent: '问事智能体开发中心', roles: ['platform_super'] }
export const agentCenterRoutes: RouteRecordRaw[] = [
  ...agentCenterSections.filter(item => 'section' in item).map(item => ({
    path: item.path.slice('/ai/'.length), name: `AgentCenter-${item.path.split('/').pop()}`,
    component: () => import('@/views/ai/AgentOperationsView.vue'),
    meta: { ...meta, title: item.title, agentSection: 'section' in item ? item.section : undefined, description: item.description },
  })),
  { path: 'knowledge', component: () => import('@/views/ai/KnowledgeCenterView.vue'), meta: { ...meta, title: '知识中心' } },
  { path: 'connections', component: () => import('@/views/ai/ConnectionsView.vue'), redirect: '/ai/connections/models', meta: { ...meta, title: '模型与连接' }, children: [
    { path: 'models', component: () => import('@/views/settings/SettingsAiView.vue'), props: { section: 'models', embedded: true }, meta: { ...meta, title: '大模型连接' } },
    { path: 'search', component: () => import('@/views/settings/SettingsAiView.vue'), props: { section: 'search', embedded: true }, meta: { ...meta, title: '联网搜索' } },
    { path: 'knowledge', component: () => import('@/views/ai/KnowledgeModelsView.vue'), meta: { ...meta, title: '知识模型' } },
  ] },
]
