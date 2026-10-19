import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const ts=createRequire(new URL('../../apps/web-platform-admin/package.json',import.meta.url))('typescript');
const compiled=ts.transpileModule(fs.readFileSync(new URL('foreground.ts',import.meta.url),'utf8'),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ES2022}}).outputText;
const {foregroundRefresh}=await import('data:text/javascript;base64,'+Buffer.from(compiled).toString('base64'));
const flush=()=>new Promise(resolve=>setImmediate(resolve));
function environment(){
 const window=new EventTarget(),document=new EventTarget();document.visibilityState='visible';const navigator={onLine:true};
 const timers=new Map();let next=0;window.setInterval=(fn,ms)=>{assert.equal(ms,15000);timers.set(++next,fn);return next};window.clearInterval=id=>timers.delete(id);
 Object.defineProperty(globalThis,'window',{value:window,configurable:true});Object.defineProperty(globalThis,'document',{value:document,configurable:true});Object.defineProperty(globalThis,'navigator',{value:navigator,configurable:true});
 return {window,document,navigator,timers,tick:()=>[...timers.values()].forEach(fn=>fn())};
}
test('a slow refresh cannot overlap timer, focus or mutation requests',async()=>{
 const env=environment();let calls=0,resolve;const stop=foregroundRefresh(async()=>{calls++;await new Promise(r=>resolve=r)});
 env.tick();env.window.dispatchEvent(new Event('focus'));env.window.dispatchEvent(new Event('askxuan:growth-changed'));assert.equal(calls,1);
 resolve();await flush();env.tick();assert.equal(calls,2);resolve();stop();await flush();
});
test('background and offline views pause, returning online refreshes immediately',async()=>{
 const env=environment();env.document.visibilityState='hidden';let calls=0;const stop=foregroundRefresh(async()=>{calls++});env.tick();assert.equal(calls,0);
 env.document.visibilityState='visible';env.navigator.onLine=false;env.document.dispatchEvent(new Event('visibilitychange'));assert.equal(calls,0);
 env.navigator.onLine=true;env.window.dispatchEvent(new Event('online'));await flush();assert.equal(calls,1);stop();
});
test('unmount invalidates in-flight results and removes every source of refresh',async()=>{
 const env=environment();let resolve,calls=0,committed=0;const stop=foregroundRefresh(async current=>{calls++;await new Promise(r=>resolve=r);if(current())committed++});stop();resolve();await flush();
 assert.equal(committed,0);assert.equal(env.timers.size,0);env.tick();env.window.dispatchEvent(new Event('online'));env.document.dispatchEvent(new Event('visibilitychange'));assert.equal(calls,1);
});
test('a rejected request recovers on the next foreground interval',async()=>{
 const env=environment();let calls=0;const stop=foregroundRefresh(async()=>{calls++;if(calls===1)throw Error('temporary failure')});await flush();env.tick();await flush();assert.equal(calls,2);stop();
});
