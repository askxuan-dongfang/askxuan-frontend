import assert from 'node:assert/strict'
import {readFile} from 'node:fs/promises'
import {stripTypeScriptTypes} from 'node:module'
import test from 'node:test'
const source=stripTypeScriptTypes(await readFile(new URL('./affiliation.ts',import.meta.url),'utf8'))
const {beliefOptions,normalizeBelief,affiliationProblem}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'))
const tag=(code,beliefCode,status='enabled')=>({code,beliefCode,status,group:'tradition',name:code})
const tags=[tag('chan','han_buddhism'),tag('forest','theravada_buddhism'),tag('quanzhen','daoism'),tag('old','han_buddhism','disabled'),{...tag('position','han_buddhism'),group:'position'}]
test('five fixed beliefs include Theravada and canonicalize the legacy Taoism spelling',()=>{
 assert.deepEqual(beliefOptions.map(item=>item.code),['han_buddhism','tibetan_buddhism','theravada_buddhism','daoism','folk'])
 assert.equal(normalizeBelief('taoism'),'daoism')
 assert.equal(affiliationProblem('taoism',['quanzhen'],tags),'')
 assert.equal(affiliationProblem('theravada_buddhism',['forest'],tags),'')
})
test('draft may be empty but submitting needs enabled same-parent tradition codes',()=>{
 assert.equal(affiliationProblem('han_buddhism',[],tags,false),'')
 assert.ok(affiliationProblem('han_buddhism',[],tags,true))
 for(const codes of [['old'],['unknown'],['position'],['quanzhen'],['chan','chan']])assert.ok(affiliationProblem('han_buddhism',codes,tags))
 assert.ok(affiliationProblem('sixth',['chan'],tags))
})
test('validation preserves legacy selections and rejects more than twelve codes',()=>{
 const history=['chan','old','quanzhen'];const original=[...history]
 assert.ok(affiliationProblem('han_buddhism',history,tags))
 assert.deepEqual(history,original)
 const catalog=Array.from({length:13},(_,i)=>tag('tag'+i,'folk'))
 assert.equal(affiliationProblem('folk',catalog.slice(0,12).map(t=>t.code),catalog),'')
 assert.ok(affiliationProblem('folk',catalog.map(t=>t.code),catalog))
})
