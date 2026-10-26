import catalog from '../../../../packages/diy-materials/DiyMaterials/geometry-catalog.json'

export type Triple = [number, number, number]
export interface MaterialStudio {
  version: 1
  part: 'bead' | 'hanging'
  motion: 'fixed' | 'rigid' | 'flexible'
  source: 'template' | 'generated'
  templateId: string
  dimensionsMm: Triple
  rotation: Triple
  mount: Triple
  connectorMm: number
  rigidFraction: number
  photos: string[]
  model?: { jobId: string; glbUrl: string; usdzUrl: string }
  previewConfirmed: boolean
}

export const geometryCatalog = catalog
export const templateOptions = [
  { value: 'round', label: '圆珠' }, { value: 'faceted', label: '切面珠' },
  { value: 'barrel', label: '桶珠' }, { value: 'disc', label: '隔片' },
  { value: 'three_way', label: '三通' }, { value: 'buddha_head', label: '佛头' },
  { value: 'pendant_generic', label: '通用吊坠' }, { value: 'pendant_lotus', label: '莲花吊坠' },
  { value: 'pendant_gourd', label: '葫芦吊坠' }, { value: 'pendant_peace', label: '平安扣' },
  { value: 'pendant_woodfish', label: '木鱼吊坠' }, { value: 'tassel', label: '流苏' },
  { value: 'tassel_knot', label: '中国结流苏' }
]

export function templateDefaults(templateId: string, diameter = 10): Pick<MaterialStudio, 'dimensionsMm' | 'mount' | 'rotation' | 'rigidFraction'> {
  const p = catalog.models[templateId as keyof typeof catalog.models]
  if (p) {
    const low = [p.minX, p.minY, p.minZ], high = [p.maxX, p.maxY, p.maxZ]
    const span = high.map((v, i) => v - low[i])
    const mount = 'mount' in p.anchors ? p.anchors.mount : [0, 0, 0]
    return {
      dimensionsMm: span.map(v => Math.max(.5, Math.min(120, Math.round(v * diameter * 100) / 100))) as Triple,
      mount: mount.map((v, i) => Math.max(-.5, Math.min(.5, (v - low[i]) / span[i] - .5))) as Triple,
      rotation: [0, 0, 0], rigidFraction: templateId === 'tassel_knot' ? .55 : .3
    }
  }
  return { dimensionsMm: [diameter * (templateId === 'disc' ? .45 : templateId === 'barrel' ? 1.15 : 1), diameter, diameter], mount: [0, 0, 0], rotation: [0, 0, 0], rigidFraction: .3 }
}

export function initialStudio(material: { category?: string; shape?: string; name?: string; diameterMm?: number } = {}): MaterialStudio {
  const kind = ['pendant', 'tassel', 'three_way', 'buddha_head'].find(v => material.category === v || material.shape === v)
  let templateId = kind || material.shape || 'round'
  if (kind === 'pendant') templateId = catalog.nameVariants.find(v => v.kind.startsWith('pendant') && v.matches.some(n => material.name?.includes(n)))?.kind || 'pendant_generic'
  if (kind === 'tassel') templateId = catalog.nameVariants.find(v => v.kind.startsWith('tassel') && v.matches.some(n => material.name?.includes(n)))?.kind || 'tassel'
  if (!templateOptions.some(v => v.value === templateId)) templateId = 'round'
  const hanging = kind === 'pendant' || kind === 'tassel'
  return { version: 1, part: hanging ? 'hanging' : 'bead', motion: hanging ? kind === 'tassel' ? 'flexible' : 'rigid' : 'fixed', source: 'template', templateId,
    ...templateDefaults(templateId, material.diameterMm || 10), connectorMm: hanging ? 2 : 0, photos: [], previewConfirmed: false }
}

export function studioFingerprint(studio: MaterialStudio): string {
  // Do not read previewConfirmed here: Vue would track it and invalidate its own confirmation.
  return JSON.stringify([studio.part, studio.motion, studio.source, studio.templateId, studio.dimensionsMm,
    studio.rotation, studio.mount, studio.connectorMm, studio.rigidFraction, studio.photos, studio.model])
}

export function studioError(studio: MaterialStudio): string {
  if (studio.part === 'bead' && studio.motion !== 'fixed' || studio.part === 'hanging' && !['rigid', 'flexible'].includes(studio.motion)) return '请选择与品类对应的运动方式'
  if (studio.dimensionsMm.some(v => !Number.isFinite(v) || v < .5 || v > 120)) return '实际尺寸需在 0.5–120 mm 之间'
  if (studio.rotation.some(v => !Number.isFinite(v) || Math.abs(v) > 180)) return '模型朝向需在 -180° 至 180° 之间'
  if (studio.mount.some(v => !Number.isFinite(v) || Math.abs(v) > .5)) return '挂点需位于模型范围内'
  if (studio.part === 'hanging' && studio.mount[2] >= .5) return '挂点不能位于自由端末端'
  if (studio.part === 'hanging' && (!Number.isFinite(studio.connectorMm) || studio.connectorMm < 1 || studio.connectorMm > 30)) return '连接绳长度需在 1–30 mm 之间'
  if (studio.motion === 'flexible' && (!Number.isFinite(studio.rigidFraction) || studio.rigidFraction < .1 || studio.rigidFraction > .9)) return '固定部分比例需在 10%–90% 之间'
  if (studio.photos.length > 4) return '最多上传四张实拍图'
  if (studio.source === 'template' && !templateOptions.some(v => v.value === studio.templateId)) return '请选择可用的形状模板'
  if (studio.source === 'generated' && (!studio.model?.jobId || !studio.model.glbUrl || !studio.model.usdzUrl)) return '请等待模型生成完成'
  return ''
}
