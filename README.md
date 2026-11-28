# general

Home for things shared across petravanta's personal growth apps.

- **Hub page:** [`index.html`](index.html), published at **https://petravanta.github.io/general/**. Links to Fitness Coach, Skating Mentor, VoiceTrainer, Nutrition Helper, Special Trip Planner, Photo Timeline, Project Tracker, Study Buddy, Mind Palace, Dance Floor, Wardrobe and Mixmaster.
- **Shared code:** [`shared/hub-link.js`](shared/hub-link.js) (the "All apps" back link every app includes) [`shared/theme.css`](shared/theme.css) (the shared colors, fonts and components), and [`shared/app-sw.js`](shared/app-sw.js) (the offline worker that makes each app installable on a phone). [`tools/make-icons.js`](tools/make-icons.js) makes each app's home-screen icons.
- **Standards:** [`STANDARDS.md`](STANDARDS.md) describes the conventions the apps follow and how to add a new app.
- **Standards:** [`CHECKLIST.md`](CHECKLIST.md) itemizes them, and [`github/standards.ps1`](github/standards.ps1) / [`.sh`](github/standards.sh) check every repo against that list and can fix the simple gaps in bulk (see *Checking every project* in STANDARDS.md).
- **Changes and patterns:** [`CHANGELOG.md`](CHANGELOG.md) has one dated line per standards or shared-code change, and [`PATTERNS.md`](PATTERNS.md) collects optional patterns apps can pick up (splitting a large app into files, on-device machine learning).
- **Shared code:** apps load everything in [`shared/`](shared/) by URL; [`github/sync-shared.ps1`](github/sync-shared.ps1) / [`.sh`](github/sync-shared.sh) report apps that still paste an old copy (see *Shared code* in STANDARDS.md).
- **Testing:** [`tools/screenshot.mjs`](tools/screenshot.mjs) takes headless Chrome screenshots at any size and theme (see *Testing changes* in STANDARDS.md).
- **Backups:** [`github/backup-repos.ps1`](github/backup-repos.ps1) / [`.sh`](github/backup-repos.sh) keep a full local mirror of every petravanta repo (see *Backups* in STANDARDS.md).

## Publishing

GitHub Pages serves this repo from the `main` branch, root folder (Settings → Pages → Deploy from a branch → `main` / `/ (root)`). The `.nojekyll` file makes Pages serve files as they are.

## License

MIT, see [LICENSE](LICENSE).
