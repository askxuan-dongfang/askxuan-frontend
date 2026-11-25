<script setup lang="ts">
import { computed, ref } from 'vue'
import type { AgentConfig, InputField, ReportTopic, SkillInfo } from '@/api/agentOperations'

const props = defineProps<{
  config: AgentConfig
  topics: ReportTopic[]
  catalog: SkillInfo[]
  knowledgeBases: { id: string; name: string; enabled: boolean }[]
  busy: boolean
}>()
const selected = ref('')
const topic = computed(() => props.topics.find(item => item.code === selected.value) ?? props.topics[0])
const policy = computed(() => props.config.topics?.find(item => item.code === topic.value?.code))
const skills = computed(() => props.catalog.filter(info =>
  info.sourceStatus === 'enabled' && props.config.skills.some(skill => skill.code === info.code && skill.enabled)))
const tools = computed(() => skills.value.filter(info =>
  info.toolAvailable && info.einoSupported && props.config.skills.some(skill => skill.code === info.code && skill.useTool)))
const canEdit = computed(() => skills.value.some(skill => skill.code === topic.value?.code) &&
  topic.value?.requiredToolCodes.every(code => tools.value.some(tool => tool.code === code)))
const fields = computed(() => {
  const source = topic.value
  if (!source) return []
  const fields = new Map<string, InputField>()
  const extraTools = policy.value?.toolCodes?.filter(code => !source.requiredToolCodes.includes(code)) ?? []
  for (const code of [source.code, ...extraTools]) {
    const schema = props.catalog.find(skill => skill.code === code)?.inputSchema
    for (const field of schema?.fields ?? []) {
      if (!fields.has(field.key)) fields.set(field.key, code === source.code ? field : { ...field, required: false, requiredWhen: undefined })
    }
  }
  return [...fields.values()]
})

function customize() {
  const item = topic.value
  if (!item || !canEdit.value || policy.value) return
  const topics = props.config.topics ??= []
  topics.push({
    code: item.code,
    knowledgeBaseIds: props.config.knowledgeEnabled ? [...(props.config.knowledgeBaseIds ?? [])] : [],
    skillCodes: [],
    toolCodes: [...item.requiredToolCodes],
    requiredFields: [],
    additionalFields: [],
    chapters: [...item.chapters],
  })
}
function reset() {
  props.config.topics = props.config.topics?.filter(item => item.code !== topic.value?.code)
  if (!props.config.topics?.length) delete props.config.topics
}
function setTools(codes: string[]) {
  if (!policy.value || !topic.value) return
  policy.value.toolCodes = [...new Set([...topic.value.requiredToolCodes, ...codes])]
  policy.value.requiredFields = policy.value.requiredFields.filter(key => fields.value.some(field => field.key === key))
}
function setRequired(key: string, required: boolean) {
  if (!policy.value) return
  policy.value.requiredFields = required
    ? [...policy.value.requiredFields, key]
    : policy.value.requiredFields.filter(field => field !== key)
}
function addField() {
  policy.value?.additionalFields.push({ key: 'topic_' + crypto.randomUUID().replace(/-/g, ''), label: '', required: false })
}
</script>

