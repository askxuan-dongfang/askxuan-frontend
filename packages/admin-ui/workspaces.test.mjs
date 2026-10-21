import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {createRequire} from 'node:module'
import test from 'node:test'
const require=createRequire(new URL('../../apps/web-platform-admin/package.json',import.meta.url))
const ts=require('typescript'),{createRouter,createMemoryHistory}=require('vue-router')
const read=path=>readFileSync(new URL(path,import.meta.url),'utf8')
function compile(source,bindings={}){
 const js=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText
 const exports={};new Function('exports','require',js)(exports,name=>bindings[name]??{});return exports
}
const {adminWorkspaces,activeWorkspacePath,workspaceForPath}=compile(read('./workspaces.ts'))
const {canAccessRoute,defaultRoute}=compile(read('../../apps/web-platform-admin/src/router/access.ts'))
const {agentCenterSections}=compile(read('../../apps/web-platform-admin/src/views/ai/centerNavigation.ts'))
const {agentCenterRoutes}=compile(read('../../apps/web-platform-admin/src/router/agentCenter.ts'),{'@/views/ai/centerNavigation':{agentCenterSections}})
const {commerceRoutes}=compile(read('../../apps/web-platform-admin/src/commerce/routes.ts'))
const routerSource=read('../../apps/web-platform-admin/src/router/index.ts')
const definitions=routerSource.slice(routerSource.indexOf('const routes:'),routerSource.indexOf('const router ='))
const js=ts.transpileModule(definitions,{compilerOptions:{target:ts.ScriptTarget.ES2020}}).outputText
const routes=new Function('commerceRoutes','agentCenterRoutes','defaultRoute','useAuthStore','Layout',js+'\nreturn routes')(commerceRoutes,agentCenterRoutes,defaultRoute,()=>({roles:['platform_super']}),{})
const router=createRouter({history:createMemoryHistory(),routes})
const visible=roles=>adminWorkspaces.flatMap(group=>group.children.filter(item=>!item.pending&&canAccessRoute(router.resolve(item.path),roles)).map(item=>item.path))
test('nine workspaces retain every existing navigation target and add no production route',()=>{
 assert.deepEqual(adminWorkspaces.map(g=>g.title),['工作台','机构与人员','服务与履约','商城与 DIY','审核与治理','财务与权益','内容与 AI','基础标准','系统与权限'])
 const targets=adminWorkspaces.flatMap(group=>group.children.filter(item=>!item.pending).map(item=>item.path))
 assert.equal(new Set(targets).size,targets.length)
 for(const path of targets)assert.equal(router.resolve(path).matched.at(-1)?.path,path,`Missing route ${path}`)
 const baseline=JSON.parse(read('../../scripts/platform-routes.json'))
 for(const path of baseline.filter(path=>!path.includes(':')&&!['/','/login','/settings/ai'].includes(path))) {
  if(['/ai','/ai/operations'].includes(path))continue
  assert.ok(workspaceForPath(path),`Unmapped existing platform route ${path}`)
 }
 assert.equal(adminWorkspaces.flatMap(g=>g.children).filter(i=>i.pending).length,1)
})
test('hidden details and all AI connections retain list breadcrumbs',()=>{
 for(const [path,list]of [['/master/create','/master/list'],['/master/detail/m1','/master/list'],['/temple/detail/t1','/temple/list'],['/user/detail/u1','/user/list'],['/commerce/materials/edit/m1','/commerce/materials'],['/commerce/diy-orders/d1','/commerce/diy-orders'],['/ai/connections/legacy','/ai/connections']]){
  assert.equal(activeWorkspacePath(path),list);assert.ok(workspaceForPath(path))
 }
})
test('navigation consults unchanged route roles: shop cannot acquire platform, AI, or rewards privileges',()=>{
 const shop=visible(['shop_admin']),service=visible(['platform_service']),superuser=visible(['platform_super'])
 assert.equal(defaultRoute(['shop_admin']),'/commerce/dashboard')
 assert.ok(shop.includes('/commerce/orders'));assert.ok(!shop.includes('/master/list'));assert.ok(!shop.includes('/ai/agent'));assert.ok(!shop.includes('/commerce/creator-rewards'))
 assert.ok(service.includes('/master/list'));assert.ok(!service.includes('/commerce/orders'));assert.ok(!service.includes('/onboarding/review'));assert.ok(!service.includes('/settings/directory-tags'))
 for(const path of ['/onboarding/review','/ai/agent','/commerce/creator-rewards','/settings/directory-tags'])assert.ok(superuser.includes(path))
})
