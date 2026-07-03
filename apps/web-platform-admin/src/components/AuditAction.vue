<template>
  <div class="audit-action">
    <el-button type="success" size="small" :icon="Check" @click="open('approve')">通过</el-button>
    <el-button type="danger" size="small" :icon="Close" @click="open('reject')">驳回</el-button>

    <el-dialog v-model="visible" :title="action === 'approve' ? '审核通过' : '审核驳回'" width="460px" append-to-body>
      <el-form label-position="top">
        <el-form-item :label="action === 'approve' ? '审核备注（选填）' : '驳回原因（必填）'">
          <el-input v-model="remark" type="textarea" :rows="4" :placeholder="action === 'approve' ? '请输入审核备注' : '请输入驳回原因'" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visible = false">取消</el-button>
        <el-button :type="action === 'approve' ? 'success' : 'danger'" :loading="submitting" @click="confirm">确认</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { Check, Close } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'

const props = defineProps<{
  /** 提交回调，返回 Promise */
  onConfirm: (action: 'approve' | 'reject', remark: string) => Promise<any>
}>()

const emit = defineEmits<{ (e: 'success', action: 'approve' | 'reject'): void }>()

const visible = ref(false)
const action = ref<'approve' | 'reject'>('approve')
const remark = ref('')
const submitting = ref(false)

function open(act: 'approve' | 'reject') {
  action.value = act
  remark.value = ''
  visible.value = true
}

async function confirm() {
  if (action.value === 'reject' && !remark.value.trim()) {
    ElMessage.warning('请输入驳回原因')
    return
  }
  submitting.value = true
  try {
    await props.onConfirm(action.value, remark.value.trim())
    ElMessage.success(action.value === 'approve' ? '已通过' : '已驳回')
    visible.value = false
    emit('success', action.value)
  } catch (e) {
    // 错误已由 client 拦截器提示
  } finally {
    submitting.value = false
  }
}
</script>
