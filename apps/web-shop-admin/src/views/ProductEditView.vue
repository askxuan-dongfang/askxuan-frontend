<script setup lang="ts">
// 商品编辑 / 新建
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import { productApi, type ProductSaveParams } from '@/api/product'
import { categoryApi } from '@/api/category'
import type { ProductCategory } from '@/types'

const route = useRoute()
const router = useRouter()

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)
const categories = ref<ProductCategory[]>([])
const intentOptions = [
  { label: '求平安', value: 'peace' }, { label: '求财运', value: 'wealth' },
  { label: '求姻缘', value: 'love' }, { label: '求事业', value: 'career' },
  { label: '求学业', value: 'study' }, { label: '化太岁', value: 'taisui' },
  { label: '定手串', value: 'diy' }, { label: '做法事', value: 'rite' }
]

const isEdit = computed(() => !!route.params.id)
const productId = computed(() => Number(route.params.id) || 0)

const form = reactive<ProductSaveParams>({
  name: '',
  categoryId: 0,
  description: '',
  mainImage: '',
  price: 0,
  marketPrice: 0,
  stock: 0,
  tags: '',
  intentTags: [],
  freightTemplateId: 0
})

const rules: FormRules = {
  name: [{ required: true, message: '请输入商品名称', trigger: 'blur' }],
  categoryId: [{ required: true, message: '请选择分类', trigger: 'change' }],
  mainImage: [{ required: true, message: '请上传主图', trigger: 'change' }],
  price: [{ required: true, message: '请输入售价', trigger: 'blur' }],
  stock: [{ required: true, message: '请输入库存', trigger: 'blur' }]
}

async function loadCategories() {
  try {
    const res = await categoryApi.list({ page: 1, size: 100 })
    categories.value = res.list || []
  } catch {
    categories.value = []
  }
}

async function loadDetail() {
  if (!isEdit.value) return
  loading.value = true
  try {
    const detail = await productApi.detail(productId.value)
    Object.assign(form, {
      name: detail.name,
      categoryId: detail.categoryId,
      description: detail.description,
      mainImage: detail.mainImage,
      price: detail.price,
      marketPrice: detail.marketPrice,
      stock: detail.stock,
      tags: detail.tags,
      intentTags: detail.intentTags || [],
      freightTemplateId: detail.freightTemplateId
    })
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
        await productApi.update(productId.value, form)
        ElMessage.success('更新成功')
      } else {
        await productApi.create(form)
        ElMessage.success('创建成功')
      }
      router.push('/products')
    } finally {
      saving.value = false
    }
  })
}

function handleCancel() {
  router.push('/products')
}

onMounted(() => {
  loadCategories()
  loadDetail()
})
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader :title="isEdit ? '编辑商品' : '新建商品'" subtitle="维护商品基本信息、价格、库存与主图" />

    <div class="df-card form-card">
      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-width="100px"
        label-position="right"
      >
        <el-form-item label="商品名称" prop="name">
          <el-input v-model="form.name" placeholder="请输入商品名称" maxlength="100" show-word-limit />
        </el-form-item>

        <el-form-item label="所属分类" prop="categoryId">
          <el-select v-model="form.categoryId" placeholder="请选择分类" style="width: 280px">
            <el-option
              v-for="c in categories"
              :key="c.id"
              :label="c.name"
              :value="c.id"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="商品主图" prop="mainImage">
          <ImageUploader v-model="form.mainImage" :multiple="false" placeholder="粘贴主图 URL" />
        </el-form-item>

        <el-form-item label="售价" prop="price">
          <el-input-number v-model="form.price" :min="0" :precision="2" :step="1" controls-position="right" />
          <span class="form-tip">元</span>
        </el-form-item>

        <el-form-item label="市场价">
          <el-input-number v-model="form.marketPrice" :min="0" :precision="2" :step="1" controls-position="right" />
          <span class="form-tip">元（可选，用于展示划线价）</span>
        </el-form-item>

        <el-form-item label="库存" prop="stock">
          <el-input-number v-model="form.stock" :min="0" :step="1" controls-position="right" />
        </el-form-item>

        <el-form-item label="标签">
          <el-input v-model="form.tags" placeholder="多个标签用逗号分隔，如：祈福,开光,禅意" style="width: 480px" />
        </el-form-item>

        <el-form-item label="诉求标签">
          <el-select v-model="form.intentTags" multiple placeholder="选择要进入的诉求聚合" style="width: 480px">
            <el-option v-for="item in intentOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>

        <el-form-item label="运费模板">
          <el-input-number v-model="form.freightTemplateId" :min="0" controls-position="right" />
          <span class="form-tip">模板 ID（0 表示默认包邮）</span>
        </el-form-item>

        <el-form-item label="商品描述">
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="5"
            placeholder="请输入商品描述"
            maxlength="2000"
            show-word-limit
          />
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
