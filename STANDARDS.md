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

## Adding a new app

1. Publish it on GitHub Pages under `petravanta.github.io/<repo>/`.
2. Add the back link above.
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
- Phone-first layout: `viewport-fit=cover`, safe-area insets on sticky headers and sheets, 16px minimum side gutter.
- Data stays in the browser (`localStorage`), with **Export backup** / **Import backup** as JSON, and optional Google Drive sync using the `drive.file` scope and the shared OAuth client that allows `https://petravanta.github.io`.
- No sign-up; each app is a static page served by GitHub Pages from its `main` branch.

When you change the shared look, update `shared/theme.css` here and the inlined copy in each app together.
