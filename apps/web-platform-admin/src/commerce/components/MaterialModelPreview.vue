<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js'
import { RGBELoader } from 'three/examples/jsm/loaders/RGBELoader.js'
import { t as uiText } from '@askxuan/localization'
import { geometryCatalog, type MaterialStudio, type Triple } from '../materialStudio'
import { appearance, previewMap, safeMaterialUrl, type PreviewAppearanceInput } from '../materialPreviewAppearance'
import environmentUrl from '../../../../../packages/diy-materials/DiyMaterials/studio.hdr?url'

const urls = import.meta.glob('../../../../../packages/diy-materials/DiyMaterials/geometry-*.json', { query: '?url', import: 'default', eager: true }) as Record<string, string>
const props = defineProps<PreviewAppearanceInput & { studio: MaterialStudio }>()
const emit = defineEmits<{ ready: [value: boolean]; mount: [value: Triple] }>()
const host = ref<HTMLDivElement>(), ready = ref(false), error = ref(''), picking = ref(false)
let renderer: THREE.WebGLRenderer | undefined, camera: THREE.PerspectiveCamera, controls: OrbitControls, scene: THREE.Scene
let rawModel: THREE.Object3D | undefined, model: THREE.Group | undefined, marker: THREE.Mesh, axes: THREE.AxesHelper
let observer: ResizeObserver | undefined, frame = 0, generation = 0, materialRevision = 0, alive = true
let materialTextures: THREE.Texture[] = []
let modelPending = false, materialPending = false
let down: { x: number; y: number } | undefined
const ownTextures: THREE.Texture[] = []


