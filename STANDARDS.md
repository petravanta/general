# Shared standards for petravanta's apps

These apply to every app linked from the hub at **https://petravanta.github.io/general/**: [Fitness Coach](https://github.com/petravanta/fitness-coach), [Skating Mentor](https://github.com/petravanta/skating-mentor), [VoiceTrainer](https://github.com/petravanta/voicetrainer), [Nutrition Helper](https://github.com/petravanta/nutrition-helper), [Special Trip Planner](https://github.com/petravanta/special-trip-planner), [Photo Timeline](https://github.com/petravanta/photo-timeline), [Project Tracker](https://github.com/petravanta/project-tracker), [Study Buddy](https://github.com/petravanta/study-buddy), [Mind Palace](https://github.com/petravanta/mind-palace), [Dance Floor](https://github.com/petravanta/dance-floor), [Wardrobe](https://github.com/petravanta/wardrobe) and [Mixmaster](https://github.com/petravanta/mixmaster).

[`CHECKLIST.md`](CHECKLIST.md) lists every concern below as one row each (what, for which repos, how it's checked), and *Checking every project* explains the script that checks them all. [`CHANGELOG.md`](CHANGELOG.md) says what changed here and when, so an app can catch up from the date it was last checked. [`PATTERNS.md`](PATTERNS.md) holds optional patterns that one app worked out and others can pick up when they need them; they aren't required.

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
2. Add the back link (above), the theme switch (below), the install files (*Installing on a phone*) the version footer with its deploy workflow (*Version and build info*) and, once it has any view that opens over another, the back stack (*Back button*), follow *Built-in knowledge* for its content, and *User data* for what people save.
3. Apply the *Protect main* ruleset and the repo settings for *Merging pull requests*: `.\github\apply-ruleset.ps1 <repo>` (or `./github/apply-ruleset.sh <repo>`).
4. Add the MIT licence: copy [`LICENSE`](LICENSE) into the repo root as is (see *License*).
5. Back it up: run `.\github\backup-repos.ps1 <repo>` (or `./github/backup-repos.sh <repo>`) once so its mirror exists from day one (*Backups*), and add its name to [`github/repos.txt`](github/repos.txt). After that the regular run picks it up by itself, because the script backs up every repo petravanta owns. Keep its working clone under `F:\Dev\petravantaapps` so `sync-all` checks it too (*Syncing every project*).
6. Add a card for it to [`index.html`](index.html): copy an existing `<li class="app …">`, set its name, link, one-line description and icon, and add a `--app` / `--app-soft` accent pair (light and dark) in the `<style>` block. Also add the app to [`shared/apps.json`](shared/apps.json) (id, name, url and the same light and dark accents) so it shows in every app's menu (the hub cards and the menu sort themselves alphabetically by name, so place doesn't matter), and add the repo to the repo list in `github/apply-ruleset.ps1` and `github/apply-ruleset.sh`.
7. Check it: `.\github\standards.ps1 <repo>` (or `./github/standards.sh <repo>`) should report no gaps (*Checking every project*), and end its `AGENTS.md` with `Checked against General as of <today's date>` (*Pasted shared code*).

## License

Every project, the hub included, is MIT licensed, so anyone can use, change and share the code and the `data/*.json` people contribute.

- Put the standard MIT text in `LICENSE` at the repo root, with the line `Copyright (c) <year the repo started> Petra Vanta`. Copy it from this repo's [`LICENSE`](LICENSE).
- End the README with a short `## License` section that points at it.
- Material from elsewhere keeps its own licence. List it in `THIRD_PARTY_NOTICES.md` (what it is, where it lives in the repo, its licence and full notice when the licence asks for one), as VoiceTrainer does for the CMU Pronouncing Dictionary. Never relabel someone else's work as MIT.
- Before adding a dependency, check its licence. Permissive ones (MIT, BSD, Apache-2.0, ISC, CC BY) are fine with a notice. Copyleft ones (GPL, AGPL, CC BY-SA) are a decision for petravanta, because they set terms for the whole app or for what's built from them.

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

Fitness Coach (exercises, sports, equipment), Skating Mentor (skills), Study Buddy (question sets, one file per set) and VoiceTrainer (reading texts, practice words, breath and control exercises) follow this. VoiceTrainer has a build step, so `build.js` inlines its data files into the page instead of fetching them.

### Say why when it isn't obvious

- An entry whose advice or rule isn't self-evident can carry an optional `why`: a short reason that motivates people to follow it and lets them judge cases the rule didn't foresee. Each dataset's schema decides which entries get a `why` and what else goes with it (sources, say).

## User data

Everything a person saves belongs to them: it stays in their browser and, if they choose, in their own Google Drive, or for images their own Google Photos (see *Images*). It never goes to a server of ours or into a repo.

### Where it lives

- The browser keeps the working copy in `localStorage`.
- **Google Drive sync** is optional. Each app keeps one JSON file, `<App name> data.json`, in the user's own Drive, in a folder per app: `petravanta/<App name>/<App name> data.json`. Anything else an app saves to Drive (exports, documents) goes in the same app folder. Images are the exception: they never go to Drive (see *Images* below). The `petravanta` folder is shared by all the apps (they use one OAuth client, so each sees the folder whichever app made it). A file saved before folders existed, in the root of My Drive, is **moved** (not copied) into the app's folder once, on the first connect, so its id stays the same and other devices carry on. Apps use the `drive.file` scope (they see only files and folders they created) and the shared OAuth client that allows `https://petravanta.github.io`. It saves a few seconds after each change, and merges with the browser copy on connect and whenever the app comes back into view.
- **Export backup** downloads the whole document as JSON, and **Import backup** merges one back in. Imports from other apps (a Fitbod CSV, a MacroFactor export) are read in the browser and become ordinary records.

