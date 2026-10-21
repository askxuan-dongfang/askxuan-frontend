<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { onMounted, reactive, ref } from 'vue'

import PageHeader from '@/components/PageHeader.vue'
import { taxonomyApi, type BeliefProfile, type IntentionTag } from '@/api/taxonomy'

const loading = ref(false)
const beliefs = ref<BeliefProfile[]>([])
const intentions = ref<IntentionTag[]>([])
const beliefVisible = ref(false)
const intentionVisible = ref(false)
const editingBelief = ref(false)
const editingIntention = ref(false)

const serviceTypeOptions = [
  { code: 'S001', name: '祈福' }, { code: 'S002', name: '供灯' },
  { code: 'S003', name: '上香' }, { code: 'S004', name: '还愿' },
  { code: 'S005', name: '超度' }, { code: 'S006', name: '开光' },
  { code: 'S007', name: '化太岁' }, { code: 'S008', name: '求姻缘' },
  { code: 'S009', name: '求财运' }, { code: 'S010', name: '求事业' },
  { code: 'S011', name: '求风水' }, { code: 'S012', name: '求健康' },
  { code: 'S013', name: '求学业' },
]

const beliefForm = reactive({ code: '', name: '', summary: '', description: '', coverImage: '', icon: 'sparkles', sort: 0 })
const intentionForm = reactive({ code: '', name: '', description: '', icon: 'sparkles', landingType: 'aggregate' as IntentionTag['landingType'], landingValue: '', actionTitle: '', sort: 0 })

async function load() {
  loading.value = true
  try {
    const [beliefRes, intentionRes] = await Promise.all([taxonomyApi.beliefs(), taxonomyApi.intentions()])
    beliefs.value = beliefRes.list || []
    intentions.value = intentionRes.list || []
  } finally {
    loading.value = false
  }
}

function openBelief(row: BeliefProfile) {
  editingBelief.value = true
  Object.assign(beliefForm, row)
  beliefVisible.value = true
}

async function saveBelief() {
  if (!editingBelief.value) return ElMessage.warning(uiText('五类信仰编码固定，请编辑已有标准'))
  if (!beliefForm.code || !beliefForm.name || !beliefForm.description) return ElMessage.warning(uiText('请填写编码、名称和简介'))
  const data = { ...beliefForm }
  const { code, ...body } = data
  await taxonomyApi.updateBelief(code, body)
  beliefVisible.value = false
  ElMessage.success(uiText('信仰分类已保存'))
  await load()
}

function openIntention(row: IntentionTag) {
  editingIntention.value = true
  Object.assign(intentionForm, row)
  intentionVisible.value = true
}

async function saveIntention() {
  if (!editingIntention.value) return ElMessage.warning(uiText('七项心愿编码固定，请编辑已有标准'))
  if (!intentionForm.code || !intentionForm.name) return ElMessage.warning(uiText('请填写编码和名称'))
  if (intentionForm.landingType === 'service' && !intentionForm.landingValue) return ElMessage.warning(uiText('请从固定目录选择服务'))
  const data = { ...intentionForm }
  const { code, ...body } = data
  await taxonomyApi.updateIntention(code, body)
  intentionVisible.value = false
  ElMessage.success(uiText('心愿分类已保存'))
  await load()
}

async function toggleBelief(row: BeliefProfile) {
  await taxonomyApi.setBeliefStatus(row.code, row.status === 'enabled' ? 'disabled' : 'enabled')
  await load()
}

async function toggleIntention(row: IntentionTag) {
  await taxonomyApi.setIntentionStatus(row.code, row.status === 'enabled' ? 'disabled' : 'enabled')
  await load()
}

onMounted(load)
</script>

