import fs from 'node:fs';import{fileURLToPath}from'node:url';import{execFileSync}from'node:child_process';import path from 'node:path';import {createRequire} from 'node:module';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const require=createRequire(root+'/apps/web-platform-admin/package.json');
const ts=require('typescript'),vue=require('@vue/compiler-dom');

const OpenCC=createRequire(root+'/packages/localization/package.json')('opencc-js');
const convert=OpenCC.Converter({from:'cn',to:'t'});
const host=path.resolve(execFileSync('xcode-select',['-p'],{encoding:'utf8'}).trim(),'Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host');
const toolchain=host;
const phrases=new Set(JSON.parse(execFileSync('xcrun',['swift','-I',toolchain,'-L',toolchain,'-lSwiftSyntax','-lSwiftParser',root+'/packages/localization/scripts/extract-native.swift',root],{encoding:'utf8',maxBuffer:8*1024*1024})));
const han=/[\u3400-\u9fff]/;
function add(s){if(s&&han.test(s)){phrases.add(s);if(s.trim())phrases.add(s.trim())}}
function walk(dir){for(const f of fs.readdirSync(dir,{withFileTypes:true})){if(['node_modules','.git','build','dist','Pods'].includes(f.name))continue;const p=path.join(dir,f.name);if(f.isDirectory())walk(p);else if(/\.(tsx?|vue)$/.test(f.name)&&!f.name.includes('.test.')){
 const s=fs.readFileSync(p,'utf8');let script=s;
 if(p.endsWith('.vue')){const start=s.indexOf('<template>')+10,end=s.lastIndexOf('</template>');if(start>=10&&end>start){const ast=vue.parse(s.slice(start,end));function scan(n){if(n.type===2)add(n.content.replace(/\s+/g,' '));if(n.type===6&&n.value)add(n.value.content);if(n.type===5)parse(n.content.content);if(n.type===7&&n.exp)parse(n.exp.content);for(const a of n.props||[])scan(a);for(const c of n.children||[])scan(c);}scan(ast);}script=[...s.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/g)].map(x=>x[1]).join('\n');}
 parse(script,p);
 }}}
function parse(s,p='file.ts'){const source=ts.createSourceFile(p,s,ts.ScriptTarget.Latest,true,p.endsWith('tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);function visit(n){if(ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n)||n.kind===ts.SyntaxKind.TemplateHead||n.kind===ts.SyntaxKind.TemplateMiddle||n.kind===ts.SyntaxKind.TemplateTail)add(n.text);if(ts.isJsxText(n))add(n.text.replace(/\s+/g,' '));ts.forEachChild(n,visit)}visit(source)}
for(const dir of ['apps/web-h5/src','apps/web-platform-admin/src','apps/web-temple-admin/src','packages/admin-ui','packages/domain-status'])walk(root+'/'+dir);
for(const s of ['语言','跟随系统','跟随系统时自动选择简体或繁体中文，其他系统语言使用简体中文。'])add(s);
const dictionary=Object.fromEntries([...phrases].sort().map(s=>[s,convert(s)]).filter(([a,b])=>a!==b));
// Product terms are reviewed explicitly; preserve established meaning across scripts.
Object.assign(dictionary,{'后台':'後台','运营后台':'運營後台','寺院后台':'寺院後台','问玄管理台':'問玄管理台','语言':'語言','跟随系统':'跟隨系統'});
const out=JSON.stringify(dictionary,null,2)+'\n';
fs.writeFileSync(root+'/packages/localization/zh-Hant.json',out);
for(const f of ['language.ts','zh-Hant.json'])fs.copyFileSync(root+'/packages/localization/'+f,root+'/apps/web-h5/src/i18n/'+f);
console.log({phrases:phrases.size,translations:Object.keys(dictionary).length,bytes:Buffer.byteLength(out)});
