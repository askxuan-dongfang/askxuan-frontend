import { readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const sharp = createRequire(import.meta.url)(process.env.BRAND_SHARP_MODULE || 'sharp');
const roles = [['customer','问玄东方','日出山川'],['master','法师工作台','一灯明心'],['temple','寺院管理台','檐下安宁'],['shop','商城管理台','相遇成环'],['platform','统一运营管理台','四方有序'],['atelier','东方珠作','一珠一念']];
async function mark(role, theme, x, y, size) {
  const bytes = await readFile(new URL(`./assets/logo-${role}-${theme}.svg`, import.meta.url));
  return `<image x="${x}" y="${y}" width="${size}" height="${size}" href="data:image/svg+xml;base64,${bytes.toString('base64')}"/>`;
}
let content = '';
for (const [index, theme] of ['light','dark'].entries()) {
  const y = index * 440;
  const ink = theme === 'light' ? '#244C43' : '#E5CCA3';
  const accent = theme === 'light' ? '#987342' : '#D7AE78';
  content += `<rect y="${y}" width="1440" height="440" fill="${theme === 'light' ? '#F6F3EC' : '#241A17'}"/>`;
  content += await mark('customer',theme,54,y+30,70);
  content += `<g fill="${ink}" font-family="Songti SC,serif"><text x="145" y="${y+73}" font-size="34" letter-spacing="4">问玄东方</text><text x="1375" y="${y+64}" text-anchor="end" font-family="sans-serif" font-size="13" letter-spacing="3" fill="${accent}">${index ? '深棕 · 朱砂 · 暖金' : '米白 · 松绿 · 古金'}</text><path d="M60 ${y+126}H1380" stroke="${ink}" opacity=".15"/>`;
  for (const [i,[role,name,idea]] of roles.entries()) {
    const x = 160 + i * 224;
    content += await mark(role,theme,x-61,y+165,122);
    content += `<text x="${x}" y="${y+328}" text-anchor="middle" font-size="19" letter-spacing="1">${name}</text><text x="${x}" y="${y+360}" text-anchor="middle" font-family="sans-serif" font-size="13" fill="${accent}" letter-spacing="3">${idea}</text>`;
  }
  content += '</g>';
}
const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1440" height="880" viewBox="0 0 1440 880">${content}</svg>`;
await writeFile(new URL('./brand-sheet.svg', import.meta.url), svg);
await sharp(Buffer.from(svg)).png().toFile(new URL('./brand-sheet.png', import.meta.url).pathname);
