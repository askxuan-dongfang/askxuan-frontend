<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, reactive, ref } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Connection, Check, Refresh, Lock, ArrowRight } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import { aiSettingsApi, type AIProviderSettings, type AIProviderUpdate, type AIModelOption } from '@/api/aiSettings'

const saved = ref<AIProviderSettings>()
const loading = ref(true), saving = ref(false), testing = ref(false)
const loadError = ref(''), testError = ref(''), tested = ref(false)
const models = ref<AIModelOption[]>([])
const form = reactive<AIProviderUpdate>({ revision: 0, provider: 'deepseek', baseUrl: 'https://api.deepseek.com', apiKey: '', defaultModel: 'deepseek-flash', visionModel: 'deepseek-flash', enabledModels: [], thinkingEnabled: true, reasoningEffort: 'low', maxOutputTokens: 2048 })
let baseline = ''
const dirty = computed(() => JSON.stringify(form) !== baseline)
const busy = computed(() => loading.value || saving.value || testing.value)
const visionOptions = computed(() => models.value.filter(item => item.supportsVision))
const names: Record<string, string> = { provider: 'Provider', baseUrl: '接口地址', apiKey: '密钥', defaultModel: '默认模型', visionModel: '图片模型', enabledModels: '开放模型', thinkingEnabled: '思考模式', reasoningEffort: '推理强度', maxOutputTokens: '输出上限' }

function useSaved(value: AIProviderSettings) {
  saved.value = value
  Object.assign(form, { revision: value.revision, provider: value.provider, baseUrl: value.baseUrl, defaultModel: value.defaultModel, visionModel: value.visionModel, enabledModels: [...(value.enabledModels || [])], thinkingEnabled: value.thinkingEnabled, reasoningEffort: value.reasoningEffort || 'low', maxOutputTokens: value.maxOutputTokens, apiKey: '' })
  baseline = JSON.stringify(form)
}
async function load() {
  loading.value = true; loadError.value = ''
  try { useSaved(await aiSettingsApi.get()) } catch { loadError.value = '配置加载失败，请重试' }
  finally { loading.value = false }
}
function connectionChanged() { tested.value = false; models.value = []; testError.value = '' }
function changeProvider(value: string) {
  connectionChanged()
  if (value === 'deepseek') { form.baseUrl = 'https://api.deepseek.com'; form.defaultModel = 'deepseek-flash'; form.visionModel = 'deepseek-flash' }
  form.enabledModels = []
}
async function testConnection() {
  testing.value = true; testError.value = ''; tested.value = false
  try {
    const result = await aiSettingsApi.test({ ...form, enabledModels: [...form.enabledModels] })
    models.value = result.list
    if (!result.list.some(m => m.id === form.defaultModel)) form.defaultModel = result.defaultModel || result.list[0]?.id || ''
    if (!result.list.some(m => m.id === form.visionModel && m.supportsVision)) form.visionModel = ''
    tested.value = true
  } catch (error) { testError.value = error instanceof Error ? error.message : '连接测试失败' }
  finally { testing.value = false }
}
async function save() {
  try { await ElMessageBox.confirm('保存前会再次验证连接与模型。生效后，新问事和新报告将使用这份配置，正在生成的回答不受影响。', '保存并生效', { confirmButtonText: '确认生效', cancelButtonText: '继续编辑', type: 'info' }) } catch { return }
  saving.value = true
  try { useSaved(await aiSettingsApi.save({ ...form, enabledModels: [...form.enabledModels] })); ElMessage.success('配置已生效，新的请求将使用新设置') }
  catch { /* client displays the sanitized server error; keep the draft for correction */ }
  finally { saving.value = false }
}
function reset() { if (saved.value) useSaved(saved.value); connectionChanged() }
onBeforeRouteLeave(async () => {
  if (!dirty.value || loading.value || !saved.value) return true
  try { await ElMessageBox.confirm('当前修改尚未保存，离开后将丢弃。', '离开设置页面', { confirmButtonText: '离开', cancelButtonText: '继续编辑' }); return true } catch { return false }
})
onBeforeUnmount(() => { form.apiKey = '' })
onMounted(load)
</script>

