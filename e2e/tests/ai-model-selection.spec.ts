import {test,expect,type Page} from '@playwright/test';
const models=[{id:'deepseek-flash',name:'DeepSeek Flash',description:'文字与图片',supportsVision:true},{id:'deepseek-v4-pro',name:'DeepSeek V4 Pro',description:'文字对话 · 不支持图片',supportsVision:false}];
async function setup(page:Page,options:{fail?:boolean;image?:boolean;guest?:boolean}={}){
 if(!options.guest)await page.addInitScript(()=>{localStorage.setItem('h5_token','fixture');localStorage.setItem('h5-auth',JSON.stringify({state:{token:'fixture',role:'customer',userId:42},version:0}));});
 const state={fail:!!options.fail,models:[...models],sent:[] as any[],messages:options.image?[{id:1,sessionId:7,role:'user',content:'图片问题',attachments:[{mediaId:1,url:'/test.png'}],status:'completed'}]:[] as any[],calls:[] as string[]};
 await page.route('**/test.png',route=>route.fulfill({contentType:'image/png',body:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=','base64')}));
 await page.route('**/api/v1/**',async route=>{
  const request=route.request(),path=new URL(request.url()).pathname;state.calls.push(path);
  let data:any={list:[],total:0};
  if(path.endsWith('/ai/models')){if(state.fail)return route.fulfill({status:503,json:{code:50301,message:'unavailable'}});data={list:state.models,defaultModel:'deepseek-flash',stale:false};}
  else if(path.endsWith('/ai/skills'))data={list:[{code:'general',name:'直接问事',inputSchema:{fields:[]}}]};
  else if(path.endsWith('/ai/topics'))data=[];
  else if(path.endsWith('/chats/incoming-call'))data={call:null};
  else if(path.endsWith('/chats/unread'))data={count:0};
  else if(path.endsWith('/ai/sessions')&&request.method()==='GET')data={list:state.messages.length?[{id:7,title:'测试问事',skillCode:'general',status:'active'}]:[],total:state.messages.length?1:0};
  else if((path.endsWith('/ai/sessions')||path.endsWith('/messages'))&&request.method()==='POST'){
   const body=request.postDataJSON();state.sent.push(body);
   state.messages.push({id:state.messages.length+1,sessionId:7,role:'user',content:body.question||body.content,status:'completed'});
   state.messages.push({id:state.messages.length+1,sessionId:7,role:'assistant',content:'隔离模型回答',model:body.model,status:'completed'});
   data={id:7,sessionId:7,messageId:state.messages.length,status:'completed'};
  }
  else if(path.endsWith('/ai/sessions/7/messages'))data={list:state.messages,total:state.messages.length};
  else if(path.endsWith('/stream'))return route.fulfill({contentType:'text/event-stream',body:'event: done\ndata: {}\n\n'});
  await route.fulfill({json:{code:0,data}});
 });return state;
}
const trigger=(page:Page)=>page.getByRole('button',{name:/^选择 AI 模型：/});
const sheet=(page:Page)=>page.getByRole('dialog',{name:'选择模型'});
async function choose(page:Page,name:string){
 await trigger(page).click();
 await sheet(page).getByRole('button',{name:new RegExp(name)}).click();
 await expect(sheet(page)).toHaveCount(0);
}
for(const width of [375,557,768])test(`model selection persists and request uses chosen model ${width}`,async({page})=>{
 await page.setViewportSize({width,height:900});const state=await setup(page);await page.goto('/c/ai');
 const picker=trigger(page);
 await expect(picker).toContainText('DeepSeek Flash');
 expect((await picker.boundingBox())!.height).toBeLessThanOrEqual(48);
 await expect(page.getByRole('combobox')).toHaveCount(0);
 await expect(page.getByText('对下一条消息生效',{exact:false})).toHaveCount(0);
 await page.screenshot({path:`artifacts/ai-models/home-${width}.png`});
 await picker.click();
 await expect(sheet(page).getByRole('button',{name:/DeepSeek Flash/})).toHaveAttribute('aria-pressed','true');
 const bounds=await sheet(page).boundingBox();
 expect(bounds!.x).toBeGreaterThanOrEqual(0);expect(bounds!.x+bounds!.width).toBeLessThanOrEqual(width);
 if(width<=600)await expect.poll(async()=>{const b=await sheet(page).boundingBox();return Math.abs(b!.y+b!.height-900);}).toBeLessThan(2);
 await page.screenshot({path:`artifacts/ai-models/sheet-${width}.png`});
 await sheet(page).getByRole('button',{name:/DeepSeek V4 Pro/}).click();
 await expect(sheet(page)).toHaveCount(0);await expect(picker).toBeFocused();
 await page.reload();await expect(picker).toContainText('DeepSeek V4 Pro');
 await page.getByRole('textbox',{name:'输入问题'}).fill('隔离问题');await page.getByRole('button',{name:'发送',exact:true}).click();
 await expect.poll(()=>state.sent.length).toBe(1);expect(state.sent[0].model).toBe('deepseek-v4-pro');
 await expect(page.getByText('隔离模型回答')).toBeVisible();
 await expect(picker).toBeEnabled();await choose(page,'DeepSeek Flash');
 await page.getByRole('textbox',{name:'输入问题'}).fill('后续问题');await page.getByRole('button',{name:'发送',exact:true}).click();
 await expect.poll(()=>state.sent.length).toBe(2);expect(state.sent[1].model).toBe('deepseek-flash');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
 await page.screenshot({path:`artifacts/ai-models/selection-${width}.png`,fullPage:true});
});
test('model list error is retryable and removed preference is replaced',async({page})=>{
 const state=await setup(page,{fail:true});await page.goto('/c/ai');await page.getByRole('textbox',{name:'输入问题'}).fill('保留草稿');
 await expect(page.getByRole('button',{name:'发送',exact:true})).toBeDisabled();await expect(trigger(page)).toContainText('模型未加载');await trigger(page).click();await expect(page.getByText('模型暂未加载，请重试')).toBeVisible();
 state.fail=false;await page.getByRole('button',{name:'重新加载模型'}).click();await expect(sheet(page).getByRole('button',{name:/DeepSeek Flash/})).toHaveAttribute('aria-pressed','true');
 await sheet(page).getByRole('button',{name:/DeepSeek V4 Pro/}).click();await expect(page.getByRole('textbox',{name:'输入问题'})).toHaveValue('保留草稿');
 state.models=[models[0]];await page.reload();await expect(trigger(page)).toContainText('DeepSeek Flash');
});
test('image history prevents unsupported model selection',async({page})=>{
 await setup(page,{image:true});await page.goto('/c/ai');await expect(page.getByText('图片问题')).toBeVisible();
 await trigger(page).click();
 await expect(sheet(page).getByRole('button',{name:/DeepSeek V4 Pro/})).toBeDisabled();
 await expect(sheet(page).getByText('本次含图片，暂不可选')).toBeVisible();
 await page.keyboard.press('Escape');await expect(sheet(page)).toHaveCount(0);await expect(trigger(page)).toBeFocused();await expect(trigger(page)).toContainText('DeepSeek Flash');
});
test('guest never requests protected model catalog',async({page})=>{
 const state=await setup(page,{guest:true});await page.goto('/c/ai');await expect(trigger(page)).toHaveCount(0);expect(state.calls.some(p=>p.endsWith('/ai/models'))).toBeFalsy();
});

test('dismissal preserves draft and model, backdrop sits above navigation',async({page})=>{
 await setup(page);await page.goto('/c/ai');await expect(trigger(page)).toContainText('DeepSeek Flash');
 await page.getByRole('textbox',{name:'输入问题'}).fill('不应丢失的问题');await trigger(page).click();
 await page.keyboard.press('Escape');await expect(trigger(page)).toBeFocused();
 await trigger(page).click();await page.mouse.click(8,80);await expect(sheet(page)).toHaveCount(0);
 await expect(trigger(page)).toContainText('DeepSeek Flash');await expect(page.getByRole('textbox',{name:'输入问题'})).toHaveValue('不应丢失的问题');
});
test('short narrow viewport supports a long model list and reduced motion',async({page})=>{
 await page.setViewportSize({width:320,height:520});await page.emulateMedia({reducedMotion:'reduce'});
 const state=await setup(page);state.models=Array.from({length:12},(_,i)=>({...models[0],id:'custom-'+i,name:'兼容模型 '+i+' — 较长模型名称示例'}));
 await page.goto('/c/ai');await trigger(page).click();await expect(sheet(page)).toBeVisible();
 expect(await sheet(page).evaluate(el=>getComputedStyle(el).animationName)).toBe('none');
 const bounds=await sheet(page).boundingBox();expect(bounds!.y).toBeGreaterThanOrEqual(0);expect(bounds!.y+bounds!.height).toBeLessThanOrEqual(521);
 await sheet(page).getByRole('button',{name:/兼容模型 11/}).click();await expect(sheet(page)).toHaveCount(0);await expect(trigger(page)).toContainText('兼容模型 11');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
});
