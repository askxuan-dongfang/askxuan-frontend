<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox, type FormInstance } from 'element-plus'
import { Check, SwitchButton, Delete } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

const templeFormRef = ref<FormInstance>()
const templeForm = reactive({
  templeId: auth.templeId,
  templeName: auth.templeName
})

function saveTemple() {
  if (!templeForm.templeId.trim() || !templeForm.templeName.trim()) {
    ElMessage.warning('寺院编码与名称不能为空')
    return
  }
  auth.setTemple(templeForm.templeId.trim(), templeForm.templeName.trim())
  ElMessage.success('寺院绑定已更新')
}

function handleLogout() {
  ElMessageBox.confirm('确定退出登录？', '提示', { type: 'warning' })
    .then(() => {
      auth.logout()
      router.replace('/login')
    })
    .catch(() => {})
}

function clearCache() {
  ElMessageBox.confirm('将清除本地缓存并刷新页面，确定？', '清除缓存', { type: 'warning' })
    .then(() => {
      localStorage.clear()
      window.location.reload()
    })
    .catch(() => {})
}
</script>

<template>
  <div class="df-page">
    <PageHeader title="系统设置" subtitle="寺院绑定与账号管理" />

    <div class="settings-grid">
      <div class="df-card section">
        <div class="section-title">寺院绑定</div>
        <p class="section-desc">
          管理台所属寺院编码与名称，用于法师与预约列表查询。登录响应未返回 templeId 时以此兜底。
        </p>
        <el-form ref="templeFormRef" :model="templeForm" label-width="92px" class="set-form">
          <el-form-item label="寺院编码">
            <el-input v-model="templeForm.templeId" placeholder="如 T001" />
          </el-form-item>
          <el-form-item label="寺院名称">
            <el-input v-model="templeForm.templeName" placeholder="如 灵隐寺" />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" :icon="Check" @click="saveTemple">保存绑定</el-button>
          </el-form-item>
        </el-form>
      </div>

      <div class="df-card section">
        <div class="section-title">账号信息</div>
        <el-descriptions :column="1" border>
          <el-descriptions-item label="账号昵称">{{ auth.userInfo?.nickname || '-' }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ auth.userInfo?.mobile || '-' }}</el-descriptions-item>
          <el-descriptions-item label="用户ID">{{ auth.userInfo?.userId ?? '-' }}</el-descriptions-item>
          <el-descriptions-item label="当前寺院">{{ auth.templeName }}（{{ auth.templeId }}）</el-descriptions-item>
        </el-descriptions>
        <div class="account-actions">
          <el-button :icon="SwitchButton" type="danger" plain @click="handleLogout">退出登录</el-button>
        </div>
      </div>

      <div class="df-card section danger-zone">
        <div class="section-title">缓存与维护</div>
        <p class="section-desc">清除本地缓存（含登录态），刷新后需重新登录。</p>
        <el-button :icon="Delete" type="warning" plain @click="clearCache">清除本地缓存</el-button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.settings-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  align-items: start;
}
.section {
  padding: 20px 22px;
}
.section-title {
  font-family: 'Noto Serif SC', serif;
  font-size: 15px;
  font-weight: 600;
  color: #2a1e1a;
  margin-bottom: 8px;
}
.section-desc {
  font-size: 12px;
  color: #8a7a6a;
  margin: 0 0 16px;
  line-height: 1.6;
}
.set-form {
  max-width: 420px;
}
.account-actions {
  margin-top: 18px;
}
.danger-zone {
  grid-column: 1 / -1;
}
</style>
