# Shared standards for petravanta's apps

These apply to every app linked from the hub at **https://petravanta.github.io/general/**: [Fitness Coach](https://github.com/petravanta/fitness-coach), [Skating Mentor](https://github.com/petravanta/skating-mentor), [VoiceTrainer](https://github.com/petravanta/voicetrainer), [Nutrition Helper](https://github.com/petravanta/nutrition-helper) and [Special Trip Planner](https://github.com/petravanta/special-trip-planner).

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

## Adding a new app

1. Publish it on GitHub Pages under `petravanta.github.io/<repo>/`.
2. Add the back link (above) and the theme switch (below), and follow *Data, not code* for its content.
3. Apply the *Protect main* ruleset: `./github/apply-ruleset.sh <repo>`.
4. Add a card for it to [`index.html`](index.html): copy an existing `<li class="app …">`, set its name, link, one-line description and icon, and add a `--app` / `--app-soft` accent pair (light and dark) in the `<style>` block. Also add the repo to `repos` in `github/apply-ruleset.sh`.

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

## Data, not code, for what an app knows

Content that people might want to review or add to (exercises, sports, equipment, skills, drills) lives in JSON files under `data/` in each app, not as literals in the code. That keeps every extension point easy to see, and lets anyone add an entry with a pull request.

- One file per dataset, `data/<dataset>.json`: an array of objects, one per entry, with readable field names. The order in the file is the order the app shows.
- Every entry has a stable `id` (lowercase letters, digits and hyphens). Saved user data refers to these ids, so an id is never renamed or reused once it has shipped.
- Each dataset has a JSON Schema, `data/schema/<dataset>.schema.json`, with a `description` on every field, enums for closed sets, and `additionalProperties: false`.
- The app loads the files with `fetch()` at startup and maps them onto whatever internal shape the code uses. User data (progress, logs, settings) stays separate and refers to entries by id.
- A `Check data` GitHub Actions workflow runs on every pull request: it validates each file against its schema with `ajv-cli`, and `scripts/check-data.js` checks what a schema can't (unique ids, references that exist).
- The README has an **Extending the app** table listing each dataset, its file, its schema and what it controls, and `CONTRIBUTING.md` walks a non-programmer through adding an entry.
- Behavior is still code. A new kind of entry that the app has to treat differently (a new movement pattern, a new skating style) means changing the code and the schema enum together.

Fitness Coach (exercises, sports, equipment), Skating Mentor (skills) and VoiceTrainer (reading texts, practice words, breath and control exercises) follow this. VoiceTrainer has a build step, so `build.js` inlines its data files into the page instead of fetching them.

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

Fitness Coach, Skating Mentor, Nutrition Helper and Special Trip Planner (and the hub) share one set of colors, fonts and components. The canonical copy is [`shared/theme.css`](shared/theme.css). Each app inlines it between the `Shared look` and `end shared look` comments and only overrides the `--accent`, `--accent-ink` and `--accent-soft` values after it:

| App | Light accent | Dark accent |
| --- | --- | --- |
| Hub | `#11897a` teal | `#3cc3ad` |
| Fitness Coach | `#4f46c8` indigo | `#9d95ff` |
| Skating Mentor | `#c2306f` pink | `#f0679f` |
| VoiceTrainer | `#2f3c95` indigo-blue | `#9aa6ff` |
| Nutrition Helper | `#c2410c` orange | `#fb8a4c` |
| Special Trip Planner | `#1d6fb8` blue | `#6cb4ff` |

VoiceTrainer has its own type and panel styles but follows the same token names for `--bg`, `--ink`, `--muted`, `--line` and `--accent`.

Conventions the apps already share:

- Light and dark themes with the shared theme switch (see *Light and dark themes* above).
- Phone-first layout: `viewport-fit=cover`, safe-area insets on sticky headers and sheets, 16px minimum side gutter.
- Data stays in the browser (`localStorage`), with **Export backup** / **Import backup** as JSON, and optional Google Drive sync using the `drive.file` scope and the shared OAuth client that allows `https://petravanta.github.io`.
- Google Drive is where a user's history lives across devices: each app keeps one JSON file (`<App name> data.json`) in the user's own Drive, saved a few seconds after each change and merged with the browser copy on connect and when the app comes back into view. User data, including imports from other apps, is loaded from inside the app and never committed to a repo.
- Merging two copies (Drive, or an imported backup): logged records carry an `id` and are combined by id, so nothing logged on either device is lost; a `deleted` list of ids carries deletions across; and settings-like objects carry an `updatedAt`, with the newer copy winning. Nutrition Helper also stamps each record with `u` (last edit time) so the newer edit of the same record wins.
- No sign-up; each app is a static page served by GitHub Pages from its `main` branch.

When you change the shared look, update `shared/theme.css` here and the inlined copy in each app together.
