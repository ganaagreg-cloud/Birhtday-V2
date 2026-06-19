# Font Layout Shift & Image Blur-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate font layout shift on mobile and add a cinematic blur-up loading pattern with gold error state to all 20 images.

**Architecture:** Self-host 7 woff2 font files with `font-display: optional` (no swap, no jump). Generate 20px base64 JPEG thumbnails via PowerShell System.Drawing, inject as `data-blur` attributes on every `<img>`, then fade from blurred placeholder to sharp image in 0.4s via vanilla JS. Error state overlays with a gold reload arrow + "Дахин ачаалах".

**Tech Stack:** Plain HTML/JS, PowerShell 5.1 (System.Drawing for thumbnail generation), Netlify static hosting.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `fonts/*.woff2` | Create (7 files) | Self-hosted font files |
| `scripts/gen-thumbnails.ps1` | Create | Resize each image to 20px, output base64 JSON |
| `scripts/blur-data.json` | Create (generated) | Map of `src → data:image/jpeg;base64,...` |
| `scripts/inject-blur.ps1` | Create | Inject `data-blur` attrs + fix 2 broken src paths |
| `index.html` | Modify | Replace GFonts link, add @font-face, preload, blur CSS, blur JS |

---

## Task 1: Download font woff2 files

**Files:**
- Create: `fonts/` directory (7 woff2 files)

- [ ] **Step 1: Create fonts directory**

```powershell
New-Item -ItemType Directory -Path "fonts" -Force | Out-Null
```

- [ ] **Step 2: Fetch Google Fonts CSS and download woff2 files**

```powershell
$ua  = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
$url = "https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;1,300;1,400&family=Montserrat:wght@200;300;400&display=optional"
$css = (Invoke-WebRequest -Uri $url -UserAgent $ua -UseBasicParsing).Content

# Extract @font-face blocks for latin subset only
$blocks = [regex]::Matches(
  $css,
  "/\* latin \*/\s*@font-face \{[^}]+\}",
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)

foreach ($block in $blocks) {
  $b = $block.Value
  $woff2 = [regex]::Match($b, "url\(([^)]+)\)").Groups[1].Value
  if (-not $woff2) { continue }

  $name = if ($b -match "Cormorant Garamond") {
    $w = [regex]::Match($b, "font-weight: (\d+)").Groups[1].Value
    $s = if ($b -match "font-style: italic") { "-italic" } else { "" }
    "cormorant-garamond-$w$s.woff2"
  } elseif ($b -match "Montserrat") {
    $w = [regex]::Match($b, "font-weight: (\d+)").Groups[1].Value
    "montserrat-$w.woff2"
  } else { $null }

  if ($name) {
    Invoke-WebRequest -Uri $woff2 -OutFile "fonts/$name" -UseBasicParsing
    Write-Host "✓ $name"
  }
}
```

- [ ] **Step 3: Verify 7 files downloaded**

```powershell
Get-ChildItem fonts/ | Select-Object Name, Length
```

Expected output — 7 files, each 15–50 KB:
```
cormorant-garamond-300.woff2
cormorant-garamond-300-italic.woff2
cormorant-garamond-400.woff2
cormorant-garamond-400-italic.woff2
montserrat-200.woff2
montserrat-300.woff2
montserrat-400.woff2
```

---

## Task 2: Replace Google Fonts link with self-hosted @font-face + preload

**Files:**
- Modify: `index.html` lines 7–9 (head section)
- Modify: `index.html` lines 10–17 (top of `<style>`)

- [ ] **Step 1: Remove Google Fonts preconnect and stylesheet links**

In `index.html`, delete these three lines (currently lines 7–9):
```html
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;1,300;1,400&family=Montserrat:wght@200;300;400&display=swap" rel="stylesheet">
```

Replace with preload tags for the two most critical fonts:
```html
  <link rel="preload" href="/fonts/cormorant-garamond-300-italic.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="preload" href="/fonts/cormorant-garamond-400.woff2" as="font" type="font/woff2" crossorigin>
```

- [ ] **Step 2: Add @font-face block at the very top of the `<style>` tag**

