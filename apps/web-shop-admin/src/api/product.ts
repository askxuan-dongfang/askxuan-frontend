// 商品接口（含 SKU、上下架）
// 后端定义：services/commerce/product-service/api/product.api
//   prefix: /api/v1/admin/products （网关路由到 product-service:8086）
import client from './client'
import type { Page, Product, ProductStatus } from '@/types'

export interface ProductListParams {
  categoryId?: number
  keyword?: string
  status?: ProductStatus | string
  page?: number
  size?: number
}

export interface ProductSaveParams {
  name: string
  categoryId: number
  description?: string
  mainImage: string
  price: number
  marketPrice?: number
  stock: number
  tags?: string
  freightTemplateId?: number
}

export const productApi = {
  /** 商品列表 */
  list(params: ProductListParams = {}): Promise<Page<Product>> {
    return client.get<Page<Product>>('/admin/products', { params })
  },
  /** 商品详情 */
  detail(id: number): Promise<Product> {
    return client.get<Product>(`/admin/products/${id}`)
  },
  /** 创建商品 */
  create(data: ProductSaveParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/products', data)
  },
  /** 更新商品 */
  update(id: number, data: ProductSaveParams): Promise<Product> {
    return client.put<Product>(`/admin/products/${id}`, data)
  },
  /** 删除商品 */
  remove(id: number): Promise<void> {
    return client.delete<void>(`/admin/products/${id}`)
  },
  /** 上下架 */
  updateStatus(id: number, status: 'on_shelf' | 'off_shelf'): Promise<{ id: number; status: string }> {
    return client.put(`/admin/products/${id}/status`, { status })
  }
}
