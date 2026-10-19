<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { type FormInstance, type FormRules } from 'element-plus'
import { ArrowLeft, Check, Plus, Delete } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import { listServiceTypes, listServices, getServiceDetail, createService, updateService } from '@/api/service'
import { listIntentions, type IntentionOption } from '@/api/taxonomy'
import type { ServiceTypeOption, TempleService, TempleServiceSlot } from '@/types'

const route = useRoute()
const router = useRouter()

const serviceId = computed(() => (route.params.id as string) || '')
const isEdit = computed(() => !!serviceId.value)

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)

const form = reactive({
  serviceCode: '',
  price: 0,
  timeSlots: [] as string[],
	slots: [] as TempleServiceSlot[],
  intentMode: 'inherit' as 'inherit' | 'custom',
  intentTags: [] as string[]
})

const rules: FormRules = {
  serviceCode: [{ required: true, message: '请选择服务类型', trigger: 'change' }],
  price: [{ required: true, type: 'number', min: 0, message: '请输入有效价格', trigger: 'blur' }]
}

const intentOptions = ref<IntentionOption[]>([])
const serviceTypeOptions = ref<ServiceTypeOption[]>([])
const enabledServiceCodes = ref<Set<string>>(new Set())

const selectedServiceType = computed(() =>
  serviceTypeOptions.value.find((item) => item.code === form.serviceCode)
)

function selectServiceType(item: ServiceTypeOption) {
  if (isEdit.value || enabledServiceCodes.value.has(item.code)) return
  form.serviceCode = item.code
}

async function loadServiceTypes() {
  const [catalog, enabled] = await Promise.all([listServiceTypes(), listServices()])
  serviceTypeOptions.value = catalog.list || []
  enabledServiceCodes.value = new Set((enabled.list || []).map((item) => item.serviceCode))
}

async function loadService() {
  if (!serviceId.value) return
  loading.value = true
  try {
    const s: TempleService = await getServiceDetail(Number(serviceId.value))
    form.serviceCode = s.serviceCode
    form.price = s.price
    form.timeSlots = s.timeSlots || []
		form.slots = s.slots?.length ? s.slots.map((slot) => ({ ...slot })) : (s.timeSlots || []).map((range, index) => {
			const [startTime, endTime] = range.split('-')
			return { code: `slot_${String(index + 1).padStart(2, '0')}`, label: range, startTime, endTime, capacity: 10, status: 'enabled', sort: index + 1 }
		})
    form.intentTags = s.intentTags || []
    form.intentMode = s.intentMode || 'custom'
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
		const slots = form.slots.map((slot, index) => ({ ...slot, sort: index + 1 }))
		const timeSlots = slots.map((slot) => `${slot.startTime}-${slot.endTime}`)
      if (isEdit.value) {
        await updateService(Number(serviceId.value), {
          price: form.price,
			timeSlots,
			slots,
          intentMode: form.intentMode,
          intentTags: form.intentMode === 'custom' ? form.intentTags : undefined
        })
        ElMessage.success(uiText('服务已更新'))
      } else {
        await createService({
          serviceCode: form.serviceCode,
          price: form.price,
			timeSlots,
			slots,
          intentMode: form.intentMode,
          intentTags: form.intentMode === 'custom' ? form.intentTags : undefined
        })
        ElMessage.success(uiText('服务已创建'))
      }
      router.push('/services')
    } finally {
      saving.value = false
    }
  })
}

function addSlot() {
	const index = form.slots.length + 1
	form.slots.push({ code: `slot_${String(index).padStart(2, '0')}`, label: `时段${index}`, startTime: '09:00', endTime: '10:00', capacity: 10, status: 'enabled', sort: index })
}

function removeSlot(index: number) {
	form.slots.splice(index, 1)
}

