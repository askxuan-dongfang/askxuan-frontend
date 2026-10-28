import { test, expect, type Page } from '@playwright/test';

const materials = [
  { id: 1, name: '测试木珠', category: 'wood', shape: 'round', diameterMm: 10, colorHex: '#76583d' },
  { id: 2, name: '普通流苏', category: 'tassel', shape: 'tassel', diameterMm: 12, colorHex: '#a63531' },
  { id: 3, name: '中国结流苏', category: 'tassel', shape: 'tassel', diameterMm: 14, colorHex: '#a63531' },
  { id: 4, name: '白玉', category: 'jade', shape: 'round', diameterMm: 10, colorHex: '#ece8d5' },
  { id: 5, name: '莲花金饰', category: 'pendant', shape: 'pendant', diameterMm: 12, colorHex: '#c5a24d' },
].map(material => ({ ...material, spec: `${material.diameterMm}mm`, unitPrice: 10, unit: '颗', stock: 100, status: 'on_shelf', image: '' }));

async function setup(page: Page, motion = false) {
  await page.emulateMedia({ reducedMotion: motion ? 'no-preference' : 'reduce' });
  await page.addInitScript(() => {
    localStorage.setItem('askxuan-language', 'zh-Hans');
    localStorage.setItem('askxuan-theme', 'light');
  });
  const writes: string[] = [], meshes: string[] = [], errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => {
    if (/\/geometry-[^/]+\.json$/.test(request.url())) meshes.push(new URL(request.url()).pathname);
  });
  // Every API response is local, including unanticipated requests from the shell.
  await page.route(/^https?:\/\/[^/]+\/api\//, async route => {
    const request = route.request(), path = new URL(request.url()).pathname;
    if (request.method() !== 'GET') writes.push(`${request.method()} ${path}`);
    const data = path.endsWith('/diy/materials') ? { list: materials, total: materials.length }
      : path.endsWith('/chats/incoming-call') ? { call: null }
      : path.endsWith('/chats/unread') ? { count: 0 } : { list: [], total: 0 };
    await route.fulfill({ json: { code: 0, data } });
  });
  return { writes, meshes, errors };
}

async function seedCrowdedDraft(page: Page) {
  // The user's 20-piece combination exercises the old long-rope/depth-stacking failure.
  const draft = [ ...Array(12).fill(4), ...Array(3).fill(5), ...Array(5).fill(2) ].map((id, index) => {
    const material = materials.find(item => item.id === id)!;
    return { slotId: `gravity-${index}`, materialId: material.id, name: material.name, spec: material.spec,
      diameterMm: material.diameterMm, shape: material.shape, subtype: material.shape,
      color: material.colorHex, unitPrice: 10, image: '', materialType: material.category,
      textureKey: '', finish: 'polished', translucency: 0, fiveElement: 'metal' };
  });
  await page.addInitScript(beads => {
    localStorage.setItem('diy-studio-draft-v1:guest:new', JSON.stringify({ version: 1, beads, wristSize: 160, allowance: 8, name: '多挂件重力测试', description: '', cord: null }));
  }, draft);
  return draft;
}

async function toolbarGeometry(page: Page) {
  return page.locator('.studio-viewport').evaluate(viewport => {
    const bounds = viewport.getBoundingClientRect();
    const rail = viewport.querySelector('.diy-3d-toolbar')!;
    const railBounds = rail.getBoundingClientRect(), railStyle = getComputedStyle(rail);
    const buttons = Array.from(viewport.querySelectorAll<HTMLButtonElement>('.diy-3d-toolbar button, .studio-expand-preview, .studio-history button')).map(button => {
      const box = button.getBoundingClientRect(), style = getComputedStyle(button);
      return { name: button.getAttribute('aria-label') || button.textContent?.trim(), left: box.left, top: box.top, right: box.right, bottom: box.bottom, width: box.width, height: box.height,
        fontFamily: style.fontFamily, fontSize: style.fontSize, paddingLeft: style.paddingLeft, paddingRight: style.paddingRight, minWidth: style.minWidth, boxSizing: style.boxSizing };
    });
    const overlaps = buttons.flatMap((a, i) => buttons.slice(i + 1).filter(b => Math.min(a.right, b.right) - Math.max(a.left, b.left) > .5 && Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > .5).map(b => [a.name, b.name]));
    return { buttons, overlaps, inside: buttons.every(button => button.left >= bounds.left - .5 && button.right <= bounds.right + .5 && button.top >= bounds.top - .5 && button.bottom <= bounds.bottom + .5), overflow: document.documentElement.scrollWidth > innerWidth,
      viewport: { width: bounds.width, height: bounds.height, left: bounds.left, right: bounds.right },
      window: { innerWidth, rootWidth: document.documentElement.getBoundingClientRect().width, bodyWidth: document.body.getBoundingClientRect().width, rootClientWidth: document.documentElement.clientWidth, scrollbarGutter: getComputedStyle(document.documentElement).scrollbarGutter, fonts: document.fonts.status },
      rail: { width: railBounds.width, left: railStyle.left, right: railStyle.right, gap: railStyle.gap },
      styleOrder: Array.from(document.querySelectorAll('style[data-vite-dev-id]')).map(style => style.getAttribute('data-vite-dev-id')).filter(path => path?.includes('/features/diy/')) };
  });
}

