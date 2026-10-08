import { test, expect } from '@playwright/test'

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
  expect(await dialog.evaluate(e=>e.closest('.el-overlay')?.parentElement===document.body)).toBe(true)
  await close.click()
  await expect(dialog).not.toBeVisible()
 })
}
