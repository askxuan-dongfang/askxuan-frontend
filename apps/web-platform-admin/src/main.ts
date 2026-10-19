import { appLanguage, installLanguage } from './i18n'
import { initOverlayViewport } from '../../../packages/admin-ui/overlay-viewport'
import { initAdminTheme } from '../../../packages/admin-ui/theme'
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import zhCn from 'element-plus/es/locale/lang/zh-cn'
import zhTw from 'element-plus/es/locale/lang/zh-tw'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import App from './App.vue'
import router from './router'
import './styles/index.css'

initAdminTheme()
initOverlayViewport()

const app = createApp(App)
installLanguage(app)

// 注册 Element Plus 图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component)
}

app.use(createPinia())
app.use(router)
app.use(ElementPlus, { size: 'default', get locale() { return appLanguage.value === 'zh-Hant' ? zhTw : zhCn } })

app.mount('#app')
