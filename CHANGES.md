# Changes: Native C Fork

This document explains what changed from the original TigerReddit and why,
for the benefit of the original author and future contributors.

Original TigerReddit by Harry Fornasier.
Native C port by Greg Gant (greggant.com).

## Summary

**Goal:** Eliminate the Python 3 runtime dependency so TigerReddit builds
and runs on a stock Mac OS X 10.4/10.5 system with only Xcode + Tigerbrew.

**Result:** A fully native Cocoa + C application with no external runtime
dependencies. The final binary statically links libcurl and OpenSSL for
TLS 1.2 Reddit access.

## Why remove the Python dependency?

- Tiger ships with Python 2.3 (incompatible with reddit_fetcher.py)
- Building Python 3.x from source on PPC is non-trivial
- It's a ~50MB runtime for HTTP requests + string processing
- Users must install it separately before the app works

With this change, the only build-time dependency is Tigerbrew's `curl` and
`openssl` packages. The resulting binary runs standalone.

## New features (not in original)

### Post detail view
- **Double-click any post** to open a detail window
- Shows full-size image at the top (downloaded to cache, not Desktop)
- Title, author, score, subreddit metadata
- Clickable post URL (truncated with ... if long)
- Right-click image to "Save Image to Desktop"

### Threaded comments
- Comments display with **nested replies** (indented, with colored bars)
- All replies expanded up to **6 levels deep**
- At depth 6+, shows clickable **"Continue reading on Reddit..."** link
- Max comment count configurable via Preferences
- Comments parsed from Reddit's nested JSON structure

### Video playback
- Reddit-hosted videos (v.redd.it) download at 360p
- Opens in **MPlayer OSX Extended** (falls back to VLC, then default player)
- Videos that require auth show a dialog with option to open in browser
- Video download is lazy — only happens when "Download & Play Video" is clicked

### Application menu
- Proper macOS app menu (TigerReddit > About, Preferences, Quit)
- Uses `setAppleMenu:` for correct Tiger/Leopard menu behavior
- Cmd+Q to quit, Cmd+, for preferences

### Preferences
- **Default subreddit** — saved to NSUserDefaults, loaded on launch
- **Max comments** — controls how many comments render in detail view
- Accessible from app menu (Cmd+,) and toolbar button

### Other improvements
- App icon (Tiger/Leopard-compatible .icns with Apple icns RLE)
- `over18=1` cookie on all requests (auto-confirms Reddit age gate)
- Image format detection via magic bytes (JPEG, PNG, GIF, WebP)
- WebP thumbnails detected and skipped (unsupported on Tiger/Leopard)
- HTML error pages detected and discarded (not saved as fake images)
- HLS URL extraction from Reddit API for video posts

## What changed (technical)

### New files

- **`reddit_fetcher.h`** — Public C API header
- **`reddit_fetcher.c`** — Complete C replacement for `reddit_fetcher.py`:
  - HTTP client using libcurl (TLS 1.2 via Tigerbrew OpenSSL 3.x)
  - Reddit JSON API parsing using cJSON
  - Content type detection (image/video/article/self/link)
  - URL cleaning (preserves auth tokens on preview.redd.it URLs)
  - YouTube/Redgifs thumbnail extraction
  - Reddit gallery metadata parsing
  - Thumbnail cache with magic byte validation (`~/.reddit_viewer_cache/`)
  - Full image cache for detail view (`reddit_cache_full_image()`)
  - Video download with CMAF resolution fallback (`reddit_download_video()`)
  - `__floatundidf` shim for GCC 4.0 PPC + OpenSSL 3.x compatibility
  - `my_memmem()` compat function for platforms without `memmem()`
- **`reddit.icns`** — App icon in classic Tiger-compatible format
- **`reddit-tiger.tiff`** — Source icon image
- **`remux_fmp4.py`** — Fragmented MP4 to regular MP4 remuxer (bundled)
- **`BUILDING.md`** — Build instructions
- **`CHANGES.md`** — This file
- **`ICNS_FORMAT.md`** — Documentation on Apple icns RLE format

### Modified files

- **`RedditViewer.m`** — Major changes:
  - `#include "reddit_fetcher.h"` — uses C API directly
  - ObjC class renamed from `RedditPost` to `RDPost` (avoids C struct collision)
  - All `NSTask` + Python calls replaced with direct C function calls
  - `updateWithResult:` populates table from C struct (no JSON round-trip)
  - `SaveableImageView` — custom NSImageView with right-click save menu
  - `showPostDetailWindow:withCommentsJSON:` — full post detail view
  - `renderComment:depth:yOffset:docView:contentWidth:permalink:shown:` — recursive threaded comment renderer
  - `playVideoFromButton:` — video download + MPlayer launch
  - `openLinkFromButton:` — clickable URL handler
  - `showPreferences:` / `loadPreferences` / `savePreferences` — prefs window
  - `showAbout:` — About dialog with credits
  - App menu bar with `setAppleMenu:` for Tiger/Leopard compatibility
  - Removed: `getPythonPath`, `getScriptPath`, `getBundledScriptPath`,
    `getScriptPathWithSimple:`, `runPythonScriptSync:sort:`,
    `runPythonScript:`, `viewComments:`, `openFullImage:`
  - Default subreddit changed from "programming" to "vintageapple"

- **`Makefile`** — Rewritten:
  - Build output to `TigerReddit/` directory
  - Statically links libcurl + OpenSSL 3.x + all dependencies from Tigerbrew Cellar
  - Bundles `reddit.icns` and `remux_fmp4.py` in app bundle
  - Version-specific Cellar paths (editable at top of file)

### Removed dependencies

- `reddit_fetcher.py` — replaced by `reddit_fetcher.c`
- `reddit_fetcher_simple.py` — no longer needed
- `table_test.py` — test data still in ObjC `addTestData` method
- Python 3.x runtime — completely eliminated

### Kept as-is

- `cJSON.c` / `cJSON.h` — unchanged
- Image cache directory location (`~/.reddit_viewer_cache/`)
- User-Agent string
- Post count popup, pagination, sort options
- yt-dlp bundling (optional, for non-Reddit video downloads)

## Technical notes

### Why libcurl instead of native Cocoa networking?

Tiger's system OpenSSL (0.9.7) only supports TLS 1.0. Reddit requires
TLS 1.2 minimum. `NSURLConnection` goes through the system SSL stack,
so it cannot connect to Reddit. libcurl linked against Tigerbrew's
OpenSSL 3.x provides TLS 1.2+ support.

### Why not regex?

Tiger's C library has no regex. Instead of adding PCRE as a dependency,
we use `strstr()` / `strchr()` — the URL patterns are simple enough.

### Apple icns RLE (not PackBits!)

The app icon uses the classic Tiger-compatible .icns format with
`is32`/`il32`/`it32` entries. These use Apple's custom RLE encoding
which is **not** standard PackBits. See `ICNS_FORMAT.md` for details.

### Video playback on PPC

Reddit serves H.264 video in CMAF (fragmented MP4) containers.
Neither QuickTime 7 nor VLC 2.0 on PPC can decode these properly.
MPlayer OSX Extended (with AltiVec-optimized H.264 decoding) handles
them correctly. The app tries MPlayer first, then VLC, then the
system default player.

### C89 compatibility

All code is C89-compatible for GCC 4.0:
- Variable declarations at top of blocks
- No C99 features
- `int i;` before all for loops

### Memory management

- C side: `_free()` functions for all returned structs
- ObjC side: manual retain/release (no ARC)
