<template>
  <div class="audit-action">
    <el-button type="success" size="small" :icon="Check" @click="open('approve')">{{ $t("通过") }}</el-button>
    <el-button type="danger" size="small" :icon="Close" @click="open('reject')">{{ $t("驳回") }}</el-button>

    <el-dialog v-model="visible" :title="$t((action === 'approve' ? $t('审核通过') : $t('审核驳回')))" width="460px" append-to-body>
      <el-alert
        :title="$t((action === 'approve' ? $t('通过后，相关资质或内容将进入后续发布、展示或业务流转。') : $t('驳回后，本次申请或内容不会通过审核，驳回原因将作为处理记录保留。')))"
        type="warning"
        :closable="false"
        show-icon
      />
      <el-form label-position="top">
        <el-form-item :label="$t((action === 'approve' ? $t('审核备注（选填）') : $t('驳回原因（必填）')))">
          <el-input v-model="remark" type="textarea" :rows="4" :placeholder="$t((action === 'approve' ? $t('请输入审核备注') : $t('请输入驳回原因')))" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visible = false" data-quiet-action="cancel">{{ $t("取消") }}</el-button>
        <el-button :type="action === 'approve' ? 'success' : 'danger'" :loading="submitting" @click="confirm">{{ $t("确认") }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { ref } from 'vue'
import { Check, Close } from '@element-plus/icons-vue'


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
    ElMessage.warning(uiText('请输入驳回原因'))
    return
  }
  submitting.value = true
  try {
    await props.onConfirm(action.value, remark.value.trim())
    ElMessage.success((action.value === 'approve' ? uiText('已通过') : uiText('已驳回')))
    visible.value = false
    emit('success', action.value)
  } catch (e) {
    // 错误已由 client 拦截器提示
  } finally {
    submitting.value = false
  }
}
</script>
