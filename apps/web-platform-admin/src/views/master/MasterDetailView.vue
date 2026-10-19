<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { isAdminSessionExpired } from '@/api/client'
// 法师详情 / 平台编辑（独立执业大师无寺庙归属，平台为唯一管理方）
// 含「可提供服务」标签（master_service_tag，S001-S013）查看与配置
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { getPublicDirectoryTags, type DirectoryTag } from '@/api/directoryTags'
import { taxonomyApi } from '@/api/taxonomy'
import ProviderDirectoryTags from '@/components/ProviderDirectoryTags.vue'
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
const loadError = ref('')
const serviceCatalog = ref<ServiceTypeOption[]>([])
const serviceTags = ref<MasterServiceTagItem[]>([])

const beliefOptions = ref<{value:string;label:string}[]>([])
async function loadBeliefs(){
 try{const data=await taxonomyApi.beliefs();beliefOptions.value=data.list.filter(b=>b.status==='enabled').map(b=>({value:b.code,label:b.name}))}
 catch(sessionError) { if (isAdminSessionExpired(sessionError)) return;ElMessage.error(uiText('分类加载失败，请刷新重试'))}
}

const beliefName = (code: string) => beliefOptions.value.find((b) => b.value === code)?.label || code
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
const directoryTags = ref<DirectoryTag[]>([])
onMounted(async()=>{try{directoryTags.value=(await getPublicDirectoryTags()).list}catch{ElMessage.error(uiText('筛选标签加载失败'))}})

// 可提供服务编辑态：每个目录项对应一个启用开关 + 定价
const tagEdits = ref<{ code: string; name: string; enabled: boolean; price: number }[]>([])

