export const beliefOptions = [
  { code: 'han_buddhism', name: '汉传佛教' },
  { code: 'tibetan_buddhism', name: '藏传佛教' },
  { code: 'theravada_buddhism', name: '南传佛教' },
  { code: 'daoism', name: '道教' },
  { code: 'folk', name: '民间信仰' }
] as const

export interface AffiliationTag {
  code: string
  group: string
  beliefCode?: string
  name: string
  status: string
}

export const normalizeBelief = (code: string) => code === 'taoism' ? 'daoism' : code
export const beliefLabel = (code: string) => beliefOptions.find(item => item.code === normalizeBelief(code))?.name || code || '未设置'

export function affiliationProblem(belief: string, codes: string[], tags: AffiliationTag[], required = true): string {
  const parent = normalizeBelief(belief)
  if (!beliefOptions.some(item => item.code === parent)) return '请选择主信仰'
  if (required && !codes.length) return '请至少选择一个标准宗派或信俗'
  if (codes.length > 12 || new Set(codes).size !== codes.length) return '宗派或信俗最多选择12项，不能重复'
  for (const code of codes) {
    const tag = tags.find(item => item.code === code && item.group === 'tradition')
    if (!tag || tag.status !== 'enabled') return '所选宗派或信俗已停用或不存在，请核对选择'
    if (normalizeBelief(tag.beliefCode || '') !== parent) return '所选宗派或信俗与主信仰不一致，请明确核对后调整'
  }
  return ''
}
