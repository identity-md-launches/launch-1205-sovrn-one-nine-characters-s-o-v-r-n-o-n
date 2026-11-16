# SOVRN.ONE ($SVO) landing page: design system

This describes the page as implemented in `web/index.html` (markup and all CSS, inline in one `<style>`)
and `web/src/fonts.css` (self-hosted fonts). The page reproduces the approved
`hoolibear/sovrn-one-landing@33c9b13` `index.html`; its CSS is copied unchanged, so every value below is
the approved one. Change nothing here without the requester's approval: the brief fixes colours,
sizes, spacing, wording and order.

## Overview

A single-screen token landing page for SVO, the Sovrn.One token: a slim header, one full-bleed hero
and a one-line footer. The hero carries the whole message: a white pill, the very large "SVO"
wordmark heading in Audiowide, one sentence, and three pill-shaped actions with exactly one filled
blue. The page is light (white ground, navy ink) or dark (deep navy ground) by
`prefers-color-scheme`. The hero is dark in both schemes because it sits on the photo. There is no
JavaScript, no live data and no wallet.

System-wide rules: rounded pill controls, navy ink on a white or navy ground, one filled blue
action per view, Audiowide only for the brand wordmark and display heading. The hero layout itself
(full-bleed image, centred column) is this page's arrangement, not a rule for every page.

## Colors

All colours are CSS custom properties on `:root` (`web/index.html:19`), overridden for dark mode in
`@media (prefers-color-scheme: dark)` (`web/index.html:30`). Notation is hex/rgba throughout.

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `--ground` | `#ffffff` | `#04153f` | page background (header and footer sit on it) |
| `--ink` | `#0b1f4d` | `#eaf0ff` | primary text, wordmark, plate button text |
| `--ink-2` | `#4a5a82` | `#aab8de` | secondary text: ghost nav buttons, footer links |
| `--ink-3` | `#8290b2` | `#7384ad` | tertiary text: footer "Sovrn.One" |
| `--line` | `#d9e0ee` | `rgba(173,196,255,0.16)` | 1px border of plates and plate buttons |
| `--plate` | `#ffffff` | `#0b1e4f` | surface of plates and plate buttons |
| `--plate-2` | `#f5f8fd` | `#122a66` | hover surface (plate and ghost buttons) |
| `--plate-line-hover` | `#c9d2e6` | `rgba(173,196,255,0.28)` | hover border of plate buttons |
| `--blue` | `#1f6feb` | `#1f6feb` | focus ring (`:focus-visible`, `web/index.html:50`) |
| `--blue-ink` | `#1649b8` | `#2b6fe8` | fill of the one primary button |
| `--blue-hover` | `#1a55d2` | `#3b7ff0` | primary button hover |
| `--led` | `#5fd8ff` | `#5fd8ff` | the glowing status dot in the header |

Fixed colours outside the tokens: hero fallback `#070a10` (`.hero`), hero shade gradient
`rgba(7,10,16,.35) → .5 at 45% → .86` (`.hero-shade`, `web/index.html:91`), heading `#fff`, lede
`rgba(255,255,255,0.85)`, primary button label `#fff`, selection `#cdebff` on `#0b1f4d`
(`web/index.html:51`), `theme-color` `#04153f`.

Measured contrast (Chromium, rendered pixels; see `artifacts/validation.md`): every text pair passes
WCAG AA in both schemes except the light-mode footer "Sovrn.One" (`--ink-3` on `--ground`, 3.19:1).
That colour belongs to the approved design and was not changed.

## Typography

| Family | Weights | Used for | Source |
| --- | --- | --- | --- |
| Audiowide | 400 | `.wordmark` (header "Sovrn.One"), `h1` "SVO" | `@fontsource/audiowide/latin-400.css` |
| Rubik | 400, 500, 600 | everything else (`body` default) | `@fontsource/rubik/latin-{400,500,600}.css` |

Fallbacks: `'Rubik', system-ui, -apple-system, sans-serif` on `body`; `'Audiowide', 'Rubik', sans-serif`
on the wordmark and heading. Fonts are bundled from `web/src/fonts.css` (Latin subset, woff2 with
woff fallback, `font-display: swap`) and emitted to `dist/assets/`. No font loads from a third party.

Type scale (six roles):

| Role | Selector | Size | Weight | Line height | Tracking |
| --- | --- | --- | --- | --- | --- |
| Display | `h1` (`web/index.html:93`) | `clamp(96px, 19vw, 260px)` | 400 | 0.9 | -0.06em, shadow `0 20px 60px rgba(0,0,0,.6)` |
| Lede | `.lede` (`:98`) | 1.125rem (18px), max 46ch | 400 | 1.55 | normal |
| Wordmark | `.wordmark` (`:62`) | 1.05rem; 1.15rem from 640px | 400 | 1 | 0.02em |
| Button | `.btn` (`:66`) | 0.9375rem (15px) | 500 | 1 | normal |
| Small button | `.btn-sm` (`:75`) | 0.8125rem (13px) | 500 | 1 | normal |
| Label / footer | `.plate` (`:82`) 600, `.footer` (`:102`) 400 | 0.75rem (12px) | 600 / 400 | normal | normal |

