<template>
  <el-tag :type="tagType" :effect="effect" size="small" class="status-tag" round>
    {{ label }}
  </el-tag>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    status?: string
    label?: string
    effect?: 'light' | 'dark' | 'plain'
  }>(),
  { effect: 'dark' }
)

// 状态映射：snake_case -> 显示文案 + el-tag 类型
const STATUS_MAP: Record<string, { text: string; type: 'success' | 'warning' | 'danger' | 'info' | 'primary' }> = {
  // 通用
  normal: { text: '正常', type: 'success' },
  enabled: { text: '启用', type: 'success' },
  disabled: { text: '禁用', type: 'info' },
  banned: { text: '封禁', type: 'danger' },
  pending: { text: '待处理', type: 'warning' },
  approved: { text: '已通过', type: 'success' },
  pass: { text: '已通过', type: 'success' },
  rejected: { text: '已驳回', type: 'danger' },
  handled: { text: '已处理', type: 'success' },
  // 审核扩展
  first_pass: { text: '初审通过', type: 'success' },
  final_pass: { text: '终审通过', type: 'success' },
  verified: { text: '已认证', type: 'success' },
  // 上下架
  on_shelf: { text: '上架', type: 'success' },
  off_shelf: { text: '下架', type: 'info' },
  recommended: { text: '推荐', type: 'primary' },
  // 财务
  confirmed: { text: '已确认', type: 'success' },
  paid: { text: '已付款', type: 'success' },
  processing: { text: '处理中', type: 'warning' },
  success: { text: '成功', type: 'success' },
  failed: { text: '失败', type: 'danger' },
  // 内容
  hidden: { text: '隐藏', type: 'info' },
  published: { text: '已发布', type: 'success' },
  offline: { text: '已下线', type: 'info' },
  draft: { text: '草稿', type: 'info' },
  unused: { text: '未使用', type: 'info' },
  used: { text: '已使用', type: 'success' },
  expired: { text: '已过期', type: 'info' }
}

const tagType = computed(() => {
  if (props.label) return 'primary'
  const s = props.status || ''
  return (STATUS_MAP[s]?.type as any) || 'info'
})

const label = computed(() => {
  if (props.label) return props.label
  const s = props.status || ''
  return STATUS_MAP[s]?.text || s || '-'
})
</script>

<style scoped>
.status-tag {
  border: none;
}
</style>
