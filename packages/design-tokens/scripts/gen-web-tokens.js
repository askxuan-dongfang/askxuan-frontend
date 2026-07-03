/* ================================================================
 * gen-web-tokens.js
 * 读取 tokens.json，生成 tokens.css（CSS 变量）与 tailwind-tokens.js
 * 仅依赖 Node 内置 fs / path 模块
 * ================================================================ */
const fs = require('fs');
const path = require('path');

const tokensPath = path.join(__dirname, '..', 'tokens.json');
const tokens = JSON.parse(fs.readFileSync(tokensPath, 'utf8'));

const outDir = path.join(__dirname, '..', 'dist', 'web');
fs.mkdirSync(outDir, { recursive: true });

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function kebab(s) {
  return s.replace(/([A-Z])/g, '-$1').toLowerCase();
}

const color = tokens.color;

// ---- tokens.css ----
const css = [];
css.push('/* ================================================================');
css.push('   问玄东方App - Web Design Tokens (Auto-generated)');
css.push('   Source: packages/design-tokens/tokens.json');
css.push('   Do not edit manually; run `npm run gen:web` to regenerate.');
css.push('   ================================================================ */');
css.push(':root {');

Object.keys(color).forEach((group) => {
  css.push(`  /* ${capitalize(group)} */`);
  Object.keys(color[group]).forEach((variant) => {
    css.push(`  --color-${group}-${variant}: ${color[group][variant]};`);
    // default 变体额外输出短别名，与原 colors_and_type.css 兼容
    if (variant === 'default') {
      css.push(`  --color-${group}: ${color[group][variant]};`);
    }
  });
});

css.push('');
css.push('  /* Fonts */');
css.push(`  --font-serif: ${tokens.font.serif.map((f) => `'${f}'`).join(', ')}, serif;`);
css.push(`  --font-sans: ${tokens.font.sans.map((f) => `'${f}'`).join(', ')}, sans-serif;`);

css.push('');
css.push('  /* Radius */');
Object.keys(tokens.radius).forEach((k) => {
  css.push(`  --radius-${k}: ${tokens.radius[k]}px;`);
});

css.push('');
css.push('  /* Spacing */');
Object.keys(tokens.spacing).forEach((k) => {
  css.push(`  --spacing-${kebab(k)}: ${tokens.spacing[k]}px;`);
});

css.push('}');
css.push('');

const cssPath = path.join(outDir, 'tokens.css');
fs.writeFileSync(cssPath, css.join('\n'));
console.log(`✓ Generated ${cssPath}`);

// ---- tailwind-tokens.js ----
const tw = {
  colors: {},
  fontFamily: {
    serif: tokens.font.serif.map((f) => `'${f}'`).concat(['serif']),
    sans: tokens.font.sans.map((f) => `'${f}'`).concat(['sans-serif']),
  },
  borderRadius: {},
  spacing: {},
};

Object.keys(color).forEach((group) => {
  tw.colors[group] = {};
  Object.keys(color[group]).forEach((variant) => {
    const key = variant === 'default' ? 'DEFAULT' : variant;
    tw.colors[group][key] = color[group][variant];
  });
});

Object.keys(tokens.radius).forEach((k) => {
  tw.borderRadius[k] = `${tokens.radius[k]}px`;
});

Object.keys(tokens.spacing).forEach((k) => {
  tw.spacing[k] = `${tokens.spacing[k]}px`;
});

const twFile = [];
twFile.push('/* Auto-generated from packages/design-tokens/tokens.json. Do not edit manually. */');
twFile.push('// Usage in tailwind.config.js:');
twFile.push('//   const tokens = require("./tailwind-tokens");');
twFile.push('//   module.exports = { theme: { extend: tokens } };');
twFile.push('');
twFile.push('module.exports = ' + JSON.stringify(tw, null, 2) + ';');
twFile.push('');

const twPath = path.join(outDir, 'tailwind-tokens.js');
fs.writeFileSync(twPath, twFile.join('\n'));
console.log(`✓ Generated ${twPath}`);
