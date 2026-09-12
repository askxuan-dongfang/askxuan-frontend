<script setup lang="ts">
// 商城运营登录页 - 禅意暗色背景 + 居中玻璃态卡片
import { reactive, ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()
const logoUrl = `${import.meta.env.BASE_URL}logos/logo-shop.png`

const formRef = ref<FormInstance>()
const loading = ref(false)
const form = reactive({
  account: '',
  password: ''
})

onMounted(() => {
  if (route.query.denied === '1') {
    ElMessage.warning('该账号没有本管理台权限，请使用对应角色账号登录')
  }
})

const rules: FormRules = {
  account: [{ required: true, message: '请输入账号', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
}

async function handleLogin() {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    loading.value = true
    try {
      await auth.login({ account: form.account, password: form.password })
      ElMessage.success('登录成功')
      const redirect = (route.query.redirect as string) || '/dashboard'
      router.push(redirect)
    } catch {
      // 错误已由拦截器提示
    } finally {
      loading.value = false
    }
  })
}
</script>

<template>
  <div class="login-page">
    <!-- 装饰圆环 -->
    <div class="login-decoration login-decoration-1"></div>
    <div class="login-decoration login-decoration-2"></div>
    <div class="login-decoration login-decoration-3"></div>

    <div class="login-card">
      <div class="login-logo">
        <img class="login-symbol" :src="logoUrl" alt="问玄东方商城管理台" />
        <h1>问玄东方</h1>
        <p>商城管理台</p>
      </div>

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        class="login-form"
        @submit.prevent="handleLogin"
      >
        <el-form-item prop="account">
          <el-input
            v-model="form.account"
            placeholder="请输入账号"
            size="large"
            :prefix-icon="User"
          />
        </el-form-item>

        <el-form-item prop="password">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            size="large"
            show-password
            :prefix-icon="Lock"
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-button
          type="primary"
          size="large"
          class="login-btn"
          :loading="loading"
          @click="handleLogin"
        >
          登 录
        </el-button>

      </el-form>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, var(--admin-bg) 0%, var(--admin-surface) 40%, var(--admin-surface-hover) 70%, var(--admin-bg) 100%);
  position: relative;
  overflow: hidden;
}
.login-page::before {
  content: '';
  position: absolute;
  inset: -50%;
  background: radial-gradient(ellipse at 30% 20%, rgba(var(--admin-accent-rgb),0.08) 0%, transparent 50%),
    radial-gradient(ellipse at 70% 80%, rgba(var(--admin-primary-rgb),0.06) 0%, transparent 50%);
  animation: loginBgMove 20s ease-in-out infinite alternate;
}
@keyframes loginBgMove {
  0% { transform: translate(0, 0) rotate(0deg); }
  100% { transform: translate(-2%, -1%) rotate(1deg); }
}

/* 装饰圆环 */
.login-decoration {
  position: absolute;
  border: 1px solid rgba(var(--admin-accent-rgb),0.08);
  border-radius: 50%;
  z-index: 0;
}
.login-decoration-1 { top: 10%; left: 5%; width: 200px; height: 200px; }
.login-decoration-2 { bottom: 15%; right: 8%; width: 300px; height: 300px; }
.login-decoration-3 { top: 60%; left: 15%; width: 100px; height: 100px; }

/* 登录卡片 - 玻璃态 */
.login-card {
  position: relative;
  width: 100%;
  max-width: 400px;
  background: rgba(var(--admin-surface-rgb), 0.92);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(var(--admin-accent-rgb),0.2);
  border-radius: 16px;
  padding: 48px 40px;
  z-index: 1;
}

.login-logo {
  text-align: center;
  margin-bottom: 36px;
}
.login-symbol {
  width: 64px;
  height: 64px;
  border-radius: 12px;
  object-fit: cover;
  border: 1px solid rgba(var(--admin-accent-rgb),0.28);
  margin: 0 auto 12px;
  display: block;
}
.login-logo h1 {
  font-family: var(--font-serif);
  font-size: var(--type-size-hero);
  color: var(--admin-accent);
  letter-spacing: 6px;
  margin: 0 0 8px;
}
.login-logo p {
  font-size: var(--type-size-body);
  color: var(--admin-accent);
  letter-spacing: 3px;
  margin: 0;
}

/* 表单外观 */
.login-form :deep(.el-input__wrapper) {
  background: var(--admin-surface-muted);
  border: 1px solid var(--admin-border);
  box-shadow: none;
}
.login-form :deep(.el-input__wrapper:hover) {
  border-color: rgba(var(--admin-accent-rgb),0.4);
}
.login-form :deep(.el-input__wrapper.is-focus) {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(var(--admin-accent-rgb),0.1) !important;
}
.login-form :deep(.el-input__inner) {
  color: var(--admin-accent);
}
.login-form :deep(.el-input__inner::placeholder) {
  color: var(--admin-text-secondary);
}
.login-form :deep(.el-input__prefix-inner) {
  color: var(--admin-text-secondary);
}

/* 登录按钮 - 品牌渐变 */
.login-btn {
  width: 100%;
  height: 48px;
  font-size: var(--type-size-reading);
  font-weight: var(--type-weight-semibold);
  letter-spacing: 4px;
  background: linear-gradient(135deg, var(--admin-primary) 0%, var(--admin-primary-hover) 100%);
  border: none;
  border-radius: 8px;
  margin-top: 8px;
}
.login-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 20px rgba(var(--admin-primary-rgb),0.4);
}

</style>
