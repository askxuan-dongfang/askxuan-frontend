<script setup lang="ts">
// 法师详情 / 平台编辑（野生大师无寺庙归属，平台为唯一管理方）
// 含「可提供服务」标签（master_service_tag，S001-S013）查看与配置
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import {
  getPlatformMasterDetail,
  updatePlatformMaster,
  getServiceTypes,
  getPlatformMasterServiceTags,
  updatePlatformMasterServiceTags,
  type ServiceTypeOption,
  type MasterServiceTagItem
} from '@/api/master'
import type { Master } from '@/types'

const route = useRoute()
const router = useRouter()

const masterId = computed(() => (route.params.id as string) || '')
const loading = ref(false)
const saving = ref(false)
const editing = ref(false)
const master = ref<Master | null>(null)
const serviceCatalog = ref<ServiceTypeOption[]>([])
const serviceTags = ref<MasterServiceTagItem[]>([])

const beliefOptions = [
  { value: 'han_buddhism', label: '汉传佛教' },
  { value: 'tibetan_buddhism', label: '藏传佛教' },
  { value: 'taoism', label: '道教' }
]
const beliefName = (code: string) => beliefOptions.find((b) => b.value === code)?.label || code
const serviceName = (code: string) => serviceCatalog.value.find((s) => s.code === code)?.name || code

const form = ref({
  dharmaName: '',
  layName: '',
  position: '',
  beliefCode: 'han_buddhism',
  sect: '',
  type: '',
  specialties: [] as string[],
  avatar: ''
})
const tagInput = ref('')

// 可提供服务编辑态：每个目录项对应一个启用开关 + 定价
const tagEdits = ref<{ code: string; name: string; enabled: boolean; price: number }[]>([])

async function loadDetail() {
  loading.value = true
  try {
    const [m, catalog, tags] = await Promise.all([
      getPlatformMasterDetail(masterId.value),
      getServiceTypes(),
      getPlatformMasterServiceTags(masterId.value)
    ])
    master.value = m
    serviceCatalog.value = catalog.list || []
    serviceTags.value = tags.list || []
  } catch {
    ElMessage.error('加载法师详情失败')
  } finally {
    loading.value = false
  }
}

function startEdit() {
  if (!master.value) return
  form.value = {
    dharmaName: master.value.dharmaName,
    layName: master.value.layName,
    position: master.value.position,
    beliefCode: master.value.beliefCode,
    sect: master.value.sect,
    type: master.value.type,
    specialties: [...(master.value.specialties || [])],
    avatar: master.value.avatar
  }
  const current = new Map(serviceTags.value.map((t) => [t.serviceCode, t.price]))
  tagEdits.value = (serviceCatalog.value || []).map((s) => ({
    code: s.code,
    name: s.name,
    enabled: current.has(s.code),
    price: current.get(s.code) ?? 0
  }))
  editing.value = true
}

function cancelEdit() {
  editing.value = false
}

function addTag() {
  const v = tagInput.value.trim()
  if (v && !form.value.specialties.includes(v)) {
    form.value.specialties.push(v)
  }
  tagInput.value = ''
}
function removeTag(t: string) {
  form.value.specialties = form.value.specialties.filter((x) => x !== t)
}

function syncType() {
  const map: Record<string, string> = {
    han_buddhism: '汉传佛教',
    tibetan_buddhism: '藏传佛教',
    taoism: '道教'
  }
  form.value.type = map[form.value.beliefCode] || form.value.type
}

async function save() {
  if (!form.value.dharmaName.trim() || !form.value.sect.trim()) {
    ElMessage.warning('请填写法号与宗派')
    return
  }
  saving.value = true
  try {
    master.value = await updatePlatformMaster(masterId.value, {
      dharmaName: form.value.dharmaName.trim(),
      layName: form.value.layName.trim() || undefined,
      position: form.value.position.trim() || undefined,
      beliefCode: form.value.beliefCode,
      sect: form.value.sect.trim(),
      type: form.value.type,
      specialties: form.value.specialties,
      avatar: form.value.avatar
    })
    // 可提供服务标签：覆盖式保存（仅保存启用的项）
    const tags: MasterServiceTagItem[] = tagEdits.value
      .filter((t) => t.enabled)
      .map((t) => ({ serviceCode: t.code, price: Number(t.price) || 0 }))
    const saved = await updatePlatformMasterServiceTags(masterId.value, tags)
    serviceTags.value = saved.list || []
    ElMessage.success('法师资料与服务标签已更新')
    editing.value = false
  } catch {
    ElMessage.error('保存失败，请稍后重试')
  } finally {
    saving.value = false
  }
}

onMounted(loadDetail)
</script>