onMounted(async () => {
  await Promise.all([
    loadServiceTypes(),
    listIntentions().then((items) => { intentOptions.value = items })
  ])
  await loadService()
})
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader :title="$t((isEdit ? $t('编辑服务') : $t('新增服务')))" :subtitle="$t((isEdit ? $t('修改法事服务信息') : $t('新增法事服务项目')))">
      <el-button :icon="ArrowLeft" @click="router.back()">{{ $t("返回") }}</el-button>
      <el-button type="primary" :icon="Check" :loading="saving" @click="handleSubmit">{{ $t("保存") }}</el-button>
    </PageHeader>

    <div class="df-card edit-card">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="92px" class="edit-form">
        <el-form-item :label='$t("服务类型")' prop="serviceCode">
          <div class="service-type-picker">
            <button
              v-for="item in serviceTypeOptions"
              :key="item.code"
              type="button"
              class="service-type-tag"
              :class="{
                selected: form.serviceCode === item.code,
                unavailable: !isEdit && enabledServiceCodes.has(item.code)
              }"
              :disabled="isEdit || enabledServiceCodes.has(item.code)"
              @click="selectServiceType(item)"
            >
              <span>{{ $t(item.name) }}</span>
              <small>{{ $t(item.category) }} · {{ $t(item.priceRange) }}</small>
            </button>
          </div>
          <div v-if="selectedServiceType" class="selected-type-hint">{{ $t(" 已选择 ") }}{{ $t(selectedServiceType.name) }}（{{ $t(selectedServiceType.code) }}{{ $t("）；服务类型由平台统一维护 ") }}</div>
        </el-form-item>
        <el-form-item :label='$t("价格（元）")' prop="price">
          <el-input-number v-model="form.price" :min="0" :precision="2" controls-position="right" />
        </el-form-item>
        <el-form-item :label='$t("开放时段")'>
		  <div class="slot-editor">
			<div v-for="(slot, index) in form.slots" :key="slot.code" class="slot-row">
			  <el-input v-model="slot.label" :placeholder='$t("名称")' />
			  <el-time-select v-model="slot.startTime" start="05:00" step="00:30" end="22:00" :placeholder='$t("开始")' />
			  <el-time-select v-model="slot.endTime" start="05:30" step="00:30" end="23:00" :placeholder='$t("结束")' />
			  <el-input-number v-model="slot.capacity" :min="1" :max="999" controls-position="right" />
			  <el-switch v-model="slot.status" active-value="enabled" inactive-value="disabled" />
			  <el-button :icon="Delete" circle :aria-label='$t("删除时段")' @click="removeSlot(index)" />
			</div>
			<el-button :icon="Plus" @click="addSlot">{{ $t("添加时段") }}</el-button>
		  </div>
        </el-form-item>
        <el-form-item :label='$t("心愿关联")'>
          <el-radio-group v-model="form.intentMode"><el-radio value="inherit">{{ $t("跟随标准服务") }}</el-radio><el-radio value="custom">{{ $t("手动设置") }}</el-radio></el-radio-group>
          <p v-if="form.intentMode==='inherit'" style="width:100%;color:var(--el-text-color-secondary)">{{ $t("按平台标准服务规则自动进入对应心愿；以后新增或调整规则也会生效。") }}</p>
          <el-select v-if="form.intentMode==='custom'" v-model="form.intentTags" multiple :placeholder='$t("空选表示不进入心愿页")' style="width: 100%">
            <el-option v-for="item in intentOptions" :key="item.code" :label="$t(item.name)" :value="item.code" />
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
	max-width: 900px;
}
.slot-editor { width: 100%; display: grid; gap: 10px; }
.slot-row { display: grid; grid-template-columns: 1.2fr 1fr 1fr 120px 48px 40px; gap: 8px; align-items: center; }
.service-type-picker { width: 100%; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
.service-type-tag { min-height: 64px; padding: 10px 12px; border: 1px solid var(--el-border-color); border-radius: 6px; background: var(--el-bg-color); color: var(--el-text-color-primary); text-align: left; cursor: pointer; }
.service-type-tag span, .service-type-tag small { display: block; }
.service-type-tag span { font-size: var(--type-size-body); font-weight: var(--type-weight-semibold); }
.service-type-tag small { margin-top: 4px; color: var(--el-text-color-secondary); }
.service-type-tag.selected { border-color: var(--el-color-primary); background: var(--el-color-primary-light-9); color: var(--el-color-primary); }
.service-type-tag.unavailable { opacity: 0.45; cursor: not-allowed; }
.selected-type-hint { margin-top: 8px; color: var(--el-text-color-secondary); font-size: var(--type-size-caption); }
@media (max-width: 760px) { .slot-row { grid-template-columns: 1fr 1fr; } }
@media (max-width: 760px) { .service-type-picker { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
</style>
