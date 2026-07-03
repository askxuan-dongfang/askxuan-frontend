/* ================================================================
 * gen-ios-tokens.js
 * 读取 tokens.json，生成 Swift Tokens.swift（Color 扩展 / 字体 / 圆角 / 间距）
 * 仅依赖 Node 内置 fs / path 模块
 * ================================================================ */
const fs = require('fs');
const path = require('path');

const tokensPath = path.join(__dirname, '..', 'tokens.json');
const tokens = JSON.parse(fs.readFileSync(tokensPath, 'utf8'));

const outDir = path.join(__dirname, '..', 'dist', 'ios');
fs.mkdirSync(outDir, { recursive: true });

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

// 将颜色值转换为 Swift Color 表达式
// 支持 #RRGGBB / RRGGBB / rgba(r,g,b,a) / rgb(r,g,b)
function colorExpr(value) {
  const m = value.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/i);
  if (m) {
    const r = parseFloat(m[1]);
    const g = parseFloat(m[2]);
    const b = parseFloat(m[3]);
    const a = m[4] !== undefined ? parseFloat(m[4]) : 1;
    return `Color(.sRGB, red: ${r}/255.0, green: ${g}/255.0, blue: ${b}/255.0, opacity: ${a})`;
  }
  const hex = value.replace(/^#/, '');
  return `Color(hex: "${hex}")`;
}

const lines = [];

lines.push('// ================================================================');
lines.push('//  问玄东方App - Design Tokens (Auto-generated)');
lines.push('//  Source: packages/design-tokens/tokens.json');
lines.push('//  Do not edit manually; run `npm run gen:ios` to regenerate.');
lines.push('// ================================================================');
lines.push('');
lines.push('import SwiftUI');
lines.push('');

// ---- Colors ----
lines.push('// MARK: - Colors');
lines.push('extension Color {');

const color = tokens.color;
const colorProps = [];
Object.keys(color).forEach((group) => {
  Object.keys(color[group]).forEach((variant) => {
    const name = group + capitalize(variant);
    colorProps.push(`    static let ${name} = ${colorExpr(color[group][variant])}`);
  });
});
lines.push(colorProps.join('\n'));
lines.push('');
lines.push('    /// Initialize a Color from a hex string (3 or 6 digits, leading # optional).');
lines.push('    init(hex: String) {');
lines.push('        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)');
lines.push('        var int: UInt64 = 0');
lines.push('        Scanner(string: cleaned).scanHexInt64(&int)');
lines.push('        let a, r, g, b: UInt64');
lines.push('        switch cleaned.count {');
lines.push('        case 3:');
lines.push('            (a, r, g, b) = (255,');
lines.push('                             (int >> 8) * 17,');
lines.push('                             (int >> 4 & 0xF) * 17,');
lines.push('                             (int & 0xF) * 17)');
lines.push('        case 6:');
lines.push('            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)');
lines.push('        default:');
lines.push('            (a, r, g, b) = (255, 0, 0, 0)');
lines.push('        }');
lines.push('        self.init(');
lines.push('            .sRGB,');
lines.push('            red: Double(r) / 255,');
lines.push('            green: Double(g) / 255,');
lines.push('            blue: Double(b) / 255,');
lines.push('            opacity: Double(a) / 255');
lines.push('        )');
lines.push('    }');
lines.push('}');
lines.push('');

// ---- Fonts ----
lines.push('// MARK: - Fonts');
lines.push('enum AppFont {');
lines.push(`    static let serif = [${tokens.font.serif.map((f) => `"${f}"`).join(', ')}]`);
lines.push(`    static let sans = [${tokens.font.sans.map((f) => `"${f}"`).join(', ')}]`);
lines.push('}');
lines.push('');

// ---- Radius ----
lines.push('// MARK: - Corner Radius');
lines.push('enum AppRadius {');
Object.keys(tokens.radius).forEach((k) => {
  lines.push(`    static let ${k}: CGFloat = ${tokens.radius[k]}`);
});
lines.push('}');
lines.push('');

// ---- Spacing ----
lines.push('// MARK: - Spacing');
lines.push('enum AppSpacing {');
Object.keys(tokens.spacing).forEach((k) => {
  lines.push(`    static let ${k}: CGFloat = ${tokens.spacing[k]}`);
});
lines.push('}');
lines.push('');

const outPath = path.join(outDir, 'Tokens.swift');
fs.writeFileSync(outPath, lines.join('\n'));
console.log(`✓ Generated ${outPath}`);
