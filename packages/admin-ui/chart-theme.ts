import tokens from '../design-tokens/tokens.json'

const colorVariables: Record<string, string> = {
  '#6a5a4a': '--admin-text-secondary', '#9a8a7a': '--admin-text-secondary',
  '#e8e0d8': '--admin-border', '#f0ebe5': '--admin-border', '#f0e9e1': '--admin-border',
  '#ffffff': '--admin-surface', '#fff': '--admin-surface', '#b5453a': '--admin-danger'
}
for (const palette of [tokens.color, tokens.themes.light.color]) {
  const groups: Record<string, Record<string, string>> = palette
  for (const group of ['state', 'text', 'bg', 'accent', 'brand']) {
    for (const [variant, color] of Object.entries(groups[group])) {
      if (!color.startsWith('#')) continue
      let variable = ''
      if (group === 'bg') variable = '--admin-surface'
      if (group === 'text') variable = variant === 'primary' ? '--admin-text' : '--admin-text-secondary'
      if (group === 'brand') variable = variant === 'light' ? '--admin-primary-hover' : '--admin-primary'
      if (group === 'accent') variable = '--admin-accent'
      if (group === 'state') variable = `--admin-${variant === 'error' ? 'danger' : variant}`
      if (variable) colorVariables[color.toLowerCase()] = variable
    }
  }
}
colorVariables['#2a1e1a'] = '--admin-surface'
colorVariables['#fff'] = colorVariables['#ffffff'] = '--admin-surface'

/** Repaint chart chrome and existing data colors without changing data or chart interaction state. */
export function withAdminChartTheme(option: Record<string, any>): Record<string, any> {
  const style = getComputedStyle(document.documentElement)
  const color = (variable: string) => style.getPropertyValue(variable).trim()
  const paintKeys = new Set(['color', 'backgroundColor', 'borderColor', 'shadowColor', 'areaColor'])
  const repaint = (value: any, property = ''): any => {
    if (typeof value === 'string') {
      if (!paintKeys.has(property)) return value;
      const variable = colorVariables[value.toLowerCase()]
      if (variable) return color(variable) || value
      const rgba = value.match(/^rgba\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([.\d]+)\)$/i)
      if (rgba) {
        const hex = '#' + rgba.slice(1, 4).map(c => Number(c).toString(16).padStart(2, '0')).join('')
        const target = colorVariables[hex]
        const replacement = target && color(target)
        if (replacement && /^#[\da-f]{6}$/i.test(replacement)) return `rgba(${[1, 3, 5].map(index => parseInt(replacement.slice(index, index + 2), 16)).join(',')},${rgba[4]})`
      }
      return value
    }
    if (Array.isArray(value)) return value.map(item => repaint(item, property))
    if (value && typeof value === 'object' && !(value instanceof Date)) return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, repaint(item, key)]))
    return value
  }
  const result = repaint(option)
  const text = color('--admin-text-secondary')
  const primaryText = color('--admin-text')
  const surface = color('--admin-surface')
  const border = color('--admin-border')
  const each = (value: any, update: (item: any) => any) => Array.isArray(value) ? value.map(update) : update(value)
  result.textStyle = { ...result.textStyle, color: primaryText }
  if (result.tooltip) result.tooltip = each(result.tooltip, item => ({ ...item, backgroundColor: surface, borderColor: border, textStyle: { ...item.textStyle, color: primaryText } }))
  if (result.legend) result.legend = each(result.legend, item => ({ ...item, textStyle: { ...item.textStyle, color: text }, pageTextStyle: { ...item.pageTextStyle, color: text } }))
  for (const name of ['xAxis', 'yAxis']) {
    if (!result[name]) continue
    result[name] = each(result[name], item => ({ ...item, axisLabel: { ...item.axisLabel, color: text }, nameTextStyle: { ...item.nameTextStyle, color: text }, axisLine: { ...item.axisLine, lineStyle: { ...item.axisLine?.lineStyle, color: border } }, splitLine: { ...item.splitLine, lineStyle: { ...item.splitLine?.lineStyle, color: border } } }))
  }
  return result
}
