<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { ArrowLeft, Check, Close } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import { listMasters, createMaster, updateMaster } from '@/api/master'
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

const form = reactive({
  dharmaName: '',
  layName: '',
  position: '',
  sect: '',
  type: '佛教',
  specialties: [] as string[],
  avatar: ''
})

const rules: FormRules = {
  dharmaName: [{ required: true, message: '请输入法号', trigger: 'blur' }],
  layName: [{ required: true, message: '请输入俗名', trigger: 'blur' }],
  position: [{ required: true, message: '请输入职位', trigger: 'blur' }],
  sect: [{ required: true, message: '请选择宗派', trigger: 'change' }]
}

const sectOptions = ['禅宗', '净土宗', '天台宗', '华严宗', '律宗', '密宗', '三论宗', '法相宗']

async function loadMaster() {
  if (!masterId.value) return
  loading.value = true
  try {
    const r = await listMasters({ templeId: auth.templeId, page: 1, size: 200 })
    const m: Master | undefined = (r.list || []).find((x) => x.id === masterId.value)
    if (!m) {
      ElMessage.error('未找到该法师')
      router.back()
      return
    }
    form.dharmaName = m.dharmaName
    form.layName = m.layName
    form.position = m.position
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
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    saving.value = true
    try {
      if (isEdit.value) {
        await updateMaster(masterId.value, {
          dharmaName: form.dharmaName,
          layName: form.layName,
          position: form.position,
          specialties: form.specialties,
          avatar: form.avatar
        })
        ElMessage.success('法师信息已更新')
      } else {
        await createMaster({
          dharmaName: form.dharmaName,
          layName: form.layName,
          templeId: auth.templeId,
          templeName: auth.templeName,
          position: form.position,
          sect: form.sect,
          type: form.type,
          specialties: form.specialties,
          avatar: form.avatar
        })
        ElMessage.success('法师已创建')
      }
      router.push('/masters')
    } finally {
      saving.value = false
    }
  })
}

onMounted(loadMaster)
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader :title="pageTitle" :subtitle="pageSubtitle">
      <el-button :icon="ArrowLeft" @click="router.back()">返回</el-button>
      <el-button type="primary" :icon="Check" :loading="saving" @click="handleSubmit">保存</el-button>
    </PageHeader>

    <div class="df-card edit-card">
      <el-form ref="formRef" :model="form" :rules="rules" label-width="92px" class="edit-form">
        <el-row :gutter="20">
          <el-col :span="12">
            <el-form-item label="法号" prop="dharmaName">
              <el-input v-model="form.dharmaName" placeholder="如 释永信" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="俗名" prop="layName">
              <el-input v-model="form.layName" placeholder="请输入俗名" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="职位" prop="position">
              <el-input v-model="form.position" placeholder="如 方丈、监院" />
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="宗派" prop="sect">
              <el-select v-model="form.sect" placeholder="请选择宗派" :disabled="isEdit" style="width: 100%">
                <el-option v-for="s in sectOptions" :key="s" :label="s" :value="s" />
              </el-select>
            </el-form-item>
          </el-col>
          <el-col :span="12">
            <el-form-item label="类型">
              <el-radio-group v-model="form.type" :disabled="isEdit">
                <el-radio value="佛教">佛教</el-radio>
                <el-radio value="道教">道教</el-radio>
              </el-radio-group>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="专长">
              <div class="tag-input">
                <el-tag
                  v-for="t in form.specialties"
                  :key="t"
                  closable
                  effect="light"
                  class="spec-tag"
                  @close="removeTag(t)"
                  >{{ t }}</el-tag
                >
                <el-input
                  v-if="form.specialties.length < 8"
                  v-model="tagInput"
                  size="small"
                  class="tag-field"
                  placeholder="输入专长后回车"
                  @keyup.enter="addTag"
                />
                <el-button v-if="tagInput" link size="small" :icon="Close" @click="tagInput = ''" />
              </div>
            </el-form-item>
          </el-col>
          <el-col :span="24">
            <el-form-item label="头像">
              <ImageUploader v-model="form.avatar" hint="建议正方形头像，不超过 1MB" />
            </el-form-item>
          </el-col>
        </el-row>
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
