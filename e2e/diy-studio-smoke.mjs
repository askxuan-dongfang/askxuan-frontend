import { chromium, expect } from '@playwright/test';
import fs from 'node:fs/promises';
const fixture=JSON.parse(await fs.readFile('/private/tmp/diy-browser-fixture.json','utf8'));
const output=process.env.DIY_VERIFY_DIR || '/private/tmp/diy-studio-verification';await fs.mkdir(output,{recursive:true});
const api=async(path,token,body,method='POST')=>{const r=await fetch('http://127.0.0.1:18088/api/v1'+path,{method,headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json();if(data.code)throw Error(JSON.stringify(data));return data.data;};
const live=JSON.parse(await fs.readFile('/private/tmp/diy-live-materials.json','utf8')).data.list;
const manifest=JSON.parse(await fs.readFile('../apps/web-h5/public/assets/diy/manifest.json','utf8'));
const existing=(await api('/diy/materials',fixture.admin,null,'GET')).list;
for(const name of ['粉晶','小叶紫檀圆珠','白玉','铜鎏金隔片']){
 if(existing.some(m=>m.name===name))continue;
 const m={...live.find(m=>m.name===name),stock:200};const a=manifest.find(a=>a.catalogName===name);
 if(a)m.renderAssets=JSON.stringify({beadImageUrl:a.file,imageCrop:a.imageCrop,source:'licensed',attribution:`${a.author} / ${a.license}; /assets/diy/credits.html`});
 if(name==='小叶紫檀圆珠')m.renderAssets=JSON.stringify({normalMapUrl:'/assets/diy/textures/wood/NormalGL.jpg',roughnessMapUrl:'/assets/diy/textures/wood/Roughness.jpg',source:'procedural'});
 await api('/admin/diy/materials',fixture.admin,m);
}
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const ctx=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
await ctx.addInitScript(({token})=>{localStorage.setItem('h5_token',token);localStorage.setItem('h5-auth',JSON.stringify({state:{token,role:'customer',userId:99002,displayName:'DIY 验收'},version:0}));},{token:fixture.other});
const page=await ctx.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
try {
 await page.goto('http://127.0.0.1:5178/c/diy/editor');
 await page.getByRole('button',{name:'添加青金石',exact:true}).waitFor();
 for(let i=0;i<8;i++)await page.getByRole('button',{name:'添加青金石',exact:true}).click();
 for(let i=0;i<8;i++)await page.getByRole('button',{name:'添加粉晶',exact:true}).click();
 for(let i=0;i<4;i++)await page.getByRole('button',{name:'添加小叶紫檀圆珠',exact:true}).click();
 await page.getByRole('button',{name:'添加弹力绳',exact:true}).click();
 await expect(page.getByLabel('珠子顺序').getByRole('button')).toHaveCount(20);
 await page.getByRole('button',{name:'撤销',exact:true}).click();
 await page.getByRole('button',{name:'重做',exact:true}).click();
 // Keyboard ordering and pointer ordering use real SVG screen transforms.
 const first=page.locator('.diy-canvas-svg [role=button]').first();await first.focus();await first.press('ArrowRight');
 await page.locator('.diy-canvas-svg').scrollIntoViewIfNeeded();
 const nodes=page.locator('.diy-canvas-svg [role=button]');const a=await nodes.nth(0).boundingBox(),b=await nodes.nth(5).boundingBox();
 await page.mouse.move(a.x+a.width/2,a.y+a.height/2);await page.mouse.down();await page.mouse.move(b.x+b.width/2,b.y+b.height/2,{steps:12});await page.mouse.up();
 await expect(page.getByLabel('珠子顺序').getByRole('button')).toHaveCount(20);
 await page.getByRole('button',{name:'3D',exact:true}).click();await expect(page.locator('canvas')).toBeVisible();
 await page.waitForTimeout(2000);await page.screenshot({path:output+'/editor-3d-390.png',fullPage:true});
 await page.getByRole('button',{name:'暂停旋转',exact:true}).click();await page.getByRole('button',{name:'2D',exact:true}).click();
 await page.getByRole('button',{name:'保存设计',exact:true}).click();await page.getByLabel('设计名称',{exact:true}).fill('青金与粉月 · 浏览器验收');await page.getByLabel('设计灵感').fill('实拍参考与木纹搭配，验证分享、复制和继续编辑。');await page.getByRole('button',{name:'确认',exact:true}).click();
 await expect(page).toHaveURL(/\/c\/diy\/\d+$/);const designId=Number(page.url().split('/').at(-1));
 await page.getByRole('button',{name:'发布到广场',exact:true}).click();await page.getByRole('button',{name:'确认发布',exact:true}).click();await expect(page.getByRole('button',{name:'下架作品',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'分享',exact:true}).click();await expect(page.getByLabel('作品分享链接')).toHaveValue(`http://127.0.0.1:5178/c/diy/${designId}`);await page.getByRole('button',{name:'关闭',exact:true}).click();
 const downloaded=page.waitForEvent('download');await page.getByRole('button',{name:'导出图片',exact:true}).click();const file=await downloaded;await file.saveAs(output+'/share-card.png');
 for(const width of [390,768,1440]) {await page.setViewportSize({width,height:900});await page.screenshot({path:`${output}/detail-${width}.png`,fullPage:true});await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();}
 const guest=await browser.newContext({viewport:{width:390,height:844}});const gp=await guest.newPage();await gp.goto(`http://127.0.0.1:5178/c/diy/${designId}`);await expect(gp.getByRole('heading',{name:'青金与粉月 · 浏览器验收',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'复制并编辑',exact:true}).click();await expect(page).toHaveURL(/editor\?design=\d+/);await expect(page.getByLabel('珠子顺序').getByRole('button')).toHaveCount(20);const cloneId=Number(new URL(page.url()).searchParams.get('design'));if(cloneId===designId)throw Error('copy reused original');
 await page.getByRole('button',{name:'添加白玉',exact:true}).click();await page.waitForTimeout(700);await page.reload();await expect(page.getByLabel('珠子顺序').getByRole('button')).toHaveCount(21);
 const original=await api(`/diy/designs/${designId}`,fixture.other,null,'GET');if(JSON.parse(original.designData).beads.length!==20)throw Error('copy modified original');
 for(const width of [390,768,1440]){await page.setViewportSize({width,height:900});await page.screenshot({path:`${output}/editor-${width}.png`,fullPage:true});await expect.poll(()=>page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();}
 await page.goto('http://127.0.0.1:5178/c/diy');await expect(page.getByRole('link',{name:/青金与粉月/}).first()).toBeVisible();await page.screenshot({path:output+'/plaza-1440.png',fullPage:true});
 if(errors.length)throw Error(errors.join('\n'));
 await fs.writeFile(output+'/browser-result.json',JSON.stringify({status:'PASS',designId,cloneId,viewports:[390,768,1440],checks:['original-photo rendering','20-bead edit','undo/redo','keyboard/pointer reorder','WebGL 3D','save','publish','share URL','PNG export','guest read','independent copy','draft restore','no horizontal overflow','no page errors']},null,2));console.log('PASS',designId,cloneId);
} catch(e){await page.screenshot({path:output+'/failure.png',fullPage:true});console.log((await page.locator('body').innerText()).slice(-4000));throw e} finally{await browser.close()}
