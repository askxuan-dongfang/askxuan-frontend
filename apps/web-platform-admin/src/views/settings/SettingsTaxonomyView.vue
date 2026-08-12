<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import { taxonomyApi, type BeliefProfile, type IntentionTag } from '@/api/taxonomy'

const loading = ref(false)
const beliefs = ref<BeliefProfile[]>([])
const intentions = ref<IntentionTag[]>([])
const beliefVisible = ref(false)
const intentionVisible = ref(false)
const editingBelief = ref(false)
const editingIntention = ref(false)

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

function openBelief(row?: BeliefProfile) {
  editingBelief.value = !!row
  Object.assign(beliefForm, row ? { ...row } : { code: '', name: '', summary: '', description: '', coverImage: '', icon: 'sparkles', sort: beliefs.value.length * 10 + 10 })
  beliefVisible.value = true
}

async function saveBelief() {
  if (!beliefForm.code || !beliefForm.name || !beliefForm.description) return ElMessage.warning('请填写编码、名称和简介')
  const data = { ...beliefForm }
  if (editingBelief.value) {
    const { code, ...body } = data
    await taxonomyApi.updateBelief(code, body)
  } else {
    await taxonomyApi.createBelief(data)
  }
  beliefVisible.value = false
  ElMessage.success('信仰分类已保存')
  await load()
}

function openIntention(row?: IntentionTag) {
  editingIntention.value = !!row
  Object.assign(intentionForm, row ? { ...row } : { code: '', name: '', description: '', icon: 'sparkles', landingType: 'aggregate', landingValue: '', actionTitle: '', sort: intentions.value.length * 10 + 10 })
  intentionVisible.value = true
}

