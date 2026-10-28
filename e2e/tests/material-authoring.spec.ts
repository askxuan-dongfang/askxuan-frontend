import { test, expect, type Page } from '@playwright/test'

const origin = 'http://127.0.0.1:5388'
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9ZQmcAAAAASUVORK5CYII=', 'base64')
// Two transformed meshes exercise actual GLTF loading without a paid generation call.
function modelGLB() {
  const positions = new Float32Array([-.5,-.5,-.5, .5,-.5,-.5, .5,.5,-.5, -.5,.5,-.5, -.5,-.5,.5, .5,-.5,.5, .5,.5,.5, -.5,.5,.5])
  const indices = new Uint16Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,2,3,7,2,7,6,0,4,7,0,7,3,1,2,6,1,6,5])
  const bin = Buffer.concat([Buffer.from(positions.buffer),Buffer.from(indices.buffer)])
  const doc = { asset:{version:'2.0'},scene:0,scenes:[{nodes:[0,1]}],nodes:[{mesh:0},{mesh:1,translation:[1.2,0,0]}],
    materials:[{pbrMetallicRoughness:{baseColorFactor:[.8,.15,.1,1]}},{pbrMetallicRoughness:{baseColorFactor:[.1,.3,.8,1]}}],
    meshes:[0,1].map(material=>({primitives:[{attributes:{POSITION:0},indices:1,material}]})),
    buffers:[{byteLength:bin.length}],bufferViews:[{buffer:0,byteOffset:0,byteLength:positions.byteLength},{buffer:0,byteOffset:positions.byteLength,byteLength:indices.byteLength}],
    accessors:[{bufferView:0,componentType:5126,count:8,type:'VEC3',min:[-.5,-.5,-.5],max:[.5,.5,.5]},{bufferView:1,componentType:5123,count:36,type:'SCALAR'}] }
  const json = Buffer.from(JSON.stringify(doc)), padding = (4-json.length%4)%4, jsonChunk = Buffer.concat([json,Buffer.alloc(padding,32)])
  const header = Buffer.alloc(20); header.writeUInt32LE(0x46546c67,0);header.writeUInt32LE(2,4);header.writeUInt32LE(28+jsonChunk.length+bin.length,8);header.writeUInt32LE(jsonChunk.length,12);header.writeUInt32LE(0x4e4f534a,16)
  const binHeader=Buffer.alloc(8);binHeader.writeUInt32LE(bin.length,0);binHeader.writeUInt32LE(0x004e4942,4)
  return Buffer.concat([header,jsonChunk,binHeader,bin])
}
async function fixture(page: Page, configured = false, canConfigure = true) {
  const token = 'e30.'+Buffer.from(JSON.stringify({userId:9901,roles:['platform_super'],clientId:'platform-admin',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture'
  await page.addInitScript(value=>{
    localStorage.setItem('df_platform_admin_token',value)
    localStorage.setItem('df_platform_admin_user',JSON.stringify({userId:9901,nickname:'材料验收'}))
  },token)
  await page.route('**/fixtures/photo.png',route=>route.fulfill({contentType:'image/png',body:png}))
  await page.route('**/fixtures/model.glb',route=>route.fulfill({contentType:'model/gltf-binary',body:modelGLB()}))
  await page.route('**/api/v1/**',async route=>{
    const path=new URL(route.request().url()).pathname
    const data=path.endsWith('/modeling/config')?{provider:'meshy',configured,hasApiKey:configured,canConfigure,model:'meshy-7.1'}:{id:77,list:[],total:0,roles:[],permissions:[]}
    await route.fulfill({json:{code:0,data}})
  })
  await page.setViewportSize({width:1280,height:960})
}
async function open(page: Page) {
  await page.goto(origin+'/admin/commerce/materials/edit')
  await expect(page.locator('[data-preview-ready=true]')).toBeVisible({timeout:15000})
  await page.getByRole('textbox',{name:/材料名称/}).fill('本地材料建模验收')
}
async function selectRadio(page: Page, name: string) {
  const radio=page.getByRole('radio',{name,exact:true});await radio.focus();await radio.press('Space');await expect(radio).toBeChecked()
}
async function confirm(page: Page) {
  await expect(page.locator('[data-preview-ready=true]')).toBeVisible({timeout:15000})
  const checkbox=page.getByRole('checkbox',{name:/已检查外观/});if(!await checkbox.isChecked()){await checkbox.focus();await checkbox.press('Space')}
  await expect(checkbox).toBeChecked()
}
test('shop page material authoring separates dynamics, picks a real mount and invalidates confirmation',async({page},testInfo)=>{
  test.setTimeout(90000)
  await fixture(page);await open(page)
  await expect(page.getByText('运动方式',{exact:true})).toHaveCount(0)
  await expect(page.getByRole('button',{name:'保存并发布',exact:true})).toBeDisabled()
  await selectRadio(page,'挂件连接')
  await expect(page.getByRole('radio',{name:'刚性摆动',exact:true})).toBeChecked()
  await expect(page.locator('[data-preview-ready=true]')).toBeVisible({timeout:15000})
  const mountZ=page.getByRole('spinbutton',{name:'挂点位置 Z',exact:true})
  const old=await mountZ.inputValue()
  await page.getByRole('button',{name:'点击模型选择挂点',exact:true}).click()
  const canvas=page.locator('.model-stage canvas');await canvas.scrollIntoViewIfNeeded();const box=(await canvas.boundingBox())!
  await page.mouse.click(box.x+box.width*.5,box.y+box.height*.5)
  await expect(mountZ).not.toHaveValue(old)
  await confirm(page)
  await page.getByRole('region',{name:'预览与挂点',exact:true}).screenshot({path:testInfo.outputPath('admin-model-mount.png')})
  await page.getByRole('spinbutton',{name:'宽度 X',exact:true}).fill('18')
  await page.getByRole('spinbutton',{name:'宽度 X',exact:true}).press('Tab')
  await expect(page.getByRole('checkbox',{name:/已检查外观/})).not.toBeChecked()
  await expect(page.getByRole('button',{name:'保存并发布',exact:true})).toBeDisabled()
  await confirm(page)
  const calls:{method:string;body:any;path:string}[]=[]
  await page.route('**/api/v1/admin/diy/materials**',async route=>{ calls.push({method:route.request().method(),body:route.request().method()==='GET'?undefined:route.request().postDataJSON(),path:new URL(route.request().url()).pathname});await route.fulfill({json:{code:0,data:{id:77,list:[],total:0}}}) })
  await page.getByRole('button',{name:'保存并发布',exact:true}).click();await expect(page).toHaveURL(origin+'/admin/commerce/materials')
  const saved=calls.find(v=>v.method==='POST')!;expect(JSON.parse(saved.body.renderAssets).studio).toMatchObject({part:'hanging',motion:'rigid',previewConfirmed:true,dimensionsMm:[18,2.9,11.45]})
  expect(calls.find(v=>v.path.endsWith('/status'))?.body).toEqual({status:'on_shelf'})
})
test('shop page material authoring unconfigured AI is explicit and a template saves as draft',async({page})=>{
  await fixture(page,false,false);await open(page)
  await selectRadio(page,'实拍生成 3D')
  await expect(page.getByText('图生 3D 服务尚未配置，可先复用形状模板。',{exact:true})).toBeVisible()
  await expect(page.getByRole('button',{name:'生成 3D 模型',exact:true})).toBeDisabled()
  await expect(page.getByRole('button',{name:'配置生成服务',exact:true})).toHaveCount(0)
  await selectRadio(page,'复用形状模板')
  let saved:any,statusWrites=0
  await page.route('**/api/v1/admin/diy/materials**',async route=>{if(route.request().method()==='POST')saved=route.request().postDataJSON();if(route.request().url().endsWith('/status'))statusWrites++;await route.fulfill({json:{code:0,data:{id:77,list:[],total:0}}})})
  await page.getByRole('button',{name:'保存草稿',exact:true}).click();await expect(page).toHaveURL(origin+'/admin/commerce/materials')
  expect(JSON.parse(saved.renderAssets).studio).toMatchObject({part:'bead',motion:'fixed',source:'template',previewConfirmed:false})
  expect(statusWrites).toBe(0)
})
test('shop page material categories survive connection and motion changes independently',async({page})=>{
  test.setTimeout(180000)
  await fixture(page)
  // Category persistence needs the real model, but not the optional HDR lighting
  // already covered by the model/publish scenarios above (expensive in SwiftShader).
  await page.route('**/studio-*.hdr',route=>route.abort())
  const saved:any[]=[]
  await page.route('**/api/v1/admin/diy/materials**',async route=>{
    const request=route.request()
    if(request.method()==='POST')saved.push(request.postDataJSON())
    expect(request.url()).not.toContain('/status')
    const list=[...saved.map((material,index)=>({...material,id:index+1,status:'off_shelf'})),
      {id:99,name:'测试绳线',category:'cord',spec:'根',unit:'根',unitPrice:1,stock:10,status:'off_shelf',image:'',renderAssets:JSON.stringify({studio:{part:'hanging',motion:'flexible'}})}]
    await route.fulfill({json:{code:0,data:request.method()==='POST'?{id:saved.length}:{list,total:list.length}}})
  })
  for(const [code,label] of [['spacer','隔珠'],['buddha_head','佛头'],['three_way','三通']]){
    await open(page)
    await page.getByRole('textbox',{name:/材料名称/}).fill('分类保留-'+label)
    const category=page.locator('.el-form-item').filter({has:page.getByText('材料分类',{exact:true})})
    await category.locator('.el-select__wrapper').click()
    await expect(page.getByRole('listbox').getByRole('option')).toHaveText(['主珠','隔珠','佛头','吊坠','流苏','三通','线绳'])
    const combo=category.getByRole('combobox')
    await combo.focus();await combo.press('Home')
    for(let index=0;index<['主珠','隔珠','佛头','吊坠','流苏','三通','线绳'].indexOf(label);index++)await combo.press('ArrowDown')
    await combo.press('Enter')
    await selectRadio(page,'挂件连接')
    await expect(category.getByText(label,{exact:true})).toBeVisible()
    await category.locator('.el-select__wrapper').click()
    await expect(page.getByRole('listbox').getByRole('option')).toHaveText(['主珠','隔珠','佛头','吊坠','流苏','三通','线绳'])
    await page.keyboard.press('Escape')
    await selectRadio(page,'柔性流苏')
    await expect(category.getByText(label,{exact:true})).toBeVisible()
    await selectRadio(page,'刚性摆动')
    await expect(category.getByText(label,{exact:true})).toBeVisible()
    await selectRadio(page,'穿绳串接')
    await expect(category.getByText(label,{exact:true})).toBeVisible()
    await expect(page.getByText('运动方式',{exact:true})).toHaveCount(0)
    await selectRadio(page,'挂件连接');await selectRadio(page,'柔性流苏')
    await expect(page.getByText('固定部分比例',{exact:true})).toBeVisible()
    await expect(page.locator('[data-preview-ready=true]')).toBeVisible({timeout:15000})
    await page.getByRole('button',{name:'保存草稿',exact:true}).click()
    await expect(page).toHaveURL(origin+'/admin/commerce/materials')
    expect(saved.at(-1).category).toBe(code)
    expect(JSON.parse(saved.at(-1).renderAssets).studio).toMatchObject({part:'hanging',motion:'flexible',templateId:'tassel',connectorMm:2})
    const row=page.getByRole('row').filter({hasText:'分类保留-'+label})
    await expect(row.getByRole('cell',{name:label,exact:true})).toBeVisible()
    await expect(row.getByRole('cell',{name:'挂件连接 · 柔性',exact:true})).toBeVisible()
  }
  const cord=page.getByRole('row').filter({hasText:'测试绳线'})
  await expect(cord.getByRole('cell',{name:'绳线',exact:true})).toBeVisible()
  await expect(cord).not.toContainText('挂件连接')
})
test('shop page material authoring uploads photos, polls a generated model and preserves its job on publish',async({page})=>{
  await fixture(page,true);await open(page)
  let submitted:any,polls=0,uploads=0,saved:any
  await page.route('**/api/v1/files/upload',async route=>{uploads++;await route.fulfill({json:{code:0,data:{url:'/fixtures/photo.png'}}})})
  await page.route('**/api/v1/admin/diy/modeling/tasks**',async route=>{
    if(route.request().method()==='POST'){submitted=route.request().postDataJSON();await route.fulfill({json:{code:0,data:{id:'job-1',status:'processing',progress:15}}});return}
    polls++;await route.fulfill({json:{code:0,data:{id:'job-1',status:'succeeded',progress:100,model:{jobId:'job-1',glbUrl:'/fixtures/model.glb',usdzUrl:'/fixtures/model.usdz'}}}})
  })
  await page.getByRole('region',{name:'实拍与尺寸',exact:true}).locator('input[type=file]').first().setInputFiles({name:'material.png',mimeType:'image/png',buffer:png})
  await expect(page.getByText('上传成功',{exact:true})).toBeVisible()
  await selectRadio(page,'实拍生成 3D')
  await page.getByRole('button',{name:'生成 3D 模型',exact:true}).click()
  await expect(page.getByText('模型已生成，请检查并确认预览。',{exact:true})).toBeVisible()
  await confirm(page)
  await page.route('**/api/v1/admin/diy/materials**',async route=>{if(route.request().method()==='POST')saved=route.request().postDataJSON();await route.fulfill({json:{code:0,data:{id:77,list:[],total:0}}})})
  await page.getByRole('button',{name:'保存并发布',exact:true}).click();await expect(page).toHaveURL(origin+'/admin/commerce/materials')
  expect(uploads).toBe(1);expect(polls).toBeGreaterThan(0);expect(submitted.photoUrls).toEqual(['/fixtures/photo.png'])
  expect(submitted.requestId).toMatch(/^[a-f0-9-]{36}$/)
  expect(JSON.parse(saved.renderAssets).studio).toMatchObject({source:'generated',templateId:'custom',previewConfirmed:true,model:{jobId:'job-1',glbUrl:'/fixtures/model.glb',usdzUrl:'/fixtures/model.usdz'}})
})
test('shop page material authoring does not replace failed generation with a template',async({page})=>{
  await fixture(page,true);await open(page)
  await page.getByRole('region',{name:'实拍与尺寸',exact:true}).getByPlaceholder('或粘贴图片 URL').first().fill('/fixtures/photo.png')
  await page.getByRole('region',{name:'实拍与尺寸',exact:true}).getByRole('button',{name:'填入',exact:true}).first().click()
  let attempts=0
  await page.route('**/api/v1/admin/diy/modeling/tasks',async route=>{attempts++;await route.fulfill({json:{code:0,data:{id:'failed-'+attempts,status:'failed',progress:0,errorMessage:'服务商未能处理此素材'}}})})
  await selectRadio(page,'实拍生成 3D');await page.getByRole('button',{name:'生成 3D 模型',exact:true}).click()
  await expect(page.getByText('服务商未能处理此素材',{exact:true})).toBeVisible();await expect(page.locator('[data-preview-ready=true]')).toHaveCount(0)
  await page.getByRole('spinbutton',{name:'宽度 X',exact:true}).fill('18');await page.getByRole('spinbutton',{name:'宽度 X',exact:true}).press('Tab')
  await expect(page.locator('[data-preview-ready=true]')).toHaveCount(0)
  await expect(page.getByRole('button',{name:'保存并发布',exact:true})).toBeDisabled()
  await page.getByRole('button',{name:'重新生成',exact:true}).click();await expect.poll(()=>attempts).toBe(2)
})
test('shop page material authoring config clears the secret when closed',async({page})=>{
  await fixture(page);await open(page)
  await selectRadio(page,'实拍生成 3D');await page.getByRole('button',{name:'配置生成服务',exact:true}).click()
  const dialog=page.getByRole('dialog',{name:'图生 3D 服务',exact:true});const key=dialog.getByLabel('API Key',{exact:true})
  await key.fill('fixture-secret-only');await expect(key).toHaveAttribute('type','password')
  await dialog.getByRole('button',{name:'取消',exact:true}).click();await expect(dialog).not.toBeVisible()
  await page.getByRole('button',{name:'配置生成服务',exact:true}).click();await expect(dialog.getByLabel('API Key',{exact:true})).toHaveValue('')
})
test('shop page material authoring remains usable at phone width',async({page},testInfo)=>{
  await fixture(page);await page.setViewportSize({width:390,height:844});await open(page)
  await expect(page.locator('canvas')).toHaveCount(1)
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy()
  await selectRadio(page,'挂件连接');await selectRadio(page,'柔性流苏')
  await expect(page.getByText('固定部分比例',{exact:true})).toBeVisible()
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy()
  await page.getByRole('region',{name:'预览与挂点',exact:true}).screenshot({path:testInfo.outputPath('admin-model-phone.png')})
})
