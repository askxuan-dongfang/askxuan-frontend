<script setup lang="ts">
// 通用状态标签：将 snake_case 状态码映射为中文 + Element Plus Tag 类型
import { computed } from 'vue'
import {
  productStatusLabel,
  productStatusType,
  orderStatusLabel,
  orderStatusType,
  returnStatusLabel,
  returnStatusType,
  enabledLabel
} from '@/utils/format'

type Domain = 'product' | 'order' | 'return' | 'enabled'

const props = withDefaults(
  defineProps<{
    status: string
    domain?: Domain
  }>(),
  { domain: 'order' }
)

const label = computed(() => {
  switch (props.domain) {
    case 'product':
      return productStatusLabel(props.status)
    case 'order':
      return orderStatusLabel(props.status)
    case 'return':
      return returnStatusLabel(props.status)
    case 'enabled':
      return enabledLabel(props.status)
    default:
      return props.status
  }
})

const type = computed(() => {
  switch (props.domain) {
    case 'product':
      return productStatusType(props.status)
    case 'order':
      return orderStatusType(props.status)
    case 'return':
      return returnStatusType(props.status)
    default:
      return props.status === 'enabled' || props.status === 'on_shelf'
        ? 'success'
        : 'info'
  }
})
</script>

<template>
  <el-tag :type="type" effect="light" round size="small">{{ label }}</el-tag>
</template>
