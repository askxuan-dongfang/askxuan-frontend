<script setup lang="ts">
import { computed } from 'vue'
import {
  bookingStatusText,
  bookingStatusType,
  serviceStatusText,
  serviceStatusType,
  reviewStatusText,
  reviewStatusType,
  masterAuthStatusText,
  templeStatusText,
  blessingStatusText
} from '@/utils/format'

type Kind = 'booking' | 'service' | 'review' | 'master' | 'temple' | 'blessing'
type TagType = 'primary' | 'success' | 'warning' | 'info' | 'danger'

const props = withDefaults(defineProps<{ status: string; kind?: Kind }>(), { kind: 'booking' })

const text = computed(() => {
  switch (props.kind) {
    case 'booking':
      return bookingStatusText(props.status)
    case 'service':
      return serviceStatusText(props.status)
    case 'review':
      return reviewStatusText(props.status)
    case 'master':
      return masterAuthStatusText(props.status)
    case 'temple':
      return templeStatusText(props.status)
    case 'blessing':
      return blessingStatusText(props.status)
    default:
      return props.status
  }
})

const type = computed<TagType>(() => {
  switch (props.kind) {
    case 'booking':
      return (bookingStatusType(props.status) as TagType) ?? 'info'
    case 'service':
      return serviceStatusType(props.status) as TagType
    case 'review':
      return reviewStatusType(props.status) as TagType
    default:
      return 'info'
  }
})
</script>

<template>
  <el-tag :type="type" effect="light" size="small" round>{{ text }}</el-tag>
</template>