function dispose(object?: THREE.Object3D, textures = false) {
  object?.traverse(node => {
    if (!(node instanceof THREE.Mesh)) return
    node.geometry.dispose()
    for (const material of Array.isArray(node.material) ? node.material : [node.material]) {
      if (textures) for (const value of Object.values(material)) if (value instanceof THREE.Texture) value.dispose()
      material.dispose()
    }
  })
}
function invalidate() {
  if (frame || !renderer || !alive) return
  frame = requestAnimationFrame(() => { frame = 0; controls.update(); renderer?.render(scene, camera) })
}
function resize() {
  if (!host.value || !renderer) return
  const { width, height } = host.value.getBoundingClientRect()
  renderer.setSize(width, height, false); camera.aspect = width / Math.max(1, height); camera.updateProjectionMatrix(); invalidate()
}
function resetView() {
  const extent = Math.max(...props.studio.dimensionsMm, 1)
  camera.position.set(extent * 1.4, extent * 1.15, extent * 1.8)
  camera.near = extent / 1000; camera.far = extent * 100; camera.updateProjectionMatrix()
  controls.target.set(0, 0, 0); controls.minDistance = extent * .7; controls.maxDistance = extent * 8; controls.update(); invalidate()
}
function updateMount() {
  if (!marker) return
  const size = props.studio.dimensionsMm
  marker.visible = props.studio.part === 'hanging'
  marker.position.set(...props.studio.mount.map((n, i) => n * size[i]) as Triple)
  marker.scale.setScalar(Math.max(...size) * .025)
  invalidate()
}
function rebuild() {
  if (!rawModel || !renderer || modelPending || materialPending || error.value) return
  scene.remove(model!); dispose(model)
  model = new THREE.Group()
  const object = rawModel.clone(true)
  object.traverse(node => {
    if (!(node instanceof THREE.Mesh)) return
    node.geometry = node.geometry.clone()
    node.material = Array.isArray(node.material) ? node.material.map(m => m.clone()) : node.material.clone()
  })
  const oriented = new THREE.Group(); oriented.add(object)
  oriented.rotation.set(...props.studio.rotation.map(v => THREE.MathUtils.degToRad(v)) as Triple)
  oriented.updateMatrixWorld(true)
  const bounds = new THREE.Box3().setFromObject(oriented), size = bounds.getSize(new THREE.Vector3()), center = bounds.getCenter(new THREE.Vector3())
  if (![size.x, size.y, size.z].every(v => Number.isFinite(v) && v > 1e-8)) {
    dispose(object); ready.value = false; emit('ready', false); error.value = '模型尺寸无效，请重新生成'; return
  }
  const scale = new THREE.Vector3(...props.studio.dimensionsMm).divide(size)
  model.add(oriented); model.scale.copy(scale); model.position.copy(center).multiply(scale).negate(); scene.add(model)
  axes.scale.setScalar(Math.max(...props.studio.dimensionsMm) * .7)
  updateMount(); resetView(); ready.value = true; emit('ready', true); invalidate()
}
function beadGeometry(shape: string) {
  // Keep this profile identical to H5 materialAppearance.beadProfile(.5, shape).
  const hole = .065, points: THREE.Vector2[] = []
  if (shape === 'disc' || shape === 'barrel') {
    const half = .5 * (shape === 'disc' ? .45 : 1.15), width = .5 * (shape === 'barrel' ? .85 : 1)
    for (const [x, y] of [[hole, -half], [width * .92, -half], [width, -half * .8], [width, half * .8], [width * .92, half], [hole, half], [hole, -half]]) points.push(new THREE.Vector2(x, y))
  } else {
    const limit = Math.acos(hole / .5)
    for (let i = 0; i <= 32; i++) { const angle = -limit + 2 * limit * i / 32; points.push(new THREE.Vector2(.5 * Math.cos(angle), .5 * Math.sin(angle))) }
    points.push(points[0].clone())
  }
  return new THREE.LatheGeometry(points, shape === 'faceted' ? 12 : 48).rotateZ(-Math.PI / 2)
}
async function loadModel() {
  if (!renderer) return
  const ticket = ++generation
  modelPending = true
  ready.value = false; error.value = ''; emit('ready', false)
  // A previous template must never stand in for an unfinished or failed new model.
  scene.remove(model!); dispose(model); model = undefined
  dispose(rawModel, true); rawModel = undefined; invalidate()
  let next: THREE.Object3D | undefined
  try {
    if (props.studio.source === 'generated') {
      const url = safeMaterialUrl(props.studio.model?.glbUrl)
      if (!url) throw new Error('请先生成模型，再检查预览')
      next = (await new GLTFLoader().loadAsync(url)).scene
    } else {
      const templateId = props.studio.templateId, profile = geometryCatalog.models[templateId as keyof typeof geometryCatalog.models]
      let geometry: THREE.BufferGeometry
      if (profile) {
        const url = urls[`../../../../../packages/diy-materials/DiyMaterials/${profile.file}`]
        const response = await fetch(url)
        if (!response.ok) throw new Error('模板加载失败，请重试')
        const data = await response.json()
        geometry = new THREE.BufferGeometry()
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(data.positions, 3))
        geometry.setAttribute('normal', new THREE.Float32BufferAttribute(data.normals, 3))
        geometry.setAttribute('uv', new THREE.Float32BufferAttribute(data.uv, 2)); geometry.setIndex(data.indices)
      } else geometry = beadGeometry(templateId)
      next = new THREE.Mesh(geometry, new THREE.MeshPhysicalMaterial())
    }
    if (!alive || ticket !== generation) { dispose(next, true); return }
    dispose(rawModel, true); rawModel = next; modelPending = false
    const applied = await applyMaterial(ticket)
    if (applied && alive && ticket === generation) rebuild()
  } catch (cause) {
    if (!alive || ticket !== generation) return
    modelPending = false
    error.value = cause instanceof Error ? cause.message : '模型加载失败，请重试'
    scene.remove(model!); dispose(model); model = undefined; invalidate()
  }
}
async function applyMaterial(ticket = generation) {
  if (!rawModel) return false
  const revision = ++materialRevision, textures: THREE.Texture[] = []
  materialPending = true
  const maps: Partial<Record<'map' | 'normalMap' | 'roughnessMap', THREE.Texture | null>> = {}
  const profile = appearance(props)
  try {
    for (const [key, input] of [['map', props.albedoMapUrl], ['normalMap', props.normalMapUrl], ['roughnessMap', props.roughnessMapUrl]] as const) {
      let texture: THREE.Texture | null
      if (props.studio.source === 'template') texture = await previewMap(props, key)
      else {
        const url = safeMaterialUrl(input)
        if (!url) continue
        texture = await new THREE.TextureLoader().loadAsync(url)
        texture.colorSpace = key === 'map' ? THREE.SRGBColorSpace : THREE.NoColorSpace
      }
      if (texture) textures.push(texture)
      if (!alive || ticket !== generation || revision !== materialRevision) { textures.forEach(t => t.dispose()); return false }
      maps[key] = texture
    }
  } catch (error) {
    textures.forEach(t => t.dispose())
    if (!alive || ticket !== generation || revision !== materialRevision) return false
    materialPending = false; throw error
  }
  rawModel.traverse(node => {
    if (!(node instanceof THREE.Mesh)) return
    for (const material of Array.isArray(node.material) ? node.material : [node.material]) {
      if (!(material instanceof THREE.MeshStandardMaterial)) continue
      if (props.studio.source === 'template') {
        material.color.set(maps.map ? '#ffffff' : props.color || '#8A6E4A'); material.roughness = profile.roughness
        material.metalness = profile.metalness; material.envMapIntensity = profile.metalness > .5 ? .85 : .65
        material.flatShading = props.studio.templateId === 'faceted'
        material.normalScale.setScalar(profile.normalStrength)
        if (material instanceof THREE.MeshPhysicalMaterial) {
          material.transmission = profile.transmission; material.ior = profile.ior; material.clearcoat = profile.clearcoat
          material.clearcoatRoughness = Math.max(.18, profile.roughness); material.thickness = Math.max(...props.studio.dimensionsMm)
          material.attenuationColor.set(props.color || '#8A6E4A'); material.attenuationDistance = profile.id === 'crystal' ? 50 : 12.7
        }
      }
      Object.assign(material, maps)
      if (maps.map) material.color.set('#ffffff')
      material.needsUpdate = true
    }
  })
  materialTextures.forEach(texture => texture.dispose()); materialTextures = textures
  materialPending = false
  return true
}
function pointerDown(event: PointerEvent) { down = { x: event.clientX, y: event.clientY } }
function pointerUp(event: PointerEvent) {
  if (!picking.value || !ready.value || !model || !down || Math.hypot(event.clientX - down.x, event.clientY - down.y) > 5 || !host.value) return
  const rect = host.value.getBoundingClientRect(), ray = new THREE.Raycaster()
  ray.setFromCamera(new THREE.Vector2((event.clientX - rect.left) / rect.width * 2 - 1, 1 - (event.clientY - rect.top) / rect.height * 2), camera)
  const hit = ray.intersectObject(model, true)[0]
  if (!hit) return
  emit('mount', hit.point.toArray().map((v, i) => Math.max(-.5, Math.min(i === 2 ? .499 : .5, Math.round(v / props.studio.dimensionsMm[i] * 1000) / 1000))) as Triple)
  picking.value = false
}
watch(picking, value => { if (controls) controls.enableRotate = !value })
watch(() => [props.studio.source, props.studio.templateId, props.studio.model?.glbUrl], loadModel)
watch(() => [props.studio.dimensionsMm, props.studio.rotation], rebuild, { deep: true })
watch(() => [props.studio.mount, props.studio.part], updateMount, { deep: true })
watch(() => [props.color, props.finish, props.materialType, props.textureKey, props.translucency, props.materialId, props.albedoMapUrl, props.normalMapUrl, props.roughnessMapUrl], async () => {
  ready.value = false; emit('ready', false)
  try { const applied = await applyMaterial(); if (applied && alive) { error.value = ''; rebuild() } } catch { ready.value = false; error.value = '材质贴图加载失败，请检查地址'; emit('ready', false) }
})
onMounted(() => {
  try {
    scene = new THREE.Scene()
    camera = new THREE.PerspectiveCamera(42, 1, .01, 1000)
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true }); renderer.setPixelRatio(Math.min(devicePixelRatio, 2))
    renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.1
    renderer.domElement.setAttribute('aria-label', uiText('材料 3D 预览，拖动旋转，滚轮缩放'))
    host.value!.appendChild(renderer.domElement)
    controls = new OrbitControls(camera, renderer.domElement); controls.enableDamping = true; controls.enablePan = false; controls.addEventListener('change', invalidate)
    scene.add(new THREE.HemisphereLight(0xffffff, 0x80664b, 2))
    const light = new THREE.DirectionalLight(0xffffff, 3); light.position.set(8, 10, 6); scene.add(light)
    axes = new THREE.AxesHelper(1); scene.add(axes)
    marker = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({ color: '#e35b3d', depthTest: false }))
    marker.renderOrder = 10; scene.add(marker)
    observer = new ResizeObserver(resize); observer.observe(host.value!); resize()
    void new RGBELoader().loadAsync(environmentUrl).then(texture => { if (!alive) { texture.dispose(); return }; texture.mapping = THREE.EquirectangularReflectionMapping; scene.environment = texture; ownTextures.push(texture); invalidate() }).catch(() => {})
    void loadModel()
  } catch { error.value = '当前设备无法启动 3D 预览，请更换支持 WebGL 的浏览器'; emit('ready', false) }
})
onBeforeUnmount(() => {
  alive = false; generation++; cancelAnimationFrame(frame); observer?.disconnect(); controls?.dispose()
  dispose(model); dispose(rawModel, true); marker?.geometry.dispose(); (marker?.material as THREE.Material | undefined)?.dispose(); axes?.dispose()
  ownTextures.forEach(texture => texture.dispose()); materialTextures.forEach(texture => texture.dispose()); renderer?.dispose()
})
</script>

