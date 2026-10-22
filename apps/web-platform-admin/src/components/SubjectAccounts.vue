<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { getAdminAccounts } from '@/api/auth'
import type { AdminAccount } from '@/types'
const props = defineProps<{ kind: 'temple' | 'master'; id: string }>()
const auth = useAuthStore()
const permitted = computed(() => auth.roles.includes('platform_super'))
const accounts = ref<AdminAccount[]>([]), loading = ref(false), error = ref(false), total = ref(0)
const filter = computed(() => props.kind === 'temple' ? { templeId: props.id } : { masterId: props.id })
let generation = 0
async function load() {
  const version = ++generation
  accounts.value = []; total.value = 0; error.value = false
  if (!permitted.value || !props.id) return
  loading.value = true
  try {
    const response = await getAdminAccounts({ ...filter.value, page: 1, size: 20 })
    if (generation === version) { accounts.value = response.list; total.value = response.total }
  } catch { if (generation === version) error.value = true }
  finally { if (generation === version) loading.value = false }
}
watch(() => [props.id, props.kind, permitted.value], load, { immediate: true })
</script>
<template>
  <section v-if="permitted" class="dfx-card subject-accounts" v-loading="loading">
    <div class="subject-heading"><h2>{{ $t('关联工作账号') }}</h2><el-button link type="primary" @click="$router.push({ path: '/settings/account', query: filter })">{{ $t('管理关联账号') }}</el-button></div>
    <div v-if="error" role="alert">{{ $t('关联账号加载失败，不能确认当前是否已有账号。') }} <el-button link @click="load">{{ $t('重新加载') }}</el-button></div>
    <p v-else-if="!loading && !accounts.length">{{ $t('当前没有关联工作账号。业务资料可独立存在，创建档案不会自动生成登录账号。') }}</p>
    <div v-for="account in accounts" :key="account.id" class="subject-account"><div><strong>{{ account.name }}</strong><p>{{ account.account }} · {{ $t(account.roleName || '') }} · {{ $t(account.status === 'enabled' ? '已启用' : '已停用') }}</p></div><el-button link type="primary" @click="$router.push('/settings/accounts/' + account.id)">{{ $t('账号详情') }}</el-button></div>
    <p v-if="total > accounts.length">{{ $t('更多账号请进入账号管理查看。') }}</p>
  </section>
</template>
<style scoped>
.subject-accounts{padding:24px}.subject-heading,.subject-account{display:flex;align-items:flex-start;justify-content:space-between;gap:16px}.subject-heading h2{margin:0 0 16px;font-size:var(--type-size-section)}.subject-account{padding:14px 0;border-bottom:1px solid var(--color-border-divider)}.subject-account p,.subject-accounts>p{color:var(--color-text-secondary);line-height:1.7;margin:6px 0;overflow-wrap:anywhere}@media(max-width:767px){.subject-accounts{padding:18px}.subject-heading{flex-wrap:wrap}}
</style>
