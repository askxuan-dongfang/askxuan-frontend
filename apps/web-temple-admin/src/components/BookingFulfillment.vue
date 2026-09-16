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
type ProgressRecord={id:string;kind:string;content:string;createdAt:string;operatorType:string;files:FileRow[]};
const records=ref<ProgressRecord[]>([]), note=ref(''), stageFiles=ref<FileRow[]>([]);
let requestId=crypto.randomUUID();
const previews = ref<Record<string, string>>({});
async function load() { try {
    const d = await client.get<{
        receipts: Receipt[]; records:ProgressRecord[];
    }>(`/bookings/${props.id}/fulfillment`);
    receipts.value = d.receipts; records.value=d.records||[];
    error.value = '';
}
catch (e) {
    error.value = (e as Error).message;
} }
watch(() => [props.id, props.status], () => void load(), { immediate: true });
onUnmounted(() => Object.values(previews.value).forEach(URL.revokeObjectURL));
async function upload(e: Event, stage=false) { const input = e.target as HTMLInputElement; const selected = Array.from(input.files || []); const target=stage?stageFiles:files; input.value = ''; if (target.value.length + selected.length > 8) {
    error.value = '最多上传 8 个文件';
    return;
} busy.value = true; error.value = ''; try {
    for (const f of selected) {
        if (f.size > 20 * 1024 * 1024)
            throw Error('单个文件不能超过 20 MB');
        const data = new FormData();
        data.append('file', f);
        target.value.push(await client.post<FileRow>(`/bookings/${props.id}/receipt-files`, data, { headers: { 'Content-Type': 'multipart/form-data' }, timeout: 60000 }));
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
    if(previews.value[f.id]) URL.revokeObjectURL(previews.value[f.id]);
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
async function publishStage(){busy.value=true;error.value='';try{await client.post(`/bookings/${props.id}/progress/update`,{id:requestId,content:note.value,fileIds:stageFiles.value.map(f=>f.id)});note.value='';stageFiles.value=[];requestId=crypto.randomUUID();await load();emit('changed');ElMessage.success('阶段记录已发布，信众可以查看')}catch(e){error.value=(e as Error).message}finally{busy.value=false}}
watch([note,stageFiles],()=>{requestId=crypto.randomUUID()},{deep:true})
</script>
<template>
 <section class="df-card" style="padding:20px;margin-bottom:16px">
  <h3>心愿与过程记录</h3>
  <p v-if="!records.length">尚未留下心愿或阶段记录。</p>
  <article v-for="r in records" :key="r.id" class="stage-record" :class="{'is-wish':r.kind==='wish'}">
   <strong>{{r.kind==='wish'?'信众心愿':'执行记录'}}</strong><time>{{r.createdAt}}</time><p>{{r.content}}</p>
   <div v-for="f in r.files" :key="f.id"><template v-if="previews[f.id]"><video v-if="f.contentType.startsWith('video/')" :src="previews[f.id]" controls preload="metadata"/><img v-else :src="previews[f.id]" :alt="f.name"/></template><el-button v-else @click="preview(f)">查看{{f.contentType.startsWith('video/')?'视频':'图片'}} · {{f.name}}</el-button></div>
  </article>
  <div v-if="status==='in_progress'" class="stage-composer">
   <h4>发布阶段记录</h4><p>说明实际执行的步骤，让信众了解服务进展。</p><label for="stage-note">本阶段的执行情况</label><el-input id="stage-note" v-model="note" type="textarea" :rows="3" maxlength="2000"/>
   <p><label>添加图片／视频（选填，每条最多 8 个，每个最多 20 MB）<input type="file" multiple accept="image/jpeg,image/png,image/webp,video/mp4,video/webm" :disabled="busy" @change="upload($event,true)"/></label></p>
   <div v-for="f in stageFiles" :key="f.id">{{f.name}}<el-button text :disabled="busy" @click="stageFiles=stageFiles.filter(x=>x.id!==f.id)">移除</el-button></div>
   <el-button type="primary" :loading="busy" :disabled="busy||note.trim().length<2" @click="publishStage">发布真实进展</el-button>
  </div>
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
   <p><label>图片／视频（1–8 个，每个最多 20 MB）<input type="file" multiple accept="image/jpeg,image/png,image/webp,video/mp4,video/webm" :disabled="busy" @change="upload($event)"/></label></p>
   <div v-for="f in files" :key="f.id">{{ f.name }} <el-button text :disabled="busy" @click="files=files.filter(x=>x.id!==f.id)">移除</el-button></div>
   <el-button type="primary" :loading="busy" :disabled="busy||summary.trim().length<5||!files.length" @click="submit">提交回执，等待信众确认</el-button>
  </div>
  <el-alert v-if="status==='pending_receipt'" title="回执已提交，等待信众核对；信众要求补充时可继续提交新版本。" type="info" :closable="false"/>
 </section>
</template>

<style scoped>
.stage-record{border-left:2px solid var(--el-color-primary);padding:12px 16px;margin:14px 0;background:var(--el-fill-color-light);border-radius:0 10px 10px 0}.stage-record.is-wish{background:var(--el-color-primary-light-9)}.stage-record time{margin-left:14px;font-size:12px;color:var(--el-text-color-secondary)}.stage-record p{white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.7}.stage-record img,.stage-record video{max-width:100%;max-height:300px;border-radius:8px;margin:8px 0}.stage-composer{border:1px solid var(--admin-border-strong);padding:18px;border-radius:12px;margin:20px 0}.stage-composer h4{margin:0}.stage-composer p{color:var(--el-text-color-secondary)}
</style>
