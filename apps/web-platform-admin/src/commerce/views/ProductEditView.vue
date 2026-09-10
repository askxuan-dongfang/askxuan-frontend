<script setup lang="ts">
// 商品编辑 / 新建
import { ref, reactive, onMounted, computed, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessage, type FormInstance, type FormRules } from "element-plus";
import PageHeader from "@/components/PageHeader.vue";
import ImageUploader from "@/components/ImageUploader.vue";
import { productApi, type ProductSaveParams } from "@/commerce/api/product";
import { categoryApi } from "@/commerce/api/category";
import type { ProductCategory } from "@/commerce/types";

const route = useRoute();
const router = useRouter();

const formRef = ref<FormInstance>();
const loading = ref(false);
const saving = ref(false);
const loadError = ref("");
const detailReady = ref(false);
let generation = 0;
const categories = ref<ProductCategory[]>([]);

const isEdit = computed(() => !!route.params.id);
const productId = computed(() => Number(route.params.id) || 0);

const form = reactive<ProductSaveParams>({
  name: "",
  categoryId: 0,
  description: "",
  mainImage: "",
  price: 0,
  marketPrice: 0,
  stock: 0,
  tags: "",
  freightTemplateId: 0,
  isExperience: false,
  sourceName: "",
  sourceUrl: "",
  sourceNote: "",
});

const rules: FormRules = {
  name: [{ required: true, message: "请输入商品名称", trigger: "blur" }],
  categoryId: [
    {
      validator: (_rule, value, done) =>
        value > 0 ? done() : done(new Error("请选择分类")),
      trigger: "change",
    },
  ],
  mainImage: [{ required: true, message: "请上传主图", trigger: "change" }],
  price: [{ required: true, message: "请输入售价", trigger: "blur" }],
  stock: [{ required: true, message: "请输入库存", trigger: "blur" }],
};

async function loadCategories() {
  try {
    const res = await categoryApi.list({ page: 1, size: 100 });
    categories.value = res.list || [];
  } catch {
    categories.value = [];
  }
}

async function loadDetail() {
  const current = ++generation;
  loadError.value = "";
  detailReady.value = false;
  if (!isEdit.value) {
    Object.assign(form, {
      name: "",
      categoryId: 0,
      description: "",
      mainImage: "",
      price: 0,
      marketPrice: 0,
      stock: 0,
      tags: "",
      freightTemplateId: 0,
      isExperience: false,
      sourceName: "",
      sourceUrl: "",
      sourceNote: "",
    });
    loading.value = false;
    detailReady.value = true;
    return;
  }
  loading.value = true;
  try {
    const detail = await productApi.detail(productId.value);
    if (current !== generation) return;
    Object.assign(form, {
      name: detail.name,
      categoryId: detail.categoryId,
      description: detail.description,
      mainImage: detail.mainImage,
      price: detail.price,
      marketPrice: detail.marketPrice,
      stock: detail.stock,
      tags: detail.tags,
      freightTemplateId: detail.freightTemplateId,
      isExperience: !!detail.isExperience,
      sourceName: detail.sourceName || "",
      sourceUrl: detail.sourceUrl || "",
      sourceNote: detail.sourceNote || "",
    });
    detailReady.value = true;
  } catch {
    if (current === generation)
      loadError.value = "商品加载失败，请重试后再编辑，避免覆盖已有数据。";
  } finally {
    if (current === generation) loading.value = false;
  }
}
const tagList = computed({
  get: () =>
    (form.tags || "")
      .split(/[,，]/)
      .map((t) => t.trim())
      .filter(Boolean),
  set: (tags: string[]) => {
    form.tags = tags.join(",");
  },
});
const categoryName = computed(
  () =>
    categories.value.find((c) => c.id === form.categoryId)?.name ||
    "请选择分类",
);
const imageValid = computed(() =>
  /^(https?:\/\/|\/(?!\/))/.test(form.mainImage || ""),
);
const presentationChecks = computed(() => [
  { label: "商品名称", ok: !!form.name.trim() },
  { label: "所属分类", ok: form.categoryId > 0 },
  { label: "主图地址", ok: imageValid.value },
  { label: "商品介绍", ok: !!form.description?.trim() },
  { label: "有可售库存", ok: form.stock > 0 },
]);

