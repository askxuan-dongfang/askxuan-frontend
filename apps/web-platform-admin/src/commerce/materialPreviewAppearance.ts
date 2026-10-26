import * as THREE from 'three'
import catalog from '../../../../packages/diy-materials/DiyMaterials/appearance.json'
const urls = import.meta.glob('../../../../packages/diy-materials/DiyMaterials/*.jpg', { query: '?url', import: 'default', eager: true }) as Record<string, string>
export interface PreviewAppearanceInput { materialId?: number; color: string; materialType: string; textureKey: string; finish: string; translucency: number; albedoMapUrl?: string; normalMapUrl?: string; roughnessMapUrl?: string }
export function appearance(input: PreviewAppearanceInput) {
  let id = (catalog.byMaterialId as Record<string, string>)[String(input.materialId)] || (catalog.byTexture as Record<string, string>)[input.textureKey] || (catalog.byType as Record<string, string>)[input.materialType] || 'fallback'
  if (id === 'wood' && input.finish === 'natural') id = 'wood-natural'
  const profile = { ...catalog.profiles[id as keyof typeof catalog.profiles], id }
  if (profile.transmission > 0 && Number.isFinite(input.translucency)) profile.transmission = Math.max(0, Math.min(1, input.translucency))
  if (profile.metalness > .5 && input.finish === 'brushed') profile.roughness = Math.max(.4, profile.roughness)
  return profile
}
export function safeMaterialUrl(value?: string) {
  if (!value || /[\r\n\\]/.test(value)) return ''
  if (value.startsWith('/') && !value.startsWith('//')) return value
  try { const url = new URL(value); return url.protocol === 'https:' && !url.username && !url.password ? url.href : '' } catch { return '' }
}
export async function previewMap(input: PreviewAppearanceInput, channel: 'map' | 'normalMap' | 'roughnessMap') {
  const profile = appearance(input)
  const custom = safeMaterialUrl(channel === 'map' ? input.albedoMapUrl : channel === 'normalMap' ? input.normalMapUrl : input.roughnessMapUrl)
  const legacyWood = custom.startsWith('/assets/diy/textures/wood/')
  const file = channel === 'map' ? profile.source : profile.id.startsWith('wood') ? channel === 'normalMap' ? 'rosewood-nor_gl.jpg' : 'rosewood-Rough.jpg' : ''
  const reference = file && urls[`../../../../packages/diy-materials/DiyMaterials/${file}`]
  let texture: THREE.Texture
  if (custom && !legacyWood) texture = await new THREE.TextureLoader().loadAsync(custom)
  else if (reference) {
    const image = await new Promise<HTMLImageElement>((resolve, reject) => { const image = new Image(); image.crossOrigin = 'anonymous'; image.onload = () => resolve(image); image.onerror = reject; image.src = reference })
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 256
    const ctx = canvas.getContext('2d', { willReadFrequently: channel === 'map' && profile.tint })!
    const crop = profile.crop
    ctx.drawImage(image, crop[0] * image.width, crop[1] * image.height, crop[2] * image.width, crop[3] * image.height, 0, 0, 256, 256)
    if (channel === 'map' && profile.tint) {
      const pixels = ctx.getImageData(0, 0, 256, 256), rgb = [1, 3, 5].map(i => parseInt(input.color.slice(i, i + 2), 16))
      let mean = 0
      for (let i = 0; i < pixels.data.length; i += 4) mean += (pixels.data[i] * .2126 + pixels.data[i + 1] * .7152 + pixels.data[i + 2] * .0722) / (256 * 256)
      for (let i = 0; i < pixels.data.length; i += 4) {
        const luminance = pixels.data[i] * .2126 + pixels.data[i + 1] * .7152 + pixels.data[i + 2] * .0722
        const modulation = Math.max(.4, Math.min(1.45, 1 + profile.contrast * (luminance / Math.max(1, mean) - 1)))
        for (let c = 0; c < 3; c++) pixels.data[i + c] = rgb[c] * modulation * profile.brightness
      }
      ctx.putImageData(pixels, 0, 0)
    }
    texture = new THREE.CanvasTexture(canvas)
  } else if (channel === 'map') texture = await new THREE.TextureLoader().loadAsync(materialTexture(input))
  else return null
  texture.colorSpace = channel === 'map' ? THREE.SRGBColorSpace : THREE.NoColorSpace
  texture.anisotropy = 4; texture.wrapS = THREE.MirroredRepeatWrapping; texture.repeat.x = 2
  return texture
}
// Keep the existing shared-catalog procedural fallback consistent with H5.
export function materialTexture(b: PreviewAppearanceInput): string {
  if (typeof document === 'undefined') return '';

  const canvas = document.createElement('canvas'); canvas.width = canvas.height = 128; const ctx = canvas.getContext('2d'); if (!ctx) return '';
  const data = ctx.createImageData(128, 128); const color = (/^#[0-9a-f]{6}$/i.test(b.color) ? b.color : '#93795b');
  const rgb = [1, 3, 5].map(i => parseInt(color.slice(i, i + 2), 16)); const kind = b.textureKey + ' ' + b.materialType;
  // Smooth, low-contrast mineral/wood variation; no repeated decorative waves.
  const random = (x: number, y: number) => { const n = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return n - Math.floor(n); };
  const noise = (x: number, y: number) => {
    const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy;
    const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
    return (random(ix, iy) * (1 - u) + random(ix + 1, iy) * u) * (1 - v) + (random(ix, iy + 1) * (1 - u) + random(ix + 1, iy + 1) * u) * v;
  };
  for (let y = 0; y < 128; y++) for (let x = 0; x < 128; x++) {
    const cloud = noise(x / 28, y / 28) * .55 + noise(x / 12, y / 12) * .3 + noise(x / 4, y / 4) * .15;
    const grain = noise(x / 2.5 + cloud * 1.4, y / 55), speck = random(x, y);
    let light = .91 + cloud * .18;
    if (/wood/.test(kind)) light = .79 + grain * .28 + speck * .025;
    else if (/seed|bodhi/.test(kind)) light = .88 + cloud * .17 - (speck > .995 ? .3 : 0);
    else if (/agate|amber|tiger/.test(kind)) light = .83 + cloud * .32 + noise(x / 40, y / 8) * .08;
    else if (/lapis|turquoise/.test(kind)) light = .78 + cloud * .38 + (speck > .997 ? .4 : 0);
    else if (/crystal|jade|glass/.test(kind)) light = .92 + cloud * .16;
    for (let c = 0; c < 3; c++) data.data[(y * 128 + x) * 4 + c] = Math.max(0, Math.min(255, rgb[c] * light));
    data.data[(y * 128 + x) * 4 + 3] = 255;
  }
  ctx.putImageData(data, 0, 0); const result = canvas.toDataURL(); return result;
}
