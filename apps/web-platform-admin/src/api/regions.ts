import client from './client'
export interface RegionTag { code: string; name: string; sort: number; status: 'enabled'|'disabled' }
export const getRegions=()=>client.get<{list:RegionTag[]}>('/admin/platform/regions')
export const saveRegion=(data:RegionTag,create:boolean)=>create?client.post('/admin/platform/regions',data):client.put(`/admin/platform/regions/${data.code}`,data)
export const assignRegion=(kind:'temple'|'master',id:string,regionCode:string)=>client.put(`/admin/platform/regions/providers/${kind}/${id}`,{regionCode})

export const getPublicRegions=()=>client.get<{list:RegionTag[]}>('/regions')
