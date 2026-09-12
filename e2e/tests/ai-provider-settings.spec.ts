import { test, expect, type Page } from '@playwright/test';
const initial = { provider:'deepseek',baseUrl:'https://api.deepseek.com',defaultModel:'deepseek-flash',visionModel:'deepseek-flash',enabledModels:[],thinkingEnabled:true,reasoningEffort:'low',maxOutputTokens:2048,revision:0,hasApiKey:true,writable:true,source:'environment',history:[] };
async function setup(page:Page, options:{role?:string;failSave?:boolean;failTest?:boolean;writable?:boolean}={}) {
 const role=options.role || 'platform_super';
 await page.addInitScript(role=>{const token='e30.'+btoa(JSON.stringify({userId:1,roles:[role],clientId:'platform-admin',exp:4000000000}))+'.fixture';localStorage.setItem('df_platform_admin_token',token);localStorage.setItem('df_platform_admin_user',JSON.stringify({userId:1,nickname:'配置验收'}));},role);
 let saved:any={...initial,writable:options.writable??true};const calls:{method:string;path:string;body:any}[]=[];
 await page.route('**/api/v1/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;const body=req.postData()?req.postDataJSON():null;calls.push({method:req.method(),path,body});let data:any={list:[],total:0};
  if(path.endsWith('/ai/admin/provider/test')){if(options.failTest)return route.fulfill({json:{code:40001,message:'连接测试失败，请检查地址、密钥和服务状态'}});data={list:[{id:'deepseek-flash',name:'DeepSeek Flash',supportsVision:true,description:'文字与图片'},{id:'deepseek-v4-pro',name:'DeepSeek V4 Pro',supportsVision:false,description:'文字对话'}],defaultModel:'deepseek-flash'};}
  else if(path.endsWith('/ai/admin/provider')){
   if(req.method()==='PUT'){
    if(options.failSave)return route.fulfill({json:{code:40001,message:'配置已被其他管理员更新，请重新加载后再保存'}});
    const {apiKey,...values}=body;saved={...saved,...values,revision:saved.revision+1,source:'platform',history:[{revision:1,actor:'1',at:'2026-09-12T10:00:00Z',fields:['apiKey','maxOutputTokens']}]};
   }
   data=saved;
  }
  await route.fulfill({json:{code:0,data}});
 });
 return calls;
}
test('secret replacement, connection probe and reviewed save',async({page})=>{
 const calls=await setup(page);await page.goto('/settings/ai');await expect(page.getByRole('heading',{name:'AI 模型设置',exact:true})).toBeVisible();
 const key=page.getByLabel('API Key',{exact:true});await expect(key).toHaveValue('');await expect(key).toHaveAttribute('type','password');
 await key.fill('fixture-replacement-key');await page.getByRole('button',{name:'测试连接与获取模型',exact:true}).click();await expect(page.getByRole('status')).toContainText('连接成功');
 expect(calls.filter(c=>c.method==='PUT')).toHaveLength(0);
 await page.getByRole('spinbutton',{name:'最大输出 Token',exact:true}).fill('4096');
 await page.getByRole('button',{name:'保存并生效',exact:true}).click();await expect(page.getByRole('dialog',{name:'保存并生效'})).toBeVisible();await page.getByRole('button',{name:'确认生效',exact:true}).click();
 await expect(page.locator('.ai-active-card')).toContainText('v1');await expect(key).toHaveValue('');await expect(page.locator('.ai-history')).toContainText('密钥');
 const write=calls.find(c=>c.method==='PUT')!;expect(write.body.apiKey).toBe('fixture-replacement-key');expect(write.body.maxOutputTokens).toBe(4096);expect(write.body.revision).toBe(0);
 await page.screenshot({path:'artifacts/ai-settings/desktop.png',fullPage:true});await page.reload();await expect(page.locator('.ai-active-card')).toContainText('v1');await expect(key).toHaveValue('');
});
test('mobile form and action bar remain within viewport',async({page})=>{
 await page.setViewportSize({width:390,height:900});await setup(page);await page.goto('/settings/ai');await expect(page.locator('.ai-active-card')).toBeVisible();
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();await page.getByRole('button',{name:'保存并生效',exact:true}).scrollIntoViewIfNeeded();await expect(page.getByRole('button',{name:'保存并生效',exact:true})).toBeVisible();await page.screenshot({path:'artifacts/ai-settings/mobile.png',fullPage:true});
});
test('failed probe and stale save never show applied state',async({page})=>{
 const calls=await setup(page,{failSave:true,failTest:true});await page.goto('/settings/ai');await page.getByLabel('API Key',{exact:true}).fill('fixture-draft-key');
 await page.getByRole('button',{name:'测试连接与获取模型',exact:true}).click();await expect(page.locator('.ai-test-error')).toContainText('连接测试失败');expect(calls.filter(c=>c.method==='PUT')).toHaveLength(0);
 await page.getByRole('button',{name:'保存并生效',exact:true}).click();await page.getByRole('button',{name:'确认生效',exact:true}).click();await expect(page.locator('.el-message').last()).toContainText('其他管理员');await expect(page.locator('.ai-active-card')).toContainText('v0');await expect(page.getByLabel('API Key',{exact:true})).toHaveValue('fixture-draft-key');
 await page.getByRole('button',{name:'撤销修改',exact:true}).click();await expect(page.getByLabel('API Key',{exact:true})).toHaveValue('');
});
for(const role of ['shop_admin','platform_service'])test(`${role} cannot enter provider settings`,async({page})=>{const calls=await setup(page,{role});await page.goto('/settings/ai');await expect(page).not.toHaveURL(/settings\/ai/);expect(calls.filter(c=>c.path.includes('/ai/admin/'))).toHaveLength(0);await expect(page.getByText('AI 模型设置',{exact:true})).toHaveCount(0);});
test('storage not enabled is explicitly read-only',async({page})=>{await setup(page,{writable:false});await page.goto('/settings/ai');await expect(page.getByText('当前为只读模式，服务器尚未启用配置持久化')).toBeVisible();await expect(page.getByLabel('API Key',{exact:true})).toBeDisabled();await expect(page.getByRole('button',{name:'保存并生效',exact:true})).toBeDisabled();});
