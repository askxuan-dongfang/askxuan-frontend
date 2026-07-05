<script setup lang="ts">
// 商城运营登录页 - 禅意暗色背景 + 居中玻璃态卡片
import { reactive, ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { User, Lock } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()

const formRef = ref<FormInstance>()
const loading = ref(false)
const form = reactive({
  account: 'admin',
  password: '123456',
  remember: true
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
        <div class="login-symbol">卍</div>
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

        <div class="login-options">
          <el-checkbox v-model="form.remember">记住登录</el-checkbox>
          <a href="#">忘记密码？</a>
        </div>

        <div class="login-tip">默认账号：admin / 123456</div>
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
  background: linear-gradient(135deg, #1c1210 0%, #2a1e1a 40%, #3d2b24 70%, #1c1210 100%);
  position: relative;
  overflow: hidden;
}
.login-page::before {
  content: '';
  position: absolute;
  inset: -50%;
  background: radial-gradient(ellipse at 30% 20%, rgba(200, 169, 110, 0.08) 0%, transparent 50%),
    radial-gradient(ellipse at 70% 80%, rgba(196, 90, 60, 0.06) 0%, transparent 50%);
  animation: loginBgMove 20s ease-in-out infinite alternate;
}
@keyframes loginBgMove {
  0% { transform: translate(0, 0) rotate(0deg); }
  100% { transform: translate(-2%, -1%) rotate(1deg); }
}

/* 装饰圆环 */
.login-decoration {
  position: absolute;
  border: 1px solid rgba(200, 169, 110, 0.08);
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
  background: rgba(255, 255, 255, 0.03);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(200, 169, 110, 0.2);
  border-radius: 16px;
  padding: 48px 40px;
  z-index: 1;
}

.login-logo {
  text-align: center;
  margin-bottom: 36px;
}
.login-symbol {
  font-size: 36px;
  color: var(--accent);
  margin-bottom: 8px;
  opacity: 0.8;
}
.login-logo h1 {
  font-family: 'Noto Serif SC', serif;
  font-size: 28px;
  color: var(--accent);
  letter-spacing: 6px;
  margin: 0 0 8px;
}
.login-logo p {
  font-size: 14px;
  color: var(--sidebar-text);
  letter-spacing: 3px;
  opacity: 0.6;
  margin: 0;
}

/* 表单暗色适配 */
.login-form :deep(.el-input__wrapper) {
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(197, 176, 151, 0.2);
  box-shadow: none;
}
.login-form :deep(.el-input__wrapper:hover) {
  border-color: rgba(200, 169, 110, 0.4);
}
.login-form :deep(.el-input__wrapper.is-focus) {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px rgba(200, 169, 110, 0.1) !important;
}
.login-form :deep(.el-input__inner) {
  color: #e8e0d8;
}
.login-form :deep(.el-input__inner::placeholder) {
  color: rgba(197, 176, 151, 0.4);
}
.login-form :deep(.el-input__prefix-inner) {
  color: rgba(197, 176, 151, 0.5);
}

/* 登录按钮 - 朱砂红渐变 */
.login-btn {
  width: 100%;
  height: 48px;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 4px;
  background: linear-gradient(135deg, var(--primary) 0%, #d47a5e 100%);
  border: none;
  border-radius: 8px;
  margin-top: 8px;
}
.login-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 20px rgba(196, 90, 60, 0.4);
}

.login-options {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 16px;
}
.login-options :deep(.el-checkbox__label) {
  color: var(--sidebar-text);
  opacity: 0.7;
  font-size: 13px;
}
.login-options :deep(.el-checkbox__inner) {
  background: transparent;
  border-color: rgba(197, 176, 151, 0.4);
}
.login-options :deep(.el-checkbox__input.is-checked .el-checkbox__inner) {
  background: var(--accent);
  border-color: var(--accent);
}
.login-options a {
  color: var(--sidebar-text);
  opacity: 0.7;
  font-size: 13px;
}
.login-options a:hover {
  opacity: 1;
  color: var(--accent);
}

.login-tip {
  margin-top: 16px;
  font-size: 12px;
  color: rgba(200, 169, 110, 0.5);
  text-align: center;
}
</style>