The `<style>` tag opens at line 10 with `:root {`. Insert this block immediately after `<style>` and before `:root`:

```css
    /* ── SELF-HOSTED FONTS ───────────────── */
    @font-face { font-family:'Cormorant Garamond'; font-style:normal;  font-weight:300; font-display:optional; src:url('/fonts/cormorant-garamond-300.woff2') format('woff2'); }
    @font-face { font-family:'Cormorant Garamond'; font-style:italic;  font-weight:300; font-display:optional; src:url('/fonts/cormorant-garamond-300-italic.woff2') format('woff2'); }
    @font-face { font-family:'Cormorant Garamond'; font-style:normal;  font-weight:400; font-display:optional; src:url('/fonts/cormorant-garamond-400.woff2') format('woff2'); }
    @font-face { font-family:'Cormorant Garamond'; font-style:italic;  font-weight:400; font-display:optional; src:url('/fonts/cormorant-garamond-400-italic.woff2') format('woff2'); }
    @font-face { font-family:'Montserrat'; font-style:normal; font-weight:200; font-display:optional; src:url('/fonts/montserrat-200.woff2') format('woff2'); }
    @font-face { font-family:'Montserrat'; font-style:normal; font-weight:300; font-display:optional; src:url('/fonts/montserrat-300.woff2') format('woff2'); }
    @font-face { font-family:'Montserrat'; font-style:normal; font-weight:400; font-display:optional; src:url('/fonts/montserrat-400.woff2') format('woff2'); }
```

- [ ] **Step 3: Verify the head section looks correct**

Open `index.html` — the `<head>` should now read:
```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>For You — A Birthday Archive</title>
  <link rel="preload" href="/fonts/cormorant-garamond-300-italic.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="preload" href="/fonts/cormorant-garamond-400.woff2" as="font" type="font/woff2" crossorigin>
  <style>
    /* ── SELF-HOSTED FONTS ───────────────── */
    @font-face { ... }
    ...
    :root { ... }
```

No Google Fonts URLs should appear anywhere in the file. Run:
```powershell
Select-String -Path index.html -Pattern "googleapis|gstatic"
```
Expected: no output (zero matches).

---

## Task 3: Commit font fix

**Files:** `index.html`, `fonts/` (7 files)

- [ ] **Step 1: Commit**

```powershell
git add index.html fonts/
git commit -m "Fix font layout shift: self-host woff2 with font-display optional"
```

---

## Task 4: Add blur-up CSS to index.html

**Files:**
- Modify: `index.html` — inside `<style>`, just before the closing `</style>` tag (currently near the `.photo-card::after` block at the end)

- [ ] **Step 1: Add blur-up and error state CSS**

Find the closing `  </style>` tag and insert this block immediately before it:

```css
    /* ── BLUR-UP & ERROR STATES ─────────── */
    .polaroid { position:relative; }
    .img-blur-overlay { position:absolute; inset:0; pointer-events:none; }
    .img-error-state {
      position:absolute; inset:0; display:flex; flex-direction:column;
      align-items:center; justify-content:center; gap:.6rem;
      background:#F0E8DC; cursor:pointer; z-index:3;
    }
    .img-error-state svg { width:28px; height:28px; }
    .img-error-state span {
      font-family:var(--serif); font-size:.82rem; letter-spacing:.08em; color:#B8975A;
    }
```

---

## Task 5: Add blur-up JS to index.html

**Files:**
- Modify: `index.html` — at the very end of the `<script>` block, just before `</script>`

- [ ] **Step 1: Add blur-up initialization function**

Find the closing `</script>` tag and insert this block immediately before it:

