# Shared standards for petravanta's apps

These apply to every app linked from the hub at **https://petravanta.github.io/general/**: [Fitness Coach](https://github.com/petravanta/fitness-coach), [Skating Mentor](https://github.com/petravanta/skating-mentor) and [VoiceTrainer](https://github.com/petravanta/voicetrainer).

## Back link to the hub

Every app shows an **All apps** link to the hub in its header, at the start of the brand row, before the app name.

Add two things to the app's HTML:

```html
<!-- in the header, before the app name -->
<a data-hub-link href="https://petravanta.github.io/general/">All apps</a>

<!-- just before </body> -->
<script src="https://petravanta.github.io/general/shared/hub-link.js" defer></script>
```

- The `<a>` is a normal link, so the back link still works where the script can't load (for example when the app runs as a claude.ai Artifact, which only allows scripts from a few CDNs).
- [`shared/hub-link.js`](shared/hub-link.js) turns it into a small pill with a grid icon, styled with the app's own `--muted`, `--line`, `--ink` and `--accent` tokens, so it fits each app's colors and dark mode without extra CSS.
- If an app has no `[data-hub-link]` element, the script adds a slim bar with the link at the top of the page, so including the script alone is enough to get a back link.
- Apps reference the script by URL rather than copying it, so a change here reaches every app on its next page load.

## Phone support

Every app is used mostly on a phone, so each one meets this checklist. [Fitness Coach](https://github.com/petravanta/fitness-coach) is the reference.

- **Installable.** A `manifest.webmanifest` next to `index.html` (template: [`shared/pwa/manifest.webmanifest`](shared/pwa/manifest.webmanifest)), with 192 and 512 px PNG icons, a maskable 512 px icon and an `icon.svg`. In `<head>`: `<link rel="manifest">`, `<link rel="apple-touch-icon" href="apple-touch-icon.png">` (180 px), `theme-color` metas for light and dark, `apple-mobile-web-app-capable`, `mobile-web-app-capable` and a short `apple-mobile-web-app-title`.
- **Opens offline.** A `sw.js` next to `index.html` (template: [`shared/pwa/sw.js`](shared/pwa/sw.js)) caches the app shell, network first. It never caches user data. Register it only on `petravanta.github.io` and `localhost`.
- **Bottom tab bar at phone width** (≤ 640 px): the app's main tabs sit in a fixed bar along the bottom, each with an icon and a short label, padded by `env(safe-area-inset-bottom)`. Page content gets enough bottom padding to clear it, and toasts sit above it. On wider screens the tabs stay in the header.
- **Touch targets** of at least 40–44 px for buttons, steppers and chips; inputs at 16 px font so iOS doesn't zoom in; `touch-action: manipulation` on buttons.
- **Safe areas:** `viewport-fit=cover`, safe-area insets on sticky headers, bottom bars and sheets, a 16 px minimum side gutter.
- **Sheets, not pop-ups:** detail views and pickers open as bottom sheets on phones.
- **Screen stays on** while the app is timing something (Screen Wake Lock), and sounds start only after a tap.

## Data lives in Google Drive

Apps keep the user's data and settings in **one JSON file in the user's own Google Drive**, not in browser storage. Use [`shared/drive-store.js`](shared/drive-store.js), inlined between its `Drive store` comments like the shared look:

```js
const store=DriveStore({clientId:GOOGLE_CLIENT_ID,file:'App Name data.json',app:'app-id',key:'xx',
  empty:()=>({...}),            // shape of a brand-new file
  merge:(a,b)=>({...}),         // combine two copies; prefer a when both changed the same thing
  onChange:()=>showStatus()});  // update the header status line (store.status())
await store.load(true);         // from a tap: signs in, reads the file (creates it on first use)
store.save(data);               // after every change; written to Drive about 1.5 s later
```

- **First open:** a screen explains that data is kept in the user's Drive, with **Connect Google Drive** and a *Look around without saving* option that keeps nothing.
- **Sign-in:** Google tokens last about an hour. The store keeps the token across reloads and renews it on the next tap when it is close to running out (Google may flash a window that closes by itself). Elements with `data-drive` are excluded from that tap so they can call `store.load(true)` themselves.
- **Offline and lapsed sign-ins:** changes that haven't reached Drive are kept in `localStorage` under `<key>.pending` and deleted as soon as Drive has them. That and the sign-in token are the only things the browser keeps.
- **Other devices:** call `store.refresh()` when the app comes back to the front and re-render if it returns `true`.
- **Moving old data:** apps that used to keep data in `localStorage` merge it into the Drive file once and remove the old keys.
- **Permissions:** `drive.file` scope only, so an app sees just the files it created. All apps use the shared OAuth client, which allows `https://petravanta.github.io`; on any other origin (for example a claude.ai preview) `GOOGLE_CLIENT_ID` is empty and the app runs in look-around mode.

## Adding a new app

1. Publish it on GitHub Pages under `petravanta.github.io/<repo>/`.
2. Add the back link above, and meet *Phone support* and *Data lives in Google Drive*.
3. Add a card for it to [`index.html`](index.html): copy an existing `<li class="app …">`, set its name, link, one-line description and icon, and add a `--app` / `--app-soft` accent pair (light and dark) in the `<style>` block.

## Shared look

Fitness Coach and Skating Mentor (and the hub) share one set of colors, fonts and components. The canonical copy is [`shared/theme.css`](shared/theme.css). Each app inlines it between the `Shared look` and `end shared look` comments and only overrides the `--accent`, `--accent-ink` and `--accent-soft` values after it:

| App | Light accent | Dark accent |
| --- | --- | --- |
| Hub | `#11897a` teal | `#3cc3ad` |
| Fitness Coach | `#4f46c8` indigo | `#9d95ff` |
| Skating Mentor | `#c2306f` pink | `#f0679f` |
| VoiceTrainer | `#2f3c95` indigo-blue | `#9aa6ff` |

VoiceTrainer has its own type and panel styles but follows the same token names for `--bg`, `--ink`, `--muted`, `--line` and `--accent`.

Conventions the apps already share:

- Light and dark themes: tokens on `:root`, dark values under `@media (prefers-color-scheme: dark)` guarded by `:root:not([data-theme="light"])`, and again under `:root[data-theme="dark"]`.
- Phone-first layout: see *Phone support* below.
- User data lives in Google Drive (see below), with **Export backup** / **Import backup** as JSON.
- Each app is a static page served by GitHub Pages from its `main` branch.

When you change the shared look, update `shared/theme.css` here and the inlined copy in each app together.