<template>
  <div class="dfx-page ai-settings" v-loading="loading">
    <PageHeader title="AI 模型设置" subtitle="管理 AI 问事与专题报告使用的大模型连接" />
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" show-icon><el-button text @click="load">重新加载</el-button></el-alert>
    <template v-else-if="saved">
      <el-alert v-if="!saved.writable" title="当前为只读模式，服务器尚未启用配置持久化" type="warning" :closable="false" show-icon class="storage-warning" />
      <div class="ai-settings-layout">
        <div class="ai-settings-main">
          <section class="ai-setting-card">
            <div class="ai-section-heading"><span class="ai-step">01</span><div><h2>连接大模型</h2><p>密钥由服务器保管，客户端通过平台调用。</p></div><el-icon class="ai-heading-icon"><Connection /></el-icon></div>
            <el-form label-position="top" :disabled="busy || !saved.writable" @submit.prevent>
              <el-form-item label="Provider">
                <el-select v-model="form.provider" aria-label="Provider" @change="changeProvider"><el-option label="DeepSeek · 官方接口" value="deepseek" /><el-option label="OpenAI 兼容接口" value="openai_compatible" /><el-option v-if="form.provider === 'mock'" label="本地模拟（当前配置）" value="mock" disabled /></el-select>
              </el-form-item>
              <el-form-item label="接口地址"><el-input v-model="form.baseUrl" aria-label="接口地址" placeholder="https://api.deepseek.com" :disabled="form.provider === 'deepseek'" @input="connectionChanged" /><span class="ai-field-hint">填写 API 根地址，不包含 /chat/completions。自定义接口支持公网 HTTPS。</span></el-form-item>
              <el-form-item label="API Key">
                <el-input v-model="form.apiKey" aria-label="API Key" type="password" autocomplete="new-password" :placeholder="saved.hasApiKey ? '已配置 · 留空保留现有密钥' : '填写 Provider API Key'" @input="connectionChanged" />
                <span class="ai-field-hint"><el-icon><Lock /></el-icon> {{ saved.hasApiKey ? '现有密钥不会回显；变更接口地址时，请同时填写新密钥。' : '密钥加密保存，不会发送给 H5 或 iOS 客户端。' }}</span>
              </el-form-item>
              <div class="ai-test-row"><el-button :icon="Connection" :loading="testing" @click="testConnection">测试连接与获取模型</el-button><span class="ai-field-hint">仅读取模型列表，不发送问事内容。</span></div>
            </el-form>
            <div v-if="tested" class="ai-connection-result" role="status"><el-icon><Check /></el-icon><div><strong>连接成功</strong><span>发现 {{ models.length }} 个可用模型，可以继续设置。</span></div></div>
            <el-alert v-if="testError" :title="testError" type="error" :closable="false" class="ai-test-error" show-icon />
          </section>

          <section class="ai-setting-card">
            <div class="ai-section-heading"><span class="ai-step">02</span><div><h2>模型与生成偏好</h2><p>默认用于新问事；用户也可选择平台开放的模型。</p></div></div>
            <el-form label-position="top" :disabled="busy || !saved.writable" @submit.prevent>
              <div class="ai-form-grid">
                <el-form-item label="默认模型">
                  <el-select v-model="form.defaultModel" aria-label="默认模型" filterable allow-create default-first-option placeholder="先测试连接，或输入模型 ID"><el-option v-for="m in models" :key="m.id" :label="m.name" :value="m.id" /></el-select>
                </el-form-item>
                <el-form-item label="图片模型">
                  <el-select v-model="form.visionModel" aria-label="图片模型" clearable filterable allow-create placeholder="不设置图片路由"><el-option v-for="m in visionOptions" :key="m.id" :label="m.name" :value="m.id" /></el-select>
                  <span class="ai-field-hint">旧版本客户端发送图片时使用；请确认供应商支持图片输入。</span>
                </el-form-item>
              </div>
              <el-form-item label="向用户开放的模型">
                <el-select v-model="form.enabledModels" aria-label="向用户开放的模型" multiple filterable allow-create :collapse-tags="false" placeholder="留空：开放供应商当前全部可用模型"><el-option v-for="m in models" :key="m.id" :label="m.name" :value="m.id" /></el-select>
                <span class="ai-field-hint">默认模型与图片模型需包含在选择范围内。留空时，后续新增模型自动进入可选列表。</span>
              </el-form-item>
              <div class="ai-form-grid">
                <el-form-item label="思考模式"><div class="ai-switch-row"><el-switch v-model="form.thinkingEnabled" aria-label="思考模式" /><span>{{ form.thinkingEnabled ? '开启' : '关闭' }}</span></div></el-form-item>
                <el-form-item label="推理强度"><el-select v-model="form.reasoningEffort" aria-label="推理强度" :disabled="!form.thinkingEnabled"><el-option label="低 · 更快回复" value="low" /><el-option label="中 · 均衡" value="medium" /><el-option label="高 · 更多推理" value="high" /></el-select></el-form-item>
                <el-form-item label="最大输出 Token"><el-input-number v-model="form.maxOutputTokens" aria-label="最大输出 Token" :min="64" :max="32768" :step="256" controls-position="right" /><span class="ai-field-hint">单条问事回复上限；专题报告有独立的结构化输出上限。</span></el-form-item>
              </div>
              <p class="ai-field-hint">思考参数由兼容接口传递，实际支持能力取决于所选供应商。</p>
            </el-form>
          </section>
        </div>

        <aside class="ai-settings-aside">
          <section class="ai-setting-card ai-active-card">
            <div class="ai-live-label"><span /> 当前生效</div>
            <h2>{{ saved.provider === 'deepseek' ? 'DeepSeek' : saved.provider === 'mock' ? '本地模拟' : 'OpenAI 兼容接口' }}</h2>
            <p class="ai-current-model">{{ saved.defaultModel || '尚未设置默认模型' }}</p>
            <dl><div><dt>配置来源</dt><dd>{{ saved.source === 'platform' ? '管理平台' : '服务器初始配置' }}</dd></div><div><dt>密钥状态</dt><dd>{{ saved.hasApiKey ? '已配置' : '未配置' }}</dd></div><div><dt>版本</dt><dd>v{{ saved.revision }}</dd></div></dl>
            <div class="ai-flow"><span>管理平台</span><el-icon><ArrowRight /></el-icon><span>AI 服务</span><el-icon><ArrowRight /></el-icon><span>用户端</span></div>
            <p>保存后立即用于新请求。H5 和 iOS 共用此设置，无需重新发布客户端。</p>
          </section>
          <section class="ai-setting-card ai-history-card">
            <h2>最近变更</h2><p v-if="!saved.history.length" class="ai-field-hint">尚无平台变更记录。首次保存后开始记录。</p>
            <ol v-else class="ai-history"><li v-for="item in saved.history.slice(0, 8)" :key="item.revision"><strong>v{{ item.revision }} <span>管理员 {{ item.actor }}</span></strong><p>{{ item.fields.map(f => names[f] || f).join('、') || '重新验证配置' }}</p><time>{{ new Date(item.at).toLocaleString() }}</time></li></ol>
          </section>
        </aside>
      </div>
      <footer class="ai-settings-actions"><span :class="{ 'is-dirty': dirty }">{{ dirty ? '有尚未保存的修改' : '已与当前配置同步' }}</span><div><el-button :disabled="busy || !dirty" :icon="Refresh" @click="reset">撤销修改</el-button><el-button type="primary" :disabled="busy || !dirty || !saved.writable" :loading="saving" @click="save">保存并生效</el-button></div></footer>
    </template>
  </div>