### Images

Storage on Google Drive is the standard for everything people save **except images**. Photos and pictures don't belong in a Drive folder full of JSON, they fill people's storage, and Google Photos is where people already look for them. So:

- **Images never go to Google Drive.** An image is either in the person's Google Photos or only on the device.
- **Uploaded to Google Photos, it says where it came from.** Every photo an app uploads carries a description naming the app and what it is, such as `Wardrobe app · cut-out of Black tee`, so it makes sense when someone finds it in their library.
- **Images the app can make again stay on the device.** Crops, cut-outs, thumbnails and other images the app can regenerate from an original may live only in the browser's IndexedDB. An image the app can't make again and keeps only on the device goes into **Export backup** with everything else.
- **Photos permissions are asked for on their own.** Google Photos scopes are never added to the shared `google-token.js`, which stays `drive.file` only: an app that uses Google Photos asks for its scopes separately, when people first use that feature, so the other apps keep their one small Drive permission.
- **The app can't archive, people can.** Google's API gives apps no way to archive a photo, so an app's album shows in the person's photo timeline. The app's help says so and explains that they can open the album in Google Photos and choose **Archive** on its photos to keep them out of the timeline.

### Staying connected to Google Drive

These are static pages with no server, so Google gives them no refresh token: a Drive sign-in lasts an hour, and getting a new one opens Google's window, which browsers only allow right after a tap. That can't be made silent, but every app does the following so it is rare and costs at most one tap:

- **One sign-in for all the apps.** They share an origin and an OAuth client, so a token from one works in all. `shared/google-token.js` (paste it in between its marker comments, see *Pasted shared code*) keeps it under `localStorage` key `petravanta.google`, one per Google account, and tells open tabs when it changes. Reconnecting in one app reconnects every app on that browser, open tabs included.
- **The account as a hint.** After connecting, the app remembers the account's email and passes it as `login_hint`, so Google's window closes by itself rather than asking which account. A first connect suggests the account the other apps already use.
- **Renew on any tap.** Once the token has under ten minutes left, the next tap anywhere renews it. Load Google's script when the page opens, not on the tap, or the browser may block the window.
- **Open without waiting for Google.** The app opens on the browser's copy and keeps saving changes there; the first tap after the hour reconnects, merges Drive's copy in, then writes. Never put a "Reconnect" screen in front of data the browser already has.
- **Sign out forgets, doesn't revoke.** Signing out removes this browser's token. Revoking would cut off every app and every device that uses the same Google permission; people can remove it at myaccount.google.com/permissions.

`shared/drive-store.js` does all of this, the folders included (its `folder()` gives the app folder's id for other files, such as Mind Palace's Google Docs), for an app whose data is one JSON file (Fitness Coach, VoiceTrainer, Study Buddy and Mind Palace inline it). Skating Mentor, Nutrition Helper and Photo Timeline have their own Drive code and use `google-token.js` for the sign-in.

### When Google Drive says no

Google throttles busy apps and sometimes fails on its side, so a save can be refused for a while. Every app handles that the same way, and `shared/drive-store.js` does it for the apps that use it:

- **Back off and try again.** A `429`, a `403` whose reason is a rate limit (`userRateLimitExceeded`, `rateLimitExceeded`), or a `5xx` is retried up to 4 times inside the request, waiting 1, 2, then 4 seconds plus a random spread, or what Google's `Retry-After` asks for.
- **Keep trying by itself.** A save that still fails is tried again 30 seconds later, then 1, 2, 4 and up to every 5 minutes, until it gets through. Offline waits for the connection to come back. A full Drive or a refused permission waits for the person, since trying again can't fix it.
- **Fewer calls.** Once the app knows its file's id it writes straight to it, and looks for the file again only if Drive answers `404`.
- **Say what happened.** The status line names the problem in plain words and ends with Google's status and reason, such as `Google Drive is busy · trying again by itself (429 rateLimitExceeded)`, so a screenshot tells us what came back.

The store's `problem` is `null` when all is well, or:

