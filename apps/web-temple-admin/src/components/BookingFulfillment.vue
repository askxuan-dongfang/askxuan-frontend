<script setup lang="ts">
import { ref, watch, onUnmounted } from 'vue';
import client from '@/api/client';
import { ElMessage } from 'element-plus';
type FileRow = {
    id: string;
    name: string;
    contentType: string;
    sha256: string;
};
type Receipt = {
    id: string;
    summary: string;
    createdAt: string;
    digest: string;
    files: FileRow[];
};
const props = defineProps<{
    id: string;
    status: string;
}>();
const emit = defineEmits<{
    changed: [
    ];
}>();
const receipts = ref<Receipt[]>([]), files = ref<FileRow[]>([]), summary = ref(''), error = ref(''), busy = ref(false);
const previews = ref<Record<string, string>>({});
async function load() { try {
    const d = await client.get<{
        receipts: Receipt[];
    }>(`/bookings/${props.id}/fulfillment`);
    receipts.value = d.receipts;
    error.value = '';
}
catch (e) {
    error.value = (e as Error).message;
} }
watch(() => [props.id, props.status], () => void load(), { immediate: true });
onUnmounted(() => Object.values(previews.value).forEach(URL.revokeObjectURL));
async function upload(e: Event) { const input = e.target as HTMLInputElement; const selected = Array.from(input.files || []); input.value = ''; if (files.value.length + selected.length > 8) {
    error.value = '最多上传 8 个文件';
    return;
} busy.value = true; error.value = ''; try {
    for (const f of selected) {
        if (f.size > 20 * 1024 * 1024)
            throw Error('单个文件不能超过 20 MB');
        const data = new FormData();
        data.append('file', f);
        files.value.push(await client.post<FileRow>(`/bookings/${props.id}/receipt-files`, data, { headers: { 'Content-Type': 'multipart/form-data' }, timeout: 60000 }));
    }
}
catch (e) {
    error.value = (e as Error).message;
}
finally {
    busy.value = false;
} }
async function preview(f: FileRow) { try {
    const blob = await client.get<Blob>(`/bookings/${props.id}/receipt-files/${f.id}`, { responseType: 'blob' });
    if (blob.type.includes('json'))
        throw Error('回执读取失败');
    previews.value[f.id] = URL.createObjectURL(blob);
}
catch (e) {
    error.value = (e as Error).message;
} }
async function submit() { busy.value = true; error.value = ''; try {
    await client.post(`/bookings/${props.id}/receipts`, { summary: summary.value, fileIds: files.value.map(f => f.id) });
    files.value = [];
    summary.value = '';
    await load();
    emit('changed');
    ElMessage.success('回执已提交，等待信众确认');
}
catch (e) {
    error.value = (e as Error).message;
}
finally {
    busy.value = false;
} }
</script>
<template>
 <section class="df-card" style="padding:20px;margin-bottom:16px">
  <h3>履约回执</h3><p>确认接单 → 执行服务 → 提交回执 → 信众确认完成</p>
  <el-alert v-if="error" :title="error" type="error" :closable="false"/><el-button v-if="error" @click="load">重试</el-button>
  <p v-if="!receipts.length">{{ ['completed','reviewed'].includes(status)?'此历史订单未留存履约回执。':'尚未提交回执。' }}</p>
  <article v-for="(r,i) in receipts" :key="r.id" style="border-top:1px solid var(--admin-border-strong);padding:12px 0">
   <strong>回执 {{ i+1 }} · {{ r.createdAt }}</strong><p style="white-space:pre-wrap">{{ r.summary }}</p>
   <div v-for="f in r.files" :key="f.id" style="margin-bottom:8px">
    <template v-if="previews[f.id]"><video v-if="f.contentType.startsWith('video/')" :src="previews[f.id]" controls style="max-width:100%;max-height:360px"/><img v-else :src="previews[f.id]" :alt="f.name" style="max-width:100%;max-height:360px"/></template>
    <el-button v-else @click="preview(f)">查看{{ f.contentType.startsWith('video/')?'视频':'图片' }} · {{ f.name }}</el-button>
   </div>
   <details><summary>回执校验信息</summary><p style="overflow-wrap:anywhere">{{ r.digest }}</p><p>文件 SHA-256 完整性校验，非区块链存证。</p></details>
  </article>
  <div v-if="status==='in_progress'">
   <label>执行说明（5–2000 字）</label><el-input v-model="summary" type="textarea" :rows="4" :maxlength="2000" placeholder="说明执行内容、时间和结果"/>
   <p><label>图片／视频（1–8 个，每个最多 20 MB）<input type="file" multiple accept="image/jpeg,image/png,image/webp,video/mp4,video/webm" :disabled="busy" @change="upload"/></label></p>
   <div v-for="f in files" :key="f.id">{{ f.name }} <el-button text :disabled="busy" @click="files=files.filter(x=>x.id!==f.id)">移除</el-button></div>
   <el-button type="primary" :loading="busy" :disabled="busy||summary.trim().length<5||!files.length" @click="submit">提交回执，等待信众确认</el-button>
  </div>
  <el-alert v-if="status==='pending_receipt'" title="回执已提交，等待信众核对；信众要求补充时可继续提交新版本。" type="info" :closable="false"/>
 </section>
</template>
