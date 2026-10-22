<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { isAdminSessionExpired } from '@/api/client'
// 法师详情 / 平台编辑（独立执业大师无寺庙归属，平台为唯一管理方）
// 含「可提供服务」标签（master_service_tag，S001-S013）查看与配置
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { beliefOptions as standardBeliefs, normalizeBelief } from '../../../../../packages/admin-ui/affiliation'

import { getDirectoryTags, getPublicDirectoryTags, type DirectoryTag } from '@/api/directoryTags'
import ProviderDirectoryTags from '@/components/ProviderDirectoryTags.vue'
import PageHeader from '@/components/PageHeader.vue'
import SubjectAccounts from '@/components/SubjectAccounts.vue'
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

const auth=useAuthStore()
const route = useRoute()
const router = useRouter()

const masterId = computed(() => (route.params.id as string) || '')
const loading = ref(false)
const saving = ref(false)
const serviceSaving=ref(false),profileReceipt=ref(''),serviceReceipt=ref(''),profileFailed=ref(false),serviceFailed=ref(false)
const profileBaseline=ref(''),serviceBaseline=ref('')
const editing = ref(false)
const master = ref<Master | null>(null)
const loadError = ref('')
const serviceCatalog = ref<ServiceTypeOption[]>([])
const servicesReady=ref(false),serviceLoading=ref(false),serviceLoadError=ref('')
const serviceTags = ref<MasterServiceTagItem[]>([])

const beliefOptions=standardBeliefs.map(item=>({value:item.code,label:item.name}))

const beliefName = (code: string) => beliefOptions.find((b) => b.value === normalizeBelief(code))?.label || code
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
const beliefRelationConflict=computed(()=>{
  const current=master.value
  if(!current||normalizeBelief(current.beliefCode)===form.value.beliefCode)return false
  return (current.traditionCodes||[]).some(code=>!directoryTags.value.some(tag=>tag.code===code&&normalizeBelief(tag.beliefCode||'')===form.value.beliefCode))
})
const tagInput = ref('')
const directoryTags = ref<DirectoryTag[]>([])
onMounted(async()=>{try{directoryTags.value=(await (auth.roles.includes('platform_super')?getDirectoryTags():getPublicDirectoryTags())).list}catch{ElMessage.error(uiText('筛选标签加载失败'))}})

// 可提供服务编辑态：每个目录项对应一个启用开关 + 定价
const tagEdits = ref<{ code: string; name: string; enabled: boolean; price: number }[]>([])

function resetServiceDraft() {
  const current = new Map(serviceTags.value.map(t => [t.serviceCode, t.price]))
  tagEdits.value = serviceCatalog.value.map(s => ({ code:s.code, name:s.name, enabled:current.has(s.code), price:current.get(s.code) ?? 0 }))
  serviceBaseline.value=JSON.stringify(tagEdits.value)
}
async function loadServiceConfig() {
  serviceLoading.value=true;servicesReady.value=false;serviceLoadError.value=''
  try {
    const [catalog,tags]=await Promise.all([getServiceTypes(),getPlatformMasterServiceTags(masterId.value)])
    serviceCatalog.value=catalog.list||[];serviceTags.value=tags.list||[];servicesReady.value=true
    if(editing.value)resetServiceDraft()
  } catch(error) {
    if(isAdminSessionExpired(error))return
    serviceLoadError.value=error instanceof Error?error.message:'服务加载失败'
  } finally {serviceLoading.value=false}
}
async function loadDetail() {
  loading.value=true;loadError.value=''
  const serviceRequest=loadServiceConfig()
  try {
    const m=await getPlatformMasterDetail(masterId.value)
    if(!m||typeof m.dharmaName!=='string'||!m.dharmaName.trim())throw new Error('法师详情数据结构不完整')
    master.value={...m,specialties:m.specialties||[]}
  } catch(error) {
    if(!isAdminSessionExpired(error)){
      master.value=null;loadError.value=error instanceof Error?error.message:'加载法师详情失败'
    }
  } finally {await serviceRequest;loading.value=false}
}

function startEdit() {
  if (!master.value || !auth.roles.includes('platform_super')) return
  form.value = {
    dharmaName: master.value.dharmaName,
    layName: master.value.layName,
    position: master.value.position,
    beliefCode: normalizeBelief(master.value.beliefCode),
    sect: master.value.sect,
    type: master.value.type,
    specialties: [...(master.value.specialties || [])],
    avatar: master.value.avatar
  }
  if(servicesReady.value)resetServiceDraft()
  else tagEdits.value=[]
  profileBaseline.value=JSON.stringify(form.value);serviceBaseline.value=JSON.stringify(tagEdits.value)
  profileReceipt.value='';serviceReceipt.value='';profileFailed.value=false;serviceFailed.value=false
  editing.value = true
}

