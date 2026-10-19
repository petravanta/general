// Makes the home-screen icons for an installable app (see STANDARDS.md, "Installing on a phone").
//
//   node tools/make-icons.js <glyph.svg> <accent> <out-dir>
//   node tools/make-icons.js tools/glyphs/photo-timeline.svg '#7442b8' ../photo-timeline
//
// The glyph is SVG markup drawn in a 32×32 box, in white on the app's light accent
// (fill="var(--bg)" punches a hole in the accent colour). It is centred at 56% of the icon,
// inside the maskable safe zone, and written out as:
//   icon.svg               rounded square, for browsers that take SVG icons and the page favicon
//   icon-192.png, icon-512.png   rounded square, manifest "any"
//   icon-maskable-512.png  full-bleed square, manifest "maskable" (Android crops it to its own shape)
//   apple-touch-icon.png   full-bleed 180px square (iOS rounds it)
// Rendering uses Playwright's Chromium: `npm i -g playwright` once if it isn't installed.
const fs = require('fs'), path = require('path');
const [glyphFile, accent, out] = process.argv.slice(2);
if (!glyphFile || !accent || !out) { console.error('usage: node tools/make-icons.js <glyph.svg> <accent> <out-dir>'); process.exit(1); }
const glyph = fs.readFileSync(glyphFile, 'utf8').trim().replace(/var\(--bg\)/g, accent);
const svg = (rx) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512"${rx ? ` rx="${rx}"` : ''} fill="${accent}"/><g transform="translate(112 112) scale(9)">${glyph}</g></svg>\n`;
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'icon.svg'), svg(112));
(async () => {
  const { chromium } = require('playwright');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [name, size, rx] of [['icon-192.png', 192, 112], ['icon-512.png', 512, 112], ['icon-maskable-512.png', 512, 0], ['apple-touch-icon.png', 180, 0]]) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<style>html,body{margin:0;background:transparent}svg{display:block;width:${size}px;height:${size}px}</style>${svg(rx)}`);
    await page.screenshot({ path: path.join(out, name), omitBackground: true });
  }
  await browser.close();
  console.log('icons written to', out);
})();
