# Standards checklist

Everything a project built on the shared template has to cover, one row per concern. [`STANDARDS.md`](STANDARDS.md) explains each one; this page is the list to tick off, and [`github/standards.ps1`](github/standards.ps1) / [`github/standards.sh`](github/standards.sh) read it to check every repo in one go (see *Checking every project* in STANDARDS.md).

How to read a row:

- **Level:** `must` is part of the standard today, `should` is recommended (or not every app can follow it yet), `planned` is agreed but not rolled out, so it is reported without counting as a gap.
- **Applies to:** `all` repos, the `hub` (general) only, the `apps` only, or apps that have a feature: `data` (a `data/` folder), `drive` (Google sign-in), `photos` (a photo picker). `!repo` leaves one repo out.

Optional patterns in [`PATTERNS.md`](PATTERNS.md) and the agents' working style have no rows: they aren't required.
- **Check:** how the script tests it. `manual` means a person has to look.
- **Fix:** what `-Apply` (`--apply`) does about a gap. `-` means it only reports it.

When you add a standard, add its row here in the same change. Keep the *Check* cell free of `|` characters, because the scripts split rows on them.

## Repo and licence

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| license | must | all | `file LICENSE` | license | MIT `LICENSE` at the root ([License](STANDARDS.md#license)) |
| license-holder | must | all | `grep:LICENSE Copyright \(c\) [0-9]{4} Petra Vanta` | - | Copyright line names Petra Vanta |
| readme-license | must | all | `grep:README.md ^## License` | readme-license | README ends with a `## License` section |
| third-party | must | all | `manual` | - | Other people's material is listed in `THIRD_PARTY_NOTICES.md`, copyleft only with petravanta's OK |
| agents-md | must | apps | `file AGENTS.md` | agents-md | `AGENTS.md` with the app-specific notes ([Notes for coding agents](STANDARDS.md#notes-for-coding-agents)) |
| agents-link | must | apps | `grep:AGENTS.md general/blob/main/STANDARDS\.md` | - | `AGENTS.md` links back to STANDARDS.md |
| claude-md | must | apps | `grep:CLAUDE.md @AGENTS\.md` | claude-md | One-line `CLAUDE.md` containing `@AGENTS.md` |
| agents-checked | should | apps | `grep:AGENTS.md Checked against General as of [0-9]{4}-[0-9]{2}-[0-9]{2}` | - | `AGENTS.md` says when the app was last checked against these standards ([Notes for coding agents](STANDARDS.md#notes-for-coding-agents)) |
| changelog | must | hub | `file CHANGELOG.md` | - | `CHANGELOG.md` with one dated line per standards or shared-code change ([Pasted shared code](STANDARDS.md#pasted-shared-code)) |

## GitHub settings and safety copies

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| pages | must | all | `pages` | - | GitHub Pages is on (from `main`, or Actions for a build step) |
| ruleset | must | all | `ruleset Protect main` | settings | *Protect main* ruleset: no force push, no deleting main ([Protecting main](STANDARDS.md#protecting-main)) |
| auto-merge | must | all | `setting allow_auto_merge` | settings | *Allow auto-merge* on ([Merging pull requests](STANDARDS.md#merging-pull-requests)) |
| squash-merge | must | all | `setting allow_squash_merge` | settings | Squash merging allowed |
| delete-branch | must | all | `setting delete_branch_on_merge` | settings | Branches deleted after merge |
| backup | must | all | `mirror` | backup | Local mirror in `_backups\<repo>.git` ([Backups](STANDARDS.md#backups)) |
| local-clone | should | all | `clone` | - | A working clone under `F:\Dev\petravantaapps`, so sync-all checks it ([Syncing every project](STANDARDS.md#syncing-every-project)) |

## Listed on the hub

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| hub-card | must | apps | `hub-grep:index.html petravanta\.github\.io/{repo}/` | - | A card on the hub page ([Adding a new app](STANDARDS.md#adding-a-new-app)) |
| hub-menu | must | apps | `hub-grep:shared/apps.json "id": "{repo}"` | - | In `shared/apps.json`, so it shows in every app's menu |
| ruleset-list | must | apps | `hub-grep:github/apply-ruleset.sh [( ]{repo}[ )]` | - | In the repo list of `apply-ruleset.sh` |
| ruleset-list-ps1 | must | apps | `hub-grep:github/apply-ruleset.ps1 '{repo}'` | - | In the repo list of `apply-ruleset.ps1` |
| glyph | should | all | `hub-file tools/glyphs/{repo}.svg` | - | Its icon glyph kept in `tools/glyphs/` so icons can be remade |

## Page: back link, themes, layout

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| hub-link | must | apps | `grep data-hub-link` | - | **All apps** link in the header ([Back link to the hub](STANDARDS.md#back-link-to-the-hub)) |
| hub-link-script | must | apps | `grep general/shared/hub-link\.js` | - | Loads `hub-link.js` by URL (app switcher menu) |
| theme-head | must | apps | `grep petravanta\.theme` | - | Head snippet applies the saved theme before first paint ([Light and dark themes](STANDARDS.md#light-and-dark-themes)) |
| theme-switch | must | apps | `grep general/shared/theme-switch\.js` | - | Loads `theme-switch.js` by URL |
| dark-tokens | must | all | `grep :root\[data-theme="dark"\]` | - | Color tokens with dark values, also under `:root[data-theme="dark"]` |
| shared-look | must | apps !voicetrainer | `grep Shared look` | - | `shared/theme.css` inlined between the *Shared look* markers ([Shared look](STANDARDS.md#shared-look)) |
| phone-layout | must | all | `grep viewport-fit=cover` | - | Phone-first: `viewport-fit=cover`, safe-area insets, 16px gutters |
| desktop-layout | must | all | `manual` | - | Checked at desktop width and at 390 px, light and dark ([Testing changes](STANDARDS.md#testing-changes)) |
| test-data | must | all | `manual` | - | Tests use throwaway `zz-` data in a separate browser profile, never a person's real data |
| version-footer | must | all !voicetrainer | `grep shared/version-footer\.js` | - | Loads `version-footer.js`: version, commit and build time at the bottom of the page ([Version and build info](STANDARDS.md#version-and-build-info)) |
| version-stamp | must | all !voicetrainer | `file .github/workflows/pages.yml` | - | Pages workflow stamps `version.json` on deploy; Pages source set to GitHub Actions |

## Shared code

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| shared-current | must | apps | `shared` | - | Pasted shared code (`google-token.js`, `drive-store.js`, `local-day.js`, `theme.css`) matches `general/shared/`; run `sync-shared` ([Pasted shared code](STANDARDS.md#pasted-shared-code)) |

## Forms and dates

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| local-day | should | apps | `nogrep toISOString\(\)\.slice\(0, ?10\)` | - | Days are local (`LocalDay` from `local-day.js`), never `toISOString().slice(0, 10)` ([Forms and dates](STANDARDS.md#forms-and-dates)) |
| overlay-close | must | apps | `manual` | - | Every overlay closes with a visible Close button, Esc and the phone's Back gesture |
| back-stack | planned | apps | `grep general/shared/back-stack\.js` | - | Loads `back-stack.js` by URL, so Back closes the view in front ([Back button](STANDARDS.md#back-button)); apps with no view over another can skip it |
| back-closes-front | planned | apps | `manual` | - | Back closes each dialog, sheet, drawer, menu, close-up and detail screen; Back at the root leaves the app; Close and Esc go through `layer.close()` |
| date-fields | should | apps | `manual` | - | Native date picker saving `YYYY-MM-DD`; older partial dates kept until a full one is picked |
| repeat-values | should | apps | `manual` | - | Free-text fields that repeat suggest values already used, most used first |
| thumbs-contain | should | photos | `manual` | - | Image thumbnails fit (`object-fit: contain`) rather than crop |

## Installing on a phone

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| manifest | must | all | `file manifest.webmanifest,pwa/manifest.webmanifest` | - | `manifest.webmanifest` ([Installing on a phone](STANDARDS.md#installing-on-a-phone)) |
| manifest-id | must | all | `grep:manifest.webmanifest,pwa/manifest.webmanifest "id": "/{repo}/"` | manifest-id | Manifest `id` is the full path `/<repo>/`, never `./` |
| icons | must | all | `file icon-512.png,pwa/icon-512.png,icons/icon-512.png` | - | Icons made with `tools/make-icons.js` |
| maskable-icon | should | all | `file icon-maskable-512.png,pwa/icon-maskable-512.png,icons/icon-maskable-512.png` | - | Maskable icon for Android |
| service-worker | must | all | `file sw.js,pwa/sw.js` | - | `sw.js` (the shared `app-sw.js`, or an older own one) |
| sw-register | must | all | `grep serviceWorker\.register` | - | Page registers the worker, on the real site only |

## Built-in knowledge (apps with a `data/` folder)

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| data-schema | must | data | `file data/schema` | - | A JSON Schema per dataset in `data/schema/` ([Data, not code](STANDARDS.md#data-not-code)) |
| check-data | must | data | `grep:.github/workflows ajv` | - | *Check data* workflow validates every pull request |
| check-script | must | data | `file scripts/check-data.js` | - | `scripts/check-data.js` checks ids and references |
| contributing | must | data | `file CONTRIBUTING.md` | - | `CONTRIBUTING.md` for adding an entry |
| extending-table | must | data | `grep:README.md Extending` | - | README *Extending the app* table |

## User data and Google Drive (apps with Google sign-in)

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| drive-scope | must | drive | `grep drive\.file` | - | Only the `drive.file` scope ([User data](STANDARDS.md#user-data)) |
| drive-folders | must | drive | `grep google-apps\.folder` | - | Saves under `petravanta/<App name>/` and moves older root files there once ([Where it lives](STANDARDS.md#where-it-lives)) |
| shared-token | must | drive | `grep petravanta\.google` | - | Shared sign-in via `google-token.js` ([Staying connected](STANDARDS.md#staying-connected-to-google-drive)) |
| drive-backoff | must | drive | `grep Retry-After` | - | Backs off and retries on Google's rate limits and 5xx, and the status line names the problem with Google's status and reason ([When Google Drive says no](STANDARDS.md#when-google-drive-says-no)) |
| export-import | must | all | `manual` | - | Export and Import backup of everything people save |
| data-shape | should | drive | `manual` | - | One document with `version`, records with `id` and `u`, a `deleted` list, merged without loss |

## Photos (apps that take images)

| ID | Level | Applies to | Check | Fix | What |
| --- | --- | --- | --- | --- | --- |
| photo-drop | must | photos | `grep dragover` | - | Photos can be dropped anywhere on the page ([Adding photos](STANDARDS.md#adding-photos)) |
| images-not-drive | must | photos | `manual` | - | Images never go to Google Drive: Google Photos or the device only ([Images](STANDARDS.md#images)) |
| photos-description | must | photos | `manual` | - | Photos uploaded to Google Photos have a description naming the app |
| photos-scope | must | photos | `manual` | - | Google Photos scopes asked for separately, never added to `google-token.js` |
| photos-archive-help | should | photos | `manual` | - | Help explains archiving the app's Google Photos album by hand |