async function loadDetail() {
  loading.value = true
  loadError.value = ''
  try {
    const [m, catalog, tags] = await Promise.all([
      getPlatformMasterDetail(masterId.value),
      getServiceTypes(),
      getPlatformMasterServiceTags(masterId.value)
    ])
    if (!m || typeof m.dharmaName !== 'string' || !m.dharmaName.trim()) {
      throw new Error('法师详情数据结构不完整')
    }
    master.value = { ...m, specialties: m.specialties || [] }
    serviceCatalog.value = catalog.list || []
    serviceTags.value = tags.list || []
  } catch (error) { if (isAdminSessionExpired(error)) return;
    master.value = null
    loadError.value = error instanceof Error ? error.message : '加载法师详情失败'
    ElMessage.error(uiText('加载法师详情失败'))
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
  form.value.type = beliefOptions.value.find(b => b.value === form.value.beliefCode)?.label || form.value.type
}

async function save() {
  if (!form.value.dharmaName.trim() || !form.value.sect.trim()) {
    ElMessage.warning(uiText('请填写法号与宗派'))
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
    ElMessage.success(uiText('法师资料与服务标签已更新'))
    editing.value = false
  } catch (sessionError) { if (isAdminSessionExpired(sessionError)) return;
    ElMessage.error(uiText('保存失败，请稍后重试'))
  } finally {
    saving.value = false
  }
}

onMounted(() => { void loadBeliefs(); void loadDetail() })
</script>

<template>
  <div class="dfx-page" v-loading="loading">
    <PageHeader :title='$t("法师详情")' :subtitle='$t("法师资料、可提供服务查看与平台编辑（寺院与独立执业两类大师）")'>
      <template #actions>
        <el-button @click="router.push('/master/list')">{{ $t("返回列表") }}</el-button>
        <el-button v-if="master && !editing" type="primary" @click="startEdit">{{ $t("编辑资料") }}</el-button>
      </template>
    </PageHeader>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t("法师详情加载失败") }}</div><div class="ax-page-feedback__description">{{ $t(loadError) }}{{ $t("，未展示的数据不会按空资料处理。") }}</div></div>
      <el-button :loading="loading" @click="loadDetail">{{ $t("重新加载") }}</el-button>
    </div>

    <!-- 查看态 -->
    <div v-if="master && !editing" class="df-card" style="max-width: 760px">
      <div class="master-head">
        <el-avatar :size="64" :src="master.avatar">{{ $t(master.dharmaName.slice(0, 1)) }}</el-avatar>
        <div class="master-head__info">
          <div class="master-head__name">
            {{ $t(master.dharmaName) }}
            <span class="master-head__lay">（{{ $t((master.layName || $t('未填俗名'))) }}）</span>
            <el-tag :type="master.manageBy === 'platform' ? 'success' : 'info'" size="small" style="margin-left: 8px">
              {{ $t((master.manageBy === 'platform' ? $t('独立执业 · 平台管理') : $t('寺庙绑定'))) }}
            </el-tag>
          </div>
          <div class="master-head__id">{{ $t("编码 ") }}{{ $t(master.id) }}</div>
        </div>
      </div>

      <el-descriptions :column="2" border style="margin-top: 16px">
        <el-descriptions-item :label='$t("管理方")'>
          {{ $t((master.manageBy === 'platform' ? $t('平台（独立执业大师）') : $t('寺庙绑定'))) }}
        </el-descriptions-item>
        <el-descriptions-item :label='$t("所属寺院")'>{{ master.templeName || '—' }}</el-descriptions-item>
        <el-descriptions-item :label='$t("职位")'>{{ $t((master.position || '—')) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("一级流派")'>{{ $t(beliefName(master.beliefCode)) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("信俗标签")' :span="2"><ProviderDirectoryTags kind="master" :id="master.id" :name="master.dharmaName" @updated="loadDetail"/></el-descriptions-item>
        <el-descriptions-item :label='$t("宗派")'>{{ $t((master.sect || '—')) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("类型")'>{{ $t((master.type || '—')) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("专长")' :span="2">
          <el-tag v-for="s in master.specialties" :key="s" size="small" effect="plain" style="margin-right: 6px">{{ $t(s) }}</el-tag>
          <span v-if="!master.specialties?.length">—</span>
        </el-descriptions-item>
        <el-descriptions-item :label='$t("可提供服务")' :span="2">
          <el-tag v-for="t in serviceTags" :key="t.serviceCode" size="small" style="margin-right: 6px">
            {{ $t(serviceName(t.serviceCode)) }} ¥{{ $t(t.price) }}
          </el-tag>
          <span v-if="!serviceTags.length" class="muted-text">{{ $t("未配置（C端按可提供服务筛选，独立执业大师上架前提）") }}</span>
        </el-descriptions-item>
        <el-descriptions-item :label='$t("认证状态")'><StatusTag :status="master.authStatus" /></el-descriptions-item>
        <el-descriptions-item :label='$t("上架状态")'><StatusTag :status="master.shelfStatus" /></el-descriptions-item>
        <el-descriptions-item :label='$t("平台状态")'><StatusTag :status="master.platformStatus" /></el-descriptions-item>
        <el-descriptions-item :label='$t("评分")'>★ {{ $t(master.rating?.toFixed(1)) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("即时咨询")'>
          {{ $t((master.consultEnabled ? ($t("¥") + String(master.consultFee) + $t(" / ") + String(master.consultValidHours) + $t("小时 / 首响") + String(master.consultResponseMinutes) + $t("分钟")) : $t('未开放'))) }}
        </el-descriptions-item>
        <el-descriptions-item :label='$t("头像")'>{{ $t((master.avatar || '—')) }}</el-descriptions-item>
      </el-descriptions>
    </div>

    <!-- 编辑态 -->
    <div v-else-if="master" class="df-card" style="max-width: 640px">
      <el-form label-width="110px">
        <el-form-item :label='$t("法号")' required>
          <el-input v-model="form.dharmaName" maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("俗名")'>
          <el-input v-model="form.layName" maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("职位")'>
          <el-select v-model="form.position" filterable allow-create default-first-option style="width:100%"><el-option v-for="tag in directoryTags.filter(t=>t.group==='position')" :key="tag.code" :value="tag.value" :label="$t(tag.name)"/></el-select>
        </el-form-item>
        <el-form-item :label='$t("一级流派")' required>
          <el-select v-model="form.beliefCode" style="width: 100%" @change="syncType">
            <el-option v-for="b in beliefOptions" :key="b.value" :label="$t(b.label)" :value="b.value" />
          </el-select>
        </el-form-item>
        <el-form-item :label='$t("宗派")' required>
          <el-input v-model="form.sect" maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("类型")'>
          <el-input v-model="form.type" maxlength="16" />
        </el-form-item>
        <el-form-item :label='$t("专长")'><el-select v-model="form.specialties" multiple filterable allow-create default-first-option style="width:100%"><el-option v-for="tag in directoryTags.filter(t=>t.group==='specialty')" :key="tag.code" :value="tag.value" :label="$t(tag.name)"/></el-select></el-form-item>
        <el-form-item :label='$t("头像")'>
          <ImageUploader v-model="form.avatar" />
        </el-form-item>

        <el-divider content-position="left">{{ $t("可提供服务（S001-S013 大师标签）") }}</el-divider>
        <el-form-item :label='$t("服务配置")'>
          <div style="width: 100%">
            <div v-for="t in tagEdits" :key="t.code" class="tag-row">
              <el-switch v-model="t.enabled" />
              <span class="tag-row__name">{{ $t(t.name) }}</span>
              <span class="tag-row__code">{{ $t(t.code) }}</span>
              <el-input-number
                v-if="t.enabled"
                v-model="t.price"
                :min="0"
                :precision="2"
                size="small"
                style="width: 130px"
                :placeholder='$t("定价")'
              />
            </div>
          </div>
        </el-form-item>

        <el-form-item>
          <el-button type="primary" :loading="saving" @click="save">{{ $t("保存") }}</el-button>
          <el-button @click="cancelEdit" data-quiet-action="cancel">{{ $t("取消") }}</el-button>
        </el-form-item>
      </el-form>
    </div>
    <div v-else-if="!loading && !loadError" class="df-card detail-empty">{{ $t("未找到该法师资料") }}</div>
  </div>
</template>

<style scoped>
.master-head {
  display: flex;
  align-items: center;
  gap: 16px;
}
.master-head__name {
  font-size: var(--type-size-card);
  font-weight: var(--type-weight-semibold);
  color: var(--color-text-primary);
}
.master-head__lay {
  font-weight: var(--type-weight-regular);
  color: var(--color-text-tertiary);
  font-size: var(--type-size-label);
}
.master-head__id {
  margin-top: 4px;
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
.muted-text {
  color: var(--color-text-tertiary);
  font-size: var(--type-size-caption);
}
.tag-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
}
.tag-row__name {
  min-width: 72px;
  font-size: var(--type-size-label);
  color: var(--color-text-primary);
}
.tag-row__code {
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
.detail-empty {
  max-width: 760px;
  padding: 40px 16px;
  color: var(--color-text-tertiary);
  text-align: center;
}
</style>
