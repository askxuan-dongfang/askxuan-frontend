<script setup lang="ts">
// DIY 材料编辑 / 新建
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import { materialApi, type MaterialSaveParams } from '@/api/material'
import type { MaterialCategory } from '@/types'

const route = useRoute()
const router = useRouter()

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)

const isEdit = computed(() => !!route.params.id)
const materialId = computed(() => Number(route.params.id) || 0)

const form = reactive<MaterialSaveParams>({
  name: '',
  spec: '',
  unitPrice: 0,
  unit: '颗',
  category: 'main_bead',
  fiveElements: '',
  image: '',
  stock: 0
})

const rules: FormRules = {
  name: [{ required: true, message: '请输入材料名称', trigger: 'blur' }],
  spec: [{ required: true, message: '请输入规格', trigger: 'blur' }],
  unitPrice: [{ required: true, message: '请输入单价', trigger: 'blur' }],
  unit: [{ required: true, message: '请输入单位', trigger: 'blur' }],
  category: [{ required: true, message: '请选择分类', trigger: 'change' }],
  image: [{ required: true, message: '请上传材料图片', trigger: 'change' }],
  stock: [{ required: true, message: '请输入库存', trigger: 'blur' }]
}

const categoryOptions: { value: MaterialCategory | string; label: string }[] = [
  { value: 'main_bead', label: '主珠' },
  { value: 'spacer', label: '隔珠' },
  { value: 'buddha_head', label: '佛头' },
  { value: 'pendant', label: '吊坠' },
  { value: 'tassel', label: '流苏' },
  { value: 'three_way', label: '三通' },
  { value: 'cord', label: '线绳' }
]

const fiveElementsOptions = ['金', '木', '水', '火', '土']

async function loadDetail() {
  if (!isEdit.value) return
  loading.value = true
  try {
    const detail = await materialApi.list({ keyword: '', page: 1, size: 100 })
    const target = (detail.list || []).find((m) => m.id === materialId.value)
    if (target) {
      Object.assign(form, {
        name: target.name,
        spec: target.spec,
        unitPrice: target.unitPrice,
        unit: target.unit,
        category: target.category,
        fiveElements: target.fiveElements || '',
        image: target.image,
        stock: target.stock
      })
    }
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
        await materialApi.update(materialId.value, form)
        ElMessage.success('更新成功')
      } else {
        await materialApi.create(form)
        ElMessage.success('创建成功')
      }
      router.push('/materials')
    } finally {
      saving.value = false
    }
  })
}

function handleCancel() {
  router.push('/materials')
}

onMounted(() => {
  loadDetail()
})
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader :title="isEdit ? '编辑材料' : '新建材料'" subtitle="维护 DIY 材料规格、价格与库存" />

    <div class="df-card form-card">
      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-width="100px"
        label-position="right"
      >
        <el-form-item label="材料名称" prop="name">
          <el-input v-model="form.name" placeholder="如：6mm 红玛瑙" maxlength="60" show-word-limit />
        </el-form-item>

        <el-form-item label="规格" prop="spec">
          <el-input v-model="form.spec" placeholder="如：直径 6mm" />
        </el-form-item>

        <el-form-item label="分类" prop="category">
          <el-select v-model="form.category" placeholder="请选择分类" style="width: 220px">
            <el-option
              v-for="c in categoryOptions"
              :key="c.value"
              :label="c.label"
              :value="c.value"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="五行属性">
          <el-select v-model="form.fiveElements" placeholder="请选择（可选）" clearable style="width: 220px">
            <el-option
              v-for="f in fiveElementsOptions"
              :key="f"
              :label="f"
              :value="f"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="单价" prop="unitPrice">
          <el-input-number v-model="form.unitPrice" :min="0" :precision="2" :step="1" controls-position="right" />
          <span class="form-tip">元</span>
        </el-form-item>

        <el-form-item label="单位" prop="unit">
          <el-input v-model="form.unit" placeholder="如：颗 / 串 / 克" style="width: 200px" />
        </el-form-item>

        <el-form-item label="库存" prop="stock">
          <el-input-number v-model="form.stock" :min="0" :step="1" controls-position="right" />
        </el-form-item>

        <el-form-item label="材料图片" prop="image">
          <ImageUploader v-model="form.image" :multiple="false" placeholder="粘贴材料图片 URL" />
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="handleSubmit">保存</el-button>
          <el-button @click="handleCancel">取消</el-button>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<style scoped>
.form-card {
  padding: 24px 32px;
  max-width: 880px;
}
.form-tip {
  margin-left: 8px;
  font-size: 12px;
  color: var(--text-light);
}
</style>