async function saveIntention() {
  if (!intentionForm.code || !intentionForm.name) return ElMessage.warning('请填写编码和名称')
  const data = { ...intentionForm }
  if (editingIntention.value) {
    const { code, ...body } = data
    await taxonomyApi.updateIntention(code, body)
  } else {
    await taxonomyApi.createIntention(data)
  }
  intentionVisible.value = false
  ElMessage.success('心愿分类已保存')
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
    <PageHeader title="首页分类" subtitle="统一维护 C 端信仰入口与心愿入口" />

    <section class="taxonomy-section">
      <div class="section-head"><div><h2>按信仰找</h2><p>启用的分类按排序展示在 C 端首页，并作为寺院、法师的一级流派。</p></div><el-button type="primary" :icon="Plus" @click="openBelief()">新增信仰</el-button></div>
      <el-table :data="beliefs" border>
        <el-table-column prop="sort" label="排序" width="70" />
        <el-table-column prop="name" label="名称" min-width="130" />
        <el-table-column prop="code" label="编码" min-width="170" />
        <el-table-column prop="icon" label="SF Symbol" min-width="150" />
        <el-table-column prop="summary" label="摘要" min-width="220" show-overflow-tooltip />
        <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag :type="row.status === 'enabled' ? 'success' : 'info'">{{ row.status === 'enabled' ? '启用' : '停用' }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="160"><template #default="{ row }"><el-button link type="primary" @click="openBelief(row)">编辑</el-button><el-button link :type="row.status === 'enabled' ? 'danger' : 'success'" @click="toggleBelief(row)">{{ row.status === 'enabled' ? '停用' : '启用' }}</el-button></template></el-table-column>
      </el-table>
    </section>

    <section class="taxonomy-section">
      <div class="section-head"><div><h2>按心愿办</h2><p>心愿可聚合商城商品与寺院服务，落地方式控制首页点击后的办理路径。</p></div><el-button type="primary" :icon="Plus" @click="openIntention()">新增心愿</el-button></div>
      <el-table :data="intentions" border>
        <el-table-column prop="sort" label="排序" width="70" />
        <el-table-column prop="name" label="名称" min-width="120" />
        <el-table-column prop="code" label="编码" min-width="130" />
        <el-table-column prop="icon" label="SF Symbol" min-width="150" />
        <el-table-column label="落地" min-width="150"><template #default="{ row }">{{ row.landingType }}<span v-if="row.landingValue"> · {{ row.landingValue }}</span></template></el-table-column>
        <el-table-column prop="actionTitle" label="按钮文案" min-width="150" />
        <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag :type="row.status === 'enabled' ? 'success' : 'info'">{{ row.status === 'enabled' ? '启用' : '停用' }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="160"><template #default="{ row }"><el-button link type="primary" @click="openIntention(row)">编辑</el-button><el-button link :type="row.status === 'enabled' ? 'danger' : 'success'" @click="toggleIntention(row)">{{ row.status === 'enabled' ? '停用' : '启用' }}</el-button></template></el-table-column>
      </el-table>
    </section>

    <el-dialog v-model="beliefVisible" :title="editingBelief ? '编辑信仰' : '新增信仰'" width="620px">
      <el-form :model="beliefForm" label-width="92px">
        <el-form-item label="编码" required><el-input v-model="beliefForm.code" :disabled="editingBelief" placeholder="小写字母、数字、下划线" /></el-form-item>
        <el-form-item label="名称" required><el-input v-model="beliefForm.name" /></el-form-item>
        <el-form-item label="摘要"><el-input v-model="beliefForm.summary" /></el-form-item>
        <el-form-item label="完整简介" required><el-input v-model="beliefForm.description" type="textarea" :rows="4" /></el-form-item>
        <el-form-item label="SF Symbol"><el-input v-model="beliefForm.icon" placeholder="如 leaf.fill" /></el-form-item>
        <el-form-item label="封面地址"><el-input v-model="beliefForm.coverImage" /></el-form-item>
        <el-form-item label="排序"><el-input-number v-model="beliefForm.sort" :min="0" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="beliefVisible=false">取消</el-button><el-button type="primary" @click="saveBelief">保存</el-button></template>
    </el-dialog>

    <el-dialog v-model="intentionVisible" :title="editingIntention ? '编辑心愿' : '新增心愿'" width="620px">
      <el-form :model="intentionForm" label-width="92px">
        <el-form-item label="编码" required><el-input v-model="intentionForm.code" :disabled="editingIntention" placeholder="小写字母、数字、下划线" /></el-form-item>
        <el-form-item label="名称" required><el-input v-model="intentionForm.name" /></el-form-item>
        <el-form-item label="说明"><el-input v-model="intentionForm.description" type="textarea" :rows="3" /></el-form-item>
        <el-form-item label="SF Symbol"><el-input v-model="intentionForm.icon" /></el-form-item>
        <el-form-item label="落地方式"><el-select v-model="intentionForm.landingType" style="width:100%"><el-option label="聚合页" value="aggregate" /><el-option label="服务办理" value="service" /><el-option label="DIY 定制" value="diy" /></el-select></el-form-item>
        <el-form-item v-if="intentionForm.landingType === 'service'" label="服务编码"><el-input v-model="intentionForm.landingValue" placeholder="如 S001" /></el-form-item>
        <el-form-item label="按钮文案"><el-input v-model="intentionForm.actionTitle" placeholder="如 立即办理" /></el-form-item>
        <el-form-item label="排序"><el-input-number v-model="intentionForm.sort" :min="0" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="intentionVisible=false">取消</el-button><el-button type="primary" @click="saveIntention">保存</el-button></template>
    </el-dialog>
  </div>
</template>

<style scoped>
.taxonomy-section { margin-bottom: 24px; }
.section-head { display:flex; align-items:flex-end; justify-content:space-between; gap:20px; margin-bottom:12px; }
.section-head h2 { margin:0 0 4px; font-size:17px; }
.section-head p { margin:0; color:var(--dfx-text-secondary); font-size:13px; }
</style>