| Field | Meaning |
|---|---|
| `kind` | `busy` (rate limit), `server` (Google's side, 5xx), `full` (Drive storage full), `denied` (other 403, usually a missing Drive permission), `missing` (404), `offline`, or `http` (anything else) |
| `text` | The sentence `status()` shows, ready for the status line |
| `status`, `reason`, `message` | Google's HTTP status, its reason string and its message, as sent (`0` and empty when offline) |
| `retrying`, `retryAt` | Whether the app will try again by itself, and when (a `Date`, or `null` when it waits for the person) |
| `at` | When it happened |

An expired sign-in is not a problem: it is the hour-long token running out, and the next tap renews it. `store.explain(error)` turns an error from the app's own Drive calls into the same shape. Apps with their own Drive code (Skating Mentor, Nutrition Helper, Photo Timeline) should back off and describe errors the same way.

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

Nutrition Helper, Project Tracker, Study Buddy and Mind Palace follow these rules. Fitness Coach merges by id and `deleted` but does not stamp `u` yet, and neither app writes `version` yet; both should catch up when they next change their data.

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

2. **A manifest**, `manifest.webmanifest`, with `name`, a short `short_name` for under the icon, `id` set to the app's own path (`/<repo>/`), `start_url` and `scope` both `./`, `display: standalone`, `background_color: #eef2f4`, `theme_color: #ffffff`, and the icons above (the 512 also listed as `maskable`). Copy one from an app that has it, such as Skating Mentor. All the apps share one site, petravanta.github.io, and Chrome reads `id` against the site's root rather than the app's folder, so `"id": "./"` would make every app the same app (installing one shows the others as already installed). Always write the full path.

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

   An app split into files (see *Splitting a large app* in [PATTERNS.md](PATTERNS.md)) lists its `css/` and `js/` files in `APP_SHELL` too, so it opens offline. An app that runs a model on the device may cache the model files itself, as *On-device machine learning* in PATTERNS.md describes; that is the one allowed exception to leaving other sites' files to the network.

When Chrome is ready to install an app, the **All apps** menu from `hub-link.js` also shows an **Install app** item.

Optional: **shortcuts** in the manifest for the one or two things people open the app to do (long-press the icon), as `./?do=<action>` URLs. The page reads `do` on load, does it, and removes it from the address with `history.replaceState` so a reload doesn't repeat it. Nutrition Helper has these.

An app with a build step (VoiceTrainer) keeps these files in `pwa/`, adds the head tags to its standalone page only, and copies `pwa/*` next to the page when it deploys.

All apps and the hub follow this. Fitness Coach and Nutrition Helper have their own `sw.js` that predates the shared worker and does the same job.

## Version and build info

Every app shows which build is running in a small line at the very bottom of the page, so a bug report or a screenshot says exactly what was deployed:

> v1.4.0 · `a1b2c3d` · built 11 Nov 2026, 09:23 · **Copy debug info**

- The short commit links to that commit on GitHub. **Copy debug info** copies the app, version, commit, build time, page URL, browser, screen, theme, service-worker and online state as plain text, ready to paste into an issue or a chat with a coding agent.
- The version (`v1.4.0`) is optional. An app that wants one keeps `{ "version": "1.4.0" }` in a `version.json` at its root and bumps it by hand; the commit and build time are always stamped.

Add two things:

1. **The script**, just before `</body>`, after `hub-link.js`:

   ```html
   <script src="https://petravanta.github.io/general/shared/version-footer.js" defer></script>
   ```

   In an app split into files it goes in `index.html`. [`shared/version-footer.js`](shared/version-footer.js) reads `version.json` next to the page and adds a `<footer>` at the end of `<body>`, styled with the app's `--muted`, `--line`, `--ink` and `--accent` tokens, so it follows light and dark themes and respects the phone's safe-area insets. An app with a fixed bottom bar adds an empty `<div data-version-footer></div>` where the line should go instead (for example after its scrolling content), so the bar doesn't cover it. The script also fills such a `<div>` when the app adds it later, so it can sit in a settings drawer; a full-screen app that shows the line only there (Mind Palace) adds `<meta name="version-footer" content="placed">` to `<head>` so no footer is added to the page. The info is also on `window.APP_BUILD` for the app's own error messages.

2. **The deploy workflow**, so `version.json` gets stamped: copy [`github/workflows/pages.yml`](github/workflows/pages.yml) to `.github/workflows/pages.yml` in the app. It deploys the repo to GitHub Pages on every push to `main` and writes `commit`, `built` and `repo` into `version.json` on the way (keeping any `version` already there). Then switch the repo's Pages source to GitHub Actions: `./github/apply-ruleset.sh <repo>` (or `.ps1`) does that for every repo that has the workflow, or by hand **Settings → Pages → Source → GitHub Actions**. The workflow checks the source first, so landing it before the switch is harmless: it stops early and Pages keeps deploying from the branch.

Until both are in place the footer still shows, with the page's last-modified date and the word *unstamped*, so a missing stamp is visible rather than silent. VoiceTrainer, which has a build step, keeps its own build line instead: its deploy workflow stamps `version.json` and the page offers a reload when a newer build is out.

## Notes for coding agents

Each app has an `AGENTS.md` that links back here and lists only what's specific to that app, plus a one-line `CLAUDE.md` containing `@AGENTS.md` so Claude Code reads the same notes.

When an agent opens a pull request, it turns on auto-merge (squash) in the same step, as *Merging pull requests* describes, unless the PR needs petravanta's decision, in which case it opens a draft and says what needs deciding.

`AGENTS.md` ends with a line saying which version of these standards the app was last brought in line with, `Checked against General as of 2026-11-22`. An agent picking up the app reads [`CHANGELOG.md`](CHANGELOG.md) from that date on to see what it needs to catch up with, and updates the date when it has.

### Working style

These are habits rather than rules, so they have no checklist row:

- **Queue first, build in batches.** A new ask goes into the app's queue (a list in its `AGENTS.md` or an issue) rather than being built straight away. When the owner says go, the queued items are built together.
- **One fresh session per batch, grouped by area.** Each batch starts from a clean session and the latest `main`, and holds related items (all the closet-screen changes, say), so the context stays small and the pull request reads as one change.
- **Test at the end of the batch, report once.** Test the whole batch as *Testing changes* describes, then send one report for it: what was built, what was tested, what's left in the queue.

## Testing changes

How an agent (or a person) checks a change before it's merged:

- **Visual changes** are checked at a desktop width (about 1280 px) and at a phone width of **390 px**, each in the **light and dark** themes: four looks. **Other changes** are checked at both widths in one theme.
- **Throwaway test data.** Anything a test creates has an obvious id or name prefix, such as `zz-`, and lives in a separate browser profile or the in-app browser, never the person's everyday one. Remove it afterwards. Never read, change or delete a person's real data to test something, and never connect a test profile to their Google Drive or Photos.
- **When there's no browser to look through** (the in-app browser pane is hidden or unavailable), use [`tools/screenshot.mjs`](tools/screenshot.mjs). It needs Node 22 or newer and an installed Chrome or Edge, nothing from npm: it starts the browser headless with its own throwaway profile and drives it over the DevTools protocol.

  ```sh
  node tools/screenshot.mjs go http://localhost:8000/ size 390x844 theme dark shot phone-dark.png
  node tools/screenshot.mjs go http://localhost:8000/ size 1280x800 theme light shot desktop-light.png full
  ```

  Its steps are `go URL`, `size WxH`, `theme light|dark`, `js EXPRESSION` (run code in the page and print the result), `shot FILE [full]`, `touch X Y`, `drag X1 Y1 X2 Y2` and `wait MS`, run in order. It can also be imported from a test script (`open()` returns the same steps as functions).

## Merging pull requests

Pull requests merge automatically by default. Nobody needs to press **Merge** on routine work.

- **Small, confident changes** can still go straight to `main`.
- **Everything else goes through a pull request that merges itself** once its checks pass (for example *Check data*). The person or agent who opens it turns on auto-merge with **squash** straight away (`gh pr merge --auto --squash`, or **Enable auto-merge** on the PR page). If the repo has no checks yet, it merges at once.
- **Hold one back on purpose.** A PR that needs petravanta's decision (a change of direction, something hard to undo, a design choice between options) is opened as a **draft**, or without auto-merge, and its description says what needs deciding. Turning auto-merge off on an open PR also holds it.
- **Only our own PRs.** Auto-merge is for PRs opened by petravanta or their coding agents. A PR from anyone else (say, someone proposing a new exercise in `data/`) waits for a review.
- **A failing check stops the merge.** Fix it on the branch and the PR merges when it goes green. Never skip or remove a check to get it through.
- Merges are squashed into one commit titled after the PR, and the branch is deleted afterwards.

Each repo needs **Allow auto-merge** switched on for this. [`github/repo-settings.json`](github/repo-settings.json) holds the settings (auto-merge, squash merges, delete branches after merge, offer to update a branch) and `.\github\apply-ruleset.ps1` (Windows) or `./github/apply-ruleset.sh` applies them together with the *Protect main* ruleset below. By hand: **Settings → General → Pull Requests**, tick *Allow auto-merge*, *Allow squash merging* and *Automatically delete head branches*.

## Protecting `main`

Every repo should have a ruleset called **Protect main** on its default branch that blocks force pushes and deleting the branch. Normal pushes and pull request merges work as before. The rule is [`github/main-branch-ruleset.json`](github/main-branch-ruleset.json).

To apply it, or roll out a change to it, run this once (it also applies the settings from *Merging pull requests*) on your own machine with the [GitHub CLI](https://cli.github.com/) signed in (`gh auth login`). [`github/apply-ruleset.ps1`](github/apply-ruleset.ps1) (Windows PowerShell 5.1 or pwsh) and [`github/apply-ruleset.sh`](github/apply-ruleset.sh) (Git Bash, macOS, Linux) do the same thing:

```powershell
.\github\apply-ruleset.ps1                # the hub and every app
.\github\apply-ruleset.ps1 my-new-app     # just one repo
.\github\apply-ruleset.ps1 -DryRun        # show what it would change
```

```sh
./github/apply-ruleset.sh                # the hub and every app
./github/apply-ruleset.sh my-new-app     # just one repo
```

Or by hand: in the repo, **Settings → Rules → Rulesets → New ruleset → Import a ruleset**, and pick `github/main-branch-ruleset.json`.

## Backups

Good storage means more than one copy. Every petravanta repo is kept in at least two independent places: GitHub, where we work, and a full local mirror, with an optional third copy on a separate drive. Each copy holds the whole history, and we test restoring from them, so no single place is the only home of the code. We keep the extra copies on our own drives rather than adding another hosting service.

### What gets copied

- **Each repo, as a mirror:** `F:\Dev\petravantaapps\_backups\<repo>.git`, made with `git clone --mirror`, so it holds every branch and tag, not just `main`. A mirror is a bare repo: there are no working files to edit in it, which also keeps it from being changed by accident.
- **The repo list:** `_backups\repos.json` records each repo's description, visibility, home page and default branch, which aren't in git.
- **Settings are already in git:** [`github/repo-settings.json`](github/repo-settings.json) and [`github/main-branch-ruleset.json`](github/main-branch-ruleset.json) come back with the hub's mirror. GitHub Pages is the one setting not in a file: every repo publishes from `main`, root folder, except VoiceTrainer, which deploys with GitHub Actions.
- **People's data is not in the repos** (*User data*). It lives in each person's browser and their own Google Drive (`<App name> data.json`), and **Export backup** in each app saves a copy. The repo backups don't cover it and don't need to.

### Keeping it fresh

[`github/backup-repos.ps1`](github/backup-repos.ps1) (Windows) and [`github/backup-repos.sh`](github/backup-repos.sh) (Git Bash, macOS, Linux) do the same thing: list petravanta's repos, clone a mirror of any new one and refresh the rest. Run them on your own machine. With the [GitHub CLI](https://cli.github.com/) signed in (`winget install --id GitHub.cli`, then `gh auth login`) they find every repo by themselves. Without it they still work, with plain git: they back up the repos named in [`github/repos.txt`](github/repos.txt), the mirrors already in `_backups` and the origins of your clones, and say that `gh` is missing.

```powershell
.\github\backup-repos.ps1                 # every repo
.\github\backup-repos.ps1 -DryRun         # show what would happen, change nothing
.\github\backup-repos.ps1 -Verify         # also check every mirror is whole
.\github\backup-repos.ps1 mind-palace     # just one
```

They are gentle on GitHub on purpose: **one** API call to list the repos, then plain `git fetch` one repo at a time, and a repo with nothing new downloads nothing. Please don't run them in a tight loop or in parallel.

- **When:** once a week on a schedule, and by hand after a big change (a merge you'd hate to redo, a new app). To schedule the weekly run in Windows (Sunday evening):
  ```powershell
  schtasks /Create /TN "petravanta backups" /SC WEEKLY /D SUN /ST 19:00 /TR "powershell -NoProfile -ExecutionPolicy Bypass -File F:\Dev\petravantaapps\general\github\backup-repos.ps1"
  ```
  This assumes a working clone of this repo at `F:\Dev\petravantaapps\general`; adjust the path if yours lives elsewhere.
- **New apps** are picked up by the next run with nothing to configure. Step 5 of *Adding a new app* runs it once straight away.

### A second copy (recommended)

One copy on one drive is one failure away from none. We recommend, but don't require, a second copy somewhere else: an external drive, or a folder in your Google Drive. Use `-Bundle` (or `--bundle`) to write one `<repo>.bundle` file per repo there; a bundle is a single file holding the whole repo with all its branches, so it copies and syncs cleanly.

```powershell
.\github\backup-repos.ps1 -Bundle "G:\My Drive\Backups\repos"
```

### Restoring

From a mirror, or a bundle, to a new empty repo (on GitHub or anywhere else):

```sh
git -C F:/Dev/petravantaapps/_backups/<repo>.git push --mirror https://github.com/petravanta/<repo>.git
# or from a bundle:
git clone --mirror <repo>.bundle <repo>.git && git -C <repo>.git push --mirror <new remote url>
```

`--mirror` sends every branch and tag and makes the remote match the copy exactly, so only push it to a new or empty repo. Then re-apply the settings (`.\github\apply-ruleset.ps1 <repo>` or `./github/apply-ruleset.sh <repo>`), turn Pages back on (see *What gets copied*) and add the repo's description from `repos.json`.

To just get working files back on your machine, `git clone F:/Dev/petravantaapps/_backups/<repo>.git <folder>`.

### Testing a restore

A backup we've never restored is a hope, not a backup. Every three months or so, pick one repo and check:

```powershell
git clone F:\Dev\petravantaapps\_backups\<repo>.git $env:TEMP\restore-test
git -C $env:TEMP\restore-test log --oneline -3   # matches the latest work on GitHub?
```

Open its `index.html` to see the app load, then delete the folder. If you keep bundles, test one of those too (`git clone <repo>.bundle`). `-Verify` checks every mirror is whole in between.

## Syncing every project

Work can sit on one machine for a while: a branch never pushed, a commit waiting on `main`, a pushed branch nobody opened a pull request for. [`github/sync-all.ps1`](github/sync-all.ps1) (Windows) and [`github/sync-all.sh`](github/sync-all.sh) (Git Bash, macOS, Linux) check every project in one go: they run the backups above, then look at every clone under `F:\Dev\petravantaapps` (any folder up to three levels down) and report what hasn't reached GitHub.

```powershell
.\github\sync-all.ps1                   # back up, then report: changes nothing in your files or branches
.\github\sync-all.ps1 -Push             # also push branches with commits GitHub doesn't have
.\github\sync-all.ps1 -Push -OpenPRs    # ...and open pull requests for branches that have none
.\github\sync-all.ps1 -SkipBackup       # report from what's on disk, without touching GitHub
```

The report lists, per clone: uncommitted or untracked files, stashes, branches with commits GitHub doesn't have, branches that were never pushed, branches that differ both ways (pull first), local branches already merged (safe to delete), and branches on GitHub that are ahead of `main` with no pull request. It ends with a **Needs you** list and is saved to `_backups\sync-report.txt`. A folder with no remote at all gets a hint with the `gh repo create … --private --source . --push` line that would put it on GitHub; sync-all never creates repos itself. `-OpenPRs` needs the GitHub CLI; everything else works with plain git.

What it will and won't do:

- **Report-only by default.** `-Push` pushes branches, `-OpenPRs` opens pull requests; nothing else changes. It never commits for you, never pushes `main` (it tells you instead), never force-pushes and never pushes a branch that has diverged.
- **Pull requests it opens are yours to merge.** It doesn't turn on auto-merge, and it never touches pull requests from other people.
- **It reads, rather than asks.** The fresh mirrors already hold every branch and every pull request's head (`refs/pull/N/head`), so the clones are compared against them on disk. Apart from the backup, the only calls to GitHub are the pushes and pull requests themselves.

### Good-citizen rate limiting

Bulk activity from one account across many repos can look like a misbehaving bot, so sync-all paces itself like a careful person would. These limits are on by default; please keep them:

- **One repo at a time**, never in parallel, with a **random 5 to 15 second pause** before every call to GitHub (the backup step pauses between repos too). `-Delay 10-30` slows it further.
- **Small caps per run:** at most **5 pushes** (`-MaxPushes`) and **2 new pull requests** (`-MaxPRs`). Anything over a cap is listed under **Next run** and picked up then.
- **A minimum gap between runs** of 60 minutes (`-MinInterval`), recorded in `_backups\sync-state.txt`. A run started too soon stops before doing anything. Only a run whose backup finishes counts: if one times out or is cut short, retry straight away and it **resumes**, skipping repos it already refreshed in the last 6 hours (listed in `_backups\sync-progress.txt`, which is cleared once the backup completes). `-SkipBackup` reports never count, because they don't touch GitHub.
- **A full stop on any refusal.** If GitHub answers 403, 429 or asks us to slow down, the run stops at once, doesn't retry, and the next runs wait out a cool-down: 6 hours, doubling after each further refusal up to 48 hours, back to normal after a clean run. Only a plain network hiccup is retried, twice, after 30 and then 60 seconds.
- **Plain git first.** Pushes are plain `git push`; the backups are `git fetch`; the GitHub API is used once to list the repos and once per new pull request.

Run it by hand once a week or after a burst of work. The scheduled weekly backup above can stay as it is, or point it at `sync-all.ps1` (report-only) instead of `backup-repos.ps1` to get the report too.

## Checking every project

[`CHECKLIST.md`](CHECKLIST.md) is the list of everything a project built on these standards has to cover, from the licence to the theme switch to the *Protect main* ruleset. [`github/standards.ps1`](github/standards.ps1) (Windows) and [`github/standards.sh`](github/standards.sh) (Git Bash, Linux; needs bash 4) read that list and check every repo against it, so bringing the apps in line is one command rather than a dozen repo-by-repo chores.

```powershell
.\github\standards.ps1                           # report for the hub and every app; changes nothing
.\github\standards.ps1 wardrobe                  # just one repo
.\github\standards.ps1 -Only auto-merge,license  # just some rows of the checklist
.\github\standards.ps1 -Offline                  # file checks only, no GitHub calls at all
.\github\standards.ps1 -Apply                    # also fix what can safely be fixed
```

The report lists, per repo, each row it doesn't meet yet (`GAP` for a *must*, `should` for a recommendation), then **By concern**: for each row, the repos that still miss it, which is the to-do list for a bulk change. Rows marked `manual` (a desktop check, say) are named once at the end. It is saved to `_backups\standards-report.txt`.

How it checks:

- **Files** (the licence, `AGENTS.md`, the hub link, the manifest) are read from the backup mirrors in `_backups`, so they cost GitHub nothing. Refresh the mirrors first (`sync-all` or `backup-repos`) to check today's state; a repo with no mirror yet is skipped and listed under **Needs you**.
- **Settings** (*Allow auto-merge*, squash, delete branches, the *Protect main* ruleset, Pages) are read from GitHub: two calls per repo, with a 2 to 5 second pause between them.
- **The hub's own lists** (the card on `index.html`, `shared/apps.json`, the `apply-ruleset` repo lists) are read from this clone of general.

What `-Apply` (`--apply`) does, and nothing more:

- **Repo settings and the ruleset:** runs `apply-ruleset` for repos that miss them (at most 5 repos per run, `-MaxSettings`).
- **Backups:** makes the first mirror for a repo that has none.
- **File fixes:** for the rows whose *Fix* column names one (the MIT `LICENSE`, the README *License* section, `CLAUDE.md`, a starter `AGENTS.md`, the manifest `id`), it makes the change in a scratch clone of the mirror, pushes one branch per repo (`standards/<date>`), opens **one small pull request** and turns on auto-merge (squash), as *Merging pull requests* describes. At most **2 pull requests per run** (`-MaxPRs`); the rest wait for the next run. A repo whose earlier `standards/…` branch is still open is skipped until that one is merged.
- Everything else (the theme switch, the shared look, Drive sign-in) needs a person or an agent working in that app, so it stays in the report.

It keeps the same manners as *Syncing every project*: one repo at a time, a random 5 to 15 second pause before every write, at least 60 minutes between `-Apply` runs (`-MinInterval`), and a full stop on any 403 or 429 that also starts sync-all's cool-down (they share `_backups\sync-state.txt`).

To add a standard, add its section here and its row to `CHECKLIST.md` in the same change. The *Check* column is a tiny language the scripts read: `file A,B` (any of these paths exists), `grep REGEX` (the app's own `.html`, `.js`, `.css` and manifest files match), `grep:PATHS REGEX` (these files or folders match), `nogrep REGEX` and `nogrep:PATHS REGEX` (the same files must *not* match), `shared` (every pasted shared block is current, as `sync-shared -Mirrors` reports), `hub-file` and `hub-grep:PATH` (the same, in general), `setting NAME` (a GitHub repo setting is true), `ruleset NAME`, `pages`, `mirror`, `clone` and `manual`. `{repo}` stands for the repo's name. A new automatic fix needs code in both scripts; a new check usually doesn't.

## Pasted shared code

Most shared code is loaded by URL (`theme.css`, `hub-link.js`, `theme-switch.js`, `version-footer.js`, `back-stack.js`, `app-sw.js`), so a change here reaches every app by itself. A few pieces can't be: [`shared/google-token.js`](shared/google-token.js), [`shared/drive-store.js`](shared/drive-store.js) and [`shared/local-day.js`](shared/local-day.js) are pasted into each app between their marker comments, and [`shared/blocks.txt`](shared/blocks.txt) lists them with their markers. Pasted copies drift, so:

- **After any change to `shared/`,** add a line to [`CHANGELOG.md`](CHANGELOG.md) and run `sync-shared` to see which apps now have an old copy.
- [`github/sync-shared.ps1`](github/sync-shared.ps1) (Windows) and [`github/sync-shared.sh`](github/sync-shared.sh) (Git Bash, macOS, Linux) look at every app clone under `F:\Dev\petravantaapps` and report each pasted block that differs from `shared/` here (ignoring its opening comment, indentation and blank lines). They never touch GitHub.

  ```powershell
  .\github\sync-shared.ps1               # report every app; changes nothing
  .\github\sync-shared.ps1 wardrobe -Diff  # one app, showing the lines that differ
  .\github\sync-shared.ps1 -Apply        # replace the old blocks in your clones' files
  .\github\sync-shared.ps1 -Mirrors      # check what's on GitHub (the backup mirrors) instead of your clones
  ```

  Each stale copy is reported as **old** (it matches an earlier version of the file here, so replacing it is safe) or **edited** (it matches no version: the app changed lines inside the markers). `-Apply` (`--apply`) replaces old copies in the working files only. It leaves edited ones alone until the app's own lines are moved after the closing marker (or into `shared/` here), unless `-Force` says to drop them; it skips a file with uncommitted changes; and it never commits or pushes. Review the change, test the app and open its pull request as usual. Telling old from edited needs this repo's history, so run it from a full clone of general, not a shallow one.
- An app split into files (see *Splitting a large app* in [PATTERNS.md](PATTERNS.md)) keeps whole copies as `js/shared/<file>` instead of pasting them; sync-shared compares and replaces those whole.
- An app never edits its pasted copy. Its own additions (extra CSS rules, say) go after the closing marker; a change every app needs goes into `shared/` here first, then out to every app.
- The *shared-current* checklist row runs the same comparison against the backup mirrors, so `standards` reports stale copies too.

## Shared look

Fitness Coach, Skating Mentor, Nutrition Helper, Special Trip Planner, Photo Timeline, Project Tracker, Study Buddy, Mind Palace, Dance Floor, Wardrobe and Mixmaster (and the hub) share one set of colors, fonts and components. They all load one stylesheet, [`shared/theme.css`](shared/theme.css), by URL, so a change to it reaches every app the next time it opens, with no update to send out. Each app links it in `<head>` (after the theme head snippet and the fonts), then sets only its `--accent`, `--accent-ink` and `--accent-soft` values in its own `<style>` after it:

```html
<link rel="stylesheet" href="https://petravanta.github.io/general/shared/theme.css">
<style>
:root{--accent:#4f46c8;--accent-ink:#fff;--accent-soft:#e6e4fb}
/* dark accent under the usual two dark selectors, then the app's own CSS */
</style>
```

- **Offline:** `shared/app-sw.js` caches `theme.css` with the other shared files, so an installed app still opens styled without a connection.
- **Backward compatible, always.** Because every app picks up a change at once, `theme.css` may add tokens, classes and refinements, but never renames or removes a class or token, and never changes what one means. A change that would break apps goes in a new file (`theme-v2.css`) that apps move to one at a time. Check every change on the style guide at [`look/`](look/) and on two or three apps before merging.
- **An app's own CSS** goes in its own `<style>` (or `css/app.css`) after the link, using the tokens. Never copy `theme.css` into an app.

Accents:

| App | Light accent | Dark accent |
| --- | --- | --- |
| Hub | `#11897a` teal | `#3cc3ad` |
| Fitness Coach | `#4f46c8` indigo | `#9d95ff` |
| Skating Mentor | `#c2306f` pink | `#f0679f` |
| VoiceTrainer | `#2f3c95` indigo-blue | `#9aa6ff` |
| Nutrition Helper | `#c2410c` orange | `#fb8a4c` |
| Special Trip Planner | `#1d6fb8` blue | `#6cb4ff` |
| Photo Timeline | `#7442b8` violet | `#bb94ff` |
| Project Tracker | `#2e7d32` green | `#6fd39a` |
| Study Buddy | `#0b7285` cyan | `#5fd0e4` |
| Mind Palace | `#9a6700` amber | `#f2c14e` |
| Dance Floor | `#a21caf` fuchsia | `#e879f9` |
| Wardrobe | `#475569` slate | `#a5b4c8` |
| Mixmaster | `#5d7a0f` chartreuse | `#b8d957` |

VoiceTrainer has its own type and panel styles but follows the same token names for `--bg`, `--ink`, `--muted`, `--line` and `--accent`.

Conventions the apps already share:

- Light and dark themes with the shared theme switch (see *Light and dark themes* above).
- Phone-first layout: `viewport-fit=cover`, safe-area insets on sticky headers and sheets, 16px minimum side gutter.
- User data in the browser with optional Google Drive sync, as *User data* above describes.
- No sign-up; each app is a static page served by GitHub Pages, deployed from its `main` branch by the workflow in *Version and build info*.

### Nightbloom (the look since 2026-11)

Plum-black nights, bone-white days, one bright accent per app. The live style guide at [`look/`](look/) ([petravanta.github.io/general/look/](https://petravanta.github.io/general/look/)) shows every token and component in both themes, with any app's accent; check a change there first.

- **Tokens.** Colors: `--bg`, `--surface`, `--raised` (drawers, menus), `--sunk`, `--line`, `--ink`, `--muted`, `--faint` (decoration and placeholders only, not body text), the `--lv-*` levels, and status pairs `--ok`/`--ok-soft`, `--warn`/`--warn-soft`, `--danger`/`--danger-soft`. Type sizes `--t-xs` … `--t-2xl`; spacing `--s-1` … `--s-7` (4, 8, 12, 16, 24, 32, 48 px); radii `--r-sm`, `--r`, `--r-lg`; `--tap` (44 px); `--shadow-1`, `--shadow-2`, `--glow`, `--scrim`, `--ease`, `--dur`. Use tokens rather than raw values in app CSS, so the next refresh reaches the app too.
- **Text contrast.** `--ink` and `--muted` stay at 4.5:1 or better on `--surface` and `--bg` in both themes; so do the status colors on their `-soft` backgrounds.
- **Status line.** An app that saves anywhere has one status line, `<span class="status" data-state="…">` (or its existing `.save-state` with a `data-state`). `data-state` is `ok`, `saving`, `local` or the Drive store's `problem.kind` (*When Google Drive says no*), and its text is `problem.text`. Problems that wait for the person (`full`, `denied`) also get a `.banner.bad`; `.banner.ok` and `.banner.warn` exist too.
- **Drill-down screens** start with `<button class="back">`, which closes the view through its `BackStack` layer (*Back button*).
- **Touch.** On a touch screen, buttons, tabs and fields grow to `--tap` and fields use 16 px text so phones don't zoom in.
- **Motion** is short and only where something moves in or out (drawers, sheets, toasts); all of it turns off with *reduce motion*.

When you change the shared look, update `shared/theme.css` here and add a CHANGELOG line; apps need no change. Apps that still paste an old copy between the `Shared look` markers replace that block with the `<link>` above (moving any of their own lines inside the markers into their own `<style>`).

## Forms and dates

Small things every app gets right the same way:

- **Days are local.** A date someone picks or logs is a day on their own calendar. Get it with `LocalDay.today()` or `LocalDay.of(date)` from [`shared/local-day.js`](shared/local-day.js) (pasted in like the other shared code). Never use `toISOString().slice(0, 10)` for it: that is the UTC date, so in the evening, west of Greenwich, it is already tomorrow.
- **Date fields** use the browser's native date picker (`<input type="date">`) and save `YYYY-MM-DD`. A value saved earlier in a shorter form (just `2025-03`, say) is shown as it is and kept until the person picks a full date; the app never rewrites it on its own.
- **Repeat values are suggested.** A free-text field whose values repeat (brands, sizes, tags, places) suggests the values already used, most used first (a `<datalist>` is enough), and still takes a new one.
- **Every overlay can be closed three ways:** a visible **Close** button, the **Esc** key, and the phone's **Back** gesture. That goes for close-ups, sheets, drawers and dialogs; *Back button* below says how, with `shared/back-stack.js`.
- **Thumbnails fit, they don't crop.** Image thumbnails use `object-fit: contain`, so the whole picture shows.

## Back button

The browser's Back button, the phone's Back gesture and a mouse's back button close whatever is in front, not the app. Back leaves the app only from its root view.

**What counts as a view in front:** anything that opens over the app and has its own way to close: dialogs, sheets, drawers, menus (the *All apps* menu too), close-ups of a photo, and drill-down screens such as a detail page opened from a list or a settings sub-page. Not tabs, filters, sorting or scrolling: Back doesn't walk back through those, because they aren't something people "go into". A multi-step form is one view, so Back closes it rather than stepping through it.

**How:** load [`shared/back-stack.js`](shared/back-stack.js) by URL, before `hub-link.js`:

```html
<script src="https://petravanta.github.io/general/shared/back-stack.js" defer></script>
<script src="https://petravanta.github.io/general/shared/hub-link.js" defer></script>
```

Then, when a view opens, push it, and close it through the layer it returns:

```js
function openItem(item) {
  render(item); sheet.hidden = false;
  var layer = BackStack.push(function (reason) { sheet.hidden = true; }, { esc: true });
  sheet.querySelector('.close').onclick = function () { layer.close(); };
}
```

- **One close function.** The function given to `push()` runs exactly once, whichever way the view goes: Back (`'back'`), the app's own `layer.close()` (`'close'`: the Close button, after Save, a tap outside), Esc (`'esc'`) or a view beneath it closing (`'parent'`). Always close through `layer.close()`, never by hiding the view alone, so its history entry goes too and the next Back doesn't land on a stale one.
- **Esc for free.** `{ esc: true }` makes Esc close the front view. Leave it off where the view handles Esc itself (a native `<dialog>`, whose `close` event then calls `layer.close()`).
- **Nested views** stack: Back closes the front one only. Closing a view also closes everything opened on top of it.
- **Unsaved input.** For Back only, the function may return `false` to keep the view open, for example to ask "Discard changes?". The entry is put back.
- **Never trap people.** Push only when someone opens something (a tap or a key), never on page load, and never at the root view: no "press Back again to exit". Browsers skip entries that no one asked for anyway.
- **No URL changes.** The script keeps the URL as it is. Views that already have their own URL (a `#/item/42` route) get Back from the browser and don't need it; use one way per view, not both.
- **Reloads.** After a reload with views open, the page steps back to its root entry, since those views are gone.
- [`shared/hub-link.js`](shared/hub-link.js) uses it for the *All apps* menu when `back-stack.js` is on the page, and [`shared/app-sw.js`](shared/app-sw.js) keeps it for offline use. It is loaded by URL rather than pasted in, so it isn't part of `sync-shared`.

Check it on a phone (or at 390 px in the in-app browser): open each view, press Back, and the view closes while the app stays; press Back at the root, and the app is left.
