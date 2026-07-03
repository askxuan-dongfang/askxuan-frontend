<script setup lang="ts">
// 祈福服务编辑 / 新建
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { serviceApi, type BlessingServiceSaveParams } from '@/api/service'

const route = useRoute()
const router = useRouter()

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)

const isEdit = computed(() => !!route.params.id)
const serviceId = computed(() => Number(route.params.id) || 0)

const form = reactive<BlessingServiceSaveParams>({
  serviceName: '',
  templeCode: '',
  masterCode: '',
  price: 0,
  description: '',
  status: 'on_shelf'
})

const rules: FormRules = {
  serviceName: [{ required: true, message: '请输入服务名称', trigger: 'blur' }],
  templeCode: [{ required: true, message: '请输入寺院编码', trigger: 'blur' }],
  masterCode: [{ required: true, message: '请输入法师编码', trigger: 'blur' }],
  price: [{ required: true, message: '请输入价格', trigger: 'blur' }]
}

async function loadDetail() {
  if (!isEdit.value) return
  loading.value = true
  try {
    const res = await serviceApi.list({ page: 1, size: 100 })
    const target = (res.list || []).find((s) => s.id === serviceId.value)
    if (target) {
      Object.assign(form, {
        serviceName: target.serviceName,
        templeCode: target.templeCode,
        masterCode: target.masterCode,
        price: target.price,
        description: target.description,
        status: target.status as 'on_shelf' | 'off_shelf'
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
        await serviceApi.update(serviceId.value, form)
        ElMessage.success('更新成功')
      } else {
        await serviceApi.create(form)
        ElMessage.success('创建成功')
      }
      router.push('/services')
    } finally {
      saving.value = false
    }
  })
}

function handleCancel() {
  router.push('/services')
}

onMounted(() => {
  loadDetail()
})
</script>

<template>
  <div class="page-wrap" v-loading="loading">
    <PageHeader :title="isEdit ? '编辑祈福服务' : '新建祈福服务'" subtitle="配置加持服务关联的寺院、法师与价格" />

    <div class="df-card form-card">
      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-width="100px"
        label-position="right"
      >
        <el-form-item label="服务名称" prop="serviceName">
          <el-input v-model="form.serviceName" placeholder="如：财神法会加持" maxlength="60" show-word-limit />
        </el-form-item>

        <el-form-item label="寺院编码" prop="templeCode">
          <el-input v-model="form.templeCode" placeholder="如：lingyin-temple" style="width: 320px" />
        </el-form-item>

        <el-form-item label="法师编码" prop="masterCode">
          <el-input v-model="form.masterCode" placeholder="如：master-001" style="width: 320px" />
        </el-form-item>

        <el-form-item label="价格" prop="price">
          <el-input-number v-model="form.price" :min="0" :precision="2" :step="10" controls-position="right" />
          <span class="form-tip">元</span>
        </el-form-item>

        <el-form-item label="状态">
          <el-radio-group v-model="form.status">
            <el-radio value="on_shelf">上架</el-radio>
            <el-radio value="off_shelf">下架</el-radio>
          </el-radio-group>
        </el-form-item>

        <el-form-item label="服务描述">
          <el-input
            v-model="form.description"
            type="textarea"
            :rows="5"
            placeholder="请输入服务描述、流程说明等"
            maxlength="1000"
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
