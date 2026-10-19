# Shared standards for petravanta's apps

These apply to every app linked from the hub at **https://petravanta.github.io/general/**: [Fitness Coach](https://github.com/petravanta/fitness-coach), [Skating Mentor](https://github.com/petravanta/skating-mentor), [VoiceTrainer](https://github.com/petravanta/voicetrainer), [Nutrition Helper](https://github.com/petravanta/nutrition-helper), [Special Trip Planner](https://github.com/petravanta/special-trip-planner) and [Photo Timeline](https://github.com/petravanta/photo-timeline).

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
- Once the script has loaded the app list from [`shared/apps.json`](shared/apps.json), the pill becomes a menu: **Home** (the hub) plus every app, with the current app marked, so people can jump straight from one app to another. If the list can't load, the pill stays a plain link to the hub.
- If an app has no `[data-hub-link]` element, the script adds a slim bar with the link at the top of the page, so including the script alone is enough to get a back link.
- Apps reference the script by URL rather than copying it, so a change here reaches every app on its next page load.

## Adding a new app

1. Publish it on GitHub Pages under `petravanta.github.io/<repo>/`.
2. Add the back link (above), the theme switch (below) and the install files (*Installing on a phone*), follow *Built-in knowledge* for its content, and *User data* for what people save.
3. Apply the *Protect main* ruleset: `./github/apply-ruleset.sh <repo>`.
4. Add a card for it to [`index.html`](index.html): copy an existing `<li class="app …">`, set its name, link, one-line description and icon, and add a `--app` / `--app-soft` accent pair (light and dark) in the `<style>` block. Also add the app to [`shared/apps.json`](shared/apps.json) (id, name, url and the same light and dark accents) so it shows in every app's menu, and add the repo to `repos` in `github/apply-ruleset.sh`.

## Light and dark themes

Every app supports a light and a dark theme. By default it follows the device setting, and the **theme switch** next to the app's header lets people pick *Match system*, *Light* or *Dark*. The choice is saved once for all apps on petravanta.github.io.

Add two things to the app's HTML:

```html
<!-- in <head>, before any CSS, so the saved choice applies before the first paint -->
<script>try{var t=localStorage.getItem('petravanta.theme');if(t==='light'||t==='dark')document.documentElement.dataset.theme=t}catch(e){}</script>

<!-- just before </body>, after hub-link.js -->
<script src="https://petravanta.github.io/general/shared/theme-switch.js" defer></script>
```

- [`shared/theme-switch.js`](shared/theme-switch.js) adds a small round button at the end of the row that holds the hub link. To place it somewhere else, add an empty `<span data-theme-switch></span>` where it should go.
- It sets `data-theme="light"` or `data-theme="dark"` on `<html>` (or removes it for *Match system*), and keeps `<meta name="theme-color">` in step.
- For this to work, the app's colors must be tokens on `:root`, with dark values under `@media (prefers-color-scheme: dark)` guarded by `:root:not([data-theme="light"])`, and again under `:root[data-theme="dark"]`. Anything drawn in JavaScript (canvas, SVG) should read the tokens and redraw when `data-theme` changes.

## Built-in knowledge

What an app knows (exercises, skills, drills, trip templates) is data, not code.

### Data, not code

Content that people might want to review or add to (exercises, sports, equipment, skills, drills) lives in JSON files under `data/` in each app, not as literals in the code. That keeps every extension point easy to see, and lets anyone add an entry with a pull request.

- One file per dataset, `data/<dataset>.json`: an array of objects, one per entry, with readable field names. The order in the file is the order the app shows.
- Every entry has a stable `id` (lowercase letters, digits and hyphens). Saved user data refers to these ids, so an id is never renamed or reused once it has shipped.
- Each dataset has a JSON Schema, `data/schema/<dataset>.schema.json`, with a `description` on every field, enums for closed sets, and `additionalProperties: false`.
- The app loads the files with `fetch()` at startup and maps them onto whatever internal shape the code uses. User data (progress, logs, settings) stays separate and refers to entries by id.
- A `Check data` GitHub Actions workflow runs on every pull request: it validates each file against its schema with `ajv-cli`, and `scripts/check-data.js` checks what a schema can't (unique ids, references that exist).
- The README has an **Extending the app** table listing each dataset, its file, its schema and what it controls, and `CONTRIBUTING.md` walks a non-programmer through adding an entry.
- Behavior is still code. A new kind of entry that the app has to treat differently (a new movement pattern, a new skating style) means changing the code and the schema enum together.
- When each entry is a large nested document rather than a row (a whole trip template, say), the dataset is a folder instead: one file per entry, `data/<dataset>/<id>.json`, plus `data/<dataset>.json` listing the entry ids in display order. One schema still covers every entry, and the same `Check data` workflow validates each file.

Fitness Coach (exercises, sports, equipment), Skating Mentor (skills) and VoiceTrainer (reading texts, practice words, breath and control exercises) follow this. VoiceTrainer has a build step, so `build.js` inlines its data files into the page instead of fetching them.

