# Building TigerReddit (Native C Version)

This fork replaces the Python 3 runtime dependency with native C code,
so TigerReddit can be built and run on Mac OS X 10.4 Tiger or 10.5 Leopard
with only Xcode and Tigerbrew installed.

## What changed

The original TigerReddit uses Python 3 (via `NSTask`) for Reddit API access,
JSON parsing, image caching, and URL detection. This fork replaces all of
that with:
- **libcurl** for HTTPS (linked against Tigerbrew's OpenSSL 3.x for TLS 1.2)
- **cJSON** for JSON parsing (already in the project)
- Native C code for URL detection, image caching, and content type classification

## Prerequisites

### On Mac OS X 10.5 Leopard (PowerPC)

1. **Xcode 3.x Developer Tools** (provides GCC 4.0)
2. **Tigerbrew** with `curl` and `openssl3` packages
3. **cJSON** source files (downloaded automatically or manually)
4. **MPlayer OSX Extended** (optional, for video playback)

### On Mac OS X 10.4 Tiger (PowerPC)

Same as Leopard, but with Xcode 2.x.

### Tigerbrew Dependencies

The Makefile expects these Tigerbrew packages in `/usr/local/Cellar/`:

| Package | Used for |
|---------|----------|
| `curl` | HTTP client library (libcurl) |
| `openssl3` | TLS 1.2 support for Reddit |
| `libnghttp2` | HTTP/2 support (curl dependency) |
| `libidn2` | International domain names (curl dep) |
| `libpsl` | Public suffix list (curl dep) |
| `libunistring` | Unicode support (idn2 dep) |
| `libiconv` | Character encoding (psl dep) |
| `zlib` | Compression (curl dep) |

Install with: `brew install curl openssl3`
(Dependencies are pulled in automatically.)

The Makefile has version-specific paths (e.g. `curl/8.16.0`). Edit the
version numbers at the top of the Makefile if yours differ:
```bash
ls /usr/local/Cellar/curl/
ls /usr/local/Cellar/openssl3/
```

## Building

```bash
cd /path/to/tigerreddit
make
```

The build output goes into `TigerReddit/TigerReddit.app`.

### Build output

```
$ make
gcc -arch ppc ... -c cJSON.c -o cJSON.o
gcc -arch ppc ... -c reddit_fetcher.c -o reddit_fetcher.o
gcc -arch ppc ... -c RedditViewer.m -o RedditViewer.o
Creating application bundle...
Built TigerReddit/TigerReddit.app successfully!

=== Build complete (static curl) ===
```

### Static linking

The Makefile statically links all Tigerbrew libraries so the resulting
binary has no runtime dependencies beyond system frameworks. The final
binary is ~8.6 MB and runs on any Tiger/Leopard system without Tigerbrew.

### Troubleshooting

**"curl/curl.h: No such file or directory"**
Check the Cellar version paths in the Makefile match your installation.

**`___floatundidf` link error**
A shim is provided in `reddit_fetcher.c` for this GCC 4.0 PPC runtime
function that OpenSSL 3.x references.

**Missing iconv/unistring symbols**
Ensure `libiconv` and `libunistring` are listed in `CURL_LIBS` in the
Makefile with their full Cellar paths.

## Running

```bash
open TigerReddit/TigerReddit.app

# For console debug output:
make debug
```

## File overview

| File | Purpose |
|------|---------|
| `RedditViewer.m` | Cocoa UI — main window, post detail view, threaded comments, preferences |
| `reddit_fetcher.c` | Reddit API client, image/video cache, URL utils, thumbnail download |
| `reddit_fetcher.h` | Public C API header |
| `cJSON.c` / `cJSON.h` | JSON parser (third-party, MIT license) |
| `reddit.icns` | App icon (Tiger/Leopard-compatible, Apple icns RLE format) |
| `reddit-tiger.tiff` | Source icon image |
| `remux_fmp4.py` | Fragmented MP4 remuxer (bundled, optional) |
| `Makefile` | Build system |
| `ICNS_FORMAT.md` | Documentation on building Tiger-compatible .icns icons |

## Architecture

```
User double-clicks a post
    |
    v
RedditViewer.m (Objective-C)
    |
    | calls reddit_fetch_posts() / reddit_fetch_comments()
    v
reddit_fetcher.c (C)
    |
    | uses libcurl for HTTPS GET (with over18=1 cookie)
    v
old.reddit.com/r/{sub}/.json  (Reddit API)
    |
    | JSON response
    v
reddit_fetcher.c
    |
    | parses with cJSON, downloads/caches thumbnails
    | returns RedditResult struct with posts array
    v
RedditViewer.m
    |
    | populates NSTableView (main list)
    | opens post detail window with image + threaded comments
    | downloads video via reddit_download_video() -> MPlayer
    v
User sees posts, images, comments, videos
```

No subprocesses, no Python, no scripts. Everything runs in-process
(except video playback which opens in MPlayer).
