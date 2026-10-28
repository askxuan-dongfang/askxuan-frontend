<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { isAdminSessionExpired } from '@/api/client'
// DIY 材料编辑 / 新建
import { ref, reactive, onMounted, onBeforeUnmount, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { type FormInstance, type FormRules } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import { materialApi, type MaterialSaveParams, type ModelingConfig, type ModelingTask } from '@/commerce/api/material'
import MaterialModelPreview from '@/commerce/components/MaterialModelPreview.vue'
import { initialStudio, studioFingerprint, studioError, templateDefaults, templateOptions, type MaterialStudio, type Triple } from '@/commerce/materialStudio'
import { useAuthStore } from '@/stores/auth'
import type { MaterialCategory } from '@/commerce/types'

const route = useRoute()
const router = useRouter()

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)

const isEdit = computed(() => !!route.params.id)
const materialId = computed(() => Number(route.params.id) || 0)
const savedId = ref(materialId.value), auth = useAuthStore()
const detailReady = ref(!isEdit.value), detailError = ref('')
const studio = ref<MaterialStudio>(initialStudio()), previewReady = ref(false)
const config = ref<ModelingConfig>(), configOpen = ref(false), configSaving = ref(false), configKey = ref(''), configModel = ref('meshy-7.1')
const task = ref<ModelingTask>(), generationError = ref(''), generating = ref(false)
let pollTimer: ReturnType<typeof setTimeout> | undefined, alive = true, hydrating = false, requestId = '', requestPhotos = ''
const taskBusy = computed(() => generating.value || !!task.value && ['queued', 'submitting', 'processing', 'running'].includes(task.value.status))
const jobStorageKey = auth.userInfo?.userId ? `diy-material-modeling:${auth.userInfo.userId}:${materialId.value || 'new'}` : null
const visibleTemplates = computed(() => templateOptions.filter(v => studio.value.part === 'hanging' ? /^(pendant|tassel)/.test(v.value) : !/^(pendant|tassel)/.test(v.value)))
const axes = ['X', 'Y', 'Z'], dimensionLabels = ['宽度 X', '厚度 Y', '长度 Z']

const assets = reactive({ beadImageUrl: '', albedoMapUrl: '', normalMapUrl: '', roughnessMapUrl: '', source: 'procedural', attribution: '' })

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

function chooseTemplate(value: string) {
  studio.value.templateId = value
  Object.assign(studio.value, templateDefaults(value, form.diameterMm || 10))
  form.shape = value.startsWith('pendant') ? 'pendant' : value.startsWith('tassel') ? 'tassel' : value
}
function choosePart(value: string | number | boolean | undefined) {
  const hanging = value === 'hanging'
  studio.value.part = hanging ? 'hanging' : 'bead'
  studio.value.motion = hanging ? 'rigid' : 'fixed'
  studio.value.connectorMm = hanging ? 2 : 0
  if (studio.value.source === 'template') chooseTemplate(hanging ? 'pendant_generic' : 'round')
}
function chooseSource(value: string | number | boolean | undefined) {
  studio.value.source = value === 'generated' ? 'generated' : 'template'
  if (studio.value.source === 'generated') { studio.value.templateId = 'custom'; studio.value.mount = [0, 0, -.5] }
  else chooseTemplate(studio.value.part === 'hanging' ? studio.value.motion === 'flexible' ? 'tassel' : 'pendant_generic' : 'round')
}
function chooseMotion(value: string | number | boolean | undefined) {
  studio.value.motion = value === 'flexible' ? 'flexible' : 'rigid'
  if (studio.value.source === 'template') chooseTemplate(value === 'flexible' ? 'tassel' : 'pendant_generic')
}
function updatePhotos(value: string | string[]) { studio.value.photos = Array.isArray(value) ? value.slice(0, 4) : value ? [value] : [] }
function updateMount(value: Triple) { studio.value.mount = value }
function percentage(value: number) { return `${Math.round(value * 100)}%` }
function confirmPreview(value: string | number | boolean) {
  if (!value) { studio.value.previewConfirmed = false; return }
  const error = studioError(studio.value)
  if (!previewReady.value || error) { ElMessage.warning(uiText(error || '请先等待 3D 预览加载完成')); return }
  studio.value.previewConfirmed = !!value
}
watch(() => [studioFingerprint(studio.value), form.colorHex, form.materialType, form.finish, form.textureKey, form.translucency, assets.albedoMapUrl, assets.normalMapUrl, assets.roughnessMapUrl], () => {
  if (!hydrating) studio.value.previewConfirmed = false
}, { flush: 'sync' })

