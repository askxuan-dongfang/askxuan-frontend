import client from './client'
export interface DirectoryTag { beliefCode?:string; code:string; group:'tradition'|'position'|'specialty'; name:string; value:string; sort:number; status:'enabled'|'disabled' }
const base='/admin/platform/beliefs/directory-tags'
export const getDirectoryTags=()=>client.get<{list:DirectoryTag[]}>(base)
export const getPublicDirectoryTags=()=>client.get<{list:DirectoryTag[]}>('/beliefs/directory-tags')
export const saveDirectoryTag=(data:DirectoryTag,create:boolean)=>create?client.post(base,data):client.put(`${base}/${data.code}`,data)
export const getProviderTags=(kind:'temple'|'master',id:string)=>client.get<{codes:string[]}>(`${base}/providers/${kind}/${id}`)
export const assignProviderTags=(kind:'temple'|'master',id:string,codes:string[])=>client.put(`${base}/providers/${kind}/${id}`,{codes})
