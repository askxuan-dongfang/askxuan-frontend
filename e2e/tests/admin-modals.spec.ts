import { test, expect } from '@playwright/test'

for (const width of [390, 768, 1440]) for (const app of ['shop', 'admin', 'temple']) {
 test(`${app} modal and date panel ${width}`, async ({page}) => {
  const height=width===390?640:900
  await page.setViewportSize({width,height})
  const role=app==='admin'?'platform_super':`${app}_admin`
  const key=app==='admin'?'platform':app
  const token='e30.'+Buffer.from(JSON.stringify({userId:9901,roles:[role],clientId:`${key}-admin`,exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')+'.fixture'
  await page.addInitScript(({key,token})=>{
   localStorage.setItem(`df_${key}_admin_token`,token)
   localStorage.setItem(`df_${key}_admin_user`,JSON.stringify({userId:9901,nickname:'本地验收账号',templeId:'TEST',templeName:'本地测试寺院'}))
   localStorage.setItem('df_temple_admin_temple_id','TEST')
  },{key,token})
  let writes=0
  page.on('request',r=>{if(['POST','PUT','DELETE','PATCH'].includes(r.method())&&r.url().includes('/api/')) writes++})
  const root=`http://127.0.0.1:5388/${app}`
  await page.goto(root+(app==='shop'?'/categories':app==='admin'?'/marketing/coupon':'/temple-gallery'))
  await page.getByRole('button',{name:app==='shop'?'删除':app==='admin'?'禁用':'删除图片',exact:true}).first().click()
  const box=page.locator('.el-message-box')
  await expect(box).toBeVisible()
  const bounds=await box.boundingBox();expect(bounds).not.toBeNull()
  expect(bounds!.width).toBeLessThanOrEqual(421)
  expect(bounds!.x).toBeGreaterThanOrEqual(0)
  expect(Math.abs(bounds!.x+bounds!.width/2-width/2)).toBeLessThan(3)
  expect(await box.evaluate(n=>getComputedStyle(n).backgroundColor)).not.toBe('rgba(0, 0, 0, 0)')
  await box.getByRole('button',{name:'取消',exact:true}).click()
  await expect(box).not.toBeVisible();expect(writes).toBe(0)
  if(app==='admin') {
   await page.getByRole('button',{name:'新建优惠券',exact:true}).click()
   await page.getByRole('combobox',{name:'有效期',exact:true}).click()
  } else {
   await page.goto(root+(app==='shop'?'/reports':'/report'))
   await page.getByPlaceholder('开始日期',{exact:true}).click()
  }
  const panel=page.locator('.el-date-range-picker:visible')
  await expect(panel).toBeVisible()
  const rect=await panel.boundingBox();expect(rect).not.toBeNull()
  expect(rect!.x).toBeGreaterThanOrEqual(-1)
  expect(rect!.x+rect!.width).toBeLessThanOrEqual(width+1)
  expect(rect!.height).toBeLessThanOrEqual(height)
  expect(rect!.y).toBeGreaterThanOrEqual(-1)
  expect(rect!.y+rect!.height).toBeLessThanOrEqual(height+1)
  // Both calendars remain available; a narrow viewport scrolls rather than clipping one away.
  await expect(panel.locator('.el-date-table')).toHaveCount(2)
  const right=panel.locator('.el-date-range-picker__content.is-right')
  await right.scrollIntoViewIfNeeded()
  const rightBounds=await right.boundingBox()
  expect(rightBounds!.x+rightBounds!.width).toBeLessThanOrEqual(width+1)
  await panel.screenshot({path:`/private/tmp/askxuan-modal-${app}-${width}.png`})
  await page.keyboard.press('Escape')
  expect(writes).toBe(0)
 })
}
