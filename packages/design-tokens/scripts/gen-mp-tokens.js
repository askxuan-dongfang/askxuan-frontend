/* ================================================================
 * gen-mp-tokens.js
 * 读取 tokens.json，生成 uni.scss（SCSS 变量）与 tokens.js（JS 常量）
 * 仅依赖 Node 内置 fs / path 模块
 * ================================================================ */
const fs = require('fs');
const path = require('path');

const tokensPath = path.join(__dirname, '..', 'tokens.json');
const tokens = JSON.parse(fs.readFileSync(tokensPath, 'utf8'));

const outDir = path.join(__dirname, '..', 'dist', 'mp');
fs.mkdirSync(outDir, { recursive: true });

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function kebab(s) {
  return s.replace(/([A-Z])/g, '-$1').toLowerCase();
}

const color = tokens.color;

// ---- uni.scss ----
const scss = [];
scss.push('// ================================================================');
scss.push('//  问玄东方App - Mini Program Design Tokens (Auto-generated)');
scss.push('//  Source: packages/design-tokens/tokens.json');
scss.push('//  Do not edit manually; run `npm run gen:mp` to regenerate.');
scss.push('// ================================================================');
scss.push('');

Object.keys(color).forEach((group) => {
  scss.push(`// ${capitalize(group)}`);
  Object.keys(color[group]).forEach((variant) => {
    const val = color[group][variant];
    if (variant === 'default') {
      // default 变体使用短别名，与原 colors_and_type.css 命名一致
      scss.push(`$color-${group}: ${val};`);
    } else {
      scss.push(`$color-${group}-${variant}: ${val};`);
    }
  });
  scss.push('');
});

scss.push('// Fonts');
scss.push(`$font-serif: ${tokens.font.serif.map((f) => `'${f}'`).join(', ')}, serif;`);
scss.push(`$font-sans: ${tokens.font.sans.map((f) => `'${f}'`).join(', ')}, sans-serif;`);
scss.push('');

scss.push('// Radius');
Object.keys(tokens.radius).forEach((k) => {
  scss.push(`$radius-${k}: ${tokens.radius[k]}px;`);
});
scss.push('');

scss.push('// Spacing');
Object.keys(tokens.spacing).forEach((k) => {
  scss.push(`$spacing-${kebab(k)}: ${tokens.spacing[k]}px;`);
});
scss.push('');

const scssPath = path.join(outDir, 'uni.scss');
fs.writeFileSync(scssPath, scss.join('\n'));
console.log(`✓ Generated ${scssPath}`);

// ---- tokens.js ----
// 扁平化颜色键，便于按名取值，例如 tokens.flat.brand / tokens.flat['bg-primary']
const flat = {};
Object.keys(color).forEach((group) => {
  Object.keys(color[group]).forEach((variant) => {
    const key = variant === 'default' ? group : `${group}-${variant}`;
    flat[key] = color[group][variant];
  });
});

const exportObj = Object.assign({}, tokens, { flat });

const jsFile = [];
jsFile.push('// ================================================================');
jsFile.push('//  问玄东方App - Mini Program Design Tokens (Auto-generated)');
jsFile.push('//  Source: packages/design-tokens/tokens.json');
jsFile.push('//  Do not edit manually; run `npm run gen:mp` to regenerate.');
jsFile.push('// ================================================================');
jsFile.push('');
jsFile.push('module.exports = ' + JSON.stringify(exportObj, null, 2) + ';');
jsFile.push('');

const jsPath = path.join(outDir, 'tokens.js');
fs.writeFileSync(jsPath, jsFile.join('\n'));
console.log(`✓ Generated ${jsPath}`);
