<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from '@/i18n'
import { t } from '../../../../packages/localization/language'
import { updateTempleState, type TempleStateChange } from '@/api/temple'
import { canShelfTemple, templeAuthLabel, templeStateAvailable } from '@/utils/templeState'
import StatusTag from '@/components/StatusTag.vue'
import type { Temple } from '@/types'
const props = defineProps<{ temple: Temple; editable?: boolean }>()
const emit = defineEmits<{ updated: [] }>()
const busy = ref(false), error = ref(''), needsRefresh = ref(false)
const ready = computed(() => templeStateAvailable(props.temple))
watch(() => props.temple, () => { needsRefresh.value = false; error.value = '' })
type Action = 'platform' | 'shelf' | 'recommend'
async function change(action: Action) {
  if (!ready.value || busy.value || needsRefresh.value) return
  const current = props.temple
  const change: TempleStateChange = { version: current.stateVersion! }
  let message = ''
  if (action === 'platform') {
    change.platformStatus = current.platformStatus === 'banned' ? 'normal' : 'banned'
    message = change.platformStatus === 'banned' ? '封禁后寺院及所属工作身份不能访问后台，前台不可见；订单和资产保留。' : '解除封禁后保持下架，需核对认证后另行上架；旧会话不会恢复。'
  } else if (action === 'shelf') {
    change.shelfStatus = current.shelfStatus === 'on_shelf' ? 'off_shelf' : 'on_shelf'
    if (change.shelfStatus === 'on_shelf' && !canShelfTemple(current)) return
    message = change.shelfStatus === 'off_shelf' ? '下架后不再接受新的发现和预约，后台仍可处理已有订单。' : '上架后将在信众端展示，并按已启用服务接受新预约。'
  } else {
    change.recommended = !current.recommended
    message = change.recommended ? '设为推荐只调整展示推荐标记，不改变认证、上架或封禁状态。' : '取消推荐只移除推荐标记，其他状态不变。'
  }
  try {
    await ElMessageBox.confirm(t(message), t('寺院状态'), { type: 'warning' })
    busy.value = true; error.value = ''
    await updateTempleState(current.id, change)
    ElMessage.success(t('状态已更新')); emit('updated')
  } catch (cause) {
    if (cause !== 'cancel' && cause !== 'close') {
      error.value = cause instanceof Error ? cause.message : '状态更新失败，请刷新后重试'
      // Keep the previous state read-only until an authoritative refresh, including CAS conflicts.
      needsRefresh.value = true
    }
  } finally { busy.value = false }
}
</script>
<template>
  <div class="temple-state">
    <div class="temple-state__tags"><StatusTag :status="temple.authStatus" :label="templeAuthLabel(temple.authStatus)"/><StatusTag v-if="temple.shelfStatus" :status="temple.shelfStatus"/><StatusTag v-if="temple.platformStatus" :status="temple.platformStatus"/><el-tag v-if="temple.recommended" size="small">{{ $t('推荐') }}</el-tag></div>
    <template v-if="editable">
      <el-dropdown v-if="ready" :disabled="busy || needsRefresh" @command="change"><el-button link type="primary" :loading="busy" :disabled="needsRefresh">{{ $t('管理状态') }}</el-button><template #dropdown><el-dropdown-menu><el-dropdown-item command="shelf" :disabled="temple.shelfStatus !== 'on_shelf' && !canShelfTemple(temple)">{{ $t(temple.shelfStatus === 'on_shelf' ? '下架寺院' : '上架寺院') }}</el-dropdown-item><el-dropdown-item command="recommend">{{ $t(temple.recommended ? '取消推荐' : '设为推荐') }}</el-dropdown-item><el-dropdown-item command="platform" divided>{{ $t(temple.platformStatus === 'banned' ? '解除封禁' : '封禁寺院') }}</el-dropdown-item></el-dropdown-menu></template></el-dropdown>
      <span v-else class="temple-state__note">{{ $t('状态资料待同步，请刷新') }}</span>
    </template>
    <p v-if="error" role="alert" class="temple-state__note">{{ $t(error) }} <el-button link @click="emit('updated')">{{ $t('刷新状态') }}</el-button></p>
  </div>
</template>
<style scoped>
.temple-state,.temple-state__tags{display:flex;flex-wrap:wrap;gap:8px;align-items:center}.temple-state{row-gap:10px}.temple-state__note{font-size:var(--type-size-caption);color:var(--color-text-secondary);margin:0}
</style>
