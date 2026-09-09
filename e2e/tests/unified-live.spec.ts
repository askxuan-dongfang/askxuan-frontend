import {test,expect} from '@playwright/test'

test('ECS legacy entry and all client login pages render',async({page})=>{
 for(const path of ['/admin/login','/shop/login','/temple/login','/c/login','/m/login']){
  const response=await page.goto(path);expect(response?.ok()).toBeTruthy()
  await expect(page.getByRole('button',{name:/登\s*录/}).first()).toBeVisible()
  if(path==='/shop/login')await expect(page).toHaveURL(/\/admin\/login$/)
 }
 await page.goto('/shop/orders/999999?page=2');await expect(page).toHaveURL(/\/admin\/login\?redirect=/)
 expect(new URL(page.url()).searchParams.get('redirect')).toBe('/commerce/orders/999999?page=2')
})

test('ECS real platform login and unified operations load with real read-only APIs',async({page})=>{
 const account=process.env.E2E_PLATFORM_ACCOUNT,password=process.env.E2E_PLATFORM_PASSWORD
 if(!account||!password)throw new Error('Explicit verification credentials required')
 const errors:string[]=[],failed:string[]=[]
 page.on('pageerror',e=>errors.push(e.message))
 page.on('response',async r=>{if(!r.url().includes('/api/v1/'))return;try{const body=await r.json();if(!r.ok()||body.code!==undefined&&body.code!==0)failed.push(new URL(r.url()).pathname+':'+body.code)}catch{failed.push(new URL(r.url()).pathname+':non-json')}})
 await page.goto('/admin/login');await page.getByPlaceholder('管理员账号').fill(account);await page.getByPlaceholder('登录密码').fill(password);await page.getByRole('button',{name:/登\s*录/}).click();await expect(page).toHaveURL(/\/admin\/dashboard$/)
 for(const path of ['/commerce','/commerce/dashboard','/commerce/products','/commerce/categories','/commerce/materials','/commerce/services','/commerce/orders','/commerce/diy-orders','/commerce/logistics','/commerce/returns','/commerce/reports','/commerce/points-mall','/marketing/rewards','/marketing/banner','/marketing/activity','/marketing/coupon','/temple/list','/master/list','/user/list','/finance/overview','/settings/account','/settings/role','/settings/dict','/settings/log','/settings/backup']){
  await page.goto('/admin'+path);await expect(page.locator('.ax-admin-header__title')).not.toBeEmpty();await page.waitForLoadState('networkidle')
  await expect(page.locator('.ax-admin-main')).not.toBeEmpty()
 }
 expect(errors).toEqual([]);expect(failed).toEqual([])
 await page.setViewportSize({width:390,height:844});await page.goto('/admin/marketing/rewards');await page.waitForLoadState('networkidle')
 await page.getByRole('button',{name:'切换主导航'}).click();await expect.poll(async()=>(await page.locator('.ax-admin-sidebar').boundingBox())?.x??-999).toBeGreaterThanOrEqual(-1);await expect(page.getByText('统一运营管理台').first()).toBeInViewport()
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1)).toBeTruthy()
 await page.screenshot({path:'/private/tmp/askxuan-unified-live-mobile.png',fullPage:true,animations:'disabled'})
})

test('ECS H5 real customer sees activity center and corrected header actions',async({page,request})=>{
 const phone=process.env.E2E_CUSTOMER_PHONE,password=process.env.E2E_CUSTOMER_PASSWORD
 if(!phone||!password)throw new Error('Explicit customer verification credentials required')
 const response=await request.post('/api/v1/auth/login',{data:{phone,password}}),body=await response.json()
 expect(body.code).toBe(0)
 await page.addInitScript(data=>{localStorage.setItem('h5_token',data.accessToken);localStorage.setItem('h5-auth',JSON.stringify({state:{role:'customer',token:data.accessToken,userId:data.userInfo?.userId||1,displayName:data.userInfo?.nickname||'验收'},version:0}))},body.data)
 for(const path of ['/c','/c/points','/c/rewards','/c/profile']){
  await page.goto(path);await page.waitForLoadState('networkidle')
  await expect(page.locator('header').getByRole('button',{name:/退出/})).toHaveCount(0)
  await expect(page.locator('header').getByRole('link',{name:'搜索',exact:true})).toHaveCount(path==='/c'?1:0)
  if(path==='/c/rewards')await expect(page.getByText('免费活动',{exact:true}).first()).toBeVisible()
 }
 await expect(page.getByRole('button',{name:'退出登录',exact:true})).toBeVisible()
})