```javascript
  /* ── Blur-up image loading ──────────────────── */
  (function() {
    function setupImg(img) {
      var blurSrc = img.getAttribute('data-blur');
      if (!blurSrc) return;
      var parent = img.parentElement;

      var overlay = document.createElement('div');
      overlay.className = 'img-blur-overlay';
      overlay.style.cssText = 'background:url("' + blurSrc + '") center/cover no-repeat;filter:blur(20px);transform:scale(1.05);';
      parent.insertBefore(overlay, img);

      img.style.opacity = '0';
      img.style.transition = 'opacity 0.4s ease-out';
      img.style.position = 'relative';
      img.style.zIndex = '2';

      function revealImg() {
        overlay.remove();
        img.style.opacity = '1';
      }

      function showError() {
        overlay.remove();
        img.style.opacity = '0';
        var err = document.createElement('div');
        err.className = 'img-error-state';
        err.innerHTML =
          '<svg viewBox="0 0 24 24" fill="none" stroke="#B8975A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">' +
          '<polyline points="1 4 1 10 7 10"/>' +
          '<path d="M3.51 15a9 9 0 1 0 .49-5.27"/>' +
          '</svg>' +
          '<span>Дахин ачаалах</span>';
        parent.appendChild(err);
        err.addEventListener('click', function() {
          err.remove();
          img.src = img.src.split('?')[0] + '?r=' + Date.now();
          setupImg(img);
        }, { once: true });
      }

      if (img.complete) {
        img.naturalWidth > 0 ? revealImg() : showError();
      } else {
        img.addEventListener('load', revealImg, { once: true });
        img.addEventListener('error', showError, { once: true });
      }
    }

    document.querySelectorAll('img[data-blur]').forEach(setupImg);
  })();
```

---

## Task 6: Write scripts/gen-thumbnails.ps1

**Files:**
- Create: `scripts/gen-thumbnails.ps1`

- [ ] **Step 1: Create the thumbnail generation script**

Create `scripts/gen-thumbnails.ps1` with this content:

```powershell
# scripts/gen-thumbnails.ps1
# Generates 20px-wide JPEG thumbnails as base64 for blur-up placeholders.
# Output: scripts/blur-data.json — map of { "html-src-attr": "data:image/jpeg;base64,..." }
Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path $PSScriptRoot -Parent

# Keys = exact src attribute values from index.html
# Values = actual relative file paths on disk
$srcToFile = [ordered]@{
  "Images/Our%20First%20time%20in%20your%20birthplace.jpeg" = "Images/Our First time in your birthplace.jpeg"
  "Images/Our%20first%20travel.jpeg"                        = "Images/Our first travel.jpeg"
  "Images/Хөгжилтэй мөч.jpg"                               = "Images/Хөгжилтэй мөч.jpg"
  "Images/FullSizeRender.jpeg "                             = "Images/FullSizeRender.jpeg"
  "Images/IMG_3982.JPG"                                     = "Images/IMG_3982.JPG"
  "Images/Anh gadaad.jpg"                                   = "Images/Anh gadaad.jpg"
  "Images/Borootoi odor.jpg"                                = "Images/Borootoi odor.jpg"
  "Images/%D0%AD%D1%8D%D0%B6.png"                           = "Images/Ээж.png"
  "Images/Аав.png"                                          = "Images/Аав.png"
  "Images/%D0%94%D2%AF%D2%AF.png"                           = "Images/Дүү.png"
  "Images/Friend%201.jpg"                                   = "Images/Friend 1.jpg"
  "Images/Friend%202.jpg"                                   = "Images/Friend 2.jpg"
  "Images/Friend%203.jpg"                                   = "Images/Friend 3.jpg"
  "Images/Friend%204.jpeg"                                  = "Images/Friend 4.jpeg"
  "Images/Friend%205.jpeg"                                  = "Images/Friend 5.jpeg"
  "Images/Our official starting point.JPG"                  = "Images/Our official starting point.JPG"
  "Images/our first adventure.jpg"                          = "Images/our first adventure.jpg"
  "Images/When I Knew.JPG"                                  = "Images/When I Knew.JPG"
  'Images\IMG_8960.jpg'                                     = "Images/IMG_8960.jpg"
  "images/Right now.jpg"                                    = "Images/Right now.jpg"
}

$jpegCodec  = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$encParams  = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, [long]60)

$blurData = [ordered]@{}

foreach ($entry in $srcToFile.GetEnumerator()) {
  $srcAttr  = $entry.Key
  $filePath = Join-Path $projectRoot $entry.Value

  if (-not (Test-Path $filePath)) {
    Write-Warning "MISSING: $filePath"
    continue
  }

  try {
    $img      = [System.Drawing.Image]::FromFile($filePath)
    $newW     = 20
    $newH     = [Math]::Max(1, [int]($newW * $img.Height / $img.Width))
    $thumb    = New-Object System.Drawing.Bitmap($newW, $newH)
    $g        = [System.Drawing.Graphics]::FromImage($thumb)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, 0, 0, $newW, $newH)
    $g.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $thumb.Save($ms, $jpegCodec, $encParams)
    $base64 = [Convert]::ToBase64String($ms.ToArray())
    $blurData[$srcAttr] = "data:image/jpeg;base64,$base64"

    $img.Dispose(); $thumb.Dispose(); $ms.Dispose()
    Write-Host "✓ $srcAttr"
  } catch {
    Write-Warning "FAILED $filePath`: $_"
  }
}

