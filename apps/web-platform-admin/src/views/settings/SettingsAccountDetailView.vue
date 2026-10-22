<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { Back, Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from '@/i18n'
import { t } from '../../../../../packages/localization/language'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getAdminAccountDetail, revokeAdminAccountSessions, updateAdminAccountStatus } from '@/api/auth'
import { isAdminSessionExpired } from '@/api/client'
import { accountScopeLabel, bindingRoute, credentialLabel, recoveryLabel } from '@/utils/accountIdentity'
import { formatDate } from '@/utils/format'
import type { AdminAccountDetail } from '@/types'

const route = useRoute()
const detail = ref<AdminAccountDetail | null>(null)
const loading = ref(false), saving = ref(false), error = ref('')
let loadVersion = 0
const accountId = computed(() => Number(route.params.id))
async function load() {
  const version = ++loadVersion
  loading.value = true; error.value = ''; detail.value = null
  try {
    if (!Number.isSafeInteger(accountId.value) || accountId.value <= 0) throw new Error('账号编号无效')
    const data = await getAdminAccountDetail(accountId.value)
    if (!data?.account || !data.identity || !Array.isArray(data.bindings) || !Array.isArray(data.blockedReasons)) throw new Error('账号详情数据结构不完整')
    if (version === loadVersion) detail.value = data
  } catch (cause) {
    if (version === loadVersion && !isAdminSessionExpired(cause)) error.value = cause instanceof Error ? cause.message : '账号详情加载失败'
  } finally { if (version === loadVersion) loading.value = false }
}
async function changeStatus() {
  const current = detail.value?.account
  if (!current) return
  const next = current.status === 'enabled' ? 'disabled' : 'enabled'
  try {
    await ElMessageBox.confirm(t(next === 'disabled' ? '停用后旧会话立即失效，业务资料和订单保留。' : '启用后仍需满足主体状态和激活条件，旧会话不会恢复。'), t('账号状态'), { type: 'warning' })
    saving.value = true
    await updateAdminAccountStatus(current.id, next)
    ElMessage.success(t('账号状态已更新')); await load()
  } catch (cause) {
    if (cause !== 'cancel' && cause !== 'close' && !isAdminSessionExpired(cause)) error.value = cause instanceof Error ? cause.message : '操作失败'
  } finally { saving.value = false }
}
async function revokeSessions() {
  const id = detail.value?.account.id
  if (!id) return
  try {
    await ElMessageBox.confirm(t('将使此账号所有已登录端退出。账号状态和密码不变，本人可重新登录。'), t('撤销全部会话'), { type: 'warning' })
    saving.value = true
    await revokeAdminAccountSessions(id)
    ElMessage.success(t('旧会话已撤销')); await load()
  } catch (cause) {
    if (cause !== 'cancel' && cause !== 'close' && !isAdminSessionExpired(cause)) error.value = cause instanceof Error ? cause.message : '操作失败'
  } finally { saving.value = false }
}
watch(() => route.params.id, load, { immediate: true })
</script>