test('DIY gravity materials preserve editing and toolbar access across phone widths', async ({ page }, testInfo) => {
  // One real WebGL session exercises the full journey and responsive resizing.
  test.setTimeout(120_000);
  await page.setViewportSize({ width: 320, height: 568 });
  const fixture = await setup(page);
  await page.goto('/c/diy/editor');
  const preview = page.locator('.studio-viewport > .diy-3d-inline');
  const viewport = page.locator('.studio-viewport');
  const count = page.locator('.studio-stage-top small');
  const undo = viewport.locator('.studio-history').getByRole('button', { name: '撤销', exact: true });
  await expect(preview).toHaveAttribute('data-ready', 'true', { timeout: 30_000 });
  await expect(page.getByRole('button', { name: /切换为(悬挂|平放)展示/ })).toHaveCount(0);
  await expect(page.locator('.diy-3d-fallback')).toHaveCount(0);

  await page.getByRole('button', { name: '添加测试木珠', exact: true }).click();
  await expect(page.getByRole('button', { name: /切换为(悬挂|平放)展示/ })).toHaveCount(0);
  await page.getByRole('button', { name: '添加普通流苏', exact: true }).click();
  await expect(preview).toHaveAttribute('data-ready', 'true');
  await expect(count).toHaveText('2 / 60 颗');

  // Removing and restoring accessories must keep editing available without a mode switch.
  await viewport.focus();
  await viewport.press('Delete');
  await expect(count).toHaveText('1 / 60 颗');
  await expect(page.getByRole('button', { name: /切换为(悬挂|平放)展示/ })).toHaveCount(0);
  await undo.click();
  await expect(count).toHaveText('2 / 60 颗');
  await expect(preview).toHaveAttribute('data-ready', 'true');

  await page.getByRole('button', { name: '添加中国结流苏', exact: true }).click();
  await expect(count).toHaveText('3 / 60 颗');
  await expect(page.locator('.studio-accessible-selection')).toContainText('中国结流苏');
  await expect.poll(() => fixture.meshes.some(path => path.endsWith('/geometry-tassel.json')) && fixture.meshes.some(path => path.endsWith('/geometry-tassel_knot.json'))).toBe(true);
  await viewport.focus();
  await viewport.press('Delete');
  await expect(count).toHaveText('2 / 60 颗');
  await expect(preview).toHaveAttribute('data-ready', 'true');
  await undo.click();
  await expect(count).toHaveText('3 / 60 颗');

  // Preview is lazy-loaded. Its real stylesheet must not undo the editor's
  // narrow toolbar when it arrives after the editor stylesheet.
  await page.evaluate(() => {
    const previewStyle = Array.from(document.querySelectorAll<HTMLStyleElement>('style[data-vite-dev-id]')).find(style => style.dataset.viteDevId?.endsWith('/src/features/diy/preview.css'));
    if (!previewStyle) throw new Error('Expected Vite preview stylesheet for lazy-load order regression');
    document.head.append(previewStyle);
  });
  for (const scrollbars of ['platform', 'classic-15px'] as const) {
    // Linux reserves a classic gutter for scrollbar-gutter:stable. Overlay-only
    // hosts reserve the same missing width explicitly; native gutters are not doubled.
    const missingGutter = scrollbars === 'classic-15px' ? await page.evaluate(() => Math.max(0, 15 - (innerWidth - document.body.getBoundingClientRect().width))) : 0;
    const classicStyle = missingGutter ? await page.addStyleTag({ content: `html{width:calc(100% - ${missingGutter}px)}` }) : null;
    for (const width of [320, 390, 489]) {
      await page.setViewportSize({ width, height: width === 320 ? 568 : 954 });
      await page.evaluate(() => document.fonts.ready);
      const geometry = await toolbarGeometry(page);
      const diagnostic = JSON.stringify({ scrollbars, width, ...geometry }, null, 2);
      await testInfo.attach(`toolbar-geometry-${scrollbars}-${width}`, { body: diagnostic, contentType: 'application/json' });
      if (scrollbars === 'classic-15px') expect(geometry.window.innerWidth - geometry.window.bodyWidth, diagnostic).toBeGreaterThanOrEqual(14.5);
      expect(geometry.buttons).toHaveLength(5);
      expect(geometry.overlaps, diagnostic).toEqual([]);
      expect(geometry.inside).toBe(true);
      expect(geometry.overflow).toBe(false);
      for (const button of geometry.buttons) expect(button.height).toBeGreaterThanOrEqual(44);

      // Icon-only history actions retain their accessible name and keyboard focus.
      await page.getByRole('button', { name: '扩大预览', exact: true }).focus();
      await page.keyboard.press('Tab');
      await expect(undo).toBeFocused();
      expect(await undo.evaluate(button => parseFloat(getComputedStyle(button).outlineWidth))).toBeGreaterThanOrEqual(2);
      await expect(viewport.locator('.studio-history').getByRole('button', { name: '重做', exact: true })).toBeVisible();
    }
    await classicStyle?.evaluate(style => style.remove());
  }
  expect(fixture.errors).toEqual([]);
  expect(fixture.writes).toEqual([]);
});


