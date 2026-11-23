import { ElMessage } from '@/i18n'
import client, { isAdminSessionExpired } from './client'
import { createCatalogTranslationApi } from '../../../../packages/admin-ui/catalog-translations'

export const catalogTranslations = createCatalogTranslationApi(client, error => {
  if (!isAdminSessionExpired(error)) ElMessage.warning({ message: '中文已保存，英文排队失败。请打开英文管理重试。', grouping: true })
})
