import client from './client';
import type { BeliefProfile, IntentionTag, ServiceCatalogItem } from '../types';

export async function getBeliefs(): Promise<BeliefProfile[]> {
  const response = await client.get('/beliefs') as unknown as { list: BeliefProfile[] };
  return response.list || [];
}

export async function getIntentionTags(): Promise<IntentionTag[]> {
  const response = await client.get('/intentions/tags') as unknown as { list: IntentionTag[] };
  return response.list || [];
}

export async function getServiceTypes(): Promise<ServiceCatalogItem[]> {
  const response = await client.get('/service-types') as unknown as { list: ServiceCatalogItem[] };
  return response.list || [];
}