// Read actual rendered transforms and deformed mesh vertices from the existing
// R3F store. The Vite test server needs no production-only diagnostics hook.
async function sampleScene(page: Page, frames = 1) {
  return page.evaluate(async frameCount => {
    const modulePath = '/node_modules/.vite/deps/@react-three_fiber.js';
    const { _roots } = await import(modulePath);
    const preview = document.querySelector<HTMLElement>('.studio-viewport > .diy-3d-inline')!;
    const canvas = preview.querySelector('canvas')!;
    const state = _roots.get(canvas)?.store.getState();
    if (!state) throw new Error('The bracelet canvas has no mounted R3F scene');
    const samples = [];
    for (let frame = 0; frame < frameCount; frame++) {
      await new Promise<void>(resolve => requestAnimationFrame(() => resolve()));
      state.scene.updateMatrixWorld(true);
      const bodies: { id: string; kind: string | null; matrix: number[]; vertices: number[]; scale: number[]; quaternion: number[] }[] = [];
      state.scene.traverse((object: any) => {
        if (!object.isMesh || !object.userData.slotId || !object.userData.materialProfile) return;
        const position = object.geometry.getAttribute('position');
        const vertices: number[] = [];
        // Vertex indices are stable across frames, including flexible tassel deformation.
        for (let i = 0; i < 16; i++) {
          const index = Math.floor(i * (position.count - 1) / 15);
          vertices.push(position.getX(index), position.getY(index), position.getZ(index));
        }
        bodies.push({ id: object.userData.slotId, kind: object.userData.accessoryKind ?? null,
          matrix: Array.from(object.matrixWorld.elements), vertices, scale: object.scale.toArray(), quaternion: object.quaternion.toArray() });
      });
      bodies.sort((a,b) => a.id.localeCompare(b.id));
      samples.push({ orientation: JSON.parse(preview.dataset.orientation || 'null') as number[] | null,
        active: preview.dataset.physicsActive, camera: Array.from(state.camera.matrixWorld.elements) as number[], bodies });
    }
    return samples;
  }, frames);
}

function pairDistances(vertices: number[]) {
  const distances: number[] = [];
  for (let a = 0; a < vertices.length; a += 3) for (let b = a + 3; b < vertices.length; b += 3)
    distances.push(Math.hypot(vertices[a] - vertices[b], vertices[a+1] - vertices[b+1], vertices[a+2] - vertices[b+2]));
  return distances;
}

