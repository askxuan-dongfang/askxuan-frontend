import client from './client'

export interface AiReportProduct {
  code: string
  title: string
  subtitle: string
  priceCents: number
  revision: number
  enabled: boolean
  version: string
}

export const aiProductsApi = {
  list: () => client.get<AiReportProduct[]>('/ai/admin/products'),
  updatePrice: (code: string, priceCents: number, revision: number) =>
    client.put<AiReportProduct>(`/ai/admin/products/${encodeURIComponent(code)}`, { priceCents, revision }),
}
