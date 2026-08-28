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
  materialType: 'gemstone',
  shape: 'round',
  diameterMm: 10,
  colorHex: '#8A6E4A',
  textureKey: 'plain',
  finish: 'polished',
  translucency: 0,
  image: '',
  stock: 0
})

const rules: FormRules = {
  name: [{ required: true, message: '请输入材料名称', trigger: 'blur' }],
  unitPrice: [{ required: true, message: '请输入单价', trigger: 'blur' }],
  unit: [{ required: true, message: '请输入单位', trigger: 'blur' }],
  category: [{ required: true, message: '请选择分类', trigger: 'change' }],
  materialType: [{ required: true, message: '请选择材质大类', trigger: 'change' }],
  shape: [{ required: true, message: '请选择形制', trigger: 'change' }],
  colorHex: [{ required: true, message: '请选择渲染主色', trigger: 'change' }],
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

const fiveElementsOptions = [
  { value: 'metal', label: '金' },
  { value: 'wood', label: '木' },
  { value: 'water', label: '水' },
  { value: 'fire', label: '火' },
  { value: 'earth', label: '土' }
]

const materialTypeOptions = [
  { value: 'crystal', label: '水晶' }, { value: 'jade', label: '玉石' },
  { value: 'gemstone', label: '天然宝石' }, { value: 'wood', label: '木质' },
  { value: 'seed', label: '菩提籽' }, { value: 'organic', label: '有机宝石' },
  { value: 'metal', label: '金属' }, { value: 'ceramic', label: '陶瓷' },
  { value: 'glass', label: '琉璃' }, { value: 'textile', label: '织物' },
  { value: 'cord', label: '绳线' }
]

const shapeOptions = [
  { value: 'round', label: '圆珠' }, { value: 'faceted', label: '切面珠' },
  { value: 'barrel', label: '桶珠' }, { value: 'disc', label: '隔片' },
  { value: 'three_way', label: '三通' }, { value: 'buddha_head', label: '佛头' },
  { value: 'pendant', label: '吊坠' }, { value: 'tassel', label: '流苏' },
  { value: 'cord', label: '绳线' }
]

const textureOptions = [
  { value: 'plain', label: '纯色' }, { value: 'crystal', label: '晶体' },
  { value: 'jade_cloud', label: '玉石云纹' }, { value: 'wood_grain', label: '木纹' },
  { value: 'bodhi', label: '菩提纹' }, { value: 'seed', label: '籽纹' },
  { value: 'agate', label: '玛瑙纹' }, { value: 'amber', label: '琥珀纹' },
  { value: 'lapis', label: '青金纹' }, { value: 'obsidian', label: '曜石纹' },
  { value: 'tiger_eye', label: '虎眼纹' }, { value: 'turquoise', label: '松石纹' },
  { value: 'dzi', label: '天珠纹' }, { value: 'cinnabar', label: '朱砂纹' },
  { value: 'porcelain', label: '青花瓷' }, { value: 'cloisonne', label: '景泰蓝' },
  { value: 'metal', label: '金属' }, { value: 'glass', label: '琉璃' },
  { value: 'silk', label: '丝线' }, { value: 'cord', label: '编绳' }
]

const finishOptions = [
  { value: 'polished', label: '抛光' }, { value: 'matte', label: '哑光' },
  { value: 'faceted', label: '切面' }, { value: 'natural', label: '自然面' },
  { value: 'carved', label: '雕刻' }, { value: 'brushed', label: '拉丝' },
  { value: 'woven', label: '编织' }, { value: 'glazed', label: '釉面' }
]

async function loadDetail() {
  if (!isEdit.value) return
  loading.value = true
  try {
    const target = await materialApi.detail(materialId.value)
    Object.assign(form, {
      name: target.name,
      spec: target.spec,
      unitPrice: target.unitPrice,
      unit: target.unit,
      category: target.category,
      fiveElements: target.fiveElements || '',
      materialType: target.materialType || 'gemstone',
      shape: target.shape || 'round',
      diameterMm: target.diameterMm ?? 10,
      colorHex: target.colorHex || '#8A6E4A',
      textureKey: target.textureKey || 'plain',
      finish: target.finish || 'polished',
      translucency: target.translucency ?? 0,
      image: target.image,
      stock: target.stock
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
    <PageHeader :title="isEdit ? '编辑材料' : '新建材料'" subtitle="统一维护材料、渲染样式、价格与库存，C 端和 iOS 实时读取" />

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
          <el-input v-model="form.spec" placeholder="如：8mm；绳线与流苏可留空" />
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
              :key="f.value"
              :label="f.label"
              :value="f.value"
            />
          </el-select>
        </el-form-item>

        <el-divider content-position="left">前端渲染样式</el-divider>

        <div class="render-grid">
          <el-form-item label="材质大类" prop="materialType">
            <el-select v-model="form.materialType" style="width: 220px">
              <el-option v-for="item in materialTypeOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="珠型/造型" prop="shape">
            <el-select v-model="form.shape" style="width: 220px">
              <el-option v-for="item in shapeOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="纹理">
            <el-select v-model="form.textureKey" filterable style="width: 220px">
              <el-option v-for="item in textureOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="表面工艺">
            <el-select v-model="form.finish" style="width: 220px">
              <el-option v-for="item in finishOptions" :key="item.value" :label="item.label" :value="item.value" />
            </el-select>
          </el-form-item>
          <el-form-item label="渲染直径">
            <el-input-number v-model="form.diameterMm" :min="0" :max="40" :precision="1" :step="1" />
            <span class="form-tip">mm</span>
          </el-form-item>
          <el-form-item label="通透度">
            <el-slider v-model="form.translucency" :min="0" :max="1" :step="0.05" show-input />
          </el-form-item>
          <el-form-item label="渲染主色" prop="colorHex">
            <el-color-picker v-model="form.colorHex" />
            <el-input v-model="form.colorHex" style="width: 140px; margin-left: 10px" />
          </el-form-item>
          <div class="bead-preview-wrap">
            <span>无图时预览</span>
            <div class="bead-preview" :class="[`shape-${form.shape}`, `finish-${form.finish}`]" :style="{ backgroundColor: form.colorHex, opacity: Math.max(0.45, 1 - form.translucency * 0.35) }" />
          </div>
        </div>

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
.render-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 24px;
}
.render-grid :deep(.el-slider) { width: 220px; }
.bead-preview-wrap { display: flex; align-items: center; justify-content: center; gap: 14px; min-height: 52px; color: var(--text-light); font-size: 13px; }
.bead-preview { width: 44px; height: 44px; border-radius: 50%; box-shadow: inset -9px -10px 14px rgba(0,0,0,.22), inset 8px 7px 12px rgba(255,255,255,.42), 0 5px 12px rgba(0,0,0,.14); }
.bead-preview.shape-disc { width: 22px; }
.bead-preview.shape-barrel { width: 52px; border-radius: 15px; }
.bead-preview.shape-faceted { clip-path: polygon(25% 4%,75% 4%,96% 28%,88% 78%,64% 98%,28% 94%,4% 68%,6% 28%); }
.bead-preview.finish-matte { filter: saturate(.8); box-shadow: inset -6px -7px 10px rgba(0,0,0,.17), 0 4px 10px rgba(0,0,0,.12); }
.form-tip {
  margin-left: 8px;
  font-size: 12px;
  color: var(--text-light);
}
</style>