Body text is antialiased (`-webkit-font-smoothing: antialiased` on `body`). Button labels do not wrap
(`white-space: nowrap`).

## Layout

- Page: `body` is a full-height flex column (`min-height: 100svh`); the hero takes the remaining
  space (`flex: 1`), so the footer sits at the bottom of the first screen when content allows.
- Header (`.header`, `web/index.html:54`): 64px tall, name at the leading edge, nav at the trailing
  edge, inline padding 20px (32px from 640px). Nav gap 4px (8px from 640px).
- Hero (`.hero`, `:89`): full bleed, `min-height: min(92svh, 880px)`, image `object-fit: cover`
  under the shade gradient. Content column `.hero-inner` (`:92`) is centred, max 1360px, padding
  96px top, 80px bottom, 20px inline (40px from 640px), 20px gap between pill, heading, lede and
  actions. `.actions` adds 16px above and wraps with 12px gaps.
- Footer (`.footer`, `:102`): wraps; 20px padding (20px 32px from 640px), gaps 8px by 20px.

Breakpoints (`web/index.html:107-115`):

- `min-width: 640px`: wider header, hero and footer padding; larger wordmark; wider nav gap.
- `max-width: 420px`: the header's ghost buttons ("Swap", "Stake") are hidden. The header keeps
  "Talk to Solomon", and Stake and Buy stay on the first screen as hero buttons.

Observed in Chromium: no horizontal scroll at 320, 390, 768 or 1440; at 390x844 the three hero
actions end at y=621 (y=569 at 320x640), so the token name and main action ("Stake") are on the first screen.

## Elevation & Depth

- `--shadow` (light `0 1px 2px rgba(11,31,77,.06), 0 8px 20px -10px rgba(11,31,77,.22)`; darker in
  dark mode) lifts the pill and plate buttons. They also carry a 1px `--line` border.
- `--primary-shadow` gives the filled Stake button a blue glow.
- The hero stacks image (`z-index: -2`), shade (`-1`) and content inside `isolation: isolate`.
- The `.led` dot glows with `0 0 0 2px rgba(95,216,255,.22), 0 0 10px rgba(95,216,255,.95)`.

## Shapes

- Buttons: fully round pills (`border-radius: 999px`), 44px tall (34px for `.btn-sm`).
- Pill label `.plate`: `--radius` 14px.
- Focus ring: 2px solid `--blue`, 2px offset, 6px radius.
- Status dot: 8px circle.

## Components

All are CSS classes in `web/index.html`; there is no component framework.

- **Button `.btn`** (`:66`): an `<a href>`, inline-flex pill. Variants: `.btn-primary` (filled
  `--blue-ink`, white label; one per view), `.btn-plate` (surface `--plate`, border `--line`, shadow),
  `.btn-ghost` (transparent, `--ink-2`). Size modifier `.btn-sm`. States: hover changes background
  (and border for plate) over 180ms `cubic-bezier(0.2, 0.8, 0.2, 1)`; `:active` moves 1px down;
  `:focus-visible` draws the blue ring. Transitions are off under `prefers-reduced-motion: reduce`.
- **Plate `.plate`** (`:82`): a static pill label (the hero's "Stake SVO. Share in Solomon.").
- **Brand `.brand`**: `.led` dot plus `.wordmark`, linking to https://sovrn.one/. The dot pulses
  (opacity 1 to 0.45, 2.6s, `@keyframes pulse`), and stops under reduced motion.
- **Footer nav**: plain text links in `--ink-2`, underlined (3px offset) in `--ink` on hover.
  External links (X, Telegram) open in a new tab with `rel="noopener noreferrer"`.

Every interactive element is a native `<a href>`; keyboard order follows the DOM: brand, Swap, Stake,
Talk to Solomon, Stake, Buy, Talk to Solomon, sovrn.one, X, Telegram.

## Do's and Don'ts

- Do keep this page's copy, links, colours and sizes exactly as approved. The brief forbids
  additions, so add no live data, price, supply counter, wallet, address, analytics or new copy.
- Do use `.btn-primary` for one action per view only. Peers are `.btn-plate`; header utilities are
  `.btn-sm .btn-ghost` or `.btn-sm .btn-plate`.
- Do take colour from the tokens, and set both theme blocks when adding one. Theme switching is
  `prefers-color-scheme` only; do not add a class-based toggle alongside it.
- Do keep asset URLs relative (`banner.jpg`, not `/banner.jpg`) and fonts self-hosted, so the export
  works from an IPFS gateway subpath and makes no third-party request.
- Don't use Audiowide for running text; it is for the brand wordmark and the display heading.
- Don't recompress or rename `web/public/banner.jpg`, `icon.png` or `apple-icon.png`: they are
  shipped byte for byte and checked by hash (`web/scripts/check-export.ts`).
- Recipe for another page: copy `web/index.html`'s `<head>` (tokens and font link) plus the
  `.header` and `.footer` markup, put the content in `<main>`, use `.btn` variants for actions and
  `.plate` for a label. Then add the page as a second Vite HTML entry
  (`build.rollupOptions.input`), because the export is static with no server rewrites.