</template>

<style scoped>
.ai-settings { --ai-border: var(--dfx-border, #e7e2d8); max-width: 1380px; margin-inline:auto; }
.storage-warning { margin-bottom:20px; }
.ai-settings-layout { display:grid; grid-template-columns:minmax(0, 1.65fr) minmax(270px, 1fr); gap:24px; align-items:start; }
.ai-settings-main,.ai-settings-aside { min-width:0; display:grid; gap:24px; }
.ai-setting-card { border:1px solid var(--ai-border); border-radius:16px; padding:28px; background:var(--dfx-bg-card, var(--el-bg-color)); }
.ai-section-heading { display:flex; align-items:flex-start; gap:14px; margin-bottom:28px; }
.ai-step { width:32px; height:32px; display:grid; place-items:center; border-radius:10px; background:var(--el-color-primary-light-9); color:var(--el-color-primary); font-weight:600; font-size:var(--type-size-caption); flex-shrink:0; }
.ai-section-heading h2,.ai-setting-card h2 { margin:0; font-size:var(--type-size-nav); font-weight:600; }
.ai-section-heading p { margin:7px 0 0; font-size:var(--type-size-label); color:var(--dfx-text-secondary); line-height:1.65; }
.ai-heading-icon { margin-left:auto; margin-top:5px; color:var(--el-color-primary); font-size:24px; }
.ai-form-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:0 18px; }
.ai-settings :deep(.el-select),.ai-settings :deep(.el-input-number) { width:100%; }
.ai-settings :deep(.el-form-item) { margin-bottom:22px; }
.ai-settings :deep(.el-input__wrapper),.ai-settings :deep(.el-select__wrapper) { min-height:40px; border-radius:8px; }
.ai-field-hint { display:block; color:var(--dfx-text-secondary); font-size:var(--type-size-caption); line-height:1.7; margin-top:8px; overflow-wrap:anywhere; }
.ai-field-hint .el-icon { vertical-align:-2px; margin-right:3px; }
.ai-test-row { display:flex; align-items:center; gap:12px; flex-wrap:wrap; }
.ai-test-row .ai-field-hint { margin:0; }
.ai-switch-row { display:flex; align-items:center; gap:10px; min-height:40px; }
.ai-connection-result { display:flex; align-items:center; gap:12px; color:var(--el-color-success); background:var(--el-color-success-light-9); border-radius:10px; padding:14px 16px; margin-top:18px; }
.ai-connection-result strong,.ai-connection-result span { display:block; font-size:var(--type-size-label); }
.ai-connection-result span { font-size:var(--type-size-caption); margin-top:3px; }
.ai-test-error { margin-top:18px; }
.ai-live-label { display:flex; gap:7px; align-items:center; color:var(--el-color-success); font-size:var(--type-size-caption); margin-bottom:18px; }
.ai-live-label span { height:6px; width:6px; border-radius:50%; background:currentColor; }
.ai-current-model { color:var(--el-color-primary); font-size:var(--type-size-reading); overflow-wrap:anywhere; margin:12px 0 24px; }
.ai-active-card dl { display:grid; gap:14px; margin:0 0 24px; font-size:var(--type-size-label); }
.ai-active-card dl div { display:flex; justify-content:space-between; gap:12px; }
.ai-active-card dt { color:var(--dfx-text-secondary); }.ai-active-card dd { margin:0; }
.ai-flow { display:flex; align-items:center; justify-content:space-between; gap:6px; border-top:1px solid var(--ai-border); padding-top:20px; font-size:var(--type-size-caption); color:var(--dfx-text-secondary); }
.ai-active-card>p:last-child { font-size:var(--type-size-caption); line-height:1.8; color:var(--dfx-text-secondary); margin-bottom:0; }
.ai-history { list-style:none; padding:0; margin:20px 0 0; }.ai-history li { border-left:2px solid var(--ai-border); padding:0 0 20px 14px; }.ai-history li:last-child {padding-bottom:0;}.ai-history strong {font-size:var(--type-size-label);}.ai-history strong span {margin-left:8px; font-weight:400;color:var(--dfx-text-secondary);}.ai-history p,.ai-history time {font-size:var(--type-size-caption);line-height:1.6;color:var(--dfx-text-secondary);}.ai-history p {margin:6px 0 4px;}
.ai-settings-actions { position:sticky; bottom:0; z-index:5; display:flex; justify-content:space-between; align-items:center; gap:16px; padding:18px 24px; margin-top:24px; border:1px solid var(--ai-border); border-radius:12px; background:var(--el-bg-color); box-shadow:0 -4px 20px rgba(0,0,0,.025); }
.ai-settings-actions>span {font-size:var(--type-size-label);color:var(--dfx-text-secondary);}.ai-settings-actions .is-dirty {color:var(--el-color-warning);}.ai-settings-actions>div {display:flex;gap:10px;}.ai-settings-actions :deep(.el-button+.el-button){margin-left:0;}
@media(max-width:1100px){.ai-settings-layout{grid-template-columns:1fr}.ai-settings-aside{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:600px){.ai-setting-card{padding:20px 16px}.ai-form-grid,.ai-settings-aside{grid-template-columns:1fr}.ai-settings-actions{padding:14px 12px;flex-wrap:wrap}.ai-settings-actions>div{width:100%}.ai-settings-actions :deep(.el-button){flex:1}.ai-heading-icon{display:none}}
</style>
