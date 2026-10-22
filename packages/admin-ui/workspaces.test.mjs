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
const {adminWorkspaces,activeWorkspacePath,workspaceForPath,workspaceItemForPath}=compile(read('./workspaces.ts'))
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
test('task workspaces preserve existing targets and separate operations, finance and AI',()=>{
 assert.deepEqual(adminWorkspaces.map(g=>g.title),['工作台','机构与人员','服务与履约','商城与 DIY','审核与治理','财务中心','运营中心','AI 中心','基础标准','系统与权限'])
 const targets=adminWorkspaces.flatMap(group=>group.children.filter(item=>!item.pending).map(item=>item.path))
 assert.equal(new Set(targets).size,targets.length)
 for(const path of targets)assert.equal(router.resolve(path).matched.at(-1)?.path,path,`Missing route ${path}`)
 const baseline=JSON.parse(read('../../scripts/platform-routes.json'))
 for(const path of baseline.filter(path=>!path.includes(':')&&!['/','/login','/settings/ai'].includes(path))) {
  if(['/ai','/ai/operations'].includes(path))continue
  assert.ok(workspaceForPath(path),`Unmapped existing platform route ${path}`)
 }
 assert.equal(adminWorkspaces.flatMap(g=>g.children).filter(i=>i.pending).length,0)
 assert.equal(workspaceForPath('/marketing/home-display').title,'运营中心')
 assert.equal(workspaceForPath('/settings/taxonomy').title,'基础标准')
 assert.equal(workspaceForPath('/finance/reconcile').title,'财务中心')
 assert.equal(workspaceForPath('/services/overview').title,'服务与履约')
})
test('hidden details and all AI connections retain list breadcrumbs',()=>{
 for(const [path,list]of [['/settings/accounts/12','/settings/account'],['/master/create','/master/list'],['/master/detail/m1','/master/list'],['/temple/detail/t1','/temple/list'],['/user/detail/u1','/user/list'],['/commerce/materials/edit/m1','/commerce/materials'],['/commerce/diy-orders/d1','/commerce/diy-orders'],['/ai/connections/legacy','/ai/connections']]){
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

test('shell preserves commerce page titles independently of workspace menu labels',()=>{
 const {reactive,computed}=require('vue')
 const routeState=reactive({path:'/dashboard',meta:{title:'平台总览'}})
 const source=read('../../apps/web-platform-admin/src/layouts/DefaultLayout.vue').match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
 const shell=compile(source+'\nexport {pageTitle,pageParent};',{
  vue:{computed},
  'vue-router':{useRoute:()=>routeState,useRouter:()=>router},
  '../../../../packages/admin-ui/navigation':{useAdminNavigation:()=>({})},
  '../../../../packages/admin-ui/workspaces':{adminWorkspaces,activeWorkspacePath,workspaceForPath,workspaceItemForPath},
  '@/router/access':{canAccessRoute,defaultRoute},
  '@/stores/auth':{useAuthStore:()=>({roles:['platform_super'],userInfo:{}})}
 })
 for(const route of JSON.parse(read('../../scripts/commerce-routes.json'))){
  routeState.path=route.path.replace('/:id?','/1').replace('/:id','/1')
  routeState.meta={title:route.title}
  assert.equal(shell.pageTitle.value,route.title,route.path)
  assert.equal(shell.pageParent.value,workspaceForPath(routeState.path).title,route.path)
 }
})
