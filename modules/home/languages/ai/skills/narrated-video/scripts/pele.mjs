// Render Mermaid with Pele and flatten its CSS variables to theme literals.
// resvg does not resolve var(), so every colour must be a literal before rasterizing.
// Usage: node pele.mjs in.mmd out.svg '<theme json>' '<font>' '<mono font>'   (PELE_JS = pele.js)
import { readFileSync, writeFileSync } from "node:fs";

const [src, dst, themeJson, font, mono] = process.argv.slice(2);
if (!process.env.PELE_JS) throw new Error("PELE_JS is not set; run through the skill's video wrapper");
const { render } = await import(process.env.PELE_JS);
const t = JSON.parse(themeJson);

const vars = {
  "pele-bg": t.bg,
  "pele-fg": t.text,
  "pele-muted": t.muted,
  "pele-line": t.line,
  "pele-surface": t.panel,
  "pele-surface-alt": t.panel_alt,
  "pele-border": t.blue,
  "pele-accent": t.blue,
  "pele-font": `'${font}'`,
  "pele-font-mono": `'${mono}'`,
  "pele-radius": "6px",
};

// Footer actors only repeat the header; dropping them lets a sequence diagram scale larger.
const out = render(readFileSync(src, "utf8"), { config: { sequence: { mirrorActors: false } } });
let svg = typeof out === "string" ? out : out.svg;

// Video legibility: quieter lifelines, heavier strokes, and a background halo so
// labels stay readable where they cross a line.
const css = `<style>
.pele-lifelines { stroke: #3d4466; stroke-width: 1.5; }
.pele-edges path { stroke-width: 1.6; }
.pele-actor rect { stroke-width: 1.5; }
.pele-frames rect, .pele-frames path { stroke-width: 1.3; }
.pele-edge-labels text, .pele-frame-label {
  stroke: ${t.bg}; stroke-width: 6; paint-order: stroke; stroke-linejoin: round;
}
</style>`;
svg = svg.replace(/(<svg\b[^>]*>)/, `$1${css}`);

// Pass 1: resolve --pele-* to the theme (or Pele's fallback), collecting the --_x aliases.
const alias = {};
svg = svg.replace(/--_(\w+):var\(--(pele-[\w-]+),([^)]*)\)/g, (_, k, name, fb) => {
  alias[k] = vars[name] ?? fb;
  return "";
});
svg = svg.replace(/var\(--(pele-[\w-]+),([^)]*)\)/g, (_, name, fb) => vars[name] ?? fb);
// Pass 2: resolve the --_x aliases, then drop empty declarations left behind.
svg = svg.replace(/var\(--_(\w+)\)/g, (m, k) => alias[k] ?? m);
svg = svg.replace(/;{2,}/g, ";").replace(/style=";/g, 'style="');
// The root shorthand names sans-serif; pin it so resvg uses a known face.
svg = svg.replace(/font:(\d+px) sans-serif/g, `font:$1 '${font}'`);

writeFileSync(dst, svg);
