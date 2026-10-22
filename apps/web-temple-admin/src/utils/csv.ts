export function downloadCSV(filename: string, rows: (string | number)[][]) {
  const csv = '\uFEFF' + rows.map(row => row.map(cell => {
    let value = String(cell)
    if (/^[=+@\-\t\r]/.test(value)) value = "'" + value
    return '"' + value.replace(/"/g, '""') + '"'
  }).join(',')).join('\r\n')
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
  const a = document.createElement('a'); a.href = url; a.download = filename; a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
