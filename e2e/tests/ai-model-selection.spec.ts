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
for(const width of [375,768])test(`model selection persists and request uses chosen model ${width}`,async({page})=>{
 await page.setViewportSize({width,height:900});const state=await setup(page);await page.goto('/c/ai');
 const picker=page.getByRole('combobox',{name:'选择 AI 模型'});
 await expect(picker).toHaveValue('deepseek-flash');await picker.selectOption('deepseek-v4-pro');
 await page.reload();await expect(picker).toHaveValue('deepseek-v4-pro');
 await page.getByRole('textbox',{name:'输入问题'}).fill('隔离问题');await page.getByRole('button',{name:'发送',exact:true}).click();
 await expect.poll(()=>state.sent.length).toBe(1);expect(state.sent[0].model).toBe('deepseek-v4-pro');
 await expect(page.getByText('隔离模型回答')).toBeVisible();
 await expect(picker).toBeEnabled();await picker.selectOption('deepseek-flash');
 await page.getByRole('textbox',{name:'输入问题'}).fill('后续问题');await page.getByRole('button',{name:'发送',exact:true}).click();
 await expect.poll(()=>state.sent.length).toBe(2);expect(state.sent[1].model).toBe('deepseek-flash');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBeTruthy();
 await page.screenshot({path:`artifacts/ai-models/selection-${width}.png`,fullPage:true});
});
test('model list error is retryable and removed preference is replaced',async({page})=>{
 const state=await setup(page,{fail:true});await page.goto('/c/ai');await page.getByRole('textbox',{name:'输入问题'}).fill('保留草稿');
 await expect(page.getByRole('button',{name:'发送',exact:true})).toBeDisabled();await expect(page.getByText('模型暂未加载，请重试')).toBeVisible();
 state.fail=false;await page.getByRole('button',{name:'重新加载模型'}).click();await expect(page.getByRole('combobox')).toHaveValue('deepseek-flash');
 await page.getByRole('combobox').selectOption('deepseek-v4-pro');state.models=[models[0]];await page.reload();await expect(page.getByRole('combobox')).toHaveValue('deepseek-flash');
});
test('image history prevents unsupported model selection',async({page})=>{
 await setup(page,{image:true});await page.goto('/c/ai');await expect(page.getByText('图片问题')).toBeVisible();
 await expect(page.locator('option[value="deepseek-v4-pro"]')).toHaveJSProperty('disabled',true);await page.getByRole('combobox').focus();await page.keyboard.press('ArrowDown');await page.keyboard.press('Enter');await expect(page.getByRole('combobox')).toHaveValue('deepseek-flash');
});
test('guest never requests protected model catalog',async({page})=>{
 const state=await setup(page,{guest:true});await page.goto('/c/ai');await expect(page.getByRole('combobox')).toHaveCount(0);expect(state.calls.some(p=>p.endsWith('/ai/models'))).toBeFalsy();
});
