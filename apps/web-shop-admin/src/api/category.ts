// 商品分类接口
// 后端定义：services/commerce/product-service/api/product.api
//   prefix: /api/v1/admin/products/categories
import client from './client'
import type { Page, ProductCategory } from '@/types'

export interface CategoryListParams {
  parentId?: number
  page?: number
  size?: number
}

export interface CategorySaveParams {
  parentId: number
  name: string
  level: number
  sort?: number
}

export const categoryApi = {
  /** 分类列表（可按 parentId 过滤） */
  list(params: CategoryListParams = {}): Promise<Page<ProductCategory>> {
    return client.get<Page<ProductCategory>>('/admin/products/categories', { params })
  },
  /** 创建分类 */
  create(data: CategorySaveParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/products/categories', data)
  },
  /** 更新分类 */
  update(id: number, data: CategorySaveParams): Promise<ProductCategory> {
    return client.put<ProductCategory>(`/admin/products/categories/${id}`, data)
  },
  /** 删除分类 */
  remove(id: number): Promise<void> {
    return client.delete<void>(`/admin/products/categories/${id}`)
  }
}