### Say why when it isn't obvious

- An entry whose advice or rule isn't self-evident can carry an optional `why`: a short reason that motivates people to follow it and lets them judge cases the rule didn't foresee. Each dataset's schema decides which entries get a `why` and what else goes with it (sources, say).

## User data

Everything a person saves belongs to them: it stays in their browser and, if they choose, in their own Google Drive. It never goes to a server of ours or into a repo.

### Where it lives

- The browser keeps the working copy in `localStorage`.
- **Google Drive sync** is optional. Each app keeps one JSON file, `<App name> data.json`, in the user's own Drive, using the `drive.file` scope (the app sees only the file it created) and the shared OAuth client that allows `https://petravanta.github.io`. It saves a few seconds after each change, and merges with the browser copy on connect and whenever the app comes back into view.
- **Export backup** downloads the whole document as JSON, and **Import backup** merges one back in. Imports from other apps (a Fitbod CSV, a MacroFactor export) are read in the browser and become ordinary records.

### Shape

One JSON document per app:

```json
{
  "version": 1,
  "settings": { "updatedAt": "2026-10-17T08:00:00Z" },
  "<records>": [ { "id": "…", "u": "2026-10-17T08:00:00Z" } ],
  "deleted": [ "…" ]
}
```

- `version` is the document's format version. When the shape changes, the app upgrades older documents on load and never writes an older format.
- Settings-like objects (a profile, targets, preferences) carry `updatedAt`.
- Records (a workout, a food entry, a plan) live in named top-level lists. Each has a random, stable `id` and `u`, the time of its last edit.
- `deleted` lists the ids of removed records, so a deletion on one device carries to the others.
- Records refer to built-in knowledge by its id, never by copying its name.

### Merging two copies

When Drive and the browser (or an imported backup) disagree, nothing logged on either side is lost:

1. Records are combined by `id`; when both have the same record, the one with the newer `u` wins.
2. Any id in either `deleted` list is dropped, and the lists are joined.
3. For each settings-like object, the newer `updatedAt` wins.

Nutrition Helper follows these rules. Fitness Coach merges by id and `deleted` but does not stamp `u` yet, and neither app writes `version` yet; both should catch up when they next change their data.

### Sharing what you know, not who you are

When an app lets people share what they have built (a template, a routine), sharing is a separate export from the backup:

- The app's data model keeps shareable knowledge apart from private tracking (doses, ticks, logs, dates, personal contacts), so the share export leaves the private side out by construction rather than by scrubbing fields.
- Before the file is written, a preview shows everything that will go out, including free text the user typed.
- The shared file names its format and version, `{ "format": "<app>-<kind>", "formatVersion": 1, … }`, and passes the same schema as the app's built-in knowledge, so it can be imported or proposed for the repo by pull request.

## Adding photos

Any app that lets people add photos (or other images) also takes them by drag and drop from the desktop, not only through its button or file picker.

- **The whole page is the drop target** while files are dragged over it, so people don't have to aim at a small box. A full-page overlay appears for as long as the drag lasts and says where the photos will go ("Drop to add 3 photos to Summer 2024").
- **Where the spot means something, the drop uses it.** If the page shows places a photo can go (a track, a day, a list), dropping onto one puts the photos there; dropping anywhere else uses the same destination the button would.
- **Only photos are taken.** Other files in the same drop are skipped and the message says how many and why; a drop with no photos at all says which formats the app accepts.
- **One path for every way in.** A dropped photo goes through the same code as one from the button: the same resizing, date reading, progress and error messages.
- **The browser never opens a dropped file in place of the app.** Prevent the default on `dragover` and `drop` for file drags anywhere on the page, even where the app doesn't take them (with a drawer open, say).
- **The button stays.** Phones have no drag and drop, and keyboard and screen-reader users need the button. On devices with a fine pointer (`@media (pointer: fine)`), say near the button or empty state that photos can be dropped.

Photo Timeline follows this.

## Installing on a phone

Every app (and the hub) is an installable web app. In Chrome on Android, *Add to Home screen* / *Install app* puts it on the home screen with its own icon, and it opens full screen in its own window, also offline. Chrome and Edge on a computer offer the same install from the address bar, and Safari on iPhone uses *Share → Add to Home Screen*.

An app needs four things:

1. **Icons**, made with [`tools/make-icons.js`](tools/make-icons.js) from a white glyph on the app's light accent (the glyphs are in [`tools/glyphs/`](tools/glyphs/)):

   ```sh
   node tools/make-icons.js tools/glyphs/<app>.svg '<light accent>' ../<app>
   ```

   It writes `icon.svg`, `icon-192.png` and `icon-512.png` (rounded), `icon-maskable-512.png` (full bleed, artwork inside the central 80% so Android can crop it to any shape) and `apple-touch-icon.png` (180 px, for iPhone).

