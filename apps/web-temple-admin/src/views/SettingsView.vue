<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { type FormInstance } from 'element-plus'
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
    ElMessage.warning(uiText('寺院编码与名称不能为空'))
    return
  }
  auth.setTemple(templeForm.templeId.trim(), templeForm.templeName.trim())
  ElMessage.success(uiText('寺院绑定已更新'))
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
    <PageHeader :title='$t("系统设置")' :subtitle='$t("寺院绑定与账号管理")' />

    <div class="settings-grid">
      <div class="df-card section">
        <div class="section-title">{{ $t("寺院绑定") }}</div>
        <p class="section-desc">{{ $t(" 管理台所属寺院编码与名称，用于法师与预约列表查询。登录响应未返回 templeId 时以此兜底。 ") }}</p>
        <el-form ref="templeFormRef" :model="templeForm" label-width="92px" class="set-form">
          <el-form-item :label='$t("寺院编码")'>
            <el-input v-model="templeForm.templeId" :placeholder='$t("如 T001")' />
          </el-form-item>
          <el-form-item :label='$t("寺院名称")'>
            <el-input v-model="templeForm.templeName" :placeholder='$t("如 灵隐寺")' />
          </el-form-item>
          <el-form-item>
            <el-button type="primary" :icon="Check" @click="saveTemple">{{ $t("保存绑定") }}</el-button>
          </el-form-item>
        </el-form>
      </div>

      <div class="df-card section">
        <div class="section-title">{{ $t("账号信息") }}</div>
        <el-descriptions :column="1" border>
          <el-descriptions-item :label='$t("账号昵称")'>{{ auth.userInfo?.nickname || '-' }}</el-descriptions-item>
          <el-descriptions-item :label='$t("手机号")'>{{ auth.userInfo?.mobile || '-' }}</el-descriptions-item>
          <el-descriptions-item :label='$t("用户ID")'>{{ $t((auth.userInfo?.userId ?? '-')) }}</el-descriptions-item>
          <el-descriptions-item :label='$t("当前寺院")'>{{ auth.templeName }}（{{ $t(auth.templeId) }}）</el-descriptions-item>
        </el-descriptions>
        <div class="account-actions">
          <el-button :icon="SwitchButton" type="danger" plain @click="handleLogout">{{ $t("退出登录") }}</el-button>
        </div>
      </div>

      <div class="df-card section danger-zone">
        <div class="section-title">{{ $t("缓存与维护") }}</div>
        <p class="section-desc">{{ $t("清除本地缓存（含登录态），刷新后需重新登录。") }}</p>
        <el-button :icon="Delete" type="warning" plain @click="clearCache">{{ $t("清除本地缓存") }}</el-button>
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
  font-family: var(--font-serif);
  font-size: var(--type-size-control);
  font-weight: var(--type-weight-semibold);
  color: var(--admin-text);
  margin-bottom: 8px;
}
.section-desc {
  font-size: var(--type-size-caption);
  color: var(--admin-text-secondary);
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
@media (max-width: 767px) {
  .settings-grid { grid-template-columns: minmax(0, 1fr); }
}
</style>