$outPath = Join-Path $PSScriptRoot "blur-data.json"
$utf8    = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, ($blurData | ConvertTo-Json -Depth 2), $utf8)
Write-Host "Done → scripts/blur-data.json ($($blurData.Count) entries)"
```

---

## Task 7: Run gen-thumbnails.ps1

**Files:**
- Create: `scripts/blur-data.json` (generated output)

- [ ] **Step 1: Run the script**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/gen-thumbnails.ps1
```

- [ ] **Step 2: Verify output**

```powershell
$data = Get-Content scripts/blur-data.json | ConvertFrom-Json
$data.PSObject.Properties | Measure-Object | Select-Object Count
```

Expected: `Count: 20`

```powershell
# Spot-check one entry — should start with data:image/jpeg;base64,
$data.'Images/IMG_3982.JPG' | Select-Object -First 1 | ForEach-Object { $_.Substring(0,40) }
```

Expected: `data:image/jpeg;base64,/9j/` (or similar JPEG magic bytes in base64)

---

## Task 8: Write scripts/inject-blur.ps1

**Files:**
- Create: `scripts/inject-blur.ps1`

- [ ] **Step 1: Create the injection script**

Create `scripts/inject-blur.ps1` with this content:

```powershell
# scripts/inject-blur.ps1
# 1. Injects data-blur="<base64>" onto every <img> in index.html that has a matching src in blur-data.json
# 2. Fixes two broken src paths: backslash and wrong case

$indexPath    = Join-Path $PSScriptRoot ".." "index.html"
$blurDataPath = Join-Path $PSScriptRoot "blur-data.json"

$utf8    = New-Object System.Text.UTF8Encoding($false)
$html    = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)
$rawJson = [System.IO.File]::ReadAllText($blurDataPath, [System.Text.Encoding]::UTF8)
$blurMap = $rawJson | ConvertFrom-Json

# Fix broken src paths before injection
$html = $html.Replace('src="Images\IMG_8960.jpg"', 'src="Images/IMG_8960.jpg"')
$html = $html.Replace('src="images/Right now.jpg"', 'src="Images/Right now.jpg"')
Write-Host "✓ Fixed broken src paths"

$injected = 0
foreach ($prop in $blurMap.PSObject.Properties) {
  $srcAttr  = $prop.Name
  $dataBlur = $prop.Value

  # Build pattern: match <img ... src="<srcAttr>" ... > not already having data-blur
  $escapedSrc = [Regex]::Escape($srcAttr)
  $pattern    = '(<img\b(?![^>]*data-blur)[^>]*\bsrc="' + $escapedSrc + '"[^>]*?)(\s*>)'

  $newHtml = [Regex]::Replace($html, $pattern, {
    param($m)
    $m.Groups[1].Value + ' data-blur="' + $dataBlur + '"' + $m.Groups[2].Value
  })

  if ($newHtml -ne $html) {
    $html = $newHtml
    $injected++
    Write-Host "✓ Injected: $srcAttr"
  } else {
    Write-Warning "No match: $srcAttr"
  }
}

[System.IO.File]::WriteAllText($indexPath, $html, $utf8)
Write-Host "Done — injected $injected / $($blurMap.PSObject.Properties | Measure-Object | Select-Object -ExpandProperty Count) images"
```

