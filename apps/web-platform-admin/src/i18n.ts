import { shallowRef, type App } from 'vue'
import { ElMessage as message, ElMessageBox as messageBox } from 'element-plus'
import { localizedMessage, localizedMessageBox } from '../../../packages/admin-ui/localized-feedback'
import { initLanguage, subscribeLanguage, t, getLanguage } from '../../../packages/localization/language'
export const appLanguage = shallowRef(getLanguage())
export const ElMessage = localizedMessage(message)
export const ElMessageBox = localizedMessageBox(messageBox)
export function installLanguage(app: App) {
  initLanguage()
  subscribeLanguage(() => { appLanguage.value = getLanguage() })
  app.config.globalProperties.$t = <T>(value: T): T => { appLanguage.value; return t(value) }
}
declare module 'vue' { interface ComponentCustomProperties { $t: typeof t } }
