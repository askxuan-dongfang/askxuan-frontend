<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { isAdminSessionExpired } from '@/api/client'
// 新增独立执业大师：平台创建独立执业大师（无寺庙），创建后待资质审核
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'

import ProviderAffiliation from '../../../../../packages/admin-ui/components/ProviderAffiliation.vue'
import { beliefOptions as standardBeliefs } from '../../../../../packages/admin-ui/affiliation'
import PageHeader from '@/components/PageHeader.vue'
import { createWildMaster } from '@/api/master'

const router = useRouter()
const saving = ref(false)
const formRef = ref()

const affiliation = ref<InstanceType<typeof ProviderAffiliation>>()
const beliefOptions = standardBeliefs.map(item=>({value:item.code,label:item.name}))


const form = reactive({
  dharmaName: '',
  layName: '',
  position: '',
  beliefCode: 'han_buddhism',
  sect: '',
  traditionCodes: [] as string[],
  type: '汉传佛教',
  specialtiesText: '',
  consultEnabled: true,
  consultFee: 39,
  consultValidHours: 72,
  consultResponseMinutes: 30
})

function syncType() {
  form.type = beliefOptions.find(b => b.value === form.beliefCode)?.label || form.type
}

async function submit() {
  if(saving.value)return
  const problem = affiliation.value?.validate(true)
  if (!form.dharmaName.trim() || problem) {
    ElMessage.warning(uiText(problem || '请填写法号'))
    return
  }
  syncType()
  saving.value = true
  try {
    const resp = await createWildMaster({
      dharmaName: form.dharmaName.trim(),
      layName: form.layName.trim() || undefined,
      position: form.position.trim() || undefined,
      beliefCode: form.beliefCode,
      sect: form.sect.trim(),
      traditionCodes: [...form.traditionCodes],
      type: form.type,
      specialties: form.specialtiesText.split(/[,，]/).map((s) => s.trim()).filter(Boolean),
      consultEnabled: form.consultEnabled,
      consultFee: Number(form.consultFee) || 0,
      consultValidHours: Number(form.consultValidHours) || 72,
      consultResponseMinutes: Number(form.consultResponseMinutes) || 30
    })
    ElMessage.success((uiText("已创建独立执业大师 ") + String(resp.id) + uiText("，待资质审核通过后上架")))
    router.push('/master/list')
  } catch (e) { if (isAdminSessionExpired(e)) return;
    ElMessage.error(e instanceof Error ? e.message : uiText('创建失败，请稍后重试'))
  } finally {
    saving.value = false
  }
}

</script>

<template>
  <div class="page-wrap">
    <PageHeader :title='$t("新增独立执业大师")' :subtitle='$t("独立执业大师（无寺庙归属），平台认证资质后分发法师端账号；用户先付费咨询再预约服务")'>
      <template #extra>
        <el-button @click="router.push('/master/list')">{{ $t("返回列表") }}</el-button>
      </template>
    </PageHeader>

    <div class="df-card" style="max-width: 760px">
      <el-form ref="formRef" :model="form" label-width="120px">
        <el-form-item :label='$t("法号")' required>
          <el-input v-model="form.dharmaName" :placeholder='$t("如：云游道人")' maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("俗名")'>
          <el-input v-model="form.layName" :placeholder='$t("如：陈道玄")' maxlength="32" />
        </el-form-item>
        <el-form-item label-width="0">
          <ProviderAffiliation ref="affiliation" v-model:belief="form.beliefCode" v-model:codes="form.traditionCodes" :disabled="saving" />
        </el-form-item>
        <el-form-item :label='$t("宗派补充说明")'>
          <el-input v-model="form.sect" :placeholder='$t("可选；不作为标准筛选关联")' maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("职位")'>
          <el-input v-model="form.position" :placeholder='$t("如：独立道长")' maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("专长")'>
          <el-input v-model="form.specialtiesText" :placeholder='$t("逗号分隔，如：八字命理,风水堪舆")' />
        </el-form-item>
        <el-form-item :label='$t("开通付费咨询")'>
          <el-switch v-model="form.consultEnabled" />
        </el-form-item>
        <el-form-item v-if="form.consultEnabled" :label='$t("咨询费（元）")'>
          <el-input-number v-model="form.consultFee" :min="0" :precision="2" style="width: 160px" />
        </el-form-item>
        <el-form-item v-if="form.consultEnabled" :label='$t("咨询有效期")'>
          <el-input-number v-model="form.consultValidHours" :min="1" style="width: 120px" />
          <span class="text-sm text-muted" style="margin-left: 8px">{{ $t("小时") }}</span>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="submit">{{ $t("创建独立执业大师") }}</el-button>
          <span class="text-sm text-muted" style="margin-left: 12px">{{ $t("创建后状态为「待审核」，需在法师审核页认证资质后上架") }}</span>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>