async function handleSubmit() {
  if (!formRef.value || saving.value || loading.value || !detailReady.value)
    return;
  if (
    form.isExperience &&
    (!form.sourceName?.trim() || !/^https:\/\//.test(form.sourceUrl || ""))
  ) {
    ElMessage.warning("请填写案例来源和 HTTPS 原商品链接");
    return;
  }
  await formRef.value.validate(async (valid) => {
    if (!valid) return;
    saving.value = true;
    try {
      if (isEdit.value) {
        await productApi.update(productId.value, form);
        ElMessage.success("更新成功");
      } else {
        await productApi.create(form);
        ElMessage.success("创建成功");
      }
      router.push("/commerce/products");
    } finally {
      saving.value = false;
    }
  });
}

function handleCancel() {
  router.push("/commerce/products");
}

onMounted(loadCategories);
watch(() => route.params.id, loadDetail, { immediate: true });
</script>

<template>
  <div class="page-wrap product-editor" v-loading="loading">
    <PageHeader
      :title="isEdit ? '编辑这份好物' : '上新一份好物'"
      subtitle="商品信息与顾客端展示同步维护；保存后在商品列表管理上下架。"
      ><template #extra
        ><el-button @click="handleCancel">返回商品列表</el-button></template
      ></PageHeader
    >
    <el-alert
      v-if="loadError"
      :title="loadError"
      type="error"
      :closable="false"
      show-icon
    /><el-button v-if="loadError" @click="loadDetail">重新加载</el-button>
    <div class="store-editor-layout">
      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-position="top"
        class="store-editor-form"
        :disabled="!detailReady || saving"
      >
        <section class="df-card store-editor-section">
          <div class="editor-section-title">
            <span>01</span>
            <div>
              <h2>先认识这份好物</h2>
              <p>名称、分类与首个标签会出现在商城商品卡片。</p>
            </div>
          </div>
          <el-form-item label="商品类型"
            ><el-switch
              v-model="form.isExperience"
              :disabled="isEdit"
              active-text="体验商品"
              inactive-text="普通商品"
            /><span class="editor-help"
              >类型创建后固定；体验商品仅模拟支付、库存与物流，不产生消费积分或商城销售收入。</span
            ></el-form-item
          >
          <template v-if="form.isExperience">
            <el-form-item label="案例来源"
              ><el-input
                v-model="form.sourceName"
                maxlength="100"
                placeholder="原商家或公开案例名称"
            /></el-form-item>
            <el-form-item label="原商品链接"
              ><el-input
                v-model="form.sourceUrl"
                maxlength="1000"
                placeholder="https://"
            /></el-form-item>
            <el-form-item label="来源说明"
              ><el-input
                v-model="form.sourceNote"
                type="textarea"
                :rows="3"
                maxlength="500"
                show-word-limit
                placeholder="资料核对日期、参考范围与体验说明"
            /></el-form-item>
          </template>
          <el-form-item label="商品名称" prop="name"
            ><el-input
              v-model="form.name"
              placeholder="清晰描述材质与品类，例如：天然香珠手串"
              maxlength="100"
              show-word-limit
          /></el-form-item>
          <el-form-item label="所属分类" prop="categoryId"
            ><el-select
              v-model="form.categoryId"
              placeholder="请选择分类"
              filterable
              style="width: 100%"
              ><el-option
                v-for="c in categories"
                :key="c.id"
                :label="c.name"
                :value="c.id" /></el-select
            ><span class="editor-help"
              >顾客通过此分类找到商品；分类顺序在分类管理中设置。</span
            ></el-form-item
          >
          <el-form-item label="展示标签"
            ><el-select
              v-model="tagList"
              multiple
              filterable
              allow-create
              default-first-option
              :reserve-keyword="false"
              placeholder="输入标签后回车，例如：天然材质、随身好物"
              style="width: 100%"
            /><span class="editor-help"
              >首个标签显示在商品卡片，所有标签展示在详情页。请填写可核实的商品特点。</span
            ></el-form-item
          >
        </section>
        <section class="df-card store-editor-section">
          <div class="editor-section-title">
            <span>02</span>
            <div>
              <h2>让细节看得见</h2>
              <p>清晰的图片与介绍，让顾客更容易做决定。</p>
            </div>
          </div>
          <el-form-item label="商品主图" prop="mainImage"
            ><ImageUploader
              v-model="form.mainImage"
              :multiple="false"
              placeholder="上传图片或粘贴图片链接"
            /><span class="editor-help"
              >建议使用清晰的正方形图片，主体居中；支持 HTTPS
              图片或站内图片路径。</span
            ></el-form-item
          >
          <el-form-item label="商品介绍"
            ><el-input
              v-model="form.description"
              type="textarea"
              :rows="6"
              placeholder="介绍材质、尺寸、工艺、使用与养护方式，让顾客看懂这份好物。"
              maxlength="2000"
              show-word-limit
          /></el-form-item>
        </section>
        <section class="df-card store-editor-section">
          <div class="editor-section-title">
            <span>03</span>
            <div>
              <h2>价格与履约</h2>
              <p>库存为零时，商城展示售罄并停止购买。</p>
            </div>
          </div>
          <div class="editor-price-grid">
            <el-form-item label="售价（元）" prop="price"
              ><el-input-number
                v-model="form.price"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
            /></el-form-item>
            <el-form-item label="参考价（元，选填）"
              ><el-input-number
                v-model="form.marketPrice"
                :min="0"
                :precision="2"
                :step="1"
                controls-position="right"
            /></el-form-item>
            <el-form-item label="库存（件）" prop="stock"
              ><el-input-number
                v-model="form.stock"
                :min="0"
                :precision="0"
                :step="1"
                controls-position="right"
            /></el-form-item>
            <el-form-item label="运费模板 ID"
              ><el-input-number
                v-model="form.freightTemplateId"
                :min="0"
                :precision="0"
                controls-position="right"
            /></el-form-item>
          </div>
          <p class="editor-help">
            参考价高于售价时才展示划线价；运费模板保留现有配送配置。
          </p>
        </section>
        <div class="store-editor-actions">
          <span>{{
            isEdit ? "保存后更新商品展示" : "新建商品先保存为草稿"
          }}</span
          ><el-button @click="handleCancel">取消</el-button
          ><el-button
            type="primary"
            :loading="saving"
            :disabled="!detailReady"
            @click="handleSubmit"
            >{{ isEdit ? "保存修改" : "保存为草稿" }}</el-button
          >
        </div>
      </el-form>
      <aside class="store-preview-column">
        <div class="store-preview-heading">
          <h2>顾客看到的样子</h2>
          <span>实时预览</span>
        </div>
        <div class="store-preview-device">
          <div class="store-preview-brand">商城 <small>购物车</small></div>
          <div class="store-preview-search">搜索商品名称 <span>搜索</span></div>
          <div class="store-preview-category">
            全部商品　 /　{{ categoryName }}
          </div>
          <article class="store-preview-product">
            <div class="store-preview-media">
              <el-image v-if="imageValid" :src="form.mainImage" fit="cover"
                ><template #error
                  ><span class="store-preview-fallback">物</span></template
                ></el-image
              ><span v-else class="store-preview-fallback">物</span
              ><small v-if="form.stock <= 0">暂时售罄</small
              ><small v-else-if="tagList[0]">{{ tagList[0] }}</small>
            </div>
            <div class="store-preview-copy">
              <h3>{{ form.name || "给这份好物一个名字" }}</h3>
              <div>
                <strong>¥{{ Number(form.price || 0).toFixed(2) }}</strong
                ><del v-if="(form.marketPrice || 0) > form.price"
                  >¥{{ Number(form.marketPrice).toFixed(2) }}</del
                ><span>↗</span>
              </div>
            </div>
          </article>
        </div>
        <section class="df-card store-display-check">
          <h3>展示检查</h3>
          <p v-for="item in presentationChecks" :key="item.label">
            <span>{{ item.label }}</span
            ><b :class="{ ready: item.ok }">{{
              item.ok ? "已就绪" : "待完善"
            }}</b>
          </p>
          <small
            >列表突出主图、名称与价格；完整介绍显示在商品详情。预览不会改变商品状态。</small
          >
        </section>
        <a
          v-if="isEdit"
          :href="`/c/shop/${productId}`"
          target="_blank"
          rel="noopener"
          class="editor-live-link"
          >打开顾客端商品详情 ↗</a
        >
      </aside>
    </div>
  </div>
</template>
<style scoped>
.store-editor-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 310px;
  gap: 26px;
  align-items: start;
}
.store-editor-form {
  min-width: 0;
  display: grid;
  gap: 18px;
}
.store-editor-section {
  padding: 24px;
}
.editor-section-title {
  display: flex;
  gap: 14px;
  margin-bottom: 22px;
}
.editor-section-title > span {
  font: 600 22px var(--font-serif);
  color: var(--primary);
  opacity: 0.6;
}
.editor-section-title h2 {
  font: 600 19px var(--font-serif);
  margin: 0 0 8px;
}
.editor-section-title p,
.editor-help {
  font-size: 12px;
  color: var(--text-light);
  line-height: 1.8;
  margin: 0;
}
.editor-help {
  display: block;
  margin-top: 8px;
}
.editor-price-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 18px;
}
.editor-price-grid :deep(.el-input-number) {
  width: 100%;
}
.store-editor-actions {
  position: sticky;
  bottom: 16px;
  z-index: 2;
  display: flex;
  gap: 10px;
  align-items: center;
  border: 1px solid var(--border);
  border-radius: 14px;
  background: var(--bg-card, #fff);
  padding: 16px;
}
.store-editor-actions > span {
  flex: 1;
  font-size: 12px;
  color: var(--text-light);
}
.store-preview-column {
  position: sticky;
  top: 24px;
  min-width: 0;
}
.store-preview-heading {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.store-preview-heading h2 {
  font: 600 18px var(--font-serif);
}
.store-preview-heading span {
  font-size: 11px;
  color: var(--text-light);
}
.store-preview-device {
  border: 1px solid #6e5135;
  background: #1c1210;
  border-radius: 24px;
  padding: 18px;
  color: #f0e6da;
}
.store-preview-brand {
  font: 600 22px var(--font-serif);
  margin: 0 0 18px;
  color: #c8a96e;
}
.store-preview-brand small {
  float: right;
  font: 12px var(--font-sans);
  padding-top: 8px;
}
.store-preview-search {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border: 1px solid #c8a96e;
  border-radius: 24px;
  padding: 5px 5px 5px 13px;
  font-size: 11px;
  color: #bba794;
}
.store-preview-search span {
  background: #c45a3c;
  color: white;
  padding: 6px 13px;
  border-radius: 18px;
}
.store-preview-category {
  font-size: 11px;
  padding: 14px 0;
  color: #c8a96e;
}
.store-preview-product {
  max-width: 200px;
  border: 1px solid #c8a96e33;
  border-radius: 17px;
  overflow: hidden;
  background: #2a1e1a;
}
.store-preview-media {
  aspect-ratio: 1;
  position: relative;
  background: #382c22;
}
.store-preview-media > .el-image {
  width: 100%;
  height: 100%;
}
.store-preview-fallback {
  display: grid;
  place-items: center;
  height: 100%;
  font: 600 48px var(--font-serif);
  color: #c8a96e;
}
.store-preview-media > small {
  position: absolute;
  top: 10px;
  left: 10px;
  border-radius: 6px;
  padding: 5px 8px;
  background: #261b16d9;
  color: #e4c797;
  font-size: 11px;
  max-width: 90%;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.store-preview-copy {
  padding: 10px;
}
.store-preview-copy > small {
  color: #968675;
  font-size: 11px;
}
.store-preview-copy h3 {
  font: 500 14px/1.55 var(--font-sans);
  margin: 8px 0;
  overflow-wrap: anywhere;
}
.store-preview-copy p {
  font-size: 12px;
  color: #bba794;
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
}
.store-preview-copy > div {
  display: flex;
  gap: 9px;
  align-items: baseline;
  flex-wrap: wrap;
}
.store-preview-copy strong {
  color: #e17b5b;
  font-size: 22px;
  font-variant-numeric: tabular-nums;
}
.store-preview-copy del {
  font-size: 11px;
  color: #968675;
}
.store-preview-copy > div > span {
  margin-left: auto;
  color: #c8a96e;
}
.store-display-check {
  padding: 20px;
  margin-top: 16px;
}
.store-display-check h3 {
  font: 600 16px var(--font-serif);
  margin-top: 0;
}
.store-display-check p {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
}
.store-display-check b {
  font-weight: 400;
  color: #a86b40;
}
.store-display-check .ready {
  color: #64826e;
}
.store-display-check small {
  display: block;
  font-size: 11px;
  color: var(--text-light);
  line-height: 1.7;
}
.editor-live-link {
  display: block;
  padding: 16px;
  color: var(--primary);
  font-size: 13px;
}
@media (max-width: 1100px) {
  .store-editor-layout {
    grid-template-columns: minmax(0, 1fr) 270px;
    gap: 18px;
  }
}
@media (max-width: 850px) {
  .store-editor-layout {
    grid-template-columns: 1fr;
  }
  .store-preview-column {
    position: static;
    max-width: 400px;
    width: 100%;
    margin: auto;
  }
  .store-editor-actions {
    bottom: 0;
    flex-wrap: wrap;
  }
  .store-editor-actions > span {
    flex-basis: 100%;
  }
  .store-editor-section {
    padding: 18px;
  }
}
</style>
