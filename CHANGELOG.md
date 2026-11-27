# Changelog

One dated line per change to the standards ([STANDARDS.md](STANDARDS.md), [CHECKLIST.md](CHECKLIST.md)) or to the shared code in [`shared/`](shared/), newest first. Each app's `AGENTS.md` ends with `Checked against General as of <date>`: to bring an app up to date, read the lines after that date, make the changes, run `sync-shared`, and move the date (STANDARDS.md, *Pasted shared code*).

Add a line in the same change as the edit it describes. Name what an app has to do, if anything.

- 2026-11-27: *Shared look* refreshed as **Nightbloom**: plum-tinted neutrals, new `--raised`, status (`--ok`, `--warn`), type, spacing, radius, shadow and `--tap` tokens, a `.status` line with `data-state`, `.banner.ok/.warn/.bad`, `.back`, touch-size targets, and a live style guide at `look/`. Class and token names are unchanged. Apps: run `sync-shared -Apply` for the new `theme.css`, update `<meta name="theme-color">` dark to `#16131b`, and give the save status a `data-state`.
- 2026-11-22: New *Pasted shared code* section, `shared/blocks.txt` and `github/sync-shared.ps1`/`.sh`: report (and with `-Apply` replace) stale pasted copies of `google-token.js`, `drive-store.js`, `local-day.js` and `theme.css`. Apps: run it and refresh old copies; add `Checked against General as of <date>` to `AGENTS.md`.
- 2026-11-22: *Images* (in *User data*): images never go to Google Drive; Google Photos uploads carry a description naming the app; regenerable images may stay in IndexedDB only; Photos scopes stay out of `google-token.js`; help explains archiving the app's album by hand. Apps that take photos: check against it.
- 2026-11-22: *Forms and dates*: local days via new `shared/local-day.js` (never `toISOString().slice(0, 10)`), native date pickers that keep older partial dates, suggestions for repeat values, Close/Esc/Back on every overlay, thumbnails that fit rather than crop.
- 2026-11-22: *Testing changes*: both widths and both themes for visual changes, throwaway `zz-` test data in a separate profile, and `tools/screenshot.mjs` for headless screenshots. *Working style* notes for agents.
- 2026-11-22: New [PATTERNS.md](PATTERNS.md) with optional patterns: splitting a large app into files without a build, and on-device machine learning.
- 2026-11-19: Version footer (`shared/version-footer.js`) and the Pages deploy workflow that stamps `version.json` are required. Apps: add both.
- 2026-11-19: Apps save to Google Drive under `petravanta/<App name>/`, moving older root files there once; `shared/drive-store.js` does it and exposes `folder()`. Apps with their own Drive code: do the same.
- 2026-11-14: [CHECKLIST.md](CHECKLIST.md) itemizes every standard; `github/standards.ps1`/`.sh` check (and partly fix) every repo.
- 2026-11-14: MIT licence for every repo, other people's material in `THIRD_PARTY_NOTICES.md`.
- 2026-11-14: Backups and sync-all: local mirrors of every repo, and a report of local work not yet on GitHub.
- 2026-10-19: One Google sign-in shared by every app (`shared/google-token.js`).
- 2026-10-19: Every app is installable (manifest with its own `id`, icons, `sw.js` with the shared `app-sw.js`), and the *All apps* link became an app switcher menu.
- 2026-10-18: Apps that take photos also take them by drag and drop.
- 2026-10-17: Built-in knowledge as `data/*.json` with schemas; user data shape and merge rules; shared theme switch; *Protect main* ruleset.
- 2026-10-16: Hub, the *All apps* back link and the first standards.
