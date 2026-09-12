import { createRequire } from 'node:module';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

// Production artwork is authored as vectors. PNGs are deterministic exports,
// never crops or recolorings of the old bitmap marks.
const require = createRequire(import.meta.url);
const sharp = require(process.env.BRAND_SHARP_MODULE || 'sharp');
const out = fileURLToPath(new URL('./assets/', import.meta.url));
await mkdir(out, { recursive: true });

export const identities = {
  customer: ['问玄东方', '日出山川'],
  master: ['法师工作台', '一灯明心'],
  temple: ['寺院管理台', '檐下安宁'],
  shop: ['商城管理台', '相遇成环'],
  platform: ['统一运营管理台', '四方有序'],
  atelier: ['东方珠作', '一珠一念'],
};

const frame = '<path d="M41 12C23 12 12 26 12 44v10c0 18 13 30 36 30s36-12 36-30V44c0-18-11-32-29-32" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/>';
const sun = '<circle cx="48" cy="34" r="8" fill="var(--accent)"/>';
const horizon = '<path d="M15 59c11-9 17-10 27-4 5 3 7 3 12 0 11-7 17-6 27 3" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/>';
const glyphs = {
  customer: `${sun}${horizon}<path d="M48 60c-20 6 26 5 6 19" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/>`,
  master: '<defs><mask id="flame-cut"><path fill="white" d="M0 0h96v96H0z"/><path d="M46 61c-3-7 7-13 6-22" fill="none" stroke="black" stroke-width="3.5" stroke-linecap="round"/></mask></defs><path mask="url(#flame-cut)" d="M49 23c3 13 14 17 14 27 0 8-6 14-15 14-9 0-15-6-15-14 0-11 13-15 16-27Z" fill="var(--accent)"/><path d="M27 72c13-6 29-6 42 0" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/>',
  temple: `${sun}<path d="M23 58c12 0 18-4 25-12 7 8 13 12 25 12H23Z" fill="var(--ink)"/><path d="M31 68h34M38 60v17m20-17v17" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/>`,
  shop: `${sun}<path d="M18 63c15-14 31-11 41 7M78 63c-15-14-31-11-41 7" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/><path d="M37 70v7m22-7v7" fill="none" stroke="var(--ink)" stroke-width="5" stroke-linecap="round"/>`,
  platform: `${sun}<path d="M48 50 33 75m15-25 15 25M48 51v27M48 50 23 63m25-13 25 13" fill="none" stroke="var(--ink)" stroke-width="4.5" stroke-linecap="round"/>`,
  atelier: '<circle cx="48" cy="49" r="23" fill="none" stroke="var(--ink)" stroke-width="2.5"/><g fill="var(--ink)"><circle cx="28" cy="37.5" r="7"/><circle cx="28" cy="60.5" r="7"/><circle cx="48" cy="72" r="7"/><circle cx="68" cy="60.5" r="7"/><circle cx="68" cy="37.5" r="7"/></g><circle cx="48" cy="26" r="8" fill="var(--accent)"/>',
};

function drawing(role, theme, app = false) {
  const dark = theme === 'dark';
  const bg = app ? (dark ? '#241A17' : role === 'master' ? '#A94132' : '#244C43') : (dark ? '#241A17' : '#F6F3EC');
  const ink = app ? '#F6F3EC' : dark ? '#E5CCA3' : '#244C43';
  const accent = app ? '#DFC18D' : dark ? '#D98B70' : '#987342';
  const styles = `--ink:${ink};--accent:${accent};--cutout:${bg}`;
  const artwork = `${frame}${glyphs[role]}`.replaceAll('var(--ink)', ink).replaceAll('var(--accent)', accent).replaceAll('var(--cutout)', bg);
  // A 90% optical box leaves clear space for both iOS and maskable PWA icons.
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${app ? 1024 : 96}" height="${app ? 1024 : 96}" viewBox="0 0 96 96" style="${styles}">${app ? `<path fill="${bg}" d="M0 0h96v96H0z"/><g transform="translate(4.8 4.8) scale(.9)">${artwork}</g>` : artwork}</svg>`;
}