---

## Task 9: Run inject-blur.ps1

**Files:**
- Modify: `index.html` (adds `data-blur` to all 20 `<img>` tags, fixes 2 broken src paths)

- [ ] **Step 1: Run the script**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/inject-blur.ps1
```

Expected output:
```
✓ Fixed broken src paths
✓ Injected: Images/Our%20First%20time%20in%20your%20birthplace.jpeg
✓ Injected: Images/Our%20first%20travel.jpeg
... (18 more lines)
Done — injected 20 / 20 images
```

If any line says "No match", open `index.html`, find the corresponding `<img>` tag, and confirm the `src` attribute matches exactly (including URL encoding) what's in `blur-data.json`.

- [ ] **Step 2: Verify injection in index.html**

```powershell
Select-String -Path index.html -Pattern 'data-blur="data:' | Measure-Object | Select-Object Count
```

Expected: `Count: 20`

```powershell
# Verify broken paths are fixed
Select-String -Path index.html -Pattern 'Images\\IMG_8960|images/Right'
```

Expected: no output (zero matches).

---

## Task 10: Visual verification

- [ ] **Step 1: Open the site in a browser and simulate slow network**

Open `index.html` in Chrome. Open DevTools → Network → Throttling → select **Slow 3G**.

Hard-reload the page (Ctrl+Shift+R).

**Font check:** Watch the hero title as the page loads. The text should appear immediately in Georgia (the fallback) and either:
- Stay in Georgia if Cormorant Garamond doesn't arrive in the first render cycle, OR
- Appear in Cormorant Garamond from the start if the preloaded font wins

In either case, there must be **no visible jump or reflow** of the last word on a line.

**Blur-up check:** Scroll through the photo archive. Each image should:
1. Show a warm blurry thumbnail while loading (not a grey box)
2. Cross-fade to sharp in ~0.4s once loaded

- [ ] **Step 2: Simulate image error**

In DevTools → Network, right-click one image request → Block request URL.

Hard-reload. That image's card should show the gold circular-arrow icon and "Дахин ачаалах" text, centered, on warm cream. Clicking it should retry the load (the URL will have `?r=<timestamp>` appended).

- [ ] **Step 3: Confirm no console errors**

DevTools → Console. Expected: zero errors. If `data-blur` base64 is malformed, you'd see a broken-image-style error. If font files 404, you'd see network errors in the Network tab (but no console errors since `font-display: optional` is silent on failure).

---

## Task 11: Commit and deploy

**Files:** All modified files

- [ ] **Step 1: Commit**

```powershell
git add index.html scripts/
git commit -m "Add blur-up image loading and fix broken img src paths"
```

- [ ] **Step 2: Deploy to Netlify**

```powershell
netlify deploy --prod
```

- [ ] **Step 3: Verify live site**

Open `https://birthdayofbabi.netlify.app` on a mobile device or Chrome DevTools mobile emulation. Scroll through the full page. Confirm:
- No font layout shift (text doesn't jump as fonts load)
- Blur-up effect visible on first visit (fonts/images not yet cached)
- Gold error state appears if you block an image in DevTools Network panel

---

## Self-Review Notes

- **Spec coverage:** Font fix ✓ (self-hosted, optional, preload). Blur-up loading ✓ (base64, 0.4s fade, error state). Error retry ✓. Scope exclusions (video poster, hero SVGs) ✓.
- **Broken src paths:** Two pre-existing broken paths (`Images\IMG_8960.jpg` backslash, `images/Right now.jpg` wrong case) fixed in inject script — these were failing silently on Netlify (Linux, case-sensitive).
- **Type consistency:** `setupImg()` used consistently in Tasks 5 and 5's retry handler. `blurData` key format matches between gen-thumbnails output and inject-blur input.
- **`.polaroid position:relative`:** Added in Task 4 CSS so the absolutely-positioned overlay and error state render correctly inside polaroid cards.
