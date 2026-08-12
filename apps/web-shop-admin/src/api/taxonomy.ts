import client from './client'

export interface IntentionOption { code: string; name: string; description: string; icon: string; sort: number }

export async function listIntentions(): Promise<IntentionOption[]> {
  const response = await client.get<{ list: IntentionOption[] }>('/intentions/tags')
  return response.list || []
}
