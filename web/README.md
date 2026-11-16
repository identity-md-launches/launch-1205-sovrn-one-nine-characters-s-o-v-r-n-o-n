# SOVRN.ONE ($SVO) landing page

One static page for the SVO token. It reproduces the approved page at
`https://github.com/hoolibear/sovrn-one-landing` commit `33c9b13792a911f81cd164d34779bd3c5ac98f03`,
with the fonts self-hosted. It has no JavaScript, no wallet and no live data.

- Source: `web/` (this folder). `index.html` holds the markup and all the CSS inline, copied unchanged
  from the approved page. `src/fonts.css` bundles Audiowide and Rubik from `@fontsource`. `public/`
  holds `banner.jpg`, `icon.png` and `apple-icon.png` exactly as downloaded.
- Export: `dist/` at the repository root. It is committed and is what gets hosted. Every URL in it
  is relative, so it works from a domain root or from an IPFS gateway path such as `/ipfs/<cid>/`.
- Design system: `DESIGN.md` at the repository root. Validation record: `artifacts/validation.md`.

## Install

Node 20.19+ or 22.12+ (built and checked with Node 24.21 and npm 11.19).

```sh
cd web
npm ci
```

## Preview

```sh
npm run dev       # live preview of the source at http://localhost:5173/
npm run preview   # serves the built dist/ at http://localhost:4173/
```

`dist/index.html` also opens straight from disk (file://) with its fonts, because it has no script and
no absolute paths.

## Rebuild

```sh
npm run build      # vite build -> ../dist (emptied first)
npm run typecheck  # tsc --noEmit over vite.config.ts and scripts/
npm run check      # static checks on ../dist (needs no network or browser)
```

Commit `dist/` after rebuilding. The publisher serves the committed export and does not build it. Font
files get content hashes (`dist/assets/*-<hash>.woff2`), so a rebuild with the same lockfile gives the
same file names. Do not commit `web/node_modules/`.

`npm run check` (`scripts/check-export.ts`) fails if any of these is false:

- the three images match their pinned SHA-256 values;
- the export has no `<script>` and no `.js` file;
- the title, description, `og:title`, `og:description`, `og:image`, favicon and apple-touch-icon are
  the approved ones;
- there are exactly the ten approved links, in order, with the approved targets (X and Telegram open
  in a new tab with `rel="noopener noreferrer"`);
- the visible text is exactly the approved copy, in order;
- every asset URL is relative and resolves inside `dist/`;
- no third-party URL appears outside the links.

## Last results (2026-11-16)

| Command | Result |
| --- | --- |
| `npm run build` | built in about 0.1s; `dist/` is 1.07 MB (3 images, 1 CSS file, 8 font files, `index.html`) |
| `npm run typecheck` | exit 0 |
| `npm run check` | 41 of 41 checks passed. On a deliberately tampered copy (one byte added to icon.png, a script tag, a changed X link) it failed 4 checks and exited 1. |
| Chromium side-by-side with the original page | 0 to 2 differing pixels per full-page screenshot (out of 0.35 to 1.36 million) at 1440, 768 and 390 wide, light and dark |
| Chromium, built page served under `/ipfs/bafyexample/` with JavaScript disabled and third-party requests blocked | HTTP 200, 0 third-party requests, 0 failed requests, 0 console errors, all four font faces loaded, no horizontal scroll at 320, 390, 768 or 1440 |
| taste@1 probe (`.imd/reads/skills/design-critic/scripts/taste.mjs --offline`) | 13 of 16 checks passed. The 3 failures come from the approved design, which the brief fixes. See `artifacts/validation.md`. |

Not run: WebKit (Safari). Playwright's WebKit could not start on the build machine because system
packages were missing and there was no root access. No physical device or screen reader was used.
Details are in `artifacts/validation.md`.
