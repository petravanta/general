# Optional patterns

Ways of solving a problem that one app worked out and other apps can use when they meet the same problem. Unlike [STANDARDS.md](STANDARDS.md), nothing here is required, and none of it has a row in [CHECKLIST.md](CHECKLIST.md). An app that uses a pattern says so in its `AGENTS.md`. A pattern that most apps end up following can be promoted to a standard.

## Splitting a large app without a build

*Worked out for Wardrobe.* Most apps are one `index.html`. Once that page passes about **100 KB** it gets hard to read and to edit, and an app may split it:

```
index.html            the page: markup, the head snippets and the script tags
css/app.css           the app's own styles
js/shared/*.js        shared code, whole copies: google-token.js, drive-store.js, local-day.js
js/*.js               the app's own code, in a few files by area
```

- **No build step.** The files are loaded with plain `<link rel="stylesheet">` and `<script src="js/….js" defer>` tags (or `type="module"`), so what's in the repo is what's served, and GitHub Pages deploys it as before.
- **Shared code comes in as whole files.** Instead of pasting a block between markers, the app keeps an unchanged copy of each pasted shared file in `js/shared/` (the shared look is linked by URL, like in every app). `sync-shared` compares those copies whole and `-Apply` replaces them (STANDARDS.md, *Pasted shared code*).
- **Offline still works.** The app's `sw.js` lists the new files in `APP_SHELL`; the shared worker already fetches the app's own files network-first with the cache as fallback.
- **The rest is unchanged.** The version footer script, the theme head snippet, the manifest and icons stay in `index.html` and the root as before.
- **A build step stays allowed, as the exception.** VoiceTrainer's pattern (sources in `src/`, a `build.js` that writes one page, files in `pwa/`) suits an app that needs one, for example to inline large data. Prefer the plain split first.

## On-device machine learning

*First used by Wardrobe* (cutting clothes out of photos, recognising similar items). For an app that runs a model in the browser, so images never leave the device:

- **The model runs in a module worker** (`new Worker('x-worker.js', { type: 'module' })`), so the page stays responsive while it loads and runs.
- **The library is vendored, pinned and unchanged.** Keep the library's published dist file in `vendor/<library>-<version>/`, exactly as released, and import it from there. Don't edit it; to upgrade, add the new version's folder and switch the import.
- **The service worker caches the model.** Model weights and `.wasm` files usually come from a CDN and are large. The app's `sw.js` caches those URLs **cache-first** under a versioned cache name (such as `models-v2`), and deletes older versions of that cache on `activate`. This is a documented exception to the shared worker, which otherwise leaves other sites' files to the network: add it in the app's own `sw.js`, after `importScripts` of the shared one.
- **Licences go in `THIRD_PARTY_NOTICES.md`:** the library and each model, with where they live and their licence (STANDARDS.md, *License*). Check model licences as carefully as code ones.
- **Tests don't download models.** A stand-in worker with the same messages returns fixed results, so headless tests (`tools/screenshot.mjs`, say) run fast and offline. The app picks it with a URL flag or a test-only setting.
- **Same quantisation everywhere.** When vectors (embeddings) are saved and compared across devices, every device must load the same model at the same quantisation (all `q8`, say), or vectors from a phone and a computer won't match. Record the model and quantisation next to the saved vectors so a later change can tell old ones apart.