function maxDifference(a: number[], b: number[]) {
  expect(a.length).toBe(b.length);
  return Math.max(0, ...a.map((value, index) => Math.abs(value - b[index])));
}

test('multiple pendants and tassels respond continuously to manipulation and settle without changing the design', async ({ page }, testInfo) => {
  test.setTimeout(120_000);
  const { fixture, draft, preview, before } = await test.step('load and settle the twenty-piece gravity fixture', async () => {
    await page.setViewportSize({ width: 390, height: 900 });
    const fixture = await setup(page, true);
    const draft = await seedCrowdedDraft(page);
    await page.goto('/c/diy/editor');
    const preview = page.locator('.studio-viewport > .diy-3d-inline');
    await expect(preview).toHaveAttribute('data-ready', 'true', { timeout: 30_000 });
    await expect(page.locator('.studio-stage-top small')).toHaveText('20 / 60 颗');
    await expect(page.getByRole('button', { name: /切换为(悬挂|平放)展示/ })).toHaveCount(0);
    await expect.poll(async () => (await sampleScene(page))[0].bodies.length).toBe(20);
    await expect(preview).toHaveAttribute('data-physics-active', 'false', { timeout: 30_000 });
    const before = (await sampleScene(page))[0];
    expect(before.bodies.filter(body => body.kind?.startsWith('pendant'))).toHaveLength(3);
    expect(before.bodies.filter(body => body.kind === 'tassel')).toHaveLength(5);
    expect(before.orientation).toHaveLength(4);

    return { fixture, draft, preview, before };
  });

  const { during, released } = await test.step('rotate continuously and verify inertial bending with a fixed camera', async () => {
    const canvas = await preview.locator('canvas').boundingBox();
    expect(canvas).not.toBeNull();
    const x = canvas!.x + 8, y = canvas!.y + canvas!.height * .28;
    await page.mouse.move(x, y);
    await page.mouse.down();
    const during = [];
    let previous = JSON.stringify(before.orientation);
    for (let step = 1; step <= 4; step++) {
      await page.mouse.move(x + step * 24, y + step * 13, { steps: 4 });
      await expect.poll(() => preview.getAttribute('data-orientation')).not.toBe(previous);
      const current = (await sampleScene(page))[0];
      expect(maxDifference(current.camera, before.camera)).toBeLessThan(1e-7);
      during.push(current);
      previous = JSON.stringify(current.orientation);
    }
    await page.mouse.up();
    await expect(preview).toHaveAttribute('data-dragging', 'false');
    await expect(preview).toHaveAttribute('data-physics-active', 'true');
    const released = await sampleScene(page, 10);
    const first = released[0], last = released.at(-1)!;
    expect(maxDifference(first.orientation!, last.orientation!)).toBeLessThan(1e-7);
    expect(maxDifference(first.camera, last.camera)).toBeLessThan(1e-7);
    const pendants = first.bodies.filter(body => body.kind?.startsWith('pendant'));
    expect(pendants.some(body => {
      const next = last.bodies.find(other => other.id === body.id)!;
      return maxDifference(body.matrix, next.matrix) > 1e-5 || maxDifference(body.vertices, next.vertices) > 1e-5;
    })).toBe(true);
    const tassels = first.bodies.filter(body => body.kind === 'tassel');
    // Pair distances change only when the strands bend, not when a rigid mesh rotates.
    expect(tassels.some(body => maxDifference(pairDistances(body.vertices), pairDistances(last.bodies.find(other => other.id === body.id)!.vertices)) > 1e-5)).toBe(true);
    for (const body of pendants) {
      const next = last.bodies.find(other => other.id === body.id)!;
      expect(maxDifference(pairDistances(body.vertices), pairDistances(next.vertices))).toBeLessThan(1e-4);
    }
    return { during, released };
  });
  const settled = await test.step('settle completely and retain the changed pendant facing', async () => {
    await expect(preview).toHaveAttribute('data-physics-active', 'false', { timeout: 30_000 });
    const settled = await sampleScene(page, 3);
    for (const body of settled[0].bodies) {
      const still = settled.at(-1)!.bodies.find(other => other.id === body.id)!;
      expect(maxDifference(body.matrix, still.matrix)).toBeLessThan(1e-7);
      expect(maxDifference(body.vertices, still.vertices)).toBeLessThan(1e-7);
    }
    const faceNormal = (matrix: number[]) => {
      const length = Math.hypot(matrix[4],matrix[5],matrix[6]);
      return [matrix[4]/length,matrix[5]/length,matrix[6]/length];
    };
    // A fixed camera must see a different pendant face after turning the ring;
    // translating camera-facing billboards is not 3D object manipulation.
    expect(before.bodies.filter(body=>body.kind?.startsWith('pendant')).some(body=>{
      const turned=settled.at(-1)!.bodies.find(other=>other.id===body.id)!;
      return maxDifference(faceNormal(body.matrix),faceNormal(turned.matrix))>.05;
    }), 'settled pendant faces follow the manipulated ring instead of facing the camera').toBe(true);
    return settled;
  });
  await test.step('reset and drag a rendered tassel without rotating or changing the design', async () => {
    await page.getByRole('button', { name: '重置 3D 视角', exact: true }).click();
    await expect.poll(async () => maxDifference((await sampleScene(page))[0].orientation!, before.orientation!)).toBeLessThan(1e-7);
    await expect(page.locator('.studio-stage-top small')).toHaveText('20 / 60 颗');
    const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('diy-studio-draft-v1:guest:new') || 'null').beads);
    expect(saved).toEqual(draft);
    await expect(preview).toHaveAttribute('data-physics-active', 'false', { timeout: 30_000 });
    const pickup = await page.evaluate(async () => {
      const modulePath = '/node_modules/.vite/deps/@react-three_fiber.js';
      const { _roots } = await import(modulePath);
      const canvas = document.querySelector<HTMLCanvasElement>('.studio-viewport canvas')!;
      const state = _roots.get(canvas).store.getState(), rect = canvas.getBoundingClientRect();
      state.scene.updateMatrixWorld(true);
      const meshes: any[] = [];
      state.scene.traverse((object: any) => { if(object.isMesh && object.userData.accessoryKind === 'tassel' && object.userData.slotId) meshes.push(object); });
      for (const mesh of meshes.reverse()) {
        const positions = mesh.geometry.getAttribute('position'), indices = mesh.geometry.index;
        for(let face=0;face<indices.count;face+=Math.max(3,Math.floor(indices.count/180/3)*3)) {
          const vertex=mesh.position.clone().set(0,0,0);
          for(let corner=0;corner<3;corner++) {
            const index=indices.getX(face+corner);
            vertex.x+=positions.getX(index)/3;vertex.y+=positions.getY(index)/3;vertex.z+=positions.getZ(index)/3;
          }
          vertex.applyMatrix4(mesh.matrixWorld).project(state.camera);
          state.raycaster.setFromCamera(state.pointer.clone().set(vertex.x,vertex.y),state.camera);
          const hit=state.raycaster.intersectObjects(state.scene.children,true).find((item:any)=>item.object.userData.slotId);
          if(hit?.object.userData.slotId === mesh.userData.slotId) return { id:mesh.userData.slotId as string, x:rect.x+(vertex.x+1)*rect.width/2, y:rect.y+(1-vertex.y)*rect.height/2 };
        }
      }
      throw new Error('No visible tassel triangle can be picked');
    });
    const beforeDrag = (await sampleScene(page))[0];
    await page.mouse.move(pickup.x,pickup.y);
    await page.mouse.down();
    await page.mouse.move(pickup.x+10,pickup.y+6,{steps:4});
    await expect(preview).toHaveAttribute('data-dragging','true');
    await expect(page.locator('.studio-accessible-selection')).toContainText('普通流苏');
    const picked = (await sampleScene(page))[0];
    expect(maxDifference(picked.orientation!,beforeDrag.orientation!)).toBeLessThan(1e-7);
    expect(maxDifference(picked.bodies.find(body=>body.id===pickup.id)!.matrix,beforeDrag.bodies.find(body=>body.id===pickup.id)!.matrix)).toBeGreaterThan(1e-4);
    await page.keyboard.press('Escape');
    await page.mouse.up();
    await expect(preview).toHaveAttribute('data-dragging','false');
    await expect(page.locator('.studio-stage-top small')).toHaveText('20 / 60 颗');
  });
  await testInfo.attach('continuous-gravity-mesh-samples', { body: JSON.stringify({ before, during, released, settled }, null, 2), contentType: 'application/json' });
  expect(fixture.errors).toEqual([]);
  expect(fixture.writes).toEqual([]);
});


