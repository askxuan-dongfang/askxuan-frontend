<script setup lang="ts">
import AccountLogin from '../../../../packages/admin-ui/components/AccountLogin.vue'
import AppearanceSelector from '../../../../packages/admin-ui/components/AppearanceSelector.vue'
import BrandLogo from '../../../../packages/admin-ui/components/BrandLogo.vue'
import {onMounted} from 'vue'
import {ElMessage} from 'element-plus'
import {useRouter,useRoute} from 'vue-router'
import {useAuthStore} from '@/stores/auth'

const router=useRouter();const route=useRoute();const auth=useAuthStore()
onMounted(()=>{if(route.query.denied==='1')ElMessage.warning('该账号没有本管理台权限，请使用对应角色账号登录')})
async function login(account:string,password:string,proof:{captchaId:string;captchaCode:string}){await auth.login(account,password,proof)}
function complete(){const next=typeof route.query.redirect==='string'?route.query.redirect:'';router.replace(next.startsWith('/')&&!next.startsWith('//')&&!next.includes(String.fromCharCode(92))&&!next.startsWith('/login')?next:'/dashboard')}
</script>
<template>
  <div class="login-page">
    <AppearanceSelector class="ax-appearance-login" />
    <div class="login-bg"></div>
    <div class="login-card df-card">
      <div class="login-brand">
        <BrandLogo class="login-mark" identity="temple" label="问玄东方寺院管理台" />
        <div>
          <div class="login-title">问玄东方</div>
          <div class="login-sub">寺院管理台</div>
        </div>
      </div>
      <p class="login-desc">以虔诚之心，护寺院清誉 · 寺院数字化运营管理</p>

      <AccountLogin :login="login" @success="complete" />


    </div>
    <div class="login-footer">© 问玄东方 · 寺院管理台 P02</div>
  </div>
</template>
<style scoped>
.login-page {
  position: relative;
  min-height: 100dvh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow-x: hidden;
  background: var(--admin-bg);
}
.login-bg {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 20% 20%, rgba(var(--admin-primary-rgb),0.35), transparent 45%),
    radial-gradient(circle at 80% 70%, rgba(var(--admin-accent-rgb),0.25), transparent 45%),
    linear-gradient(135deg, var(--admin-bg) 0%, var(--admin-surface) 100%);
}
.login-bg::after {
  content: '禅';
  position: absolute;
  right: -40px;
  bottom: -80px;
  font-family: var(--font-serif);
  font-size: 360px;
  color: rgba(var(--admin-accent-rgb),0.06);
  font-weight: var(--type-weight-semibold);
  line-height: 1;
}
.login-card {
  position: relative;
  z-index: 1;
  width: min(400px, calc(100vw - 48px));
  box-sizing: border-box;
  margin: 40px 0;
  padding: 36px 32px 28px;
  border-radius: 16px;
}
.login-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}
.login-mark {
  width: 44px;
  height: 44px;
  flex-shrink: 0;
}
.login-title {
  font-family: var(--font-serif);
  font-size: var(--type-size-page);
  font-weight: var(--type-weight-semibold);
  color: var(--admin-text);
}
.login-sub {
  font-size: var(--type-size-label);
  color: var(--admin-text-secondary);
  margin-top: 2px;
}
.login-desc {
  font-size: var(--type-size-label);
  color: var(--admin-text-secondary);
  margin: 14px 0 24px;
}
.login-btn {
  width: 100%;
  margin-top: 6px;
  height: 44px;
  font-size: var(--type-size-control);
  letter-spacing: 4px;
}
.login-tip {
  margin-top: 18px;
  padding: 10px 12px;
  background: var(--admin-surface-muted);
  border: 1px dashed var(--admin-border-strong);
  border-radius: 8px;
  font-size: var(--type-size-caption);
  color: var(--admin-text-secondary);
  display: flex;
  align-items: center;
  gap: 6px;
}
.login-tip b {
  color: var(--admin-primary);
}
.login-footer {
  position: absolute;
  bottom: 20px;
  color: var(--admin-text-secondary);
  font-size: var(--type-size-caption);
  z-index: 1;
}
</style>
