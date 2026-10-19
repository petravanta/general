# general

Home for things shared across petravanta's personal growth apps.

- **Hub page:** [`index.html`](index.html), published at **https://petravanta.github.io/general/**. Links to Fitness Coach, Skating Mentor, VoiceTrainer, Nutrition Helper, Special Trip Planner, Photo Timeline and Project Tracker.
- **Shared code:** [`shared/hub-link.js`](shared/hub-link.js) (the "All apps" back link every app includes) [`shared/theme.css`](shared/theme.css) (the shared colors, fonts and components), and [`shared/app-sw.js`](shared/app-sw.js) (the offline worker that makes each app installable on a phone). [`tools/make-icons.js`](tools/make-icons.js) makes each app's home-screen icons.
- **Standards:** [`STANDARDS.md`](STANDARDS.md) describes the conventions the apps follow and how to add a new app.

## Publishing

GitHub Pages serves this repo from the `main` branch, root folder (Settings → Pages → Deploy from a branch → `main` / `/ (root)`). The `.nojekyll` file makes Pages serve files as they are.
