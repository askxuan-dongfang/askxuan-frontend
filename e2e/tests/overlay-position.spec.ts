import { test, expect } from '@playwright/test'

for (const width of [390, 1440]) {
 test(`temple administrator uses one workspace without staff management at ${width}px`, async ({page}) => {
  await page.setViewportSize({width,height:900})
  await page.addInitScript(() => {
   const token='e30.'+btoa(JSON.stringify({userId:9901,roles:['temple_admin'],clientId:'temple-admin',exp:Math.floor(Date.now()/1000)+3600}))+'.fixture'
   localStorage.setItem('df_temple_admin_token',token)
   localStorage.setItem('df_temple_admin_user',JSON.stringify({userId:9901,templeId:'TEST',templeName:'本地测试寺院'}))
  })
  const staffRequests:string[]=[]
  page.on('request',request=>{if(request.url().includes('/auth/temple/team'))staffRequests.push(request.url())})
  await page.route('**/api/v1/admin/temples/masters?**', route=>route.fulfill({json:{code:0,data:{list:[{id:'MASTER_TEST',dharmaName:'测试法师'}],total:1}}}))
  await page.goto('http://127.0.0.1:5388/temple/team')
  await expect(page).toHaveURL(/\/temple\/settings$/)
  await expect(page.locator('main')).toContainText('机构与账号')
  await expect(page.locator('body')).not.toContainText('岗位与成员')
  await expect(page.locator('body')).not.toContainText('管理岗位与成员')
  await page.goto('http://127.0.0.1:5388/temple/schedules')
  await expect(page.getByRole('button',{name:'保存排班',exact:true})).toBeVisible()
  await page.goto('http://127.0.0.1:5388/temple/masters/accounts')
  await expect(page.locator('main')).toContainText('账号分配')
  expect(staffRequests).toEqual([])
 })
}

for (const role of ['temple_reception','temple_operations','temple_finance']) {
 test(`retired temple role ${role} cannot enter the administrator workspace`, async ({page}) => {
  await page.addInitScript(role => {
   const token='e30.'+btoa(JSON.stringify({userId:9901,roles:[role],clientId:'temple-admin',exp:Math.floor(Date.now()/1000)+3600}))+'.fixture'
   localStorage.setItem('df_temple_admin_token',token)
   localStorage.setItem('df_temple_admin_user',JSON.stringify({userId:9901,templeId:'TEST'}))
  },role)
  await page.route('**/api/v1/auth/access', route=>route.fulfill({json:{code:0,data:{templeCode:'TEST',templeName:'本地测试寺院',permissions:['temple.team.manage','temple.profile.read']}}}))
  await page.goto('http://127.0.0.1:5388/temple/settings')
  await expect(page).toHaveURL(/\/temple\/login/)
  await expect(page.locator('input[autocomplete="username"]')).toBeVisible()
  expect(await page.evaluate(()=>localStorage.getItem('df_temple_admin_token'))).toBeNull()
 })
}