async function loadDetail() {
  if (!isEdit.value) return
  loading.value = true; detailError.value = ''
  try {
    const target = await materialApi.detail(materialId.value)
    hydrating = true
    let parsed: Record<string, any> = {}
    try { parsed = JSON.parse(target.renderAssets || '{}') } catch { ElMessage.warning(uiText('材质素材配置无效，请重新填写')) }
    Object.assign(assets, parsed)
    Object.assign(form, {
      name: target.name, spec: target.spec, unitPrice: target.unitPrice, unit: target.unit, category: target.category,
      fiveElements: target.fiveElements || '', materialType: target.materialType || 'gemstone', shape: target.shape || 'round',
      diameterMm: target.diameterMm ?? 10, colorHex: target.colorHex || '#8A6E4A', textureKey: target.textureKey || 'plain',
      finish: target.finish || 'polished', translucency: target.translucency ?? 0, image: target.image, stock: target.stock
    })
    studio.value = parsed.studio?.version === 1 ? { ...initialStudio(target), ...parsed.studio } : initialStudio(target)
    detailReady.value = true
  } catch (error) { if (!isAdminSessionExpired(error)) detailError.value = '材料读取失败，请重试后再编辑' } finally { hydrating = false; loading.value = false }
}
async function loadConfig() {
  try { config.value = await materialApi.modelingConfig(); configModel.value = config.value.model || 'meshy-7.1' }
  catch (error) { if (isAdminSessionExpired(error)) return; generationError.value = '生成服务状态读取失败，请重试' }
}
async function saveConfig() {
  configSaving.value = true
  try {
    config.value = await materialApi.saveModelingConfig({ apiKey: configKey.value || undefined, model: configModel.value })
    configOpen.value = false; ElMessage.success(uiText('生成服务配置已保存'))
  } finally { configKey.value = ''; configSaving.value = false }
}
function applyTask(value: ModelingTask) {
  task.value = value
  if (value.status === 'succeeded') {
    if (!value.model?.glbUrl || !value.model.usdzUrl) { generationError.value = '模型文件尚未就绪，请重新查询'; return }
    studio.value.model = { ...value.model, jobId: value.id }
    studio.value.templateId = 'custom'; studio.value.source = 'generated'; studio.value.rotation = [0, 0, 0]; studio.value.mount = [0, 0, -.5]
    generationError.value = ''; return
  }
  if (value.status === 'failed') { generationError.value = value.errorMessage || '生成失败，请检查实拍图后重试'; return }
  pollTimer = setTimeout(() => pollTask(value.id), 2500)
}
async function pollTask(id: string) {
  clearTimeout(pollTimer)
  try { const value = await materialApi.modelingTask(id); if (alive) applyTask(value) }
  catch (error) { if (isAdminSessionExpired(error) || !alive) return; generationError.value = '任务查询失败，已保留任务，可继续查询' }
}
async function generate() {
  if (!config.value?.configured) { ElMessage.warning(uiText('请先配置图生 3D 服务')); return }
  if (!studio.value.photos.length) { ElMessage.warning(uiText('请先上传至少一张实拍图')); return }
  generating.value = true; generationError.value = ''
  const photos = JSON.stringify(studio.value.photos)
  if (!requestId || requestPhotos !== photos || ['failed', 'succeeded'].includes(task.value?.status || '')) requestId = crypto.randomUUID()
  requestPhotos = photos
  try {
    const value = await materialApi.generateModel({ requestId, photoUrls: [...studio.value.photos] })
    if (!alive) return
    if (jobStorageKey) sessionStorage.setItem(jobStorageKey, JSON.stringify({ id: value.id, photos: studio.value.photos }))
    applyTask(value)
  } catch (error) { if (isAdminSessionExpired(error) || !alive) return; generationError.value = '未能提交生成任务，可重试；相同请求不会重复创建任务' }
  finally { generating.value = false }
}
async function resumeTask() {
  if (!jobStorageKey) return
  try {
    const saved = JSON.parse(sessionStorage.getItem(jobStorageKey) || 'null')
    if (!saved?.id || !Array.isArray(saved.photos) || saved.id === studio.value.model?.jobId) return
    studio.value.source = 'generated'; studio.value.templateId = 'custom'; studio.value.photos = saved.photos
    await pollTask(saved.id)
  } catch { sessionStorage.removeItem(jobStorageKey) }
}
async function handleSubmit(publish = false) {
  if (!formRef.value || saving.value || !detailReady.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return
  const modelError = studioError(studio.value)
  if (modelError && !(studio.value.source === 'generated' && !studio.value.model && !publish)) { ElMessage.warning(uiText(modelError)); return }
  if (publish && (!previewReady.value || !studio.value.previewConfirmed)) { ElMessage.warning(uiText('请先检查并确认 3D 模型与挂点')); return }
  saving.value = true
  try {
    const data = { ...form, renderAssets: JSON.stringify({ ...assets, studio: studio.value }) }
    if (savedId.value) await materialApi.update(savedId.value, data)
    else savedId.value = (await materialApi.create(data)).id
    if (publish) await materialApi.updateStatus(savedId.value, 'on_shelf')
    if (jobStorageKey) sessionStorage.removeItem(jobStorageKey)
    ElMessage.success(uiText(publish ? '材料已发布' : '草稿已保存'))
    router.push('/commerce/materials')
  } catch (error) { if (isAdminSessionExpired(error)) return } finally { saving.value = false }
}
function handleCancel() { router.push('/commerce/materials') }
onMounted(async () => { await Promise.all([loadDetail(), loadConfig()]); if (alive && detailReady.value) await resumeTask() })
onBeforeUnmount(() => { alive = false; clearTimeout(pollTimer); configKey.value = '' })
</script>

<template>
  <div class="page-wrap material-authoring" v-loading="loading">
    <PageHeader :title="$t(isEdit ? '编辑材料' : '新建材料')" :subtitle='$t("选择品类、准备模型，确认实物尺寸与挂点后发布")' />
    <el-alert v-if="detailError" :title="$t(detailError)" type="error" :closable="false"><el-button @click="loadDetail">{{ $t('重新读取材料') }}</el-button></el-alert>
    <ol class="authoring-steps" :aria-label='$t("材料建模流程")'><li v-for="(label, index) in ['材料建档', '实拍与尺寸', '生成或复用', '预览与挂点', '保存发布']" :key="label"><span>{{ index + 1 }}</span>{{ $t(label) }}</li></ol>
    <el-form ref="formRef" :model="form" :rules="rules" :disabled="!detailReady" label-position="top" @submit.prevent="handleSubmit(false)">
      <div class="authoring-columns">
        <div class="authoring-fields">
          <section class="authoring-section" :aria-label='$t("材料建档")'>
            <h2>{{ $t('材料建档') }}</h2>
            <el-form-item :label='$t("连接方式")'>
              <el-radio-group :model-value="studio.part" @change="choosePart"><el-radio-button value="bead">{{ $t('穿绳串接') }}</el-radio-button><el-radio-button value="hanging">{{ $t('挂件连接') }}</el-radio-button></el-radio-group>
              <p class="field-help">{{ $t(studio.part === 'bead' ? '沿主绳穿孔排列，随整串转动。' : '通过独立短绳连接，可随重力摆动。') }}</p>
            </el-form-item>
            <el-form-item v-if="studio.part === 'hanging'" :label='$t("运动方式")'><el-radio-group :model-value="studio.motion" @change="chooseMotion"><el-radio-button value="rigid">{{ $t('刚性摆动') }}</el-radio-button><el-radio-button value="flexible">{{ $t('柔性流苏') }}</el-radio-button></el-radio-group></el-form-item>
            <el-form-item :label='$t("材料名称")' prop="name"><el-input v-model="form.name" :placeholder='$t("如：8mm 红玛瑙")' maxlength="60" show-word-limit /></el-form-item>
            <div class="field-pair">
              <el-form-item :label='$t("材料分类")' prop="category"><el-select v-model="form.category"><el-option v-for="item in categoryOptions" :key="item.value" :label="$t(item.label)" :value="item.value" /></el-select></el-form-item>
              <el-form-item :label='$t("材质大类")' prop="materialType"><el-select v-model="form.materialType"><el-option v-for="item in materialTypeOptions" :key="item.value" :label="$t(item.label)" :value="item.value" /></el-select></el-form-item>
              <el-form-item :label='$t("规格")' prop="spec"><el-input v-model="form.spec" :placeholder='$t("如：8mm")' /></el-form-item>
              <el-form-item :label='$t("五行属性")'><el-select v-model="form.fiveElements" :placeholder='$t("可选")' clearable><el-option v-for="item in fiveElementsOptions" :key="item.value" :label="$t(item.label)" :value="item.value" /></el-select></el-form-item>
              <el-form-item :label='$t("单价（元）")' prop="unitPrice"><el-input-number v-model="form.unitPrice" :min="0" :precision="2" :step="1" controls-position="right" /></el-form-item>
              <el-form-item :label='$t("单位")' prop="unit"><el-input v-model="form.unit" :placeholder='$t("如：颗 / 个")' /></el-form-item>
              <el-form-item :label='$t("库存")' prop="stock"><el-input-number v-model="form.stock" :min="0" :precision="0" :step="1" controls-position="right" /></el-form-item>
            </div>
          </section>
          <section class="authoring-section" :aria-label='$t("实拍与尺寸")'>
            <h2>{{ $t('实拍与尺寸') }}</h2>
            <el-form-item :label='$t("多角度实拍")'><div v-if="!taskBusy" class="photo-input"><ImageUploader :model-value="studio.photos" :multiple="true" :limit="4" :hint='$t("同一材料的正面、背面、侧面，最多四张；每张不超过 10MB。")' @update:model-value="updatePhotos" /></div><p v-else role="status">{{ $t('生成期间保留当前实拍图，完成后可修改。') }}</p><p class="field-help">{{ $t('复用模板时可选；图生 3D 至少需要一张实拍图。') }}</p></el-form-item>
            <el-form-item :label='$t("实际尺寸（mm）")'><div class="triple-fields"><label v-for="(label, index) in dimensionLabels" :key="label"><span>{{ $t(label) }}</span><el-input-number v-model="studio.dimensionsMm[index]" :aria-label="$t(label)" :min=".5" :max="120" :precision="2" :step="1" controls-position="right" /></label></div></el-form-item>
            <el-form-item :label='$t("材料展示图")'><ImageUploader v-model="form.image" :multiple="false" /></el-form-item>
          </section>
          <section class="authoring-section" :aria-label='$t("生成或复用模型")'>
            <h2>{{ $t('生成或复用模型') }}</h2>
            <el-form-item :label='$t("模型来源")'><el-radio-group :model-value="studio.source" :disabled="taskBusy" @change="chooseSource"><el-radio-button value="template">{{ $t('复用形状模板') }}</el-radio-button><el-radio-button value="generated">{{ $t('实拍生成 3D') }}</el-radio-button></el-radio-group></el-form-item>
            <template v-if="studio.source === 'template'"><el-form-item :label='$t("形状模板")'><el-select :model-value="studio.templateId" @change="chooseTemplate"><el-option v-for="item in visibleTemplates" :key="item.value" :label="$t(item.label)" :value="item.value" /></el-select></el-form-item><p class="field-help">{{ $t('模板是示意形状，请按实物核对尺寸。切换模板后会重新填入模板尺寸与挂点。') }}</p></template>
            <div v-else class="generation-panel">
              <p v-if="!config?.configured" role="status">{{ $t('图生 3D 服务尚未配置，可先复用形状模板。') }}</p><p v-else>{{ $t('使用实拍生成模型，完成后在右侧检查外观与挂点。') }}</p>
              <div class="generation-actions"><el-button type="primary" :loading="taskBusy" :disabled="!config?.configured || !studio.photos.length || taskBusy" @click="generate">{{ $t(task?.status === 'failed' ? '重新生成' : studio.model ? '再次生成' : '生成 3D 模型') }}</el-button><el-button v-if="config?.canConfigure" @click="configOpen = true">{{ $t('配置生成服务') }}</el-button><el-button v-if="!config" @click="loadConfig">{{ $t('重试读取配置') }}</el-button></div>
              <p v-if="taskBusy" role="status">{{ $t('模型正在生成，可稍后回来继续。') }} {{ Math.round(task?.progress || 0) }}%</p><el-progress v-if="taskBusy" :percentage="Math.max(0, Math.min(100, task?.progress || 0))" :show-text="false" />
              <p v-if="task?.status === 'succeeded' && studio.model" role="status">{{ $t('模型已生成，请检查并确认预览。') }}</p><p v-if="generationError" class="generation-error" role="alert">{{ $t(generationError) }}</p><el-button v-if="generationError && task?.id && task.status !== 'failed'" @click="pollTask(task.id)">{{ $t('继续查询任务') }}</el-button>
            </div>
            <div class="field-pair">
              <el-form-item :label='$t("渲染主色")' prop="colorHex"><div class="color-field"><el-color-picker v-model="form.colorHex" /><el-input v-model="form.colorHex" /></div></el-form-item>
              <el-form-item :label='$t("表面工艺")'><el-select v-model="form.finish"><el-option v-for="item in finishOptions" :key="item.value" :label="$t(item.label)" :value="item.value" /></el-select></el-form-item>
              <el-form-item :label='$t("纹理")'><el-select v-model="form.textureKey" filterable><el-option v-for="item in textureOptions" :key="item.value" :label="$t(item.label)" :value="item.value" /></el-select></el-form-item>
              <el-form-item :label='$t("通透度")'><el-slider v-model="form.translucency" :min="0" :max="1" :step=".05" /></el-form-item>
            </div>
            <details class="material-map-fields"><summary>{{ $t('实拍图与材质贴图') }}</summary>
              <el-form-item :label='$t("单珠实拍")'><ImageUploader v-model="assets.beadImageUrl" :multiple="false" :placeholder='$t("透明底单珠图片 URL")' /></el-form-item>
              <el-form-item :label='$t("颜色贴图")'><el-input v-model="assets.albedoMapUrl" :placeholder='$t("3D 展开纹理 URL（可选）")' /></el-form-item>
              <el-form-item :label='$t("法线贴图")'><el-input v-model="assets.normalMapUrl" :placeholder='$t("表面细节纹理 URL（可选）")' /></el-form-item>
              <el-form-item :label='$t("粗糙度图")'><el-input v-model="assets.roughnessMapUrl" :placeholder='$t("黑白粗糙度纹理 URL（可选）")' /></el-form-item>
              <el-form-item :label='$t("素材来源")'><el-select v-model="assets.source"><el-option :label='$t("实拍素材")' value="photograph" /><el-option :label='$t("授权素材")' value="licensed" /><el-option :label='$t("程序材质预览")' value="procedural" /></el-select></el-form-item>
              <el-form-item :label='$t("授权与说明")'><el-input v-model="assets.attribution" type="textarea" :rows="2" maxlength="400" /></el-form-item>
            </details>
          </section>
        </div>
        <section class="authoring-preview authoring-section" :aria-label='$t("预览与挂点")'>
          <h2>{{ $t('预览与挂点') }}</h2>
          <MaterialModelPreview :studio="studio" :color="form.colorHex" :finish="form.finish" :material-type="form.materialType" :texture-key="form.textureKey" :translucency="form.translucency" :material-id="savedId || undefined" :albedo-map-url="assets.albedoMapUrl" :normal-map-url="assets.normalMapUrl" :roughness-map-url="assets.roughnessMapUrl" @ready="previewReady = $event" @mount="updateMount" />
          <el-form-item :label='$t("模型朝向（度）")'><div class="triple-fields"><label v-for="(axis, index) in axes" :key="axis"><span>{{ axis }}</span><el-input-number v-model="studio.rotation[index]" :aria-label="$t('模型朝向') + ' ' + axis" :min="-180" :max="180" :step="15" controls-position="right" /></label></div><p class="field-help">{{ $t('此处调整模型实际朝向；上方拖动只改变观察视角。') }}</p></el-form-item>
          <template v-if="studio.part === 'hanging'">
            <el-form-item :label='$t("挂点位置")'><div class="triple-fields"><label v-for="(axis, index) in axes" :key="axis"><span>{{ axis }}</span><el-input-number v-model="studio.mount[index]" :aria-label="$t('挂点位置') + ' ' + axis" :min="-.5" :max="index === 2 ? .499 : .5" :step=".05" :precision="3" controls-position="right" /></label></div></el-form-item>
            <el-form-item :label='$t("连接绳长度（mm）")'><el-input-number v-model="studio.connectorMm" :min="1" :max="30" :precision="1" controls-position="right" /></el-form-item>
            <el-form-item v-if="studio.motion === 'flexible'" :label='$t("固定部分比例")'><el-slider v-model="studio.rigidFraction" :min=".1" :max=".9" :step=".05" :format-tooltip="percentage" /><p class="field-help">{{ $t('从挂点沿蓝 Z 轴计算，剩余部分可以弯曲。') }}</p></el-form-item>
          </template>
          <p v-else class="field-help">{{ $t('穿绳孔需沿红 X 轴居中；主绳保持同一平面。') }}</p>
          <el-checkbox :model-value="studio.previewConfirmed" :disabled="!previewReady" @change="confirmPreview"><span class="confirm-copy">{{ $t(studio.part === 'hanging' ? '已检查外观、尺寸、朝向与挂点' : '已检查外观、尺寸与穿绳方向') }}</span></el-checkbox><p class="field-help">{{ $t('修改模型或尺寸后，需要重新确认。') }}</p>
        </section>
      </div>
      <div class="authoring-footer"><span>{{ $t('草稿不会出现在用户材料库中。') }}</span><div><el-button @click="handleCancel" data-quiet-action="cancel">{{ $t('取消') }}</el-button><el-button :loading="saving" :disabled="taskBusy || !detailReady" @click="handleSubmit(false)">{{ $t('保存草稿') }}</el-button><el-button type="primary" :loading="saving" :disabled="!previewReady || !studio.previewConfirmed || taskBusy || !detailReady" @click="handleSubmit(true)">{{ $t('保存并发布') }}</el-button></div></div>
    </el-form>
    <el-dialog v-model="configOpen" :title='$t("图生 3D 服务")' width="min(520px, 94vw)" append-to-body @closed="configKey = ''">
      <p>{{ $t('Meshy：密钥仅保存在服务器，不会出现在材料或客户端配置中。') }}</p><el-form label-position="top"><el-form-item label="API Key"><el-input v-model="configKey" type="password" show-password autocomplete="new-password" :placeholder="$t(config?.hasApiKey ? '留空保留现有密钥' : '填写服务商 API Key')" /></el-form-item><el-form-item :label='$t("生成模型")'><el-select v-model="configModel"><el-option label="Meshy 7.1" value="meshy-7.1" /><el-option label="Meshy 6" value="meshy-6" /></el-select></el-form-item></el-form>
      <template #footer><el-button @click="configOpen = false">{{ $t('取消') }}</el-button><el-button type="primary" :loading="configSaving" :disabled="!config?.hasApiKey && !configKey" @click="saveConfig">{{ $t('保存配置') }}</el-button></template>
    </el-dialog>
  </div>
</template>

<style scoped>
.authoring-steps { display: flex; flex-wrap: wrap; gap: 12px 24px; padding: 0; margin: 0 0 28px; list-style: none; color: var(--text-secondary); font-size: var(--type-size-caption); }
.authoring-steps li { display: flex; gap: 8px; align-items: center; }
.authoring-steps span { display: grid; place-items: center; width: 24px; height: 24px; border-radius: 50%; background: var(--bg-color); color: var(--color-primary); }
.authoring-columns { display: grid; grid-template-columns: minmax(0, 1.05fr) minmax(340px, 1fr); gap: 36px; align-items: start; max-width: 1400px; }
.authoring-section { min-width: 0; margin-bottom: 28px; }
.authoring-section h2 { font-size: var(--type-size-title-sm, 18px); font-weight: 600; margin: 0 0 20px; }
.authoring-fields .authoring-section + .authoring-section { padding-top: 24px; border-top: 1px solid var(--border-color-light, rgba(128, 110, 80, .1)); }
.authoring-preview { position: sticky; top: 24px; }
.authoring-preview > :deep(.el-form-item) { margin-top: 20px; }
.field-pair { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 16px; }
.field-pair :deep(.el-select), .field-pair :deep(.el-input-number) { width: 100%; }
.triple-fields { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; width: 100%; }
.triple-fields label { min-width: 0; display: flex; flex-direction: column; gap: 4px; font-size: var(--type-size-caption); color: var(--text-light); }
.triple-fields :deep(.el-input-number) { width: 100%; }
.field-help { margin: 8px 0 0; color: var(--text-light); font-size: var(--type-size-caption); line-height: 1.7; width: 100%; }
.color-field { display: flex; gap: 10px; width: 100%; }.color-field > :deep(.el-input) { flex: 1; }
.photo-input { width: 100%; }.photo-input.is-busy { pointer-events: none; opacity: .65; }
.generation-panel { margin: 16px 0 24px; padding: 16px; background: var(--bg-color); border-radius: 12px; }
.generation-panel p { line-height: 1.6; font-size: var(--type-size-caption); }
.generation-actions { display: flex; flex-wrap: wrap; gap: 8px; }.generation-actions :deep(.el-button + .el-button) { margin: 0; }
.generation-error { color: var(--el-color-danger); }
.material-map-fields { margin-top: 12px; }.material-map-fields summary { cursor: pointer; color: var(--text-secondary); padding: 8px 0 18px; }
.confirm-copy { white-space: normal; line-height: 1.6; }
.authoring-preview :deep(.el-checkbox) { height: auto; align-items: flex-start; margin-top: 18px; }.authoring-preview :deep(.el-checkbox__input) { margin-top: 4px; }
.authoring-footer { display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 16px; margin-top: 12px; padding: 20px 0; background: var(--bg-card, var(--bg-color)); }
.authoring-footer > span { color: var(--text-light); font-size: var(--type-size-caption); }.authoring-footer > div { display: flex; flex-wrap: wrap; gap: 8px; }.authoring-footer :deep(.el-button + .el-button) { margin: 0; }
@media (max-width: 1050px) { .authoring-columns { grid-template-columns: minmax(0, 1fr); gap: 12px; } .authoring-preview { position: static; } }
@media (max-width: 500px) { .field-pair { grid-template-columns: minmax(0, 1fr); } .authoring-steps { gap: 8px 12px; } .triple-fields { gap: 6px; } .authoring-footer > div { width: 100%; } }
</style>
