export type CatalogKind = 'shop-product' | 'points-product' | 'reward-campaign' | 'reward-prize' | 'diy-material' | 'diy-design' | 'temple' | 'master' | 'temple-service' | 'belief'

export interface CatalogTranslation {
  revision: string
  status: 'missing' | 'queued' | 'translating' | 'review' | 'published' | 'failed'
  source: Record<string, string>
  fields: Record<string, string>
  reviewRequired: boolean
  publicEligible?: boolean
}

interface RequestOptions { suppressErrorMessage: boolean }
interface CatalogTranslationClient {
  get<T>(url: string, options: RequestOptions): Promise<T>
  post<T>(url: string, data: undefined, options: RequestOptions): Promise<T>
  put<T>(url: string, data: unknown, options: RequestOptions): Promise<T>
}

export function createCatalogTranslationApi(client: CatalogTranslationClient, onQueueError: (error: unknown) => void) {
  const options = { suppressErrorMessage: true }
  const path = (kind: CatalogKind, id: string | number) => `/ai/admin/catalog-translations/${kind}/${encodeURIComponent(String(id))}`
  const queue = (kind: CatalogKind, id: string | number) => client.post<CatalogTranslation>(path(kind, id), undefined, options)
  return {
    read: (kind: CatalogKind, id: string | number) => client.get<CatalogTranslation>(path(kind, id), options),
    queue,
    save: (kind: CatalogKind, id: string | number, revision: string, fields: Record<string, string>, publish: boolean) =>
      client.put<CatalogTranslation>(path(kind, id), { revision, fields, publish }, options),
    queueAfterSave(kind: CatalogKind, id: string | number) {
      void queue(kind, id).catch(onQueueError)
    }
  }
}

export type CatalogTranslationApi = ReturnType<typeof createCatalogTranslationApi>