// Static production bundles with isolated API fixtures; never submit a form.
for (const viewport of [{width:390,height:640},{width:768,height:900},{width:1440,height:900},{width:812,height:375}]) {
 for (const target of [
  {app:'admin',path:'/marketing/coupon',button:'新建优惠券'},
  {app:'admin',path:'/settings/account',button:'新建账号'},
  {app:'temple',path:'/temple-gallery',button:'上传图片'},
 ]) test(`${target.app}${target.path} dialog stays visible ${viewport.width}x${viewport.height}`,async({page})=>{
  await page.setViewportSize(viewport)
  const key=target.app==='admin'?'platform':'temple'
  const token='e30.'+Buffer.from(JSON.stringify({userId:9901,roles:[key==='platform'?'platform_super':'temple_admin'],clientId:key+'-admin',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture'
  await page.addInitScript(({key,token})=>{
   localStorage.setItem(`df_${key}_admin_token`,token)
   localStorage.setItem(`df_${key}_admin_user`,JSON.stringify({userId:9901,roles:[key==='platform'?'platform_super':'temple_admin'],templeId:'TEST',templeName:'本地测试寺院'}))
   localStorage.setItem('df_temple_admin_temple_id','TEST')
  },{key,token})
  await page.goto(`http://127.0.0.1:5388/${target.app}${target.path}`)
  await page.getByRole('button',{name:target.button,exact:true}).click()
  const dialog=page.locator('.el-dialog:visible')
  await expect(dialog).toBeVisible()
  await expect.poll(async()=>{
   const r=(await dialog.boundingBox())!
   return Math.abs(r.x+r.width/2-viewport.width/2)
  }).toBeLessThan(2)
  const r=(await dialog.boundingBox())!
  expect(r.y).toBeGreaterThanOrEqual(0)
  expect(r.y+r.height).toBeLessThanOrEqual(viewport.height+1)
  expect(Math.abs(r.y+r.height/2-viewport.height/2)).toBeLessThan(2)
  const close=dialog.locator('.el-dialog__headerbtn')
  await expect(close).toBeInViewport()
  await expect(dialog.locator('.el-dialog__footer')).toBeInViewport()
  const footerButtons = await dialog.locator('.el-dialog__footer .el-button').evaluateAll(buttons =>
    buttons.map(button => { const r = button.getBoundingClientRect(); return {top:r.top,height:r.height} })
  )
  // Adjacent actions must share a baseline; sibling margins once shifted the
  // second action down by 6px on phones even when both fit on one row.
  if (footerButtons.length === 2) {
    expect(Math.abs(footerButtons[0].top - footerButtons[1].top)).toBeLessThan(1)
    expect(Math.abs(footerButtons[0].height - footerButtons[1].height)).toBeLessThan(1)
  }
  expect(await dialog.evaluate(e=>e.closest('.el-overlay')?.parentElement===document.body)).toBe(true)
  await close.click()
  await expect(dialog).not.toBeVisible()
 })
}

for (const width of [390, 1440]) {
 test(`admin pages share heading and control geometry at ${width}px`, async ({page}) => {
  await page.setViewportSize({width,height:900})
  await page.addInitScript(() => {
   for (const [key,role] of [['platform','platform_super'],['temple','temple_admin']]) {
    const token='e30.'+btoa(JSON.stringify({userId:9901,roles:[role],clientId:key+'-admin',exp:Math.floor(Date.now()/1000)+3600}))+'.fixture'
    localStorage.setItem(`df_${key}_admin_token`,token)
    localStorage.setItem(`df_${key}_admin_user`,JSON.stringify({userId:9901,templeId:'TEST',templeName:'本地测试寺院'}))
   }
   localStorage.setItem('df_temple_admin_temple_id','TEST')
  })
  for (const path of ['/admin/settings/service-intentions','/admin/onboarding/review','/admin/commerce/points-mall','/temple/masters/accounts','/temple/services']) {
   await page.goto(`http://127.0.0.1:5388${path}`)
   await expect(page.locator('main .aui-page-header')).toBeVisible()
   const geometry = await page.evaluate(() => {
    const main=document.querySelector('main')!.getBoundingClientRect()
    const heading=document.querySelector('main .aui-page-header')!.getBoundingClientRect()
    const controls=[...document.querySelectorAll('.filter-bar > .el-select,.filter-bar > .el-input,.filter-bar > .el-button,.aui-page-header__actions > .el-button')]
      .map(e=>e.getBoundingClientRect().height).filter(Boolean)
    const fixedCells=[...document.querySelectorAll('.el-table-fixed-column--left,.el-table-fixed-column--right')].map(e=>getComputedStyle(e).position)
    return {left:heading.left-main.left,controls,fixedCells,overflow:document.documentElement.scrollWidth-document.documentElement.clientWidth}
   })
   expect(Math.abs(geometry.left-(width<768?12:24)),path).toBeLessThan(1)
   expect(geometry.overflow,path).toBeLessThanOrEqual(1)
   for (const height of geometry.controls) expect(Math.abs(height-(width<768?40:36)),path).toBeLessThan(1)
   if (width<768) for (const position of geometry.fixedCells) expect(position,path).toBe('static')
  }
 })
}
