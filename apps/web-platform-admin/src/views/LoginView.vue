<template>
  <div class="login">
    <AppearanceSelector class="ax-appearance-login" />
    <div class="login__bg">
      <div class="login__orb login__orb--1"></div>
      <div class="login__orb login__orb--2"></div>
      <div class="login__grid"></div>
    </div>

    <div class="login__panel dfx-card">
      <div class="login__brand">
        <img class="login__seal" :src="logoUrl" alt="问玄东方平台总管理台" />
        <h1 class="login__title dfx-serif">问玄东方</h1>
        <p class="login__subtitle">统一运营管理台 · 平台与商城</p>
      </div>

      <el-form ref="formRef" :model="form" :rules="rules" size="large" @submit.prevent="onSubmit">
        <el-form-item prop="account">
          <el-input v-model="form.account" placeholder="管理员账号" :prefix-icon="User" />
        </el-form-item>
        <el-form-item prop="password">
          <el-input v-model="form.password" type="password" show-password placeholder="登录密码" :prefix-icon="Lock" @keyup.enter="onSubmit" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" class="login__submit" :loading="loading" @click="onSubmit">登 录</el-button>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<script setup lang="ts">
import AppearanceSelector from '../../../../packages/admin-ui/components/AppearanceSelector.vue'
import { ref, reactive, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { User, Lock } from '@element-plus/icons-vue'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { defaultRoute } from '@/router/access'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const logoUrl = `${import.meta.env.BASE_URL}logos/logo-platform.png`

const formRef = ref<FormInstance>()
const loading = ref(false)
const form = reactive({ account: '', password: '' })

onMounted(() => {
  if (route.query.denied === '1') {
    ElMessage.warning('该账号没有本管理台权限，请使用对应角色账号登录')
  }
})

const rules: FormRules = {
  account: [{ required: true, message: '请输入账号', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

async function onSubmit() {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    loading.value = true
    try {
      await auth.login({ account: form.account, password: form.password })
      ElMessage.success('登录成功')
      const requested = typeof route.query.redirect === 'string' ? route.query.redirect : ''
      const redirect = requested.startsWith('/') && !requested.startsWith('//') ? requested : defaultRoute(auth.roles)
      router.push(redirect)
    } catch (e: any) {
      ElMessage.error(e?.message || '登录失败，请检查账号密码')
    } finally {
      loading.value = false
    }
  })
}
</script>

<style scoped>
.login {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100vh;
  overflow: hidden;
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
  width: 400px;
  padding: 44px 40px 36px;
  background: rgba(var(--admin-surface-rgb), 0.92);
  backdrop-filter: blur(12px);
  border: 1px solid var(--color-border-strong);
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
  border-radius: var(--radius-md);
  object-fit: cover;
  border: 1px solid var(--color-border-strong);
  box-shadow: 0 6px 20px rgba(var(--admin-primary-rgb), 0.2);
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
</style>
