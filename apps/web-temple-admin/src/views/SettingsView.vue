<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'
import { ElMessageBox } from '@/i18n'
import { t } from '../../../../packages/localization/language'
const auth = useAuthStore(), router = useRouter()
async function logout() {
  try {
    await ElMessageBox.confirm(t('确定退出当前寺院账号？'), t('退出登录'), { type: 'warning' })
    auth.logout()
    await router.replace('/login')
  } catch { /* cancelled */ }
}
</script>
<template>
  <div class="df-page">
    <PageHeader :title="$t('机构与账号')" :subtitle="$t('机构归属由平台审核与工作账号授权确定')" />
    <div class="df-card settings-card">
      <h2>{{ $t('当前机构') }}</h2>
      <el-descriptions :column="1" border>
        <el-descriptions-item :label="$t('寺院名称')">{{ auth.templeName }}</el-descriptions-item>
        <el-descriptions-item :label="$t('寺院编码')">{{ auth.templeId }}</el-descriptions-item>
        <el-descriptions-item :label="$t('归属来源')">{{ $t('已验证的服务端工作账号') }}</el-descriptions-item>
      </el-descriptions>
      <p>{{ $t('如需变更机构归属，请由平台管理员在工作账号管理中处理。此处显示当前授权结果。') }}</p>
    </div>
    <div class="df-card settings-card">
      <h2>{{ $t('当前账号') }}</h2>
      <el-descriptions :column="1" border>
        <el-descriptions-item :label="$t('姓名')">{{ auth.userInfo?.nickname || '—' }}</el-descriptions-item>
        <el-descriptions-item :label="$t('登录账号')">{{ auth.userInfo?.mobile || '—' }}</el-descriptions-item>
      </el-descriptions>
      <el-button type="danger" plain @click="logout">{{ $t('退出登录') }}</el-button>
    </div>
  </div>
</template>
<style scoped>
.settings-card{padding:24px;margin-bottom:20px;max-width:800px}.settings-card h2{font-size:18px;margin:0 0 16px}.settings-card p{line-height:1.8;color:var(--el-text-color-secondary)}
</style>
