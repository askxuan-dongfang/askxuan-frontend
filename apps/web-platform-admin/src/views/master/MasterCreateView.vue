<script setup lang="ts">
// 新增野生大师：平台创建独立执业大师（无寺庙），创建后待资质审核
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import { createWildMaster } from '@/api/master'

const router = useRouter()
const saving = ref(false)
const formRef = ref()

const beliefOptions = [
  { value: 'han_buddhism', label: '汉传佛教' },
  { value: 'tibetan_buddhism', label: '藏传佛教' },
  { value: 'taoism', label: '道教' }
]

const form = reactive({
  dharmaName: '',
  layName: '',
  position: '',
  beliefCode: 'han_buddhism',
  sect: '',
  type: '汉传佛教',
  specialtiesText: '',
  consultEnabled: true,
  consultFee: 39,
  consultValidHours: 72,
  consultResponseMinutes: 30
})

function syncType() {
  const map: Record<string, string> = {
    han_buddhism: '汉传佛教',
    tibetan_buddhism: '藏传佛教',
    taoism: '道教'
  }
  form.type = map[form.beliefCode] || '汉传佛教'
}

async function submit() {
  if (!form.dharmaName.trim() || !form.sect.trim()) {
    ElMessage.warning('请填写法号与宗派')
    return
  }
  saving.value = true
  try {
    const resp = await createWildMaster({
      dharmaName: form.dharmaName.trim(),
      layName: form.layName.trim() || undefined,
      position: form.position.trim() || undefined,
      beliefCode: form.beliefCode,
      sect: form.sect.trim(),
      type: form.type,
      specialties: form.specialtiesText.split(/[,，]/).map((s) => s.trim()).filter(Boolean),
      consultEnabled: form.consultEnabled,
      consultFee: Number(form.consultFee) || 0,
      consultValidHours: Number(form.consultValidHours) || 72,
      consultResponseMinutes: Number(form.consultResponseMinutes) || 30
    })
    ElMessage.success(`已创建野生大师 ${resp.id}，待资质审核通过后上架`)
    router.push('/master/list')
  } catch (e) {
    ElMessage.error('创建失败，请稍后重试')
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="page-wrap">
    <PageHeader title="新增野生大师" subtitle="独立执业大师（无寺庙归属），平台认证资质后分发法师端账号；用户先付费咨询再预约服务">
      <template #extra>
        <el-button @click="router.push('/master/list')">返回列表</el-button>
      </template>
    </PageHeader>

    <div class="df-card" style="max-width: 640px">
      <el-form ref="formRef" :model="form" label-width="120px">
        <el-form-item label="法号" required>
          <el-input v-model="form.dharmaName" placeholder="如：云游道人" maxlength="32" />
        </el-form-item>
        <el-form-item label="俗名">
          <el-input v-model="form.layName" placeholder="如：陈道玄" maxlength="32" />
        </el-form-item>
        <el-form-item label="一级流派" required>
          <el-select v-model="form.beliefCode" style="width: 100%" @change="syncType">
            <el-option v-for="b in beliefOptions" :key="b.value" :label="b.label" :value="b.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="宗派" required>
          <el-input v-model="form.sect" placeholder="如：正一派" maxlength="32" />
        </el-form-item>
        <el-form-item label="职位">
          <el-input v-model="form.position" placeholder="如：独立道长" maxlength="32" />
        </el-form-item>
        <el-form-item label="专长">
          <el-input v-model="form.specialtiesText" placeholder="逗号分隔，如：八字命理,风水堪舆" />
        </el-form-item>
        <el-form-item label="开通付费咨询">
          <el-switch v-model="form.consultEnabled" />
        </el-form-item>
        <el-form-item v-if="form.consultEnabled" label="咨询费（元）">
          <el-input-number v-model="form.consultFee" :min="0" :precision="2" style="width: 160px" />
        </el-form-item>
        <el-form-item v-if="form.consultEnabled" label="咨询有效期">
          <el-input-number v-model="form.consultValidHours" :min="1" style="width: 120px" />
          <span class="text-sm text-muted" style="margin-left: 8px">小时</span>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="submit">创建野生大师</el-button>
          <span class="text-sm text-muted" style="margin-left: 12px">创建后状态为「待审核」，需在法师审核页认证资质后上架</span>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>
