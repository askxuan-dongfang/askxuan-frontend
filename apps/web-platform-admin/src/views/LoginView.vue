<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import AccountLogin from '../../../../packages/admin-ui/components/AccountLogin.vue'
import AppearanceSelector from '../../../../packages/admin-ui/components/AppearanceSelector.vue'
import BrandLogo from '../../../../packages/admin-ui/components/BrandLogo.vue'
import {onMounted} from 'vue'

import {useRouter,useRoute} from 'vue-router'
import {useAuthStore} from '@/stores/auth'
import {defaultRoute} from '@/router/access'
const router=useRouter();const route=useRoute();const auth=useAuthStore()
onMounted(()=>{if(route.query.denied==='1')ElMessage.warning(uiText('该账号没有本管理台权限，请使用对应角色账号登录'))})
async function login(account:string,password:string,proof:{captchaId:string;captchaCode:string}){await auth.login({account,password,...proof})}
function complete(){const next=typeof route.query.redirect==='string'?route.query.redirect:'';router.replace(next.startsWith('/')&&!next.startsWith('//')&&!next.includes(String.fromCharCode(92))&&!next.startsWith('/login')?next:defaultRoute(auth.roles,auth.access))}
</script>
<template>
  <div class="login">
    <div class="login__bg">
      <div class="login__orb login__orb--1"></div>
      <div class="login__orb login__orb--2"></div>
      <div class="login__grid"></div>
    </div>

    <div class="login__panel dfx-card">
      <div class="login__brand">
        <BrandLogo class="login__seal" identity="platform" :label='$t("问玄东方统一运营管理台")' />
        <h1 class="login__title dfx-serif">{{ $t("问玄东方") }}</h1>
        <p class="login__subtitle">{{ $t("统一运营管理台 · 平台与商城") }}</p>
      </div>

      <AccountLogin :login="login" @success="complete" />
    </div>
    <footer class="login__preferences"><AppearanceSelector class="ax-appearance-login" /></footer>
  </div>
</template>
<style scoped>
.login {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24px;
  box-sizing: border-box;
  padding: max(40px, env(safe-area-inset-top, 0px)) max(24px, env(safe-area-inset-right, 0px)) calc(20px + env(safe-area-inset-bottom, 0px)) max(24px, env(safe-area-inset-left, 0px));
  min-height: 100dvh;
  overflow-x: hidden;
  background: var(--color-bg-primary);
}
.login__bg {
  position: absolute;
  inset: 0;
  z-index: 0;
}
.login__orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.35;
}
.login__orb--1 {
  width: 480px;
  height: 480px;
  background: var(--color-brand);
  top: -120px;
  left: -80px;
}
.login__orb--2 {
  width: 420px;
  height: 420px;
  background: var(--color-accent-dark);
  bottom: -100px;
  right: -60px;
}
.login__grid {
  position: absolute;
  inset: 0;
  background-image: linear-gradient(rgba(var(--admin-accent-rgb),0.04) 1px, transparent 1px),
    linear-gradient(90deg, rgba(var(--admin-accent-rgb),0.04) 1px, transparent 1px);
  background-size: 40px 40px;
}
.login__panel {
  position: relative;
  z-index: 1;
  width: min(400px, 100%);
  box-sizing: border-box;
  margin: auto 0;
  padding: 44px 40px 36px;
  background: rgba(var(--admin-surface-rgb), 0.92);
  backdrop-filter: blur(12px);
  border: 0;
  border-radius: var(--radius-xl);
  box-shadow: 0 20px 60px rgba(var(--admin-shadow-rgb), 0.16);
}
.login__brand {
  text-align: center;
  margin-bottom: 32px;
}
.login__seal {
  display: inline-block;
  width: 56px;
  height: 56px;
  margin-bottom: 16px;
}
.login__title {
  margin: 0;
  font-size: var(--type-size-hero);
  font-weight: var(--type-weight-semibold);
  color: var(--admin-text);
  letter-spacing: 4px;
}
.login__subtitle {
  margin: 6px 0 0;
  font-size: var(--type-size-label);
  color: var(--admin-text-secondary);
  letter-spacing: 2px;
}
.login__submit {
  width: 100%;
  height: 44px;
  font-size: var(--type-size-reading);
  letter-spacing: 6px;
  background: linear-gradient(135deg, var(--color-brand), var(--color-brand-dark));
  border: none;
}
.login__hint {
  margin: 0;
  text-align: center;
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
.login__preferences {
  position: relative;
  z-index: 1;
  width: min(400px, 100%);
}
</style>
