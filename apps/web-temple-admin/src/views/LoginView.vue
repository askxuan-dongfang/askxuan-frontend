<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { User, Lock, InfoFilled } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const route = useRoute()
const auth = useAuthStore()

const formRef = ref<FormInstance>()
const loading = ref(false)
const form = reactive({ account: 'lingyin_admin', password: '123456' })

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
      await auth.login(form.account, form.password)
      ElMessage.success('登录成功')
      const redirect = (route.query.redirect as string) || '/dashboard'
      router.replace(redirect)
    } catch {
      // 错误提示已由 axios 拦截器统一处理
    } finally {
      loading.value = false
    }
  })
}
</script>

<template>
  <div class="login-page">
    <div class="login-bg"></div>
    <div class="login-card df-card">
      <div class="login-brand">
        <div class="login-mark">寺</div>
        <div>
          <div class="login-title">问玄东方</div>
          <div class="login-sub">寺院管理台</div>
        </div>
      </div>
      <p class="login-desc">以虔诚之心，护寺院清誉 · 寺院数字化运营管理</p>

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        size="large"
        label-position="top"
        @keyup.enter="handleLogin"
      >
        <el-form-item label="管理员账号" prop="account">
          <el-input v-model="form.account" placeholder="请输入账号" clearable>
            <template #prefix><el-icon><User /></el-icon></template>
          </el-input>
        </el-form-item>
        <el-form-item label="密码" prop="password">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            show-password
            clearable
          >
            <template #prefix><el-icon><Lock /></el-icon></template>
          </el-input>
        </el-form-item>
        <el-button
          type="primary"
          class="login-btn"
          :loading="loading"
          @click="handleLogin"
        >
          登 录
        </el-button>
      </el-form>

      <div class="login-tip">
        <el-icon><InfoFilled /></el-icon>
        演示账号：<b>lingyin_admin</b> / 密码：<b>123456</b>
      </div>
    </div>
    <div class="login-footer">© 问玄东方 · 寺院管理台 P02</div>
  </div>
</template>

<style scoped>
.login-page {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background: #1c1210;
}
.login-bg {
  position: absolute;
  inset: 0;
  background:
    radial-gradient(circle at 20% 20%, rgba(196, 90, 60, 0.35), transparent 45%),
    radial-gradient(circle at 80% 70%, rgba(200, 169, 110, 0.25), transparent 45%),
    linear-gradient(135deg, #1c1210 0%, #2a1e1a 100%);
}
.login-bg::after {
  content: '禅';
  position: absolute;
  right: -40px;
  bottom: -80px;
  font-family: 'Noto Serif SC', serif;
  font-size: 360px;
  color: rgba(200, 169, 110, 0.06);
  font-weight: 700;
  line-height: 1;
}
.login-card {
  position: relative;
  z-index: 1;
  width: 400px;
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
  border-radius: 10px;
  background: linear-gradient(135deg, #c45a3c 0%, #c8a96e 100%);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: 'Noto Serif SC', serif;
  font-weight: 700;
  font-size: 22px;
}
.login-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 22px;
  font-weight: 700;
  color: #2a1e1a;
}
.login-sub {
  font-size: 13px;
  color: #8a7a6a;
  margin-top: 2px;
}
.login-desc {
  font-size: 13px;
  color: #6a5a4a;
  margin: 14px 0 24px;
}
.login-btn {
  width: 100%;
  margin-top: 6px;
  height: 44px;
  font-size: 15px;
  letter-spacing: 4px;
}
.login-tip {
  margin-top: 18px;
  padding: 10px 12px;
  background: #faf6f0;
  border: 1px dashed #e8d5b8;
  border-radius: 8px;
  font-size: 12px;
  color: #8a7a6a;
  display: flex;
  align-items: center;
  gap: 6px;
}
.login-tip b {
  color: #c45a3c;
}
.login-footer {
  position: absolute;
  bottom: 20px;
  color: rgba(240, 230, 218, 0.4);
  font-size: 12px;
  z-index: 1;
}
</style>