test('pendant and tassel replacement preserves the slot and correct rendered dimensions', async ({ page }, testInfo) => {
  test.setTimeout(120_000);
  const { fixture, preview } = await test.step('load the independent twenty-piece replacement fixture', async () => {
    await page.setViewportSize({ width: 390, height: 900 });
    const fixture = await setup(page, true);
    await seedCrowdedDraft(page);
    await page.goto('/c/diy/editor');
    const preview = page.locator('.studio-viewport > .diy-3d-inline');
    await expect(preview).toHaveAttribute('data-ready','true',{timeout:30_000});
    await expect(page.locator('.studio-stage-top small')).toHaveText('20 / 60 颗');
    await expect.poll(async()=>(await sampleScene(page))[0].bodies.length).toBe(20);
    return { fixture, preview };
  });
  const { replace, replaced } = await test.step('replace the selected rigid pendant with a full-size flexible tassel', async () => {
    const viewport = page.locator('.studio-viewport');
    await viewport.focus();
    for (let press=0;press<13;press++) await viewport.press('ArrowRight');
    await expect(page.locator('.studio-accessible-selection')).toContainText('莲花金饰');
    const replace = page.getByRole('button',{name:'替换材料',exact:true});
    await replace.focus(); await replace.press('Enter');
    await page.getByRole('button',{name:'替换为普通流苏',exact:true}).click();
    await expect.poll(async()=>(await sampleScene(page))[0].bodies.find(body=>body.id==='gravity-12')?.kind).toBe('tassel');
    await expect(preview).toHaveAttribute('data-ready','true');
    await expect(page.locator('.studio-stage-top small')).toHaveText('20 / 60 颗');
    const replaced = (await sampleScene(page))[0], flexible = replaced.bodies.find(body=>body.id==='gravity-12')!;
    expect(flexible.scale).toEqual([1,1,1]);
    expect(flexible.quaternion).toEqual([0,0,0,1]);
    const existingTassel = replaced.bodies.find(body=>body.id==='gravity-16')!;
    const sizeRatio=Math.max(...pairDistances(flexible.vertices))/Math.max(...pairDistances(existingTassel.vertices));
    expect(sizeRatio).toBeGreaterThan(.5);expect(sizeRatio).toBeLessThan(1.5);
    return { replace, replaced };
  });
  await test.step('replace the same slot back to a rigid pendant', async () => {
    await replace.focus(); await replace.press('Enter');
    await page.getByRole('button',{name:'替换为莲花金饰',exact:true}).click();
    await expect.poll(async()=>(await sampleScene(page))[0].bodies.find(body=>body.id==='gravity-12')?.kind).toBe('pendant_lotus');
    await expect(page.locator('.studio-stage-top small')).toHaveText('20 / 60 颗');
  });
  await testInfo.attach('replacement-mesh-samples', { body: JSON.stringify(replaced, null, 2), contentType: 'application/json' });
  expect(fixture.errors).toEqual([]);
  expect(fixture.writes).toEqual([]);
});