2. **A manifest**, `manifest.webmanifest`, with `name`, a short `short_name` for under the icon, `id`, `start_url` and `scope` all `./`, `display: standalone`, `background_color: #eef2f4`, `theme_color: #ffffff`, and the icons above (the 512 also listed as `maskable`). Copy one from an app that has it, such as Skating Mentor.

3. **Tags in `<head>`**, next to the theme-color pair the theme switch already uses:

   ```html
   <meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
   <meta name="theme-color" content="#172129" media="(prefers-color-scheme: dark)">
   <link rel="manifest" href="manifest.webmanifest">
   <link rel="icon" href="icon.svg" type="image/svg+xml">
   <link rel="apple-touch-icon" href="apple-touch-icon.png">
   ```

4. **A service worker**, `sw.js`, so Chrome offers the install and the app opens offline. It lists the files the app needs to start and loads the shared worker, [`shared/app-sw.js`](shared/app-sw.js):

   ```js
   self.APP_SHELL = ['./', 'manifest.webmanifest', 'icon-192.png', 'icon.svg', 'data/skills.json'];
   importScripts('https://petravanta.github.io/general/shared/app-sw.js');
   ```

   and the page registers it just before `</body>` (only on the real site, so a claude.ai Artifact or a local file is unaffected):

   ```html
   <script>if('serviceWorker' in navigator&&/^(petravanta\.github\.io|localhost|127\.0\.0\.1)$/.test(location.hostname))navigator.serviceWorker.register('sw.js').catch(function(){})</script>
   ```

   The shared worker fetches pages and the app's own files network-first, so an update shows the next time the app opens online, falls back to the cached copy offline, keeps Google Fonts cached, and leaves everything else (Google sign-in, Drive, Photos, food databases) to the network. User data is never cached by it.

When Chrome is ready to install an app, the **All apps** menu from `hub-link.js` also shows an **Install app** item.

Optional: **shortcuts** in the manifest for the one or two things people open the app to do (long-press the icon), as `./?do=<action>` URLs. The page reads `do` on load, does it, and removes it from the address with `history.replaceState` so a reload doesn't repeat it. Nutrition Helper has these.

An app with a build step (VoiceTrainer) keeps these files in `pwa/`, adds the head tags to its standalone page only, and copies `pwa/*` next to the page when it deploys.

All apps and the hub follow this. Fitness Coach and Nutrition Helper have their own `sw.js` that predates the shared worker and does the same job.

## Notes for coding agents

Each app has an `AGENTS.md` that links back here and lists only what's specific to that app, plus a one-line `CLAUDE.md` containing `@AGENTS.md` so Claude Code reads the same notes.

## Protecting `main`

Every repo should have a ruleset called **Protect main** on its default branch that blocks force pushes and deleting the branch. Normal pushes and pull request merges work as before. The rule is [`github/main-branch-ruleset.json`](github/main-branch-ruleset.json).

To apply it, or roll out a change to it, run this once on your own machine with the [GitHub CLI](https://cli.github.com/) signed in (`gh auth login`):

```sh
./github/apply-ruleset.sh                # the hub and every app
./github/apply-ruleset.sh my-new-app     # just one repo
```

Or by hand: in the repo, **Settings → Rules → Rulesets → New ruleset → Import a ruleset**, and pick `github/main-branch-ruleset.json`.

## Shared look

Fitness Coach, Skating Mentor, Nutrition Helper, Special Trip Planner and Photo Timeline (and the hub) share one set of colors, fonts and components. The canonical copy is [`shared/theme.css`](shared/theme.css). Each app inlines it between the `Shared look` and `end shared look` comments and only overrides the `--accent`, `--accent-ink` and `--accent-soft` values after it:

| App | Light accent | Dark accent |
| --- | --- | --- |
| Hub | `#11897a` teal | `#3cc3ad` |
| Fitness Coach | `#4f46c8` indigo | `#9d95ff` |
| Skating Mentor | `#c2306f` pink | `#f0679f` |
| VoiceTrainer | `#2f3c95` indigo-blue | `#9aa6ff` |
| Nutrition Helper | `#c2410c` orange | `#fb8a4c` |
| Special Trip Planner | `#1d6fb8` blue | `#6cb4ff` |
| Photo Timeline | `#7442b8` violet | `#bb94ff` |

VoiceTrainer has its own type and panel styles but follows the same token names for `--bg`, `--ink`, `--muted`, `--line` and `--accent`.

Conventions the apps already share:

- Light and dark themes with the shared theme switch (see *Light and dark themes* above).
- Phone-first layout: `viewport-fit=cover`, safe-area insets on sticky headers and sheets, 16px minimum side gutter.
- User data in the browser with optional Google Drive sync, as *User data* above describes.
- No sign-up; each app is a static page served by GitHub Pages from its `main` branch.

When you change the shared look, update `shared/theme.css` here and the inlined copy in each app together.
