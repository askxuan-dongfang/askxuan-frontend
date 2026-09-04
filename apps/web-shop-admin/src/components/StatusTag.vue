<script setup lang="ts">
import { getStatusMeta, type StatusDomain, type StatusTone } from '@askxuan/domain-status'

type LegacyKind = 'booking' | 'service' | 'review' | 'master' | 'temple' | 'blessing'
type AdminStatusDomain = StatusDomain | 'enabled'

const props = withDefaults(
  defineProps<{
    status?: string
    domain?: AdminStatusDomain
    kind?: LegacyKind
    label?: string
    effect?: 'light' | 'dark' | 'plain'
  }>(),
  { status: '', domain: 'generic', effect: 'light' }
)

const legacyDomains: Record<LegacyKind, StatusDomain> = {
  booking: 'booking',
  service: 'service',
  review: 'review',
  master: 'masterAuth',
  temple: 'temple',
  blessing: 'blessing'
}

function resolvedDomain(): StatusDomain {
  if (props.kind) return legacyDomains[props.kind]
  return props.domain === 'enabled' ? 'generic' : props.domain
}

function resolvedLabel(): string {
  return props.label || getStatusMeta(resolvedDomain(), props.status).label
}

function resolvedTone(): StatusTone {
  return props.label ? 'primary' : getStatusMeta(resolvedDomain(), props.status).tone
}
</script>

<template>
  <el-tag :type="resolvedTone()" :effect="effect" size="small" class="aui-status-tag" round>
    {{ resolvedLabel() }}
  </el-tag>
</template>

<style scoped>
.aui-status-tag {
  max-width: 100%;
  border-width: 1px;
  font-weight: 600;
  white-space: nowrap;
}
</style>
