#!/usr/bin/env node
// Headless Chrome screenshots for testing an app when no browser pane is to hand (see STANDARDS.md, "Testing changes").
// Starts Chrome headless with its own throwaway profile and drives it over the DevTools protocol, using only what
// ships with Node 22+ (fetch, WebSocket). No npm install.
//
//   node tools/screenshot.mjs go http://localhost:8000/wardrobe/ size 390x844 theme dark shot phone-dark.png
//   node tools/screenshot.mjs go URL size 1280x800 theme light js "document.title" shot desktop-light.png full
//
// Steps run in order, each a name and its arguments:
//   go URL              open URL and wait for it to load
//   size WxH[@SCALE]    window size in CSS pixels (390x844 is a phone); widths up to 500 also emulate touch and mobile
//   theme light|dark    the device colour scheme (prefers-color-scheme), which apps follow on "Match system"
//   js EXPRESSION       run JavaScript in the page (promises are awaited) and print the result
//   shot FILE [full]    save a PNG of the window, or of the whole page with "full"
//   touch X Y           tap at a point
//   drag X1 Y1 X2 Y2    press, move and release the mouse
//   wait MS             pause, for animations
// Options (before the steps): --chrome PATH (or env CHROME), --port N (default 9333), --show (not headless).
// Also importable: const b = await open(); await b.go(url); await b.shot('a.png'); await b.close();
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const sleep = ms => new Promise(r => setTimeout(r, ms));

function findChrome() {
  if (process.env.CHROME) return process.env.CHROME;
  const win = ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe', 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe', 'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'];
  const mac = ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'];
  const nix = ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/snap/bin/chromium'];
  const list = process.platform === 'win32' ? win : process.platform === 'darwin' ? mac : nix;
  return list.find(p => existsSync(p)) || 'google-chrome';
}

export async function open({ chrome = findChrome(), port = 9333, show = false } = {}) {
  if (typeof WebSocket === 'undefined') throw new Error('Needs Node 22 or newer (built-in WebSocket).');
  const profile = mkdtempSync(join(tmpdir(), 'screenshot-profile-'));   // never the person's own profile
  const args = [`--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--no-first-run', '--no-default-browser-check',
    '--hide-scrollbars', '--mute-audio', 'about:blank'];
  if (!show) args.unshift('--headless=new');
  if (process.platform === 'linux' && process.getuid?.() === 0) args.unshift('--no-sandbox');   // containers run as root
  const proc = spawn(chrome, args, { stdio: 'ignore' });
  let target;
  for (let i = 0; i < 100 && !target; i++) {
    await sleep(100);
    try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page'); } catch {}
  }
  if (!target) { proc.kill(); throw new Error(`Chrome didn't open its debugging port ${port} (is ${chrome} right? set --chrome or CHROME)`); }

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('Could not connect to Chrome')); });
  let seq = 0; const waiting = new Map(), listeners = [];
  ws.onmessage = e => {
    const m = JSON.parse(e.data);
    if (m.id && waiting.has(m.id)) { const { res, rej } = waiting.get(m.id); waiting.delete(m.id); m.error ? rej(new Error(m.error.message)) : res(m.result); }
    else if (m.method) listeners.forEach(f => f(m));
  };
  const send = (method, params = {}) => new Promise((res, rej) => { const id = ++seq; waiting.set(id, { res, rej }); ws.send(JSON.stringify({ id, method, params })); });
  const once = (method, ms = 30000) => new Promise(res => {
    const f = m => { if (m.method === method) { listeners.splice(listeners.indexOf(f), 1); res(m.params); } };
    listeners.push(f); setTimeout(() => { const i = listeners.indexOf(f); if (i >= 0) { listeners.splice(i, 1); res(null); } }, ms);
  });
  await send('Page.enable'); await send('Runtime.enable');

  const b = {
    send,
    async go(url) { const loaded = once('Page.loadEventFired'); await send('Page.navigate', { url }); await loaded; await sleep(300); },
    async size(spec) {
      const [, w, h, s] = String(spec).match(/^(\d+)x(\d+)(?:@([\d.]+))?$/) || [];
      if (!w) throw new Error(`size wants WxH, like 390x844 (got ${spec})`);
      const mobile = +w <= 500;
      await send('Emulation.setDeviceMetricsOverride', { width: +w, height: +h, deviceScaleFactor: +(s || (mobile ? 2 : 1)), mobile });
      await send('Emulation.setTouchEmulationEnabled', { enabled: mobile, maxTouchPoints: mobile ? 5 : 1 });
    },
    async theme(t) {
      if (!['light', 'dark'].includes(t)) throw new Error('theme wants light or dark');
      await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: t }] });
      await sleep(100);
    },
    async js(expression) {
      const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true, userGesture: true });
      if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
      return r.result.value;
    },
    async shot(file, full) {
      const { data } = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: !!full });
      writeFileSync(file, Buffer.from(data, 'base64'));
      return file;
    },
    async touch(x, y) {
      const p = [{ x: +x, y: +y }];
      await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: p });
      await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await sleep(150);
    },
    async drag(x1, y1, x2, y2, steps = 12) {
      await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: +x1, y: +y1 });
      await send('Input.dispatchMouseEvent', { type: 'mousePressed', x: +x1, y: +y1, button: 'left', buttons: 1, clickCount: 1 });
      for (let i = 1; i <= steps; i++) {
        await send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: +x1 + (x2 - x1) * i / steps, y: +y1 + (y2 - y1) * i / steps, button: 'left', buttons: 1 });
        await sleep(16);
      }
      await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: +x2, y: +y2, button: 'left', buttons: 0, clickCount: 1 });
      await sleep(150);
    },
    wait: ms => sleep(+ms),
    async close() {
      try { await send('Browser.close'); } catch {}
      ws.close(); await sleep(300); proc.kill();
      try { rmSync(profile, { recursive: true, force: true }); } catch {}
    },
  };
  return b;
}

// --- Command line ---------------------------------------------------------------------------------------
const arity = { go: 1, size: 1, theme: 1, js: 1, shot: 1, touch: 2, drag: 4, wait: 1 };
async function main(argv) {
  const opts = {};
  while (argv[0]?.startsWith('--')) {
    const o = argv.shift();
    if (o === '--chrome') opts.chrome = argv.shift();
    else if (o === '--port') opts.port = +argv.shift();
    else if (o === '--show') opts.show = true;
    else throw new Error(`Unknown option ${o}`);
  }
  if (!argv.length || argv[0] === '-h' || argv[0] === 'help') {
    console.log('Usage: node tools/screenshot.mjs [--chrome PATH] [--port N] [--show] go URL size 390x844 theme dark shot out.png ...');
    return;
  }
  const steps = [];
  while (argv.length) {
    const name = argv.shift();
    if (!(name in arity)) throw new Error(`Unknown step "${name}" (steps: ${Object.keys(arity).join(', ')})`);
    const a = argv.splice(0, arity[name]);
    if (name === 'shot' && argv[0] === 'full') a.push(argv.shift());
    if (a.length < arity[name]) throw new Error(`${name} needs ${arity[name]} argument(s)`);
    steps.push([name, a]);
  }
  const b = await open(opts);
  try {
    for (const [name, a] of steps) {
      const r = await b[name](...a);
      if (name === 'js') console.log(typeof r === 'string' ? r : JSON.stringify(r, null, 1));
      if (name === 'shot') console.log(`saved ${r}`);
    }
  } finally { await b.close(); }
}
if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  main(process.argv.slice(2)).catch(e => { console.error(e.message); process.exit(1); });
}
