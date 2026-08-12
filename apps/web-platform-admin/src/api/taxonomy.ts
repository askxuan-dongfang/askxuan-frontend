import client from './client'

export interface BeliefProfile {
  code: string
  name: string
  summary: string
  description: string
  coverImage: string
  icon: string
  sort: number
  status: 'enabled' | 'disabled'
}

export interface IntentionTag {
  code: string
  name: string
  description: string
  icon: string
  landingType: 'aggregate' | 'service' | 'diy'
  landingValue: string
  actionTitle: string
  sort: number
  status: 'enabled' | 'disabled'
}

export const taxonomyApi = {
  beliefs: () => client.get<{ list: BeliefProfile[] }>('/admin/platform/beliefs'),
  createBelief: (data: Omit<BeliefProfile, 'status'>) => client.post<BeliefProfile>('/admin/platform/beliefs', data),
  updateBelief: (code: string, data: Omit<BeliefProfile, 'code' | 'status'>) => client.put<BeliefProfile>(`/admin/platform/beliefs/${code}`, data),
  setBeliefStatus: (code: string, status: BeliefProfile['status']) => client.put(`/admin/platform/beliefs/${code}/status`, { status }),
  intentions: () => client.get<{ list: IntentionTag[] }>('/admin/platform/intentions'),
  createIntention: (data: Omit<IntentionTag, 'status'>) => client.post<IntentionTag>('/admin/platform/intentions', data),
  updateIntention: (code: string, data: Omit<IntentionTag, 'code' | 'status'>) => client.put<IntentionTag>(`/admin/platform/intentions/${code}`, data),
  setIntentionStatus: (code: string, status: IntentionTag['status']) => client.put(`/admin/platform/intentions/${code}/status`, { status })
}
