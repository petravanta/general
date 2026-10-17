# general

Home for things shared across petravanta's personal growth apps.

- **Hub page:** [`index.html`](index.html), published at **https://petravanta.github.io/general/**. Links to Fitness Coach, Skating Mentor and VoiceTrainer.
- **Shared code:** [`shared/hub-link.js`](shared/hub-link.js) (the "All apps" back link every app includes), [`shared/theme.css`](shared/theme.css) (the shared colors, fonts and components), [`shared/drive-store.js`](shared/drive-store.js) (keeps each app's data in the user's Google Drive) and [`shared/pwa/`](shared/pwa/) (manifest and offline service worker templates for installing apps on a phone).
- **Standards:** [`STANDARDS.md`](STANDARDS.md) describes the conventions the apps follow and how to add a new app.

## Publishing

GitHub Pages serves this repo from the `main` branch, root folder (Settings → Pages → Deploy from a branch → `main` / `/ (root)`). The `.nojekyll` file makes Pages serve files as they are.