const dirty=computed(()=>editing.value&&(JSON.stringify(form.value)!==profileBaseline.value||JSON.stringify(tagEdits.value)!==serviceBaseline.value))
async function confirmLeave(){if(!dirty.value)return true;try{await ElMessageBox.confirm(uiText('还有未保存的修改，离开将丢弃这些草稿。已保存的内容不会回滚。'),uiText('未保存的修改'),{confirmButtonText:uiText('放弃草稿并离开'),cancelButtonText:uiText('继续编辑'),type:'warning'});return true}catch{return false}}
async function cancelEdit(){if(await confirmLeave())editing.value=false}
onBeforeRouteLeave(async()=>await confirmLeave())
function beforeUnload(event:BeforeUnloadEvent){if(dirty.value){event.preventDefault();event.returnValue=''}}
onMounted(()=>window.addEventListener('beforeunload',beforeUnload))
onUnmounted(()=>window.removeEventListener('beforeunload',beforeUnload))


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
  form.value.type = beliefOptions.find(b => b.value === form.value.beliefCode)?.label || form.value.type
}

async function saveProfile() {
  if (beliefRelationConflict.value) { ElMessage.warning(uiText('已有选择与当前主信仰或有效目录不一致。请明确核对后调整，不会自动清空。')); return }
  if (!form.value.dharmaName.trim()) { ElMessage.warning(uiText('请填写法号')); return }
  if (saving.value) return
  const submitted = JSON.parse(JSON.stringify(form.value)) as typeof form.value
  saving.value = true;profileFailed.value=false;profileReceipt.value=''
  try {
    master.value = await updatePlatformMaster(masterId.value, {
      dharmaName: submitted.dharmaName.trim(), layName: submitted.layName.trim() || undefined,
      position: submitted.position.trim() || undefined,
      ...(auth.roles.includes('platform_super')?{beliefCode:submitted.beliefCode}:{}),
      sect: submitted.sect.trim(), type: submitted.type,
      specialties: submitted.specialties, avatar: submitted.avatar
    })
    profileBaseline.value=JSON.stringify(submitted)
    profileReceipt.value='资料已保存，服务草稿仍独立保留'
    ElMessage.success(uiText('资料已保存'))
  } catch (error) {
    if (isAdminSessionExpired(error)) return
    profileFailed.value=true;profileReceipt.value=error instanceof Error?error.message:'资料保存失败，草稿已保留，可单独重试'
  } finally { saving.value=false }
}
async function saveServices() {
  if (serviceSaving.value || !servicesReady.value) return
  const submitted = JSON.parse(JSON.stringify(tagEdits.value)) as typeof tagEdits.value
  serviceSaving.value=true;serviceFailed.value=false;serviceReceipt.value=''
  try {
    const tags:MasterServiceTagItem[]=submitted.filter(t=>t.enabled).map(t=>({serviceCode:t.code,price:Number(t.price)||0}))
    const saved=await updatePlatformMasterServiceTags(masterId.value,tags)
    serviceTags.value=saved.list||[];serviceBaseline.value=JSON.stringify(submitted)
    serviceReceipt.value='服务已保存，资料草稿不会被提交'
    ElMessage.success(uiText('服务已保存'))
  } catch(error) {
    if (isAdminSessionExpired(error)) return
    serviceFailed.value=true;serviceReceipt.value=error instanceof Error?error.message:'服务保存失败，草稿已保留，可仅重试服务'
  } finally {serviceSaving.value=false}
}

onMounted(() => { void loadDetail() })
</script>