<template>
  <section class="material-model-preview" :data-preview-ready="ready" :aria-label='$t("模型预览")'>
    <div ref="host" class="model-stage" :class="{ 'is-picking': picking }" @pointerdown="pointerDown" @pointerup="pointerUp">
      <p v-if="error" class="model-message" role="alert">{{ $t(error) }}<el-button @click="loadModel">{{ $t('重新加载') }}</el-button></p>
      <p v-else-if="!ready" class="model-message" role="status">{{ $t('正在加载模型') }}</p>
    </div>
    <div class="model-tools">
      <el-button :disabled="!ready" @click="resetView">{{ $t('复位视角') }}</el-button>
      <el-button v-if="studio.part === 'hanging'" :disabled="!ready" :type="picking ? 'primary' : 'default'" :aria-pressed="picking" @click="picking = !picking">{{ $t(picking ? '取消选择挂点' : '点击模型选择挂点') }}</el-button>
    </div>
    <p class="model-help">{{ $t(picking ? '点击模型上的连接位置；也可在下方输入挂点坐标。' : '拖动查看各面，滚轮缩放；红 X 为穿绳轴，蓝 Z 指向挂件自由端。') }}</p>
  </section>
</template>

<style scoped>
.material-model-preview { min-width: 0; }
.model-stage { position: relative; height: 360px; background: var(--bg-color, #f7f4ed); border-radius: 12px; overflow: hidden; touch-action: none; }
.model-stage :deep(canvas) { display: block; width: 100%; height: 100%; }
.model-stage.is-picking { cursor: crosshair; }
.model-tools { display: flex; gap: 8px; flex-wrap: wrap; margin: 12px 0 8px; }
.model-tools :deep(.el-button + .el-button) { margin: 0; }
.model-message { position: absolute; inset: 0; margin: 0; padding: 24px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 12px; color: var(--text-light); z-index: 1; background: var(--bg-color, #f7f4ed); }
.model-help { font-size: var(--type-size-caption); color: var(--text-light); line-height: 1.6; margin: 0; }
@media (max-width: 767px) { .model-stage { height: 300px; } }
</style>