for (const role of Object.keys(identities)) {
  for (const theme of ['light', 'dark']) {
    const svg = drawing(role, theme);
    await writeFile(path.join(out, `logo-${role}-${theme}.svg`), svg + '\n');
    await sharp(Buffer.from(svg)).resize(512, 512).png().toFile(path.join(out, `logo-${role}-${theme}.png`));
    const icon = drawing(role, theme, true);
    await writeFile(path.join(out, `icon-${role}-${theme}.svg`), icon + '\n');
    await writeFile(path.join(out, `favicon-${role}-${theme}.svg`), icon.replace('translate(4.8 4.8) scale(.9)', 'translate(0 0)') + '\n');
    await sharp(Buffer.from(icon)).resize(1024, 1024).removeAlpha().png().toFile(path.join(out, `icon-${role}-${theme}-1024.png`));
  }
  const adaptive = drawing(role, 'light', true).replace('translate(4.8 4.8) scale(.9)', 'translate(0 0)').replace('><path', '><style>@media(prefers-color-scheme:dark){svg{--ink:#E5CCA3;--accent:#D98B70;--cutout:#241A17}.icon-bg{fill:#241A17}[stroke="#F6F3EC"]{stroke:#E5CCA3}[fill="#F6F3EC"]{fill:#E5CCA3}}</style><path class="icon-bg"');
  await writeFile(path.join(out, `favicon-${role}.svg`), adaptive + '\n');
}

for (const role of ['customer', 'master']) for (const size of [180, 192, 512]) {
  await sharp(Buffer.from(drawing(role, 'light', true))).resize(size, size).removeAlpha().png().toFile(path.join(out, `icon-${role}-${size}.png`));
}

const cards = Object.entries(identities).map(([role, [name, idea]]) => `<article><img src="assets/logo-${role}-light.svg" class="light" alt="${name}标志"><img src="assets/logo-${role}-dark.svg" class="dark" alt=""><h2>${name}</h2><p>${idea}</p><div class="sizes">${[16,24,32].map(size => `<img src="assets/logo-${role}-light.svg" class="light" style="width:${size}px;height:${size}px" alt=""><img src="assets/logo-${role}-dark.svg" class="dark" style="width:${size}px;height:${size}px" alt="">`).join('')}</div></article>`).join('');
await writeFile(new URL('./index.html', import.meta.url), `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>问玄东方 · 品牌图形</title><style>*{box-sizing:border-box}body{margin:0;background:#F6F3EC;color:#244C43;font-family:"Songti SC","Noto Serif CJK SC",serif}main{max-width:1200px;margin:auto;padding:64px 40px}header{display:flex;align-items:center;gap:28px;padding-bottom:48px;border-bottom:1px solid #244c4325}header img{width:104px;height:104px}h1{font-size:42px;letter-spacing:6px;margin:0 0 14px}p{color:#987342;font-family:system-ui,sans-serif;font-size:13px;letter-spacing:2px}button{margin-left:auto;background:none;border:1px solid #98734266;border-radius:24px;padding:12px 22px;color:inherit;cursor:pointer}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:1px;margin:44px 0;background:#244c4318;border:1px solid #244c4318}article{text-align:center;background:#F6F3EC;padding:34px 14px}article>img{width:96px;height:96px}h2{font-size:17px;margin:22px 0 10px;letter-spacing:2px}.sizes{display:flex;gap:18px;align-items:center;justify-content:center;margin-top:28px;height:32px}.apps{display:flex;gap:24px;align-items:center}.apps img{width:100px;height:100px;border-radius:23px}.dark{display:none}body[data-theme=dark],body[data-theme=dark] article{background:#241A17;color:#E5CCA3}body[data-theme=dark] .grid{background:#e5cca322;border-color:#e5cca322}body[data-theme=dark] header{border-color:#e5cca322}body[data-theme=dark] p{color:#D7AE78}body[data-theme=dark] .dark{display:inline-block}body[data-theme=dark] .light{display:none}@media(max-width:600px){main{padding:32px 20px}header{gap:16px;flex-wrap:wrap}header img{width:70px;height:70px}h1{font-size:28px;letter-spacing:3px}.grid{grid-template-columns:repeat(2,1fr)}article{padding:28px 8px}button{margin-left:0}}</style><main><header><img src="assets/logo-customer-light.svg" class="light" alt=""><img src="assets/logo-customer-dark.svg" class="dark" alt=""><div><h1>问玄东方</h1><p>东方有序 · 心有所栖</p></div><button type="button" onclick="document.body.dataset.theme=document.body.dataset.theme==='dark'?'light':'dark'">切换浅深色</button></header><section class="grid">${cards}</section><section class="apps"><img src="assets/icon-customer-light-1024.png" alt="信众应用图标"><img src="assets/icon-master-light-1024.png" alt="法师应用图标"><img src="assets/icon-customer-dark-1024.png" alt="深色应用图标"><p>日出、山川与圆融的印记<br><br>同一笔意，不同身份。</p></section></main></html>`);
console.log('Generated six identities, light/dark vectors, PNGs, app icons and a preview.');
