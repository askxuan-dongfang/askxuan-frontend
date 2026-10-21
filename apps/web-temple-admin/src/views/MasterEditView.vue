<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { type FormInstance, type FormRules } from 'element-plus'
import { ArrowLeft, Check, Close } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import { getMasterDetail, createMaster, updateMaster } from '@/api/master'
import ProviderAffiliation from '../../../../packages/admin-ui/components/ProviderAffiliation.vue'
import { beliefLabel, normalizeBelief } from '../../../../packages/admin-ui/affiliation'
import { useAuthStore } from '@/stores/auth'
import type { Master } from '@/types'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const masterId = computed(() => (route.params.id as string) || '')
const isEdit = computed(() => !!masterId.value)
const pageTitle = computed(() => (isEdit.value ? '编辑法师' : '新增法师'))
const pageSubtitle = computed(() => (isEdit.value ? '修改法师资料' : '登记本寺法师'))

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)
const tagInput = ref('')
const affiliation = ref<InstanceType<typeof ProviderAffiliation>>()

const form = reactive({
  dharmaName: '',
  layName: '',
  position: '',
  beliefCode: '',
  sect: '',
  traditionCodes: [] as string[],
  type: '佛教',
  specialties: [] as string[],
  avatar: ''
})

const rules: FormRules = {
  dharmaName: [{ required: true, message: '请输入法号', trigger: 'blur' }],
  layName: [{ required: true, message: '请输入俗名', trigger: 'blur' }],
  position: [{ required: true, message: '请输入职位', trigger: 'blur' }],
  beliefCode: [{ required: true, message: '请选择主信仰', trigger: 'change' }],

}

async function loadMaster() {
  if (!masterId.value) return
  loading.value = true
  try {
    const m: Master = await getMasterDetail(masterId.value)
    form.dharmaName = m.dharmaName
    form.layName = m.layName
    form.position = m.position
    form.beliefCode = normalizeBelief(m.beliefCode)
    form.traditionCodes = [...(m.traditionCodes || [])]
    form.sect = m.sect
    form.type = m.type
    form.specialties = m.specialties || []
    form.avatar = m.avatar
  } finally {
    loading.value = false
  }
}

function addTag() {
  const v = tagInput.value.trim()
  if (v && !form.specialties.includes(v)) {
    form.specialties.push(v)
  }
  tagInput.value = ''
}
function removeTag(t: string) {
  form.specialties = form.specialties.filter((x) => x !== t)
}

async function handleSubmit() {
  if (saving.value || !formRef.value) return
  if (!isEdit.value) { const problem=affiliation.value?.validate(true); if(problem){ElMessage.warning(uiText(problem));return} }
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    if (!isEdit.value) form.type = beliefLabel(form.beliefCode)
    saving.value = true
    try {
      if (isEdit.value) {
        await updateMaster(masterId.value, {
          dharmaName: form.dharmaName,
          layName: form.layName,
          position: form.position,
          sect: form.sect,
          specialties: form.specialties,
          avatar: form.avatar
        })
        ElMessage.success(uiText('法师信息已更新'))
      } else {
        await createMaster({
          dharmaName: form.dharmaName,
          layName: form.layName,
          templeId: auth.templeId,
          templeName: auth.templeName,
          position: form.position,
          beliefCode: form.beliefCode,
          traditionCodes: [...form.traditionCodes],
          sect: form.sect,
          type: form.type,
          specialties: form.specialties,
          avatar: form.avatar
        })
        ElMessage.success(uiText('法师已创建'))
      }
      router.push('/masters')
    } finally {
      saving.value = false
    }
  })
}

onMounted(async () => {
  if (!isEdit.value && !form.beliefCode) form.beliefCode = 'han_buddhism'
  await loadMaster()
})
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader :title="$t(pageTitle)" :subtitle="$t(pageSubtitle)">
      <el-button :icon="ArrowLeft" @click="router.back()">{{ $t("返回") }}</el-button>
      <el-button type="primary" :icon="Check" :loading="saving" @click="handleSubmit">{{ $t("保存") }}</el-button>
    </PageHeader>

    <div class="df-card edit-card">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="92px" class="edit-form">
        <el-row :gutter="20">
          <el-col :xs="24" :sm="12">
            <el-form-item :label='$t("法号")' prop="dharmaName">
              <el-input v-model="form.dharmaName" :placeholder='$t("如 释永信")' />
            </el-form-item>
          </el-col>
          <el-col :xs="24" :sm="12">
            <el-form-item :label='$t("俗名")' prop="layName">
              <el-input v-model="form.layName" :placeholder='$t("请输入俗名")' />
            </el-form-item>
          </el-col>
          <el-col :xs="24" :sm="12">
            <el-form-item :label='$t("职位")' prop="position">
              <el-input v-model="form.position" :placeholder='$t("如 方丈、监院")' />
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label-width="0">
              <ProviderAffiliation ref="affiliation" v-model:belief="form.beliefCode" v-model:codes="form.traditionCodes" :readonly="isEdit" :disabled="saving" />
              <p v-if="isEdit" class="affiliation-scope-note">{{ $t('已建档法师的主信仰与标准宗派由平台维护；本寺可继续补充资料说明。') }}</p>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item :label='$t("宗派补充说明")' prop="sect">
              <el-input v-model="form.sect" maxlength="32" :placeholder='$t("可选；不作为标准筛选关联")'/>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item :label='$t("专长")'>
              <div class="tag-input">
                <el-tag
                  v-for="t in form.specialties"
                  :key="t"
                  closable
                  effect="light"
                  class="spec-tag"
                  @close="removeTag(t)"
                  >{{ $t(t) }}</el-tag
                >
                <el-input
                  v-if="form.specialties.length < 8"
                  v-model="tagInput"
                  size="small"
                  class="tag-field"
                  :placeholder='$t("输入专长后回车")'
                  @keyup.enter="addTag"
                />
                <el-button v-if="tagInput" link size="small" :icon="Close" @click="tagInput = ''" />
              </div>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item :label='$t("头像")'>
              <ImageUploader v-model="form.avatar" hint="建议正方形头像，不超过 1MB" />
            </el-form-item>
          </el-col>
        </el-row>
      </el-form>
    </div>
  </div>
</template>

<style scoped>
.affiliation-scope-note{font-size:12px;line-height:1.7;color:var(--color-text-tertiary);margin:12px 0 0}
.edit-card {
  padding: 22px 24px;
}
.edit-form {
  max-width: 900px;
}
.tag-input {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}
.spec-tag {
  margin: 0;
}
.tag-field {
  width: 160px;
}
</style>
