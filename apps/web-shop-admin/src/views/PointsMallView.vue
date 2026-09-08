<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import 'element-plus/es/components/message/style/css'
import 'element-plus/es/components/message-box/style/css'
import 'element-plus/es/components/loading/style/css'
import client from '@/api/client'
import ImageUploader from '@/components/ImageUploader.vue'
interface Product { id:number; name:string; category:string; description:string; image:string; pointsPrice:number; stock:number; status:string; version:number }
interface Order { id:number; orderNo:string; productName:string; quantity:number; pointsTotal:number; status:string; receiver:string; mobile:string; address:string; carrier:string; trackingNo:string; createdAt:string }
const keyword=ref(''), status=ref(''), loaded=ref(false)
const products=ref<Product[]>([]), orders=ref<Order[]>([])
const report=reactive({productCount:0,orderCount:0,pointsSpent:0,pendingCount:0})
const tab=ref('products'), page=ref(1), busy=ref(false), error=ref(''), editing=ref(false), shipping=ref<Order|null>(null)
const form=reactive<Product>({id:0,name:'',category:'',description:'',image:'',pointsPrice:1,stock:0,status:'draft',version:0})
const shipment=reactive({carrier:'',trackingNo:''})
const labels:Record<string,string>={draft:'草稿',on_sale:'上架',off_sale:'下架',pending:'待发货',shipped:'已发货',completed:'已完成',cancelled:'已取消'}
async function load(){busy.value=true;error.value='';try{const [r,rows]=await Promise.all([client.get<typeof report>('/admin/points/report'),client.get<Product[]|Order[]>(`/admin/points/${tab.value}`,{params:{page:page.value,keyword:keyword.value,status:status.value}})]);Object.assign(report,r);loaded.value=true;if(tab.value==='products')products.value=rows as Product[];else orders.value=rows as Order[]}catch(e){error.value=e instanceof Error?e.message:'加载失败'}finally{busy.value=false}}
function edit(p?:Product){Object.assign(form,p||{id:0,name:'',category:'',description:'',image:'',pointsPrice:1,stock:0,status:'draft',version:0});editing.value=true}
async function save(){if(!form.name.trim()||!Number.isInteger(form.pointsPrice)||form.pointsPrice<1||!Number.isInteger(form.stock)||form.stock<0){ElMessage.error('请填写商品名称、正整数积分价格和非负整数库存');return}busy.value=true;try{if(form.id)await client.put(`/admin/points/products/${form.id}`,form);else await client.post('/admin/points/products',form);editing.value=false;ElMessage.success('商品已保存');await load()}catch(e){error.value=e instanceof Error?e.message:'操作失败';ElMessage.error(error.value)}finally{busy.value=false}}
async function cancel(o:Order){try{await ElMessageBox.confirm(`取消 ${o.orderNo}，退回 ${o.pointsTotal} 积分并恢复库存？`,'取消兑换')}catch{return}busy.value=true;try{await client.post(`/admin/points/orders/${o.id}/cancel`);await load()}catch(e){error.value=e instanceof Error?e.message:'操作失败';ElMessage.error(error.value)}finally{busy.value=false}}
function openShip(o:Order){shipping.value=o;shipment.carrier='';shipment.trackingNo=''}
async function ship(){if(!shipping.value||!shipment.carrier.trim()||!shipment.trackingNo.trim()){ElMessage.error('请填写物流公司和运单号');return}busy.value=true;try{await client.post(`/admin/points/orders/${shipping.value.id}/ship`,shipment);shipping.value=null;await load()}catch(e){error.value=e instanceof Error?e.message:'操作失败';ElMessage.error(error.value)}finally{busy.value=false}}
function switchTab(){page.value=1;status.value='';keyword.value='';void load()}
onMounted(load)
</script>
<template>
  <div class="points-page">
    <div class="points-heading"><div><span class="eyebrow">REWARDS STUDIO</span><h1>积分商城</h1></div><el-button :loading="busy" @click="load">刷新数据</el-button></div><p class="intro">独立商品、库存与兑换订单；使用积分兑换，报表独立计算。</p>
    <div class="metrics"><el-card><span>积分商品</span><strong>{{loaded?report.productCount:'—'}}</strong></el-card><el-card><span>兑换订单</span><strong>{{loaded?report.orderCount:'—'}}</strong></el-card><el-card><span>已兑换积分（扣除取消）</span><strong>{{loaded?report.pointsSpent:'—'}}</strong></el-card><el-card><span>待发货</span><strong>{{loaded?report.pendingCount:'—'}}</strong></el-card></div>
    <el-alert v-if="error" :title="error" type="error" show-icon :closable="false"/>
    <el-tabs v-model="tab" @tab-change="switchTab"><el-tab-pane name="products" label="积分商品"/><el-tab-pane name="orders" label="兑换订单"/></el-tabs>
    <div class="toolbar"><el-input v-model="keyword" clearable placeholder="搜索商品、分类或兑换单号" aria-label="积分商城搜索" style="max-width:300px" @keyup.enter="page=1;load()"/><el-select v-model="status" clearable placeholder="全部状态" style="width:160px" @change="page=1;load()"><el-option v-for="key in (tab==='products'?['draft','on_sale','off_sale']:['pending','shipped','completed','cancelled'])" :key="key" :label="labels[key]" :value="key"/></el-select><el-button @click="page=1;load()">查询</el-button><el-button v-if="tab==='products'" type="primary" @click="edit()">新增积分商品</el-button><el-button :loading="busy" @click="load">刷新</el-button></div>
    <el-table v-if="tab==='products'" :data="products" v-loading="busy" empty-text="暂无积分商品，请新增商品后上架">
      <el-table-column label="商品" min-width="220"><template #default="{row}"><div class="product-cell"><img v-if="row.image" :src="row.image" alt=""/><div><strong>{{row.name}}</strong><small>{{row.category||'未分类'}}</small></div></div></template></el-table-column><el-table-column prop="category" label="独立分类" min-width="100"/><el-table-column prop="pointsPrice" label="积分价格" width="100"/><el-table-column prop="stock" label="库存" width="90"/><el-table-column label="状态" width="90"><template #default="{row}">{{labels[row.status]}}</template></el-table-column><el-table-column label="操作" width="150"><template #default="{row}"><el-button link type="primary" @click="edit(row as Product)">编辑 / 上下架</el-button></template></el-table-column>
    </el-table>
    <el-table v-else :data="orders" v-loading="busy" empty-text="暂无兑换订单">
      <el-table-column prop="orderNo" label="兑换单号" min-width="240"/><el-table-column prop="productName" label="商品" min-width="130"/><el-table-column prop="quantity" label="数量" width="70"/><el-table-column prop="pointsTotal" label="积分" width="90"/><el-table-column label="收货信息" min-width="220"><template #default="{row}">{{row.receiver}} {{row.mobile}}<br/>{{row.address}}</template></el-table-column><el-table-column label="状态 / 物流" min-width="150"><template #default="{row}">{{labels[row.status]}}<br/>{{row.carrier}} {{row.trackingNo}}</template></el-table-column><el-table-column prop="createdAt" label="兑换时间" min-width="170"/><el-table-column label="操作" width="140" fixed="right"><template #default="{row}"><template v-if="row.status==='pending'"><el-button link type="primary" :disabled="busy" @click="openShip(row as Order)">发货</el-button><el-button link type="danger" :disabled="busy" @click="cancel(row as Order)">取消</el-button></template></template></el-table-column>
    </el-table>
    <div class="toolbar"><el-button :disabled="page===1||busy" @click="page--;load()">上一页</el-button><span>第 {{page}} 页</span><el-button :disabled="busy||(tab==='products'?products.length:orders.length)<20" @click="page++;load()">下一页</el-button></div>
    <el-dialog v-model="editing" :title="form.id?'编辑积分商品':'新增积分商品'" width="min(600px, 94vw)" :close-on-click-modal="false">
      <el-form label-position="top"><el-form-item label="商品名称" required><el-input v-model="form.name" maxlength="120"/></el-form-item><el-form-item label="独立分类"><el-input v-model="form.category" maxlength="80" placeholder="例如：生活礼品"/></el-form-item><el-form-item label="商品图片地址"><ImageUploader :model-value="form.image" @update:model-value="v => form.image = Array.isArray(v) ? v[0] || '' : v"/></el-form-item><el-form-item label="商品详情"><el-input v-model="form.description" type="textarea" :rows="4" maxlength="20000"/></el-form-item><el-form-item label="兑换积分（整数）" required><el-input-number v-model="form.pointsPrice" :min="1" :max="100000000" :precision="0"/></el-form-item><el-form-item label="独立库存" required><el-input-number v-model="form.stock" :min="0" :max="100000000" :precision="0"/></el-form-item><el-form-item label="上架状态"><el-select v-model="form.status"><el-option label="草稿" value="draft"/><el-option label="上架" value="on_sale"/><el-option label="下架" value="off_sale"/></el-select></el-form-item></el-form>
      <template #footer><el-button :disabled="busy" @click="editing=false">取消</el-button><el-button type="primary" :loading="busy" @click="save">保存</el-button></template>
    </el-dialog>
    <el-dialog :model-value="!!shipping" title="积分订单发货" width="min(500px, 94vw)" @close="shipping=null"><el-form label-position="top"><el-form-item label="物流公司"><el-input v-model="shipment.carrier" maxlength="80"/></el-form-item><el-form-item label="运单号"><el-input v-model="shipment.trackingNo" maxlength="100"/></el-form-item></el-form><template #footer><el-button type="primary" :loading="busy" @click="ship">确认发货</el-button></template></el-dialog>
  </div>
</template>
<style scoped>
.points-page{padding:4px;min-width:0}.points-heading{display:flex;align-items:center;justify-content:space-between;gap:16px}.points-heading h1{font-size:28px;margin:8px 0}.eyebrow{font-size:11px;letter-spacing:3px;color:#b77b52}.product-cell{display:flex;align-items:center;gap:12px}.product-cell img{width:48px;height:56px;object-fit:cover;border-radius:8px}.product-cell small{display:block;color:#8b7b6a;margin-top:4px}.toolbar{flex-wrap:wrap}.intro{color:#8b7b6a}.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px;margin:24px 0}.metrics strong{display:block;font-size:28px;margin-top:12px}.toolbar{display:flex;align-items:center;gap:12px;margin:16px 0}@media(max-width:700px){.points-page{padding:12px}.metrics{grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.metrics strong{font-size:22px}}
</style>
