# DIY 材质资源

`DiyMaterials/` 是 iOS 与 H5 共同使用的材质目录。iOS 将整个目录打包为资源；H5 镜像位于 `apps/web-h5/public/assets/diy/materials-v2/`，渲染配置镜像位于 `src/features/diy/material-profiles.json`。

更新源文件后，在 H5 仓库运行：

```sh
node scripts/sync-diy-materials.mjs
npm run check:diy-assets
```

校验包括原始素材 SHA-256、两端资源清单和字节一致性。H5 发布流程固定 frontend revision，防止跨仓库漂移。

## 内容与边界

- 8 张矿石、种子实拍参考，1 组实物木皮 PBR 扫描，以及摄影棚 HDRI。作者、授权、原始链接及哈希见 `sources.json`；对外署名见 `credits.html`。
- `appearance.json` 定义 20 类表面参数与当前 45 款材料映射，未知材料按纹理和材质类型回退。新增 SKU 不应直接借用其他 SKU 的照片。
- 运行时裁切、镜像、按材料配置调色；缩略图与 3D 使用同一纹理。照片参考不是在售商品实拍，也不是木种或宝石鉴定证据。星月菩提、金属、陶瓷、织物等仍使用程序表面；雕刻配件仅作外形示意。
- H5 使用物理透射和环境反射；SceneKit 通过双层透明表面与视角相关密度近似透光，不具备等同的体积折射。光学参数用于视觉预览，未经过实物测量。
- 珠体含贯穿孔，材质按粗糙度、涂层、金属度和透射区分。生产自定义素材优先于内置参考，旧演示木材贴图由新资源替换。

运行时生成的裁切与调色纹理沿用原图许可；发布时保留署名、原图链接及修改说明。不要用来源不明的商城照片替换这些资源。