<template>
  <div class="dfx-page">
    <PageHeader :title="$t('账号详情') + (detail ? ' · ' + detail.account.name : '')" :subtitle="$t('登录身份、业务归属与访问状态')">
      <template #actions><el-button :icon="Back" @click="$router.push('/settings/account')">{{ $t('账号列表') }}</el-button><el-button :icon="Refresh" :loading="loading" @click="load">{{ $t('刷新') }}</el-button></template>
    </PageHeader>
    <div v-if="error" class="ax-page-feedback is-error" role="alert"><div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t(error) }}</div><p>{{ $t('当前状态无法确认，请重新加载后操作。') }}</p></div><el-button :loading="loading" @click="load">{{ $t('重新加载') }}</el-button></div>
    <div v-loading="loading" class="account-detail">
      <template v-if="detail">
        <section class="dfx-card account-section">
          <div class="account-heading"><div><h2>{{ detail.account.name }}</h2><p>{{ detail.account.account }} · #{{ detail.account.id }}</p></div><StatusTag :status="detail.account.status" /></div>
          <dl class="account-grid"><div><dt>{{ $t('角色') }}</dt><dd>{{ $t(detail.account.roleName || detail.account.roleCode || '未设置') }}</dd></div><div><dt>{{ $t('权限范围') }}</dt><dd>{{ $t(accountScopeLabel(detail.account.authzScope)) }}</dd></div><div><dt>{{ $t('注册时间') }}</dt><dd>{{ formatDate(detail.account.createTime) }}</dd></div><div><dt>{{ $t('最近登录') }}</dt><dd>{{ detail.account.lastLoginTime ? formatDate(detail.account.lastLoginTime) : $t('尚未登录') }}</dd></div></dl>
          <div class="access-state" :class="{ 'is-blocked': !detail.loginAllowed }" role="status"><strong>{{ $t(detail.loginAllowed ? '允许登录' : '当前不可登录') }}</strong><ul v-if="detail.blockedReasons.length"><li v-for="reason in detail.blockedReasons" :key="reason">{{ $t(reason) }}</li></ul></div>
          <div class="account-actions"><el-button :type="detail.account.status === 'enabled' ? 'warning' : 'success'" :loading="saving" @click="changeStatus">{{ $t(detail.account.status === 'enabled' ? '停用账号' : '启用账号') }}</el-button><el-button :disabled="saving" @click="revokeSessions">{{ $t('撤销全部会话') }}</el-button><el-button @click="$router.push({ path: '/settings/account', query: { keyword: detail.account.account } })">{{ $t('编辑角色与归属') }}</el-button></div>
        </section>
        <section class="dfx-card account-section"><h2>{{ $t('认证与激活') }}</h2><dl class="account-grid"><div><dt>{{ $t('凭据状态') }}</dt><dd>{{ $t(credentialLabel(detail.identity)) }}</dd></div><div><dt>{{ $t('本人邮箱') }}</dt><dd>{{ detail.identity.email || $t('未绑定') }} <el-tag v-if="detail.identity.email" :type="detail.identity.emailVerified ? 'success' : 'info'" size="small">{{ $t(detail.identity.emailVerified ? '已验证' : '未验证') }}</el-tag></dd></div><div v-if="detail.identity.verifiedAt"><dt>{{ $t('验证时间') }}</dt><dd>{{ formatDate(detail.identity.verifiedAt) }}</dd></div><div v-if="detail.identity.invitationEmail"><dt>{{ $t('邀请邮箱') }}</dt><dd>{{ detail.identity.invitationEmail }}</dd></div><div v-if="detail.identity.activationStatus && detail.identity.activationStatus !== 'none'"><dt>{{ $t('激活状态') }}</dt><dd>{{ $t(({ pending: '待本人激活', activated: '已激活', revoked: '已停用' } as Record<string, string>)[detail.identity.activationStatus]) }}</dd></div></dl><p class="account-note">{{ $t(recoveryLabel(detail.identity)) }}</p></section>
        <section class="dfx-card account-section"><h2>{{ $t('业务身份关联') }}</h2><div v-if="!detail.bindings.length" class="account-note">{{ $t('此账号按平台角色工作，没有寺院、大师或商铺归属。') }}</div><article v-for="binding in detail.bindings" :key="binding.type + ':' + binding.id" class="binding-row"><div><strong>{{ binding.name || binding.id }}</strong><p>{{ $t(({temple:'寺院',master:'大师',shop:'商铺'} as Record<string,string>)[binding.type]) }} · {{ binding.id }}</p><div class="binding-states"><StatusTag v-if="!binding.authStatus && !binding.shelfStatus && !binding.platformStatus && binding.status" :status="binding.status"/><StatusTag v-if="binding.authStatus" :status="binding.authStatus"/><StatusTag v-if="binding.shelfStatus" :status="binding.shelfStatus"/><StatusTag v-if="binding.platformStatus" :status="binding.platformStatus"/></div></div><el-button v-if="bindingRoute(binding)" link type="primary" @click="$router.push(bindingRoute(binding)!)">{{ $t('查看主体') }}</el-button></article><p class="account-note">{{ $t('登录账号与业务主体分别管理；关联不合并其他身份的订单、余额或资产。') }}</p></section>
      </template>
    </div>
  </div>
</template>

<style scoped>
.account-detail{display:grid;gap:16px;min-height:120px}.account-section{padding:24px;min-width:0}.account-section h2{font-size:var(--type-size-section);margin:0 0 16px}.account-heading{display:flex;align-items:flex-start;justify-content:space-between;gap:16px}.account-heading p,.binding-row p{margin:6px 0 16px;color:var(--color-text-secondary);overflow-wrap:anywhere}.account-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;margin:16px 0 24px}.account-grid div{min-width:0}.account-grid dt{color:var(--color-text-tertiary);font-size:var(--type-size-caption);margin-bottom:8px}.account-grid dd{margin:0;overflow-wrap:anywhere}.account-actions,.binding-states{display:flex;flex-wrap:wrap;gap:10px}.account-actions{margin-top:20px}.account-actions :deep(.el-button+.el-button){margin-left:0}.access-state{padding:14px 16px;background:var(--color-bg-tertiary);border-radius:var(--radius-sm);color:var(--color-text-primary)}.access-state.is-blocked{border-left:3px solid var(--color-accent)}.access-state ul{margin:8px 0 0;padding-left:20px}.account-note{color:var(--color-text-secondary);line-height:1.8;margin-bottom:0}.binding-row{display:flex;justify-content:space-between;align-items:flex-start;gap:20px;padding:16px 0;border-bottom:1px solid var(--color-border-divider)}@media(max-width:767px){.account-section{padding:18px}.account-grid{grid-template-columns:minmax(0,1fr)}.account-heading{flex-wrap:wrap}.account-actions{align-items:stretch}.account-actions :deep(.el-button){flex:1 1 auto}}
</style>
