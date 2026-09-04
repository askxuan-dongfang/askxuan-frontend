#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { basename, dirname, extname, join, relative, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const frontendRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const backendRoot = resolve(process.argv[2] ?? join(frontendRoot, '..', 'askXuan-backend'))
const typescriptPath = join(frontendRoot, 'apps/web-h5/node_modules/typescript/lib/typescript.js')

if (!existsSync(typescriptPath)) {
  console.error(`TypeScript 运行时不存在: ${typescriptPath}`)
  console.error('请先在 apps/web-h5 安装依赖。')
  process.exit(2)
}
if (!existsSync(join(backendRoot, 'services'))) {
  console.error(`后端 services 目录不存在: ${backendRoot}`)
  process.exit(2)
}

const importedTypeScript = await import(pathToFileURL(typescriptPath).href)
const ts = importedTypeScript.default ?? importedTypeScript

const projects = [
  ['h5', join(frontendRoot, 'apps/web-h5/src/api')],
  ['platform', join(frontendRoot, 'apps/web-platform-admin/src/api')],
  ['shop', join(frontendRoot, 'apps/web-shop-admin/src/api')],
  ['temple', join(frontendRoot, 'apps/web-temple-admin/src/api')],
]

function walk(directory, predicate) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) return walk(path, predicate)
    return predicate(path) ? [path] : []
  })
}

function normalizePath(path) {
  const withoutQuery = path.split(/[?#]/, 1)[0]
  const withApiPrefix = withoutQuery.startsWith('/api/v1')
    ? withoutQuery
    : `/api/v1${withoutQuery}`
  const normalized = withApiPrefix
    .replace(/\/+/g, '/')
    .replace(/\/:([^/]+)/g, '/:param')
  return normalized.length > 1 ? normalized.replace(/\/$/, '') : normalized
}

function contract(method, path) {
  return `${method.toUpperCase()} ${normalizePath(path)}`
}

function sourceLocation(sourceFile, node) {
  const { line } = sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile))
  return `${relative(frontendRoot, sourceFile.fileName)}:${line + 1}`
}

function placeholderName(expression, sourceFile) {
  const raw = expression.getText(sourceFile)
  const identifiers = raw.match(/[A-Za-z_$][\w$]*/g)
  return identifiers?.at(-1)?.replace(/[^A-Za-z0-9_-]/g, '') || 'param'
}

function isApiBaseExpression(expression, sourceFile) {
  const text = expression.getText(sourceFile)
  return text === 'base' || text === 'API_BASE_URL'
}

function enclosingLiteralUnion(expression, call, sourceFile) {
  if (!ts.isIdentifier(expression)) return null
  let current = call.parent
  while (current && !ts.isFunctionLike(current)) current = current.parent
  if (!current) return null
  const parameter = current.parameters.find(
    (item) => ts.isIdentifier(item.name) && item.name.text === expression.text,
  )
  if (!parameter?.type || !ts.isUnionTypeNode(parameter.type)) return null
  const values = parameter.type.types.flatMap((item) =>
    ts.isLiteralTypeNode(item) && ts.isStringLiteralLike(item.literal)
      ? [item.literal.text]
      : [],
  )
  return values.length === parameter.type.types.length ? values : null
}

function renderPathExpressions(expression, sourceFile, call) {
  if (
    ts.isParenthesizedExpression(expression) ||
    ts.isAsExpression(expression) ||
    ts.isTypeAssertionExpression(expression) ||
    ts.isNonNullExpression(expression)
  ) {
    return renderPathExpressions(expression.expression, sourceFile, call)
  }

  if (ts.isStringLiteralLike(expression)) return [expression.text]

  if (ts.isTemplateExpression(expression)) {
    let values = [expression.head.text]
    for (const span of expression.templateSpans) {
      const replacements = isApiBaseExpression(span.expression, sourceFile)
        ? ['']
        : enclosingLiteralUnion(span.expression, call, sourceFile) ??
          [`:${placeholderName(span.expression, sourceFile)}`]
      values = values.flatMap((value) =>
        replacements.map((replacement) => `${value}${replacement}${span.literal.text}`),
      )
    }
    return values
  }

  if (ts.isBinaryExpression(expression) && expression.operatorToken.kind === ts.SyntaxKind.PlusToken) {
    const left = renderPathExpressions(expression.left, sourceFile, call) ??
      [`:${placeholderName(expression.left, sourceFile)}`]
    const right = renderPathExpressions(expression.right, sourceFile, call) ??
      [`:${placeholderName(expression.right, sourceFile)}`]
    return left.flatMap((leftValue) => right.map((rightValue) => `${leftValue}${rightValue}`))
  }

  if (isApiBaseExpression(expression, sourceFile)) return ['']
  if (ts.isIdentifier(expression) || ts.isPropertyAccessExpression(expression) || ts.isCallExpression(expression)) {
    return enclosingLiteralUnion(expression, call, sourceFile) ??
      [`:${placeholderName(expression, sourceFile)}`]
  }
  return null
}

function isThinUrlWrapper(call, method) {
  const argument = call.arguments[0]
  if (!argument || !ts.isIdentifier(argument) || argument.text !== 'url') return false
  let current = call.parent
  while (current && !ts.isFunctionLike(current)) current = current.parent
  if (!current?.name || !ts.isIdentifier(current.name)) return false
  const expected = method === 'DELETE' ? 'del' : method.toLowerCase()
  return current.name.text === expected
}

