import client from './client';
import type { BeliefProfile, IntentionTag } from '../types';

export async function getBeliefs(): Promise<BeliefProfile[]> {
  const response = await client.get('/beliefs') as unknown as { list: BeliefProfile[] };
  return response.list || [];
}

export async function getIntentionTags(): Promise<IntentionTag[]> {
  const response = await client.get('/intentions/tags') as unknown as { list: IntentionTag[] };
  return response.list || [];
}