<template>
  <div class="dfx-page" v-loading="loading">
    <PageHeader :title='$t("信仰与心愿标准 / 首页展示")' :subtitle='$t("标准编码唯一维护；展示文案、封面与排序引用同一编码。")' />
    <p class="standard-scope-note">{{ $t('五类主信仰与七项心愿范围固定，本页只编辑已有标准与首页展示。宗派信俗由完整标准目录维护；身份和擅长是资料选项，不代表资质或实际服务。') }}</p>

    <section class="taxonomy-section">
      <div class="section-head"><div><h2>{{ $t("按信仰找") }}</h2><p>{{ $t("五类主信仰编码固定；启用状态、排序和展示资料用于首页。") }}</p></div></div>
      <el-table :data="beliefs" border>
        <el-table-column prop="sort" :label='$t("排序")' width="70" />
        <el-table-column prop="name" :label='$t("名称")' min-width="130" />
        <el-table-column prop="code" :label='$t("编码")' min-width="170" />
        <el-table-column prop="icon" label="SF Symbol" min-width="150" />
        <el-table-column prop="summary" :label='$t("摘要")' min-width="220" show-overflow-tooltip />
        <el-table-column :label='$t("状态")' width="90"><template #default="{ row }"><el-tag :type="row.status === 'enabled' ? 'success' : 'info'">{{ $t((row.status === 'enabled' ? $t('启用') : $t('停用'))) }}</el-tag></template></el-table-column>
        <el-table-column :label='$t("操作")' width="160"><template #default="{ row }"><el-button link type="primary" @click="openBelief(row)">{{ $t("编辑") }}</el-button><el-button link :type="row.status === 'enabled' ? 'danger' : 'success'" @click="toggleBelief(row)">{{ $t((row.status === 'enabled' ? $t('停用') : $t('启用'))) }}</el-button></template></el-table-column>
      </el-table>
    </section>

    <section class="taxonomy-section">
      <div class="section-head"><div><h2>{{ $t("按心愿办") }}</h2><p>{{ $t("七项标准心愿沿用固定编码；已有历史展示入口原样保留，落地配置不新增标准。") }}</p></div></div>
      <el-table :data="intentions" border>
        <el-table-column prop="sort" :label='$t("排序")' width="70" />
        <el-table-column prop="name" :label='$t("名称")' min-width="120" />
        <el-table-column prop="code" :label='$t("编码")' min-width="130" />
        <el-table-column prop="icon" label="SF Symbol" min-width="150" />
        <el-table-column :label='$t("落地")' min-width="150"><template #default="{ row }">{{ $t(row.landingType) }}<span v-if="row.landingValue"> · {{ $t(row.landingValue) }}</span></template></el-table-column>
        <el-table-column prop="actionTitle" :label='$t("按钮文案")' min-width="150" />
        <el-table-column :label='$t("状态")' width="90"><template #default="{ row }"><el-tag :type="row.status === 'enabled' ? 'success' : 'info'">{{ $t((row.status === 'enabled' ? $t('启用') : $t('停用'))) }}</el-tag></template></el-table-column>
        <el-table-column :label='$t("操作")' width="160"><template #default="{ row }"><el-button link type="primary" @click="openIntention(row)">{{ $t("编辑") }}</el-button><el-button link :type="row.status === 'enabled' ? 'danger' : 'success'" @click="toggleIntention(row)">{{ $t((row.status === 'enabled' ? $t('停用') : $t('启用'))) }}</el-button></template></el-table-column>
      </el-table>
    </section>

    <el-dialog v-model="beliefVisible" :title="$t('编辑信仰')" width="620px" append-to-body>
      <el-form :model="beliefForm" label-width="92px">
        <el-form-item :label='$t("编码")' required><el-input v-model="beliefForm.code" disabled :placeholder='$t("小写字母、数字、下划线")' /></el-form-item>
        <el-form-item :label='$t("名称")' required><el-input v-model="beliefForm.name" /></el-form-item>
        <el-form-item :label='$t("摘要")'><el-input v-model="beliefForm.summary" /></el-form-item>
        <el-form-item :label='$t("完整简介")' required><el-input v-model="beliefForm.description" type="textarea" :rows="4" /></el-form-item>
        <el-form-item label="SF Symbol"><el-input v-model="beliefForm.icon" :placeholder='$t("如 leaf.fill")' /></el-form-item>
        <el-form-item :label='$t("封面地址")'><el-input v-model="beliefForm.coverImage" /></el-form-item>
        <el-form-item :label='$t("排序")'><el-input-number v-model="beliefForm.sort" :min="0" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="beliefVisible=false" data-quiet-action="cancel">{{ $t("取消") }}</el-button><el-button type="primary" @click="saveBelief">{{ $t("保存") }}</el-button></template>
    </el-dialog>

    <el-dialog v-model="intentionVisible" :title="$t('编辑心愿')" width="620px" append-to-body>
      <el-form :model="intentionForm" label-width="92px">
        <el-form-item :label='$t("编码")' required><el-input v-model="intentionForm.code" disabled :placeholder='$t("小写字母、数字、下划线")' /></el-form-item>
        <el-form-item :label='$t("名称")' required><el-input v-model="intentionForm.name" /></el-form-item>
        <el-form-item :label='$t("说明")'><el-input v-model="intentionForm.description" type="textarea" :rows="3" /></el-form-item>
        <el-form-item label="SF Symbol"><el-input v-model="intentionForm.icon" /></el-form-item>
        <el-form-item :label='$t("落地方式")'><el-select v-model="intentionForm.landingType" style="width:100%"><el-option :label='$t("聚合页")' value="aggregate" /><el-option :label='$t("服务办理")' value="service" /><el-option :label='$t("独立 DIY 入口（不聚合）")' value="diy" /></el-select></el-form-item>
        <el-form-item v-if="intentionForm.landingType === 'service'" :label='$t("固定服务")' required>
          <el-select v-model="intentionForm.landingValue" filterable style="width:100%" :placeholder='$t("从 S001-S013 选择")'>
            <el-option v-for="item in serviceTypeOptions" :key="item.code" :label="$t(($t('') + String(item.code) + $t(' · ') + String(item.name) + $t('')))" :value="item.code" />
          </el-select>
        </el-form-item>
        <el-form-item :label='$t("按钮文案")'><el-input v-model="intentionForm.actionTitle" :placeholder='$t("如 立即办理")' /></el-form-item>
        <el-form-item :label='$t("排序")'><el-input-number v-model="intentionForm.sort" :min="0" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="intentionVisible=false" data-quiet-action="cancel">{{ $t("取消") }}</el-button><el-button type="primary" @click="saveIntention">{{ $t("保存") }}</el-button></template>
    </el-dialog>
  </div>
</template>

<style scoped>
.standard-scope-note{font-size:13px;line-height:1.8;color:var(--dfx-text-secondary);margin:0 0 24px}.section-head{flex-wrap:wrap}
.taxonomy-section { margin-bottom: 24px; }
.section-head { display:flex; align-items:flex-end; justify-content:space-between; gap:20px; margin-bottom:12px; }
.section-head h2 { margin:0 0 4px; font-size: var(--type-size-nav); }
.section-head p { margin:0; color:var(--dfx-text-secondary); font-size: var(--type-size-label); }
</style>
