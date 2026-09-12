<script setup lang="ts">
import { isAdminSessionExpired } from '@/api/client'
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import client from '@/api/client'
type Design = { id:number; name:string; userId:string; status:string; revision:number; sourceDesignId:number; totalPrice:number; description:string; updateTime:string; designData:string }
const list=ref<Design[]>([]), loading=ref(false), error=ref(''), total=ref(0), acting=ref(0)
const query=reactive({page:1,size:20,status:'public',keyword:''})
const labels:Record<string,string>={private:'私密草稿',public:'已发布',pending_review:'待审核',approved:'已通过',rejected:'已下架'}
async function load(){loading.value=true;error.value='';try{const r=await client.get<{list:Design[];total:number}>('/admin/diy/designs',{params:query});list.value=r.list||[];total.value=r.total}catch(e){error.value=e instanceof Error?e.message:'作品加载失败'}finally{loading.value=false}}
async function remove(d:Design){try{await ElMessageBox.confirm(`下架「${d.name}」后，公开链接、复制和新定制将停止。已有副本和订单保留。`,'下架设计',{type:'warning',confirmButtonText:'确认下架',cancelButtonText:'取消'})}catch{return}acting.value=d.id;try{await client.put(`/admin/diy/designs/${d.id}/status`,{revision:d.revision,status:'rejected'});ElMessage.success('作品已下架');await load()}catch(e){ if (isAdminSessionExpired(e)) return;ElMessage.error(e instanceof Error?e.message:'下架失败，请重试')}finally{acting.value=0}}
onMounted(load)
</script>
<template>
 <section class="design-manager"><header><div><h2>设计广场</h2><p>查看已发布作品、设计来源与材料参考价，管理公开展示。</p></div><el-button @click="load">刷新</el-button></header>
 <div class="filters"><el-select v-model="query.status" @change="query.page=1;load()" style="width:160px"><el-option label="全部状态" value=""/><el-option v-for="(label,key) in labels" :key="key" :label="label" :value="key"/></el-select><el-input v-model="query.keyword" placeholder="搜索设计名称" clearable @keyup.enter="query.page=1;load()" style="max-width:260px"/><el-button @click="query.page=1;load()">查询</el-button></div>
 <el-alert v-if="error" :title="error" type="error" :closable="false"/>
 <el-table :data="list" v-loading="loading" style="width:100%"><el-table-column label="设计" min-width="200"><template #default="{row}"><strong>{{row.name}}</strong><p class="muted">{{row.description||'未填写灵感说明'}}</p></template></el-table-column><el-table-column prop="userId" label="作者ID" width="110"/><el-table-column label="来源" width="130"><template #default="{row}">{{row.sourceDesignId?`作品 #${row.sourceDesignId} 的副本`:'原创设计'}}</template></el-table-column><el-table-column label="材料参考价" width="120"><template #default="{row}">¥{{row.totalPrice.toFixed(2)}}</template></el-table-column><el-table-column label="状态" width="110"><template #default="{row}"><el-tag>{{labels[row.status]||row.status}}</el-tag></template></el-table-column><el-table-column prop="updateTime" label="最近更新" width="175"/><el-table-column label="操作" width="145" fixed="right"><template #default="{row}"><a v-if="row.status==='public'" :href="`/c/diy/${row.id}`" target="_blank" rel="noopener">查看</a><el-button v-if="row.status==='public'" link type="danger" :loading="acting===row.id" @click="remove(row)">下架</el-button><span v-else class="muted">仅作者可编辑</span></template></el-table-column></el-table>
 <el-pagination v-model:current-page="query.page" :page-size="query.size" :total="total" layout="prev,pager,next,total" @current-change="load"/>
 </section>
</template>
<style scoped>.design-manager{padding:22px;border:1px solid var(--admin-border);border-radius:14px;margin-bottom:24px}header{display:flex;justify-content:space-between;gap:20px;align-items:center}h2{font-size:20px;margin:0 0 8px}p,.muted{color:var(--color-text-secondary,#897b6b);font-size:12px;line-height:1.7}p{margin:0 0 16px}.filters{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:18px}.el-pagination{margin-top:20px;overflow:auto}a{margin-right:12px;color:var(--admin-accent);text-decoration:none}</style>
