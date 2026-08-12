import client from './client'

export interface BeliefOption { code: string; name: string; summary: string; icon: string; sort: number }
export interface IntentionOption { code: string; name: string; description: string; icon: string; sort: number }

export async function listBeliefs(): Promise<BeliefOption[]> {
  const response = await client.get<{ list: BeliefOption[] }>('/beliefs')
  return response.list || []
}

export async function listIntentions(): Promise<IntentionOption[]> {
  const response = await client.get<{ list: IntentionOption[] }>('/intentions/tags')
  return response.list || []
}