function axiosMethod(call, sourceFile) {
  const expression = call.expression
  if (ts.isIdentifier(expression)) {
    const name = expression.text.toLowerCase()
    if (['get', 'post', 'put', 'patch', 'del'].includes(name)) {
      return name === 'del' ? 'DELETE' : name.toUpperCase()
    }
    return null
  }
  if (!ts.isPropertyAccessExpression(expression)) return null
  const owner = expression.expression.getText(sourceFile)
  const name = expression.name.text.toLowerCase()
  if (!['client', 'axios', 'instance'].includes(owner)) return null
  if (!['get', 'post', 'put', 'patch', 'delete'].includes(name)) return null
  return name.toUpperCase()
}

function fetchMethod(call) {
  const options = call.arguments[1]
  if (!options || !ts.isObjectLiteralExpression(options)) return 'GET'
  for (const property of options.properties) {
    if (!ts.isPropertyAssignment(property) || property.name.getText().replace(/["']/g, '') !== 'method') continue
    return ts.isStringLiteralLike(property.initializer)
      ? property.initializer.text.toUpperCase()
      : null
  }
  return 'GET'
}

function frontendContracts() {
  const all = new Map()
  const unresolved = []
  const ignoredExternal = []
  const perProject = new Map()

  for (const [project, directory] of projects) {
    const projectContracts = new Set()
    const files = walk(directory, (path) => ['.ts', '.tsx'].includes(extname(path)) && !path.endsWith('.d.ts'))
    for (const file of files) {
      const source = readFileSync(file, 'utf8')
      const sourceFile = ts.createSourceFile(
        file,
        source,
        ts.ScriptTarget.Latest,
        true,
        extname(file) === '.tsx' ? ts.ScriptKind.TSX : ts.ScriptKind.TS,
      )

      function visit(node) {
        if (ts.isCallExpression(node)) {
          let method = axiosMethod(node, sourceFile)
          const isFetch = ts.isIdentifier(node.expression) && node.expression.text === 'fetch'
          if (isFetch) method = fetchMethod(node)
          if (method && node.arguments[0]) {
            const renderedPaths = renderPathExpressions(node.arguments[0], sourceFile, node)
            const location = sourceLocation(sourceFile, node)
            if (isThinUrlWrapper(node, method)) {
              // The concrete path is audited at each call to this local helper.
            } else if (renderedPaths?.every((item) => item.startsWith('/'))) {
              for (const rendered of renderedPaths) {
                const key = contract(method, rendered)
                projectContracts.add(key)
                const sources = all.get(key) ?? new Set()
                sources.add(`${project}:${location}`)
                all.set(key, sources)
              }
            } else if (isFetch && renderedPaths?.some((item) => item.includes('uploadUrl'))) {
              ignoredExternal.push(`${location} (${renderedPaths.join(' | ')})`)
            } else if (!(basename(file) === 'client.ts' && renderedPaths?.some((item) => item.startsWith(':url')))) {
              unresolved.push(`${location} (${method} ${renderedPaths?.join(' | ') ?? '<unknown>'})`)
            }
          }
        }
        ts.forEachChild(node, visit)
      }
      visit(sourceFile)
    }
    perProject.set(project, projectContracts)
  }

  return { all, ignoredExternal, perProject, unresolved }
}

function backendContracts() {
  const runtime = new Map()
  const routePattern = /Method:\s*http\.Method(Get|Post|Put|Delete|Patch)[\s\S]*?Path:\s*"([^"]+)"/g
  const routeFiles = walk(join(backendRoot, 'services'), (path) => basename(path) === 'routes.go')

  for (const file of routeFiles) {
    const source = readFileSync(file, 'utf8')
    const blocks = source.includes('rest.WithPrefix(')
      ? [...source.matchAll(/server\.AddRoutes\(([\s\S]*?)\n\t\)/g)].map((match) => match[1])
      : [source]
    for (const block of blocks) {
      const prefix = block.match(/rest\.WithPrefix\("([^"]+)"\)/)?.[1] ?? ''
      for (const match of block.matchAll(routePattern)) {
        const path = prefix && match[2] === '/' ? prefix : `${prefix}${match[2]}`
        runtime.set(contract(match[1], path), relative(backendRoot, file))
      }
    }
  }
  return runtime
}

const frontend = frontendContracts()
const backend = backendContracts()
const missing = [...frontend.all.keys()].filter((item) => !backend.has(item)).sort()

console.log(`后端运行时 HTTP 契约: ${backend.size}`)
for (const [project, contracts] of frontend.perProject) {
  console.log(`${project} 前端唯一调用契约: ${contracts.size}`)
}
console.log(`四个 Web 工程唯一调用契约: ${frontend.all.size}`)
console.log(`外部预签名上传调用（不参与后端路由比对）: ${frontend.ignoredExternal.length}`)
console.log(`无法静态解析的 API 调用: ${frontend.unresolved.length}`)
for (const item of frontend.unresolved) console.log(`- ${item}`)
console.log(`后端缺失或 HTTP 方法不一致: ${missing.length}`)
for (const item of missing) {
  console.log(`- ${item}`)
  for (const source of frontend.all.get(item) ?? []) console.log(`  - ${source}`)
}

process.exitCode = missing.length === 0 && frontend.unresolved.length === 0 ? 0 : 1
