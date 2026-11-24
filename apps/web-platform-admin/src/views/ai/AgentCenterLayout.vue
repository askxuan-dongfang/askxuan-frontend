<script setup lang="ts">
import { computed, provide, ref } from 'vue'
import { Collection, Connection, Cpu } from '@element-plus/icons-vue'
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
  <section class="agent-center" :aria-label='$t("问事智能体")'>
    <div class="center-chrome">
      <header class="center-navigation">
        <div class="center-identity">
          <span class="center-mark" aria-hidden="true"><el-icon><Connection /></el-icon></span>
          <strong class="center-agent-name">{{ $t("问事智能体") }}</strong>
        </div>
        <nav class="center-stages" :aria-label='$t("开发流程")'>
          <RouterLink v-for="stage in agentWorkflow" :key="stage.title" :to="stage.steps[0].path"
            :class="{ 'is-current': activeStage === stage }" :aria-current="activeStage === stage ? 'step' : undefined">
            {{ $t(stage.title) }}
          </RouterLink>
        </nav>
        <nav class="center-resources" :aria-label='$t("共享资源")'>
          <RouterLink to="/ai/connections" :class="{ 'is-current': route.path.startsWith('/ai/connections') }">
            <el-icon aria-hidden="true"><Cpu /></el-icon>{{ $t("模型与连接") }}
          </RouterLink>
          <RouterLink to="/ai/knowledge">
            <el-icon aria-hidden="true"><Collection /></el-icon>{{ $t("知识中心") }}
          </RouterLink>
        </nav>
      </header>
      <nav v-if="activeStage && activeStage.steps.length > 1" class="center-steps" :aria-label='$t(activeStage.title)'>
        <RouterLink v-for="step in activeStage.steps" :key="step.path" :to="step.path">{{ $t(step.title) }}</RouterLink>
      </nav>
    </div>
    <RouterView v-slot="{ Component }">
      <KeepAlive include="AgentOperationsView">
        <component :is="Component" />
      </KeepAlive>
    </RouterView>
  </section>
</template>

<style scoped>
.agent-center {
  --studio-line: var(--el-border-color-light);
  --studio-surface: var(--el-bg-color);
  --studio-muted: var(--el-text-color-secondary);
  --studio-tint: var(--el-color-primary-light-9);
  min-width: 0;
}
.center-chrome {
  width: min(100%, var(--admin-content-max));
  margin-inline: auto;
  padding: var(--admin-page-padding);
  padding-block-end: 0;
}
.center-navigation {
  display: flex;
  align-items: stretch;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 2px 24px;
  border-bottom: 1px solid var(--studio-line);
}
.center-stages, .center-resources, .center-steps {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px 8px;
}
.center-identity {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 48px;
}
.center-mark {
  display: grid;
  place-items: center;
  flex: none;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--studio-tint);
  color: var(--el-color-primary);
  font-size: 18px;
}
.center-agent-name {
  color: var(--el-text-color-primary);
  font-size: 17px;
  white-space: nowrap;
}
.center-stages { align-items: stretch; margin-inline-end: auto }
.center-navigation a, .center-steps a {
  display: inline-flex;
  justify-content: center;
  align-items: center;
  min-height: 44px;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 6px;
  color: var(--el-text-color-regular);
  font-size: 14px;
  text-decoration: none;
  white-space: nowrap;
}
.center-stages a {
  position: relative;
  border-radius: 0;
  font-weight: 600;
}
.center-stages a.is-current::after {
  position: absolute;
  inset: auto 8px -1px;
  height: 2px;
  background: var(--el-color-primary);
  content: '';
}
.center-resources a { font-size: 13px }
.center-steps { padding-block: 8px 0 }
.center-steps a { min-height: 36px; padding-inline: 12px; font-size: 13px }
.center-navigation a:hover, .center-steps a:hover { background: var(--el-fill-color-light) }
.center-stages a.is-current { color: var(--el-color-primary) }
.center-resources a.is-current, .center-resources a.router-link-exact-active, .center-steps .router-link-exact-active {
  background: var(--studio-tint);
  color: var(--el-color-primary);
  font-weight: 600;
}
.center-navigation a:focus-visible, .center-steps a:focus-visible {
  outline: 2px solid var(--el-color-primary);
  outline-offset: 2px;
}
@media (max-width: 780px) {
  .center-navigation { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 0 4px }
  .center-stages {
    grid-area: 2 / 1 / auto / -1;
    display: grid;
    grid-template-columns: 1fr 1.8fr 1fr 1fr;
    gap: 2px;
    margin: 0;
  }
  .center-stages a { padding-inline: 7px; font-size: 13px }
  .center-resources { grid-area: 1 / 2 }
  .center-resources a { padding-inline: 8px }
  .center-resources .el-icon { display: none }
  .center-agent-name { font-size: 15px }
  .center-steps { gap: 2px }
  .center-steps a { min-height: 40px; padding-inline: 8px }
}
</style>
