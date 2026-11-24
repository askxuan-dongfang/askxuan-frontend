<script setup lang="ts">
import { computed, provide, ref } from 'vue'
import { onBeforeRouteLeave, useRoute } from 'vue-router'
import { ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'
import { agentDraftDirtyKey, agentWorkflow } from './centerNavigation'

const route = useRoute()
const activeStage = computed(() => agentWorkflow.find(stage => stage.steps.some(step => step.section === route.meta.agentSection)))
const draftDirty = ref(false)
provide(agentDraftDirtyKey, draftDirty)

onBeforeRouteLeave(async () => {
  if (!draftDirty.value) return true
  try {
    await ElMessageBox.confirm(uiText('当前草稿尚未保存，离开后将丢弃修改。'), uiText('离开智能体管理'), {
      confirmButtonText: uiText('离开'), cancelButtonText: uiText('继续编辑'),
    })
    return true
  } catch {
    return false
  }
})
</script>

<template>
  <div class="agent-center">
    <div class="center-chrome">
      <div class="center-navigation">
        <nav class="center-stages" :aria-label='$t("开发流程")'>
          <RouterLink v-for="stage in agentWorkflow" :key="stage.title" :to="stage.steps[0].path"
            :class="{ 'is-current': activeStage === stage }" :aria-current="activeStage === stage ? 'step' : undefined">
            {{ $t(stage.title) }}
          </RouterLink>
        </nav>
        <nav class="center-resources" :aria-label='$t("共享资源")'>
          <RouterLink to="/ai/connections" :class="{ 'is-current': route.path.startsWith('/ai/connections') }">{{ $t("模型与连接") }}</RouterLink>
          <RouterLink to="/ai/knowledge">{{ $t("知识中心") }}</RouterLink>
        </nav>
      </div>
      <nav v-if="activeStage && activeStage.steps.length > 1" class="center-steps" :aria-label='$t(activeStage.title)'>
        <RouterLink v-for="step in activeStage.steps" :key="step.path" :to="step.path">{{ $t(step.title) }}</RouterLink>
      </nav>
    </div>
    <RouterView v-slot="{ Component }">
      <KeepAlive include="AgentOperationsView">
        <component :is="Component" />
      </KeepAlive>
    </RouterView>
  </div>
</template>

<style scoped>
.agent-center { min-width: 0 }
.center-chrome {
  width: min(100%, var(--admin-content-max));
  margin-inline: auto;
  padding: var(--admin-page-padding);
  padding-bottom: 0;
}
.center-navigation {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 4px 16px;
  padding: 4px 14px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 12px;
  background: var(--el-bg-color);
}
.center-stages, .center-resources, .center-steps {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px 6px;
}
.center-navigation a, .center-steps a {
  display: inline-flex;
  justify-content: center;
  align-items: center;
  min-height: 44px;
  padding: 6px 12px;
  border-radius: 7px;
  color: var(--el-text-color-regular);
  font-size: 14px;
  text-decoration: none;
  white-space: nowrap;
}
.center-stages a { font-weight: 600 }
.center-resources a { font-size: 13px }
.center-steps { margin-top: 8px }
.center-steps a { padding-inline: 12px; font-size: 13px }
.center-navigation a:hover, .center-steps a:hover { background: var(--el-fill-color-light) }
.center-navigation a.is-current, .center-navigation a.router-link-exact-active, .center-steps .router-link-exact-active {
  background: var(--el-color-primary-light-9);
  color: var(--el-color-primary);
  font-weight: 600;
}
.center-navigation a:focus-visible, .center-steps a:focus-visible {
  outline: 2px solid var(--el-color-primary);
  outline-offset: 2px;
}
@media (max-width: 640px) {
  .center-navigation { display: grid; grid-template-columns: minmax(0, 1fr); gap: 4px; padding: 6px 8px }
  .center-stages { display: grid; grid-template-columns: 1fr 1.8fr 1fr 1fr; gap: 2px }
  .center-stages a { padding-inline: 7px; font-size: 13px }
  .center-resources { border-top: 1px solid var(--el-border-color-light) }
  .center-steps { gap: 2px }
  .center-steps a { padding-inline: 8px }
}
</style>