function authoredModelFixture() {
  const positions = new Float32Array([-1,-1,-1, 1,-1,-1, 1,1,-1, -1,1,-1, -1,-1,1, 1,-1,1, 1,1,1, -1,1,1]);
  const indices = new Uint16Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5]);
  const binary = Buffer.concat([Buffer.from(positions.buffer),Buffer.from(indices.buffer)]);
  const document = { asset:{version:'2.0'}, scene:0, scenes:[{nodes:[0,1]}], nodes:[{mesh:0,translation:[-1.1,0,0]},{mesh:1,translation:[1.1,0,0]}],
    meshes:[0,1].map(material=>({primitives:[{attributes:{POSITION:0},indices:1,material}]})),
    materials:[{pbrMetallicRoughness:{baseColorFactor:[1,.1,.1,1],metallicFactor:0}},{pbrMetallicRoughness:{baseColorFactor:[.1,.1,1,1],metallicFactor:0}}],
    buffers:[{byteLength:binary.length}],bufferViews:[{buffer:0,byteOffset:0,byteLength:positions.byteLength,target:34962},{buffer:0,byteOffset:positions.byteLength,byteLength:indices.byteLength,target:34963}],
    accessors:[{bufferView:0,componentType:5126,count:8,type:'VEC3',min:[-1,-1,-1],max:[1,1,1]},{bufferView:1,componentType:5123,count:indices.length,type:'SCALAR'}] };
  const json=Buffer.from(JSON.stringify(document)), padded=Buffer.alloc(Math.ceil(json.length/4)*4,32);json.copy(padded);
  const header=Buffer.alloc(12),jh=Buffer.alloc(8),bh=Buffer.alloc(8);
  header.writeUInt32LE(0x46546c67,0);header.writeUInt32LE(2,4);header.writeUInt32LE(28+padded.length+binary.length,8);
  jh.writeUInt32LE(padded.length,0);jh.writeUInt32LE(0x4e4f534a,4);bh.writeUInt32LE(binary.length,0);bh.writeUInt32LE(0x004e4942,4);
  return Buffer.concat([header,jh,padded,bh,binary]);
}