<template>
  <div class="dfx-page" v-loading="loading">
    <PageHeader title="法师详情" subtitle="法师资料、可提供服务查看与平台编辑（寺院+野生两类大师）">
      <template #actions>
        <el-button @click="router.push('/master/list')">返回列表</el-button>
        <el-button v-if="master && !editing" type="primary" @click="startEdit">编辑资料</el-button>
      </template>
    </PageHeader>

    <!-- 查看态 -->
    <div v-if="master && !editing" class="df-card" style="max-width: 760px">
      <div class="master-head">
        <el-avatar :size="64" :src="master.avatar">{{ master.dharmaName.slice(0, 1) }}</el-avatar>
        <div class="master-head__info">
          <div class="master-head__name">
            {{ master.dharmaName }}
            <span class="master-head__lay">（{{ master.layName || '未填俗名' }}）</span>
            <el-tag :type="master.manageBy === 'platform' ? 'success' : 'info'" size="small" style="margin-left: 8px">
              {{ master.manageBy === 'platform' ? '野生·平台直管' : '寺庙绑定' }}
            </el-tag>
          </div>
          <div class="master-head__id">编码 {{ master.id }}</div>
        </div>
      </div>

      <el-descriptions :column="2" border style="margin-top: 16px">
        <el-descriptions-item label="管理方">
          {{ master.manageBy === 'platform' ? '平台（野生大师）' : '寺庙绑定' }}
        </el-descriptions-item>
        <el-descriptions-item label="所属寺院">{{ master.templeName || '—' }}</el-descriptions-item>
        <el-descriptions-item label="职位">{{ master.position || '—' }}</el-descriptions-item>
        <el-descriptions-item label="一级流派">{{ beliefName(master.beliefCode) }}</el-descriptions-item>
        <el-descriptions-item label="宗派">{{ master.sect || '—' }}</el-descriptions-item>
        <el-descriptions-item label="类型">{{ master.type || '—' }}</el-descriptions-item>
        <el-descriptions-item label="专长" :span="2">
          <el-tag v-for="s in master.specialties" :key="s" size="small" effect="plain" style="margin-right: 6px">{{ s }}</el-tag>
          <span v-if="!master.specialties?.length">—</span>
        </el-descriptions-item>
        <el-descriptions-item label="可提供服务" :span="2">
          <el-tag v-for="t in serviceTags" :key="t.serviceCode" size="small" style="margin-right: 6px">
            {{ serviceName(t.serviceCode) }} ¥{{ t.price }}
          </el-tag>
          <span v-if="!serviceTags.length" class="muted-text">未配置（C端按可提供服务筛选，野生大师上架前提）</span>
        </el-descriptions-item>
        <el-descriptions-item label="认证状态"><StatusTag :status="master.authStatus" /></el-descriptions-item>
        <el-descriptions-item label="上架状态"><StatusTag :status="master.shelfStatus" /></el-descriptions-item>
        <el-descriptions-item label="平台状态"><StatusTag :status="master.platformStatus" /></el-descriptions-item>
        <el-descriptions-item label="评分">★ {{ master.rating?.toFixed(1) }}</el-descriptions-item>
        <el-descriptions-item label="即时咨询">
          {{ master.consultEnabled ? `¥${master.consultFee} / ${master.consultValidHours}小时 / 首响${master.consultResponseMinutes}分钟` : '未开放' }}
        </el-descriptions-item>
        <el-descriptions-item label="头像">{{ master.avatar || '—' }}</el-descriptions-item>
      </el-descriptions>
    </div>

    <!-- 编辑态 -->
    <div v-else-if="master" class="df-card" style="max-width: 640px">
      <el-form label-width="110px">
        <el-form-item label="法号" required>
          <el-input v-model="form.dharmaName" maxlength="32" />
        </el-form-item>
        <el-form-item label="俗名">
          <el-input v-model="form.layName" maxlength="32" />
        </el-form-item>
        <el-form-item label="职位">
          <el-input v-model="form.position" maxlength="32" />
        </el-form-item>
        <el-form-item label="一级流派" required>
          <el-select v-model="form.beliefCode" style="width: 100%" @change="syncType">
            <el-option v-for="b in beliefOptions" :key="b.value" :label="b.label" :value="b.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="宗派" required>
          <el-input v-model="form.sect" maxlength="32" />
        </el-form-item>
        <el-form-item label="类型">
          <el-input v-model="form.type" maxlength="16" />
        </el-form-item>
        <el-form-item label="专长">
          <div style="width: 100%">
            <el-tag v-for="t in form.specialties" :key="t" closable style="margin: 0 6px 6px 0" @close="removeTag(t)">{{ t }}</el-tag>
            <el-input v-model="tagInput" size="small" style="width: 140px" placeholder="输入后回车" @keyup.enter="addTag" />
          </div>
        </el-form-item>
        <el-form-item label="头像">
          <ImageUploader v-model="form.avatar" />
        </el-form-item>

        <el-divider content-position="left">可提供服务（S001-S013 大师标签）</el-divider>
        <el-form-item label="服务配置">
          <div style="width: 100%">
            <div v-for="t in tagEdits" :key="t.code" class="tag-row">
              <el-switch v-model="t.enabled" />
              <span class="tag-row__name">{{ t.name }}</span>
              <span class="tag-row__code">{{ t.code }}</span>
              <el-input-number
                v-if="t.enabled"
                v-model="t.price"
                :min="0"
                :precision="2"
                size="small"
                style="width: 130px"
                placeholder="定价"
              />
            </div>
          </div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="save">保存</el-button>
          <el-button @click="cancelEdit">取消</el-button>
        </el-form-item>
      </el-form>
    </div>
  </div>
</template>

<style scoped>
.master-head {
  display: flex;
  align-items: center;
  gap: 16px;
}
.master-head__name {
  font-size: 18px;
  font-weight: 700;
  color: var(--color-text-primary);
}
.master-head__lay {
  font-weight: 400;
  color: var(--color-text-tertiary);
  font-size: 13px;
}
.master-head__id {
  margin-top: 4px;
  font-size: 12px;
  color: var(--color-text-tertiary);
}
.muted-text {
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.tag-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
}
.tag-row__name {
  min-width: 72px;
  font-size: 13px;
  color: var(--color-text-primary);
}
.tag-row__code {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
</style>
