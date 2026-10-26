<script setup lang="ts">
import { ref, nextTick, onMounted, onUnmounted } from 'vue'
import client from '@/api/client'
import { t as uiText } from '../../../../packages/localization/language'

type Message = { id: number; senderType: string; content: string; createTime: string; kind?: string; attachment?: { id: string; name: string } }
type Window = { list: Message[]; hasMore: boolean }
const props = defineProps<{ id: string }>()
const conversation = ref<{ canChat: boolean; peerName: string } | null>(null)
const messages = ref<Message[]>([])
const draft = ref('')
const error = ref('')
const sending = ref(false)
const more = ref(false)
const olderLoading = ref(false)
const area = ref<HTMLElement>()
const history = ref<HTMLElement>()
let alive = true
let syncing = false
let timer: ReturnType<typeof setInterval>
let pending: { clientMessageId: string; content: string } | null = null
const endpoint = `/chats/${encodeURIComponent(props.id)}`
function merge(rows: Message[]) {
  const all = new Map(messages.value.map(row => [row.id, row]))
  rows.forEach(row => all.set(row.id, row))
  messages.value = [...all.values()].sort((a, b) => a.id - b.id)
}
async function sync(first = false) {
  if (syncing || !alive) return
  syncing = true
  try {
    const [detail, result] = await Promise.all([
      client.get<{ canChat: boolean; peerName: string }>(endpoint),
      client.get<Window>(endpoint + '/messages', { params: { size: 100, afterId: first ? undefined : messages.value.at(-1)?.id } })
    ])
    if (!alive) return
    conversation.value = detail
    if (first) more.value = result.hasMore
    const follow = first || !history.value || history.value.scrollHeight - history.value.scrollTop - history.value.clientHeight < 40
    merge(result.list)
    await nextTick()
    if (follow && history.value) history.value.scrollTop = history.value.scrollHeight
    error.value = ''
    const rect = area.value?.getBoundingClientRect()
    if (document.hasFocus() && document.visibilityState === 'visible' && rect && rect.top < innerHeight && rect.bottom > 0 && follow && messages.value.length) {
      await client.post(endpoint + '/read', { throughId: messages.value.at(-1)!.id })
    }
  } catch (e) { if (alive) error.value = e instanceof Error ? e.message : uiText('加载失败') }
  finally { syncing = false }
}
async function older() {
  if (olderLoading.value) return
  olderLoading.value = true
  try {
    const result = await client.get<Window>(endpoint + '/messages', { params: { size: 100, beforeId: messages.value[0]?.id } })
    if (alive) { merge(result.list); more.value = result.hasMore }
  } catch (e) { if (alive) error.value = e instanceof Error ? e.message : uiText('加载失败') }
  finally { olderLoading.value = false }
}
async function send() {
  const content = draft.value.trim()
  if (!content || sending.value || !conversation.value?.canChat) return
  if (pending?.content !== content) pending = { clientMessageId: crypto.randomUUID(), content }
  sending.value = true
  try {
    const row = await client.post<Message>(endpoint + '/messages', pending)
    if (!alive) return
    merge([row]); draft.value = ''; pending = null; error.value = ''
    await sync()
  } catch (e) { if (alive) error.value = e instanceof Error ? e.message : uiText('发送失败') }
  finally { sending.value = false }
}
async function download(message: Message) {
  if (!message.attachment) return
  try {
    const file = await client.get<Blob>(endpoint + '/attachments/' + encodeURIComponent(message.attachment.id), { responseType: 'blob' })
    const url = URL.createObjectURL(file)
    const a = document.createElement('a'); a.href = url; a.download = message.attachment.name; a.click()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  } catch (e) { error.value = e instanceof Error ? e.message : uiText('下载失败') }
}
onMounted(() => {
  void sync(true)
  timer = setInterval(() => { if (document.visibilityState === 'visible') void sync() }, 4000)
})
onUnmounted(() => { alive = false; clearInterval(timer) })
</script>

<template>
  <section class="df-card booking-chat" ref="area" aria-label="预约沟通">
    <header><h2>{{ $t('预约沟通') }}</h2><el-button text @click="sync()">{{ $t('刷新') }}</el-button></header>
    <p class="muted">{{ $t('与信众沟通本次全院服务的安排和履约事项。') }}</p>
    <el-button v-if="more" text :loading="olderLoading" @click="older">{{ $t('加载更早消息') }}</el-button>
    <div ref="history" class="chat-history" aria-live="polite" role="log">
      <p v-if="!messages.length" class="muted">{{ $t('暂无消息') }}</p>
      <article v-for="message in messages" :key="message.id" :class="{ own: message.senderType === 'temple' }">
        <div class="message-meta">{{ message.senderType === 'temple' ? $t('寺院') : (conversation?.peerName || $t('信众')) }} · {{ message.createTime }}</div>
        <p>{{ message.content }}</p>
        <el-button v-if="message.attachment" text @click="download(message)">{{ message.attachment.name }}</el-button>
      </article>
    </div>
    <p v-if="error" role="alert" class="error">{{ error }}</p>
    <form v-if="conversation?.canChat" @submit.prevent="send">
      <label for="temple-booking-message">{{ $t('发送消息') }}</label>
      <el-input id="temple-booking-message" v-model="draft" type="textarea" :rows="3" :maxlength="2000" show-word-limit :disabled="sending" :placeholder="$t('请输入消息内容')" />
      <div class="send-action"><el-button type="primary" native-type="submit" :loading="sending" :disabled="!draft.trim()">{{ $t('发送消息') }}</el-button></div>
    </form>
    <p v-else-if="conversation" class="muted">{{ $t('预约已取消，仅可查看历史消息') }}</p>
  </section>
</template>

<style scoped>
.booking-chat { padding: 18px 20px; margin-bottom: 16px; }
header { display: flex; align-items: center; justify-content: space-between; }
h2 { font-family: var(--font-serif); font-size: var(--type-size-control); margin: 0; }
.muted, .message-meta { color: var(--admin-text-secondary); font-size: var(--type-size-label); }
.chat-history { max-height: 360px; overflow: auto; margin: 12px 0; }
article { padding: 10px 12px; margin: 8px 12% 8px 0; border-radius: 10px; background: var(--admin-surface-muted); }
article.own { margin: 8px 0 8px 12%; border: 0; }
article p { margin: 6px 0 0; white-space: pre-wrap; overflow-wrap: anywhere; }
form label { display: block; margin-bottom: 8px; }
.send-action { display: flex; justify-content: flex-end; margin-top: 10px; }
.error { color: var(--el-color-danger); }
</style>