test('authored part categories, dimensions and multi-material generated models drive the real bracelet', async ({page},testInfo)=>{
  test.setTimeout(120_000);
  const fixture=await setup(page);
  const base={version:1,part:'bead',motion:'fixed',source:'template',templateId:'round',dimensionsMm:[8,8,8],rotation:[0,0,0],mount:[0,0,0],connectorMm:0,rigidFraction:.3,photos:[],previewConfirmed:true};
  const catalog=[
    {...materials[0],id:101,name:'名称含流苏的普通珠',category:'tassel',shape:'tassel',renderAssets:JSON.stringify({studio:base})},
    {...materials[0],id:102,name:'生成的刚性挂件',renderAssets:JSON.stringify({studio:{...base,part:'hanging',motion:'rigid',source:'generated',templateId:'custom',dimensionsMm:[14,7,24],rotation:[0,90,0],mount:[0,0,-.5],connectorMm:2,model:{jobId:'fixture',glbUrl:'/test-model.glb',usdzUrl:'/test-model.usdz'}}})},
    {...materials[0],id:103,name:'模板柔性挂件',renderAssets:JSON.stringify({studio:{...base,part:'hanging',motion:'flexible',templateId:'tassel_knot',dimensionsMm:[12,5,36],mount:[0,0,-.5],connectorMm:2,rigidFraction:.55}})},
  ];
  await page.route('**/api/v1/diy/materials?*',route=>route.fulfill({json:{code:0,data:{list:catalog,total:catalog.length}}}));
  await page.route('**/test-model.glb',route=>route.fulfill({body:authoredModelFixture(),contentType:'model/gltf-binary'}));
  await page.goto('/c/diy/editor');
  await page.getByRole('button',{name:'全部',exact:true}).click();
  await expect(page.locator('.studio-materials>button')).toHaveCount(3);
  await page.getByRole('button',{name:'添加名称含流苏的普通珠',exact:true}).click();
  await page.getByRole('button',{name:'动态挂件',exact:true}).click();
  await expect(page.locator('.studio-materials>button')).toHaveCount(3);
  await page.getByRole('button',{name:'添加生成的刚性挂件',exact:true}).click();
  await page.getByRole('button',{name:'添加模板柔性挂件',exact:true}).click();
  await expect(page.locator('.studio-stage-top small')).toHaveText('3 / 60 颗');
  const inspect=()=>page.evaluate(async()=>{
    const modulePath='/node_modules/.vite/deps/@react-three_fiber.js';
    const {_roots}=await import(modulePath),canvas=document.querySelector('.studio-viewport canvas');
    const state=canvas&&_roots.get(canvas)?.store.getState();
    if(!state)return null;
    const result={models:[] as any[],bodies:[] as any[],cordHeight:0};
    state.scene.traverse((object:any)=>{
      if(object.userData.gravityBodies)result.bodies=object.userData.gravityBodies.map((b:any)=>({flexible:!!b.spec.flexible,connector:b.spec.connectorLength,bodyLength:b.spec.bodyLength}));
      if(object.isMesh&&object.userData.slotId&&object.userData.materialProfile)result.models.push({slot:object.userData.slotId,materials:Array.isArray(object.material)?object.material.map((m:any)=>m.color?.toArray()):[],vertices:object.geometry.getAttribute('position').count});
      if(object.userData.braceletCord){const p=object.geometry.getAttribute('position');for(let i=0;i<p.count;i++)result.cordHeight=Math.max(result.cordHeight,Math.abs(p.getY(i)));}
    });
    return result;
  });
  await expect.poll(async()=> (await inspect())?.models.length,{timeout:30_000}).toBe(3);
  const scene=await inspect();
  expect(scene!.bodies).toHaveLength(2);
  expect(scene!.bodies.map(x=>x.flexible).sort()).toEqual([false,true]);
  expect(scene!.cordHeight).toBeLessThan(.009);
  const generated=scene!.models.find(x=>x.materials.length===2);
  expect(generated).toBeTruthy();
  expect(generated.materials[0][0]).toBeCloseTo(1,3);
  expect(generated.materials[1][2]).toBeCloseTo(1,3);
  await expect(page.locator('.diy-3d-fallback')).toHaveCount(0);
  expect(fixture.errors).toEqual([]);expect(fixture.writes).toEqual([]);
  await testInfo.attach('authored-actual-scene',{body:JSON.stringify(scene,null,2),contentType:'application/json'});
});


