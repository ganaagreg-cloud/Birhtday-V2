# Font Layout Shift & Image Blur-Up Design

**Date:** 2026-06-19  
**Project:** Birthday V2 (birthdayofbabi.netlify.app)  
**Stack:** Plain HTML/JS, no build framework, hosted on Netlify

---

## Problem

1. **Font layout shift** — Cormorant Garamond and Montserrat load via Google Fonts with `font-display: swap`. On slow connections, text renders in Georgia/system fallback first, then re-flows when the custom font arrives, causing the last word on a line to jump down then back up.

2. **Image loading states** — All `<img loading="lazy">` elements have no loading placeholder or error handling. On slow networks, users see broken grey boxes. On error, there's no recovery path.

---

## Fix 1: Font Self-Hosting + `font-display: optional`

### What changes

- Remove the existing Google Fonts `<link>` tags (preconnect + stylesheet).
- Download woff2 subsets for:
  - **Cormorant Garamond**: weight 300 and 400, normal and italic (4 files)
  - **Montserrat**: weight 200, 300, and 400, normal only (3 files)
- Place files in `/fonts/` directory.
- Add `@font-face` declarations in `<style>` with `font-display: optional`.
- Add `<link rel="preload">` in `<head>` for the two most visually impactful files: Cormorant Garamond 300 italic (used in hero title) and Cormorant Garamond 400 (used in body serif).
- Keep existing font-family stacks unchanged — fallbacks (Georgia, sans-serif) already present.

### Why `font-display: optional`

`optional` tells the browser: use the fallback immediately; only swap to the custom font if it arrives within the first render cycle (≈100ms). If it misses that window, the custom font is cached silently for next load. No visible swap ever happens. The preload tags maximize the chance the font wins the first-render race on a normal connection.

### Font files to download

Source: `https://fonts.gstatic.com` (Google's CDN). Download via `google-webfonts-helper` API or direct URL construction.

Files:
```
/fonts/cormorant-garamond-300.woff2
/fonts/cormorant-garamond-300-italic.woff2
/fonts/cormorant-garamond-400.woff2
/fonts/cormorant-garamond-400-italic.woff2
/fonts/montserrat-200.woff2
/fonts/montserrat-300.woff2
/fonts/montserrat-400.woff2
```

### `@font-face` template

```css
@font-face {
  font-family: 'Cormorant Garamond';
  font-style: normal;
  font-weight: 300;
  font-display: optional;
  src: url('/fonts/cormorant-garamond-300.woff2') format('woff2');
}
/* ...repeat for each variant */
```

### Preload tags

```html
<link rel="preload" href="/fonts/cormorant-garamond-300-italic.woff2"
      as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/cormorant-garamond-400.woff2"
      as="font" type="font/woff2" crossorigin>
```

---

## Fix 2: Image Blur-Up Loading Pattern

### Scope

Apply to all `<img>` elements in:
- Archive section (`#archive-track .photo-card img`) — 7 images
- Friends section (`#friends-track .photo-card img`) — 8 images
- Timeline polaroids (`.polaroid img`) — 5 images

The video poster is a CSS `background-image`, not an `<img>` — exclude from this treatment (its placeholder is already the dark background).

### Placeholder generation

Write a one-time Node.js script (`scripts/gen-blur.js`) that:
1. Reads each image path from a hardcoded list matching the HTML
2. Uses `sharp` to resize to 20px wide (maintain aspect ratio)
3. Outputs as base64-encoded JPEG (`quality: 60`)
4. Prints a JSON map: `{ "Images/foo.jpg": "data:image/jpeg;base64,..." }`

Run once: `node scripts/gen-blur.js > scripts/blur-data.json`

A second script (`scripts/inject-blur.js`) reads `blur-data.json` and uses regex to find each `<img src="...">` tag in `index.html`, injecting the matching `data-blur="<base64>"` attribute. Outputs to `index.html` in place.

### Loading state (JS)

On `DOMContentLoaded`, for each image with `data-blur`:
1. Set `img.style.filter = 'blur(20px)'`, `img.style.transform = 'scale(1.05)'` (hide blur edges), `img.style.transition = 'filter 0.4s ease-out, transform 0.4s ease-out, opacity 0.4s ease-out'`
2. Create a parent wrapper `<div class="img-blur-wrap">` with `background: #F0E8DC` and `overflow: hidden`
3. Show the blur placeholder as a CSS `background-image` on the wrapper set to the base64 data URI, blurred and scaled
4. On `img.onload`: remove blur, remove scale, opacity transitions to 1 → sharp image revealed
5. On `img.onerror`: show error state (see below)

### Error state

Replace the failed `<img>` parent with:
```html
<div class="img-error-state">
  <svg><!-- thin gold (#B8975A) circular arrow --></svg>
  <span>Дахин ачаалах</span>
</div>
```
Clicking retries: set `img.src = img.src + '?r=' + Date.now()` to bust cache and re-trigger load.

### CSS additions

```css
.img-blur-wrap {
  position: relative;
  background: #F0E8DC;
  overflow: hidden;
}

.img-error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.6rem;
  background: #F0E8DC;
  color: #B8975A;
  font-family: var(--serif);
  font-size: 0.85rem;
  letter-spacing: 0.08em;
  cursor: pointer;
  width: 100%;
  height: 100%;
  min-height: 80px;
}

.img-error-state svg {
  width: 28px;
  height: 28px;
  stroke: #B8975A;
  fill: none;
  stroke-width: 1.5;
}
```

---

## Out of scope

- Hero `<section>` has no images — only inline SVGs and CSS gradients. No treatment needed.
- Video poster (`vs-poster-bg`) is a CSS background. Its dark `#060308` base color already acts as a placeholder.
- Audio element — no visual component.
- Tweaks panel palette/energy/voice — no image handling changes needed.

---

## Implementation order

1. Download font files → place in `/fonts/`
2. Replace Google Fonts `<link>` with `@font-face` + preload tags in `index.html`
3. Write `scripts/gen-blur.js`, install `sharp`, run script
4. Inject `data-blur` attributes into `index.html`
5. Add CSS for `.img-blur-wrap` and `.img-error-state`
6. Add JS blur-up initialization block in `index.html` `<script>`
7. Test on Chrome DevTools slow-3G throttle
8. Commit + deploy to Netlify