<template>
  <div class="dfx-page" v-loading="loading">
    <PageHeader :title='$t("法师详情")' :subtitle='$t("法师资料、可提供服务查看与平台编辑（寺院与独立执业两类大师）")'>
      <template #actions>
        <el-button @click="router.push('/master/list')">{{ $t("返回列表") }}</el-button>
        <el-button v-if="master && !editing && auth.roles.includes('platform_super')" type="primary" @click="startEdit">{{ $t("编辑资料") }}</el-button>
      </template>
    </PageHeader>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t("法师详情加载失败") }}</div><div class="ax-page-feedback__description">{{ $t(loadError) }}{{ $t("，未展示的数据不会按空资料处理。") }}</div></div>
      <el-button :loading="loading" @click="loadDetail">{{ $t("重新加载") }}</el-button>
    </div>

    <div v-if="serviceLoadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy"><div class="ax-page-feedback__title">{{ $t('服务加载失败') }}</div><div class="ax-page-feedback__description">{{ $t(serviceLoadError) }}{{ $t('，未展示的数据不会按空资料处理。') }}</div></div>
      <el-button :loading="serviceLoading" @click="loadServiceConfig">{{ $t('重新加载') }}</el-button>
    </div>
    <!-- 查看态 -->
    <SubjectAccounts v-if="master && !editing" kind="master" :id="master.id" />
    <div v-if="master && !editing && auth.roles.includes('platform_super')" class="df-card" style="max-width: 760px">
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
        <el-descriptions-item :label='$t("主信仰")'>{{ $t(beliefName(master.beliefCode)) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("标准宗派 / 信俗")' :span="2"><el-tag v-for="code in master.traditionCodes || []" :key="code" size="small" style="margin:2px 6px 2px 0">{{ $t(directoryTags.find(tag=>tag.code===code)?.name || code) }}<small v-if="!directoryTags.some(tag=>tag.code===code&&tag.status==='enabled'&&normalizeBelief(tag.beliefCode||'')===normalizeBelief(master!.beliefCode))">{{ $t('（历史关联，需核对）') }}</small></el-tag><span v-if="!master.traditionCodes?.length">{{ $t('未关联') }}</span><ProviderDirectoryTags kind="master" :id="master.id" :name="master.dharmaName" :belief="master.beliefCode" @updated="loadDetail"/></el-descriptions-item>
        <el-descriptions-item :label='$t("宗派补充说明")'>{{ $t((master.sect || '—')) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("类型")'>{{ $t((master.type || '—')) }}</el-descriptions-item>
        <el-descriptions-item :label='$t("专长")' :span="2">
          <el-tag v-for="s in master.specialties" :key="s" size="small" effect="plain" style="margin-right: 6px">{{ $t(s) }}</el-tag>
          <span v-if="!master.specialties?.length">—</span>
        </el-descriptions-item>
        <el-descriptions-item :label='$t("可提供服务")' :span="2">
          <el-tag v-for="t in serviceTags" :key="t.serviceCode" size="small" style="margin-right: 6px">
            {{ $t(serviceName(t.serviceCode)) }} ¥{{ $t(t.price) }}
          </el-tag>
          <span v-if="servicesReady && !serviceTags.length" class="muted-text">{{ $t("未配置（C端按可提供服务筛选，独立执业大师上架前提）") }}</span>
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
      <el-form label-width="110px" :disabled="saving || serviceSaving">
        <el-form-item :label='$t("法号")' required>
          <el-input v-model="form.dharmaName" maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("俗名")'>
          <el-input v-model="form.layName" maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("职位")'>
          <el-select v-model="form.position" filterable allow-create default-first-option style="width:100%"><el-option v-for="tag in directoryTags.filter(t=>t.group==='position')" :key="tag.code" :value="tag.value" :label="$t(tag.name)"/></el-select>
        </el-form-item>
        <el-form-item :label='$t("主信仰")' required>
          <el-select v-model="form.beliefCode" :disabled="!auth.roles.includes('platform_super')" style="width: 100%" @change="syncType">
            <el-option v-if="form.beliefCode && !beliefOptions.some(b=>b.value===form.beliefCode)" :value="form.beliefCode" :label="form.beliefCode + $t('（历史关联，需核对）')" disabled />
            <el-option v-for="b in beliefOptions" :key="b.value" :label="$t(b.label)" :value="b.value" />
          </el-select>
        </el-form-item>
        <p v-if="beliefRelationConflict" class="save-segment-note" role="status">{{ $t('已有选择与当前主信仰或有效目录不一致。请明确核对后调整，不会自动清空。') }}</p>
        <el-form-item :label='$t("宗派补充说明")'>
          <el-input v-model="form.sect" maxlength="32" />
        </el-form-item>
        <el-form-item :label='$t("类型")'>
          <el-input v-model="form.type" maxlength="16" />
        </el-form-item>
        <el-form-item :label='$t("专长")'><el-select v-model="form.specialties" multiple filterable allow-create default-first-option style="width:100%"><el-option v-for="tag in directoryTags.filter(t=>t.group==='specialty')" :key="tag.code" :value="tag.value" :label="$t(tag.name)"/></el-select></el-form-item>
        <el-form-item :label='$t("头像")'>
          <ImageUploader v-model="form.avatar" />
        </el-form-item>

        <p class="save-segment-note">{{ $t('展示文字与标准关联分别维护。保存资料不会改写宗派标签；历史资料与交易快照保留。') }}</p>
        <div class="segment-save"><el-button type="primary" :loading="saving" @click="saveProfile">{{ $t(profileFailed ? '仅重试资料' : '保存资料') }}</el-button><p v-if="profileReceipt" :role="profileFailed?'alert':'status'" :class="{failed:profileFailed}">{{ $t(profileReceipt) }}</p></div>
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
          <el-button type="primary" :loading="serviceSaving" :disabled="!servicesReady || serviceLoading" @click="saveServices">{{ $t(serviceFailed ? "仅重试服务" : "保存服务") }}</el-button>
          <el-button @click="cancelEdit" data-quiet-action="cancel">{{ $t("返回查看") }}</el-button>
        </el-form-item>
        <p v-if="serviceReceipt" :role="serviceFailed?'alert':'status'" :class="{failed:serviceFailed}">{{ $t(serviceReceipt) }}</p>
      </el-form>
    </div>
    <div v-else-if="!loading && !loadError" class="df-card detail-empty">{{ $t("未找到该法师资料") }}</div>
  </div>
</template>

<style scoped>
.save-segment-note{font-size:12px;color:var(--color-text-tertiary);line-height:1.7}.segment-save{display:flex;align-items:center;flex-wrap:wrap;gap:12px;margin:16px 0}.segment-save p{font-size:13px}.failed{color:var(--color-danger,#b53d32)}
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