test('material rail restores individual bead categories and keeps authored hangings and cord separate', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const fixture = await setup(page);
  const base = { version: 1, part: 'hanging', motion: 'rigid', source: 'template', templateId: 'pendant_generic',
    dimensionsMm: [10, 4, 14], rotation: [0, 0, 0], mount: [0, 0, -.5], connectorMm: 2, rigidFraction: .3, photos: [], previewConfirmed: true };
  const catalog = [
    { ...materials[0], id: 201, name: '分类主珠', category: 'main_bead' },
    { ...materials[0], id: 202, name: '分类隔珠', category: 'spacer', shape: 'disc' },
    { ...materials[0], id: 203, name: '分类佛头', category: 'buddha_head', shape: 'buddha_head' },
    { ...materials[0], id: 204, name: '分类三通', category: 'three_way', shape: 'three_way' },
    { ...materials[0], id: 205, name: '自定义动态佛头', category: 'buddha_head', renderAssets: JSON.stringify({ studio: base }) },
    { ...materials[1], id: 206, name: '分类流苏' },
    { ...materials[4], id: 207, name: '分类吊坠' },
    { ...materials[0], id: 208, name: '分类绳线', category: 'cord', renderAssets: JSON.stringify({ studio: base }) },
  ];
  await page.route('**/api/v1/diy/materials?*', route => route.fulfill({ json: { code: 0, data: { list: catalog, total: catalog.length } } }));
  await page.goto('/c/diy/editor');
  const rail = page.getByRole('group', { name: '材料分类' });
  await expect(rail.getByRole('button')).toHaveText(['正在使用', '全部', '主珠', '隔珠', '佛头', '三通', '动态挂件', '绳线']);
  const cards = page.locator('.studio-materials>button');
  await expect(cards).toHaveCount(8);
  for (const [label, material] of [['主珠', '分类主珠'], ['隔珠', '分类隔珠'], ['佛头', '分类佛头'], ['三通', '分类三通'], ['绳线', '分类绳线']]) {
    await rail.getByRole('button', { name: label, exact: true }).click();
    await expect(cards).toHaveCount(1);
    await expect(cards.first()).toHaveAttribute('aria-label', '添加' + material);
  }
  await rail.getByRole('button', { name: '动态挂件', exact: true }).click();
  await expect(cards).toHaveCount(3);
  for (const label of ['添加自定义动态佛头', '添加分类流苏', '添加分类吊坠']) await expect(page.getByRole('button', { name: label, exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: '添加分类绳线', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: '添加自定义动态佛头', exact: true }).click();
  await rail.getByRole('button', { name: '正在使用', exact: true }).click();
  await expect(cards).toHaveCount(1);
  await expect(page.locator('.studio-stage-top small')).toHaveText('1 / 60 颗');
  await expect.poll(() => page.evaluate(() => {
    const draft = JSON.parse(localStorage.getItem('diy-studio-draft-v1:guest:new') || 'null');
    return draft?.beads?.[0]?.subtype;
  })).toBe('buddha_head');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  expect(fixture.errors).toEqual([]);
  expect(fixture.writes).toEqual([]);
});