<template>
  <section class="ops-card topic-settings">
    <el-empty v-if="!topic" :description='$t("暂无可配置的专题")' />
    <el-form v-else label-position="top" :disabled="busy" @submit.prevent>
      <div class="topic-heading">
        <el-form-item :label='$t("专题")'>
          <el-select :model-value="topic.code" :aria-label='$t("专题")' @update:model-value="selected = $event">
            <el-option v-for="item in topics" :key="item.code" :value="item.code" :label="$t(item.title)" />
          </el-select>
        </el-form-item>
        <el-button v-if="policy" text @click="reset">{{ $t("恢复专题默认") }}</el-button>
        <el-button v-else type="primary" plain :disabled="!canEdit" @click="customize">{{ $t("自定义专题") }}</el-button>
      </div>
      <p v-if="!canEdit" class="topic-hint">{{ $t("请先在「技能与工具」中启用该专题和它的基础工具。") }}</p>
      <template v-if="policy">
        <div class="topic-scopes">
          <el-form-item :label='$t("知识库")'>
            <el-select v-model="policy.knowledgeBaseIds" multiple filterable :aria-label='$t("专题知识库")'
              :placeholder='$t("留空则不检索知识库")'>
              <el-option v-for="id in config.knowledgeEnabled ? config.knowledgeBaseIds : []" :key="id" :value="id"
                :label="$t(knowledgeBases.find(base => base.id === id)?.name ?? id)"
                :disabled="knowledgeBases.some(base => base.id === id && !base.enabled)" />
            </el-select>
          </el-form-item>
          <el-form-item :label='$t("附加技能")'>
            <el-select v-model="policy.skillCodes" multiple filterable :aria-label='$t("附加技能")' :placeholder='$t("选择已启用的技能")'>
              <el-option v-for="skill in skills.filter(skill => skill.code !== topic?.code)" :key="skill.code" :value="skill.code" :label="$t(skill.name)" />
            </el-select>
          </el-form-item>
          <el-form-item class="topic-tools" :label='$t("MCP 与内置工具")'>
            <el-select :model-value="policy.toolCodes" multiple filterable :aria-label='$t("专题工具")'
              :placeholder='$t("选择已启用的工具")' @update:model-value="setTools">
              <el-option v-for="tool in tools" :key="tool.code" :value="tool.code"
                :disabled="topic.requiredToolCodes.includes(tool.code)"
                :label="$t(tool.name + (topic.requiredToolCodes.includes(tool.code) ? '（必需）' : ' · ' + tool.toolName))" />
            </el-select>
          </el-form-item>
        </div>
        <section class="topic-details">
          <h2>{{ $t("必填资料") }}</h2>
          <div v-if="fields.length" role="group" :aria-label='$t("专题必填资料")' class="topic-required">
            <el-checkbox v-for="field in fields" :key="field.key" :model-value="field.required || policy.requiredFields.includes(field.key)"
              :disabled="field.required" @update:model-value="setRequired(field.key, $event === true)">
              {{ $t(field.label || field.key) }}<span v-if="field.requiredWhen" class="topic-hint"> · {{ $t("按条件必填") }}</span>
            </el-checkbox>
          </div>
          <div v-for="(field, i) in policy.additionalFields" :key="field.key" class="topic-custom-field">
            <el-input v-model="field.label" maxlength="50" :placeholder='$t("资料名称")' :aria-label='$t("自定义资料名称")' />
            <el-checkbox v-model="field.required">{{ $t("必填") }}</el-checkbox>
            <el-button text @click="policy.additionalFields.splice(i, 1)">{{ $t("删除") }}</el-button>
          </div>
          <el-button text type="primary" :disabled="policy.additionalFields.length >= 12" @click="addField">
            {{ $t("添加自定义资料") }}
          </el-button>
        </section>
        <el-form-item :label='$t("报告章节")'>
          <el-input :model-value="policy.chapters.join('\n')" type="textarea" :rows="6" maxlength="744"
            :aria-label='$t("报告章节")' @update:model-value="policy.chapters = $event.split('\n')" />
          <span class="topic-hint">{{ $t("每行一个标题，按报告顺序填写 3 至 12 章。") }}</span>
        </el-form-item>
      </template>
      <template v-else>
        <p class="topic-hint">{{ $t("正在使用默认配置。自定义后与问事助手一起保存、评测和发布。") }}</p>
        <h2>{{ $t("报告章节") }}</h2>
        <ol class="topic-outline"><li v-for="chapter in topic.chapters" :key="chapter">{{ $t(chapter) }}</li></ol>
      </template>
    </el-form>
  </section>
</template>

<style scoped>
.topic-heading { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 12px; margin-bottom: 20px }
.topic-heading .el-form-item { width: min(100%, 320px); margin: 0 }
.topic-scopes { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 250px), 1fr)); gap: 0 20px }
.topic-tools { grid-column: 1 / -1 }
.topic-details { margin-bottom: 20px; padding-block: 16px; border-top: 1px solid var(--el-border-color-light) }
.topic-required { display: flex; flex-wrap: wrap; align-items: center; gap: 0 16px }
.topic-required .el-checkbox { margin: 0; height: auto; min-height: 32px; white-space: normal }
.topic-custom-field { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 12px; margin-block: 10px }
.topic-custom-field .el-input { flex: 1 1 180px }
.topic-custom-field .el-checkbox { margin: 0 }
.topic-hint { color: var(--el-text-color-secondary); font-size: 13px }
.topic-outline { padding-inline-start: 20px; margin: 0; line-height: 1.8 }
</style>
