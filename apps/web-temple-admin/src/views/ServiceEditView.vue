<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { ArrowLeft, Check } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import { listServices, createService, updateService } from '@/api/service'
import type { TempleService } from '@/types'

const route = useRoute()
const router = useRouter()

const serviceId = computed(() => (route.params.id as string) || '')
const isEdit = computed(() => !!serviceId.value)

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)

const form = reactive({
  serviceCode: '',
  serviceName: '',
  price: 0,
  timeSlots: [] as string[],
  intentTags: [] as string[]
})

const rules: FormRules = {
  serviceCode: [{ required: true, message: '请输入服务编码', trigger: 'blur' }],
  serviceName: [{ required: true, message: '请输入服务名称', trigger: 'blur' }],
  price: [{ required: true, type: 'number', min: 0, message: '请输入有效价格', trigger: 'blur' }]
}

const slotPresets = ['06:00-07:00', '08:00-09:00', '09:00-10:00', '10:00-11:00', '14:00-15:00', '15:00-16:00']
const intentOptions = [
  { label: '求平安', value: 'peace' }, { label: '求财运', value: 'wealth' },
  { label: '求姻缘', value: 'love' }, { label: '求事业', value: 'career' },
  { label: '求学业', value: 'study' }, { label: '化太岁', value: 'taisui' },
  { label: '定手串', value: 'diy' }, { label: '做法事', value: 'rite' }
]

async function loadService() {
  if (!serviceId.value) return
  loading.value = true
  try {
    const r = await listServices()
    const s: TempleService | undefined = (r.list || []).find((x) => x.id === Number(serviceId.value))
    if (!s) {
      ElMessage.error('未找到该服务')
      router.back()
      return
    }
    form.serviceCode = s.serviceCode
    form.serviceName = s.serviceName
    form.price = s.price
    form.timeSlots = s.timeSlots || []
    form.intentTags = s.intentTags || []
  } finally {
    loading.value = false
  }
}

async function handleSubmit() {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    saving.value = true
    try {
      if (isEdit.value) {
        await updateService(Number(serviceId.value), {
          serviceName: form.serviceName,
          price: form.price,
          timeSlots: form.timeSlots,
          intentTags: form.intentTags
        })
        ElMessage.success('服务已更新')
      } else {
        await createService({
          serviceCode: form.serviceCode,
          serviceName: form.serviceName,
          price: form.price,
          timeSlots: form.timeSlots,
          intentTags: form.intentTags
        })
        ElMessage.success('服务已创建')
      }
      router.push('/services')
    } finally {
      saving.value = false
    }
  })
}

onMounted(loadService)
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader :title="isEdit ? '编辑服务' : '新增服务'" :subtitle="isEdit ? '修改法事服务信息' : '新增法事服务项目'">
      <el-button :icon="ArrowLeft" @click="router.back()">返回</el-button>
      <el-button type="primary" :icon="Check" :loading="saving" @click="handleSubmit">保存</el-button>
    </PageHeader>

    <div class="df-card edit-card">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="92px" class="edit-form">
        <el-form-item label="服务编码" prop="serviceCode">
          <el-input v-model="form.serviceCode" :disabled="isEdit" placeholder="如 S001" />
        </el-form-item>
        <el-form-item label="服务名称" prop="serviceName">
          <el-input v-model="form.serviceName" placeholder="如 早课祈福、供灯法会" />
        </el-form-item>
        <el-form-item label="价格（元）" prop="price">
          <el-input-number v-model="form.price" :min="0" :precision="2" controls-position="right" />
        </el-form-item>
        <el-form-item label="开放时段">
          <el-select
            v-model="form.timeSlots"
            multiple
            filterable
            allow-create
            default-first-option
            placeholder="选择或输入时段"
            style="width: 100%"
          >
            <el-option v-for="s in slotPresets" :key="s" :label="s" :value="s" />
          </el-select>
        </el-form-item>
        <el-form-item label="诉求标签">
          <el-select v-model="form.intentTags" multiple placeholder="选择要进入的诉求聚合" style="width: 100%">
            <el-option v-for="item in intentOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<style scoped>
.edit-card {
  padding: 22px 24px;
}
.edit-form {
  max-width: 640px;
}
</style>
