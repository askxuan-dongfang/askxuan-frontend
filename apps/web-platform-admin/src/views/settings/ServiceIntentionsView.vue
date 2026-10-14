<script setup lang="ts">
import {onMounted,ref} from 'vue'
import client from '@/api/client'
import {ElMessage} from 'element-plus'
const tags=[['peace','求平安'],['wealth','求财运'],['love','求姻缘'],['career','求事业'],['study','求学业'],['taisui','化太岁'],['rite','做法事']]
type Row={kind:string;id:string;name:string;serviceCode:string;serviceName:string;tags:string;selected:string[]}
const rows=ref<Row[]>([]),busy=ref(false),error=ref('')
async function load(){busy.value=true;try{const d=await client.get<{list:Row[]}>('/admin/platform/intentions/bindings');rows.value=d.list.map(r=>({...r,selected:r.tags?r.tags.split(','):[]}));error.value=''}catch(e){error.value=String(e)}finally{busy.value=false}}
async function save(row:Row){busy.value=true;try{await client.put('/admin/platform/intentions/bindings',{kind:row.kind,id:row.id,serviceCode:row.serviceCode,tags:row.selected});ElMessage.success('关联已保存');await load()}catch(e){error.value=String(e)}finally{busy.value=false}}
onMounted(load)
</script>
<template><section><h1>心愿与服务关联</h1><p>七个心愿入口保持固定。逐项选择这家寺院／这位师傅的实际服务适用哪些心愿；空选表示不进入心愿聚合。这里只管理关联，不替代服务上架或资质审核。</p><el-alert v-if="error" :title="error" type="error"/><el-table :data="rows" v-loading="busy"><el-table-column prop="name" label="提供者" width="180"/><el-table-column label="类型" width="90"><template #default="{row}">{{row.kind==='master'?'师傅':'寺院'}}</template></el-table-column><el-table-column prop="serviceName" label="实际服务" width="140"/><el-table-column label="关联心愿"><template #default="{row}"><el-checkbox-group v-model="row.selected"><el-checkbox v-for="[code,name] in tags" :key="code" :value="code">{{name}}</el-checkbox></el-checkbox-group></template></el-table-column><el-table-column label="操作" width="90"><template #default="{row}"><el-button :disabled="busy" @click="save(row)">保存</el-button></template></el-table-column></el-table></section></template>
