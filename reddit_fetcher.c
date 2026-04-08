/*
 * reddit_fetcher.c - Native C Reddit API client for TigerReddit
 *
 * Replaces reddit_fetcher.py with pure C, using libcurl + cJSON.
 * C89-compatible for GCC 4.0 on Mac OS X 10.4 Tiger.
 *
 * Copyright 2026 - TigerReddit Contributors
 * Based on the original Python implementation by Harry Fornasier.
 */

#include "reddit_fetcher.h"
#include "cJSON.h"

#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <unistd.h>
#include <pwd.h>
#include <time.h>

/*
 * GCC 4.0 for PPC does not provide __floatundidf (unsigned long long to
 * double conversion). OpenSSL 3.x references it. Provide a shim so we
 * can link statically against Tigerbrew's OpenSSL without a newer GCC.
 */
double __floatundidf(unsigned long long a) {
    double result = (double)(unsigned long)(a >> 32);
    result *= 4294967296.0;  /* 2^32 */
    result += (double)(unsigned long)(a & 0xFFFFFFFFUL);
    return result;
}

/* memmem may not exist on all platforms */
static void *my_memmem(const void *haystack, size_t hlen,
                       const void *needle, size_t nlen) {
    const unsigned char *h = (const unsigned char *)haystack;
    const unsigned char *n = (const unsigned char *)needle;
    size_t i;
    if (nlen == 0) return (void *)haystack;
    if (nlen > hlen) return NULL;
    for (i = 0; i <= hlen - nlen; i++) {
        if (memcmp(h + i, n, nlen) == 0) return (void *)(h + i);
    }
    return NULL;
}

/* --- Constants -------------------------------------------------------- */

#define USER_AGENT      "Mozilla/5.0 (Macintosh; PPC Mac OS X 10_4) Reddit Viewer 1.0"
#define MAX_URL_LEN     2048
#define MAX_PATH_LEN    1024
#define THUMB_MAX_BYTES (200 * 1024)   /* 200 KB thumbnail limit */
#define THUMB_TIMEOUT   5L             /* seconds per thumbnail */
#define API_TIMEOUT     15L            /* seconds for Reddit API */
#define COMMENT_TIMEOUT 20L            /* seconds for comments */
#define DOWNLOAD_TIMEOUT 30L           /* seconds for full image */
#define RATE_LIMIT_MS   100            /* ms between thumbnail downloads */

/* --- Internal: growable buffer for curl responses --------------------- */

typedef struct {
    char  *data;
    size_t size;
    size_t capacity;
} Buffer;

static void buffer_init(Buffer *b) {
    b->data = NULL;
    b->size = 0;
    b->capacity = 0;
}

static void buffer_free(Buffer *b) {
    free(b->data);
    b->data = NULL;
    b->size = 0;
    b->capacity = 0;
}

static size_t buffer_write_cb(void *ptr, size_t size, size_t nmemb, void *userdata) {
    Buffer *b = (Buffer *)userdata;
    size_t bytes = size * nmemb;
    size_t needed = b->size + bytes + 1;

    if (needed > b->capacity) {
        size_t newcap = (b->capacity == 0) ? 4096 : b->capacity;
        while (newcap < needed) newcap *= 2;
        {
            char *tmp = realloc(b->data, newcap);
            if (!tmp) return 0;
            b->data = tmp;
            b->capacity = newcap;
        }
    }
    memcpy(b->data + b->size, ptr, bytes);
    b->size += bytes;
    b->data[b->size] = '\0';
    return bytes;
}

/* Size-limited write callback for thumbnails */
typedef struct {
    FILE  *fp;
    size_t written;
    size_t limit;
} FileWriter;

static size_t file_write_cb(void *ptr, size_t size, size_t nmemb, void *userdata) {
    FileWriter *fw = (FileWriter *)userdata;
    size_t bytes = size * nmemb;
    if (fw->written + bytes > fw->limit) {
        return 0; /* abort - too large */
    }
    {
        size_t w = fwrite(ptr, 1, bytes, fw->fp);
        fw->written += w;
        return w;
    }
}

/* --- Internal: cache directory ---------------------------------------- */

static char g_cache_dir[MAX_PATH_LEN] = {0};

static const char *get_home_dir(void) {
    const char *home = getenv("HOME");
    if (home) return home;
    {
        struct passwd *pw = getpwuid(getuid());
        if (pw) return pw->pw_dir;
    }
    return "/tmp";
}

static void ensure_cache_dir(void) {
    if (g_cache_dir[0] == '\0') {
        snprintf(g_cache_dir, sizeof(g_cache_dir),
                 "%s/.reddit_viewer_cache", get_home_dir());
    }
    mkdir(g_cache_dir, 0755);
}

/* --- Internal: string utilities --------------------------------------- */

static char *strdup_safe(const char *s) {
    char *d;
    if (!s) return NULL;
    d = malloc(strlen(s) + 1);
    if (d) strcpy(d, s);
    return d;
}

/* Simple MD5-ish hash for cache keys (FNV-1a, not crypto) */
static unsigned int fnv_hash(const char *s) {
    unsigned int h = 2166136261u;
    while (*s) {
        h ^= (unsigned char)*s++;
        h *= 16777619u;
    }
    return h;
}

/* URL-encode a string into dst (must be large enough). */
static void url_encode(const char *src, char *dst, size_t dst_size) {
    static const char *hex = "0123456789ABCDEF";
    size_t i = 0;
    while (*src && i + 3 < dst_size) {
        unsigned char c = (unsigned char)*src;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~') {
            dst[i++] = c;
        } else {
            dst[i++] = '%';
            dst[i++] = hex[c >> 4];
            dst[i++] = hex[c & 0xF];
        }
        src++;
    }
    dst[i] = '\0';
}

/* Replace all occurrences of `find` with `replace` in a new string. Caller frees. */
static char *str_replace(const char *str, const char *find, const char *replace) {
    const char *p;
    size_t find_len, replace_len, count, result_len;
    char *result, *w;

    if (!str || !find || !replace) return strdup_safe(str);

    find_len = strlen(find);
    replace_len = strlen(replace);
    if (find_len == 0) return strdup_safe(str);

    /* Count occurrences */
    count = 0;
    p = str;
    while ((p = strstr(p, find)) != NULL) {
        count++;
        p += find_len;
    }
    if (count == 0) return strdup_safe(str);

    result_len = strlen(str) + count * (replace_len - find_len);
    result = malloc(result_len + 1);
    if (!result) return NULL;

    w = result;
    p = str;
    while (*p) {
        if (strncmp(p, find, find_len) == 0) {
            memcpy(w, replace, replace_len);
            w += replace_len;
            p += find_len;
        } else {
            *w++ = *p++;
        }
    }
    *w = '\0';
    return result;
}

/* Case-insensitive substring search */
static const char *strcasestr_compat(const char *haystack, const char *needle) {
    size_t nlen;
    if (!haystack || !needle) return NULL;
    nlen = strlen(needle);
    if (nlen == 0) return haystack;
    while (*haystack) {
        size_t i;
        for (i = 0; i < nlen; i++) {
            char h = haystack[i];
            char n = needle[i];
            if (h >= 'A' && h <= 'Z') h += 32;
            if (n >= 'A' && n <= 'Z') n += 32;
            if (h != n) break;
        }
        if (i == nlen) return haystack;
        haystack++;
    }
    return NULL;
}

/* Check if string ends with suffix (case-insensitive) */
static int str_endswith_ci(const char *str, const char *suffix) {
    size_t slen, xlen;
    if (!str || !suffix) return 0;
    slen = strlen(str);
    xlen = strlen(suffix);
    if (xlen > slen) return 0;
    return (strcasestr_compat(str + slen - xlen, suffix) != NULL);
}

/* Extract path component from URL (before query string) */
static void url_path(const char *url, char *path, size_t path_size) {
    const char *start, *end;
    size_t len;

    /* Skip scheme */
    start = strstr(url, "://");
    if (start) {
        start += 3;
        start = strchr(start, '/');
        if (!start) { path[0] = '\0'; return; }
    } else {
        start = url;
    }

    /* Find end (query or fragment) */
    end = strchr(start, '?');
    if (!end) end = strchr(start, '#');
    if (!end) end = start + strlen(start);

    len = end - start;
    if (len >= path_size) len = path_size - 1;
    memcpy(path, start, len);
    path[len] = '\0';
}

/* Get file extension from path */
static const char *get_extension(const char *path) {
    const char *dot = strrchr(path, '.');
    if (!dot || dot == path) return "";
    return dot + 1;
}

/* Clean image URL: strip query params after known image extensions.
 * EXCEPT for preview.redd.it URLs, which use query params for auth tokens. */
static char *clean_image_url(const char *url) {
    static const char *exts[] = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", NULL};
    int i;
    if (!url) return NULL;

    /* Never strip query params from Reddit preview URLs - they need auth tokens */
    if (strstr(url, "preview.redd.it") || strstr(url, "external-preview.redd.it")) {
        return strdup_safe(url);
    }

    for (i = 0; exts[i]; i++) {
        const char *p = strcasestr_compat(url, exts[i]);
        if (p) {
            size_t end = (p - url) + strlen(exts[i]);
            char *cleaned = malloc(end + 1);
            if (cleaned) {
                memcpy(cleaned, url, end);
                cleaned[end] = '\0';
            }
            return cleaned;
        }
    }
    return strdup_safe(url);
}

/* Sanitize a string for use as a filename */
static void sanitize_filename(const char *src, char *dst, size_t dst_size) {
    size_t i = 0;
    size_t max = dst_size - 1;
    if (max > 50) max = 50; /* truncate long titles */
    while (*src && i < max) {
        char c = *src++;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
            (c >= '0' && c <= '9') || c == '-' || c == '_' || c == ' ') {
            dst[i++] = (c == ' ') ? '_' : c;
        }
        /* skip other chars */
    }
    dst[i] = '\0';
}

/* --- Internal: content type detection --------------------------------- */

static int is_image_url(const char *url) {
    static const char *img_exts[] = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", NULL};
    static const char *img_hosts[] = {"i.redd.it", "i.imgur.com", "imgur.com", "i.postimg.cc", NULL};
    int i;

    if (!url) return 0;

    for (i = 0; img_exts[i]; i++) {
        char path[MAX_URL_LEN];
        url_path(url, path, sizeof(path));
        if (str_endswith_ci(path, img_exts[i])) return 1;
    }
    for (i = 0; img_hosts[i]; i++) {
        if (strcasestr_compat(url, img_hosts[i])) return 1;
    }
    return 0;
}

static int is_video_url(const char *url) {
    static const char *vid_exts[] = {".mp4", ".webm", ".mov", ".avi", ".mkv", ".m4v", NULL};
    static const char *vid_hosts[] = {
        "v.redd.it", "v.reddit.com", "youtube.com", "youtu.be",
        "streamable.com", "gfycat.com", "redgifs.com",
        "clips.twitch.tv", "vimeo.com", NULL
    };
    int i;

    if (!url) return 0;

    for (i = 0; vid_exts[i]; i++) {
        char path[MAX_URL_LEN];
        url_path(url, path, sizeof(path));
        if (str_endswith_ci(path, vid_exts[i])) return 1;
    }
    for (i = 0; vid_hosts[i]; i++) {
        if (strcasestr_compat(url, vid_hosts[i])) return 1;
    }
    return 0;
}

static int is_article_url(const char *url) {
    static const char *article_indicators[] = {
        ".com", ".org", ".net", ".edu", ".gov", ".co.uk", ".io",
        "news", "blog", "article", "medium.com", "substack.com", NULL
    };
    int i;

    if (!url) return 0;
    if (strcasestr_compat(url, "reddit.com") || strcasestr_compat(url, "redd.it")) return 0;
    if (is_image_url(url) || is_video_url(url)) return 0;

    for (i = 0; article_indicators[i]; i++) {
        if (strcasestr_compat(url, article_indicators[i])) return 1;
    }
    return 0;
}

static const char *get_content_type(cJSON *post, const char *url) {
    cJSON *is_self = cJSON_GetObjectItem(post, "is_self");
    if (is_self && cJSON_IsTrue(is_self)) return "self";
    if (is_video_url(url)) return "video";
    if (is_image_url(url)) return "image";
    if (is_article_url(url)) return "article";
    return "link";
}

/* --- Internal: thumbnail extraction from post data -------------------- */

/* Try to get a valid thumbnail URL from Reddit's data */
static char *get_reddit_thumbnail(cJSON *post) {
    cJSON *thumb = cJSON_GetObjectItem(post, "thumbnail");
    if (thumb && cJSON_IsString(thumb) && thumb->valuestring) {
        const char *t = thumb->valuestring;
        if (strncmp(t, "http", 4) == 0 &&
            strcmp(t, "self") != 0 &&
            strcmp(t, "default") != 0 &&
            strcmp(t, "spoiler") != 0 &&
            strcmp(t, "nsfw") != 0) {
            return strdup_safe(t);
        }
    }
    return NULL;
}

/* Extract YouTube video ID and build thumbnail URL */
static char *extract_youtube_thumb(const char *url) {
    const char *id_start = NULL;
    char vid_id[12];
    char *thumb;

    /* youtube.com/watch?v=XXXXXXXXXXX */
    id_start = strstr(url, "youtube.com/watch?v=");
    if (id_start) {
        id_start += 19;
    } else {
        /* youtu.be/XXXXXXXXXXX */
        id_start = strstr(url, "youtu.be/");
        if (id_start) id_start += 9;
    }

    if (!id_start) return NULL;

    /* Copy 11-char video ID */
    {
        int i;
        for (i = 0; i < 11 && id_start[i]; i++) {
            char c = id_start[i];
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                (c >= '0' && c <= '9') || c == '_' || c == '-') {
                vid_id[i] = c;
            } else {
                break;
            }
        }
        if (i < 11) return NULL;
        vid_id[11] = '\0';
    }

    thumb = malloc(256);
    if (thumb) {
        snprintf(thumb, 256, "https://img.youtube.com/vi/%s/mqdefault.jpg", vid_id);
    }
    return thumb;
}

/* Extract video thumbnail */
static char *extract_video_thumbnail(cJSON *post, const char *url) {
    char *thumb;

    /* Reddit's own thumbnail first */
    thumb = get_reddit_thumbnail(post);
    if (thumb) return thumb;

    /* Redgifs */
    if (strstr(url, "redgifs.com") && strstr(url, "/watch/")) {
        const char *id_start = strstr(url, "/watch/");
        if (id_start) {
            const char *id_end;
            id_start += 7;
            id_end = strchr(id_start, '?');
            if (!id_end) id_end = id_start + strlen(id_start);
            {
                size_t id_len = id_end - id_start;
                thumb = malloc(256);
                if (thumb) {
                    snprintf(thumb, 256, "https://thumbs2.redgifs.com/%.*s-mobile.jpg",
                             (int)id_len, id_start);
                }
                return thumb;
            }
        }
    }

    /* YouTube */
    thumb = extract_youtube_thumb(url);
    if (thumb) return thumb;

    return NULL;
}

/* --- Internal: CA certificate bundle path ------------------------------ */

static char g_ca_bundle[MAX_PATH_LEN] = {0};

static const char *get_ca_bundle(void) {
    struct stat st;
    if (g_ca_bundle[0]) return g_ca_bundle;

    /* 1. Bundled in .app/Contents/Resources/ (set by ObjC side) */
    if (getenv("TIGERREDDIT_CA_BUNDLE")) {
        strncpy(g_ca_bundle, getenv("TIGERREDDIT_CA_BUNDLE"), sizeof(g_ca_bundle) - 1);
        if (stat(g_ca_bundle, &st) == 0) return g_ca_bundle;
    }

    /* 2. Tigerbrew location */
    if (stat("/usr/local/etc/openssl@3/cert.pem", &st) == 0) {
        strncpy(g_ca_bundle, "/usr/local/etc/openssl@3/cert.pem", sizeof(g_ca_bundle) - 1);
        return g_ca_bundle;
    }

    /* 3. Cache dir (we copy it there on first launch) */
    {
        char path[MAX_PATH_LEN];
        snprintf(path, sizeof(path), "%s/.reddit_viewer_cache/ca-bundle.crt", get_home_dir());
        if (stat(path, &st) == 0) {
            strncpy(g_ca_bundle, path, sizeof(g_ca_bundle) - 1);
            return g_ca_bundle;
        }
    }

    /* 4. System locations */
    if (stat("/etc/ssl/certs/ca-certificates.crt", &st) == 0) {
        strncpy(g_ca_bundle, "/etc/ssl/certs/ca-certificates.crt", sizeof(g_ca_bundle) - 1);
        return g_ca_bundle;
    }

    g_ca_bundle[0] = '\0';
    return NULL;
}

/* --- Internal: HTTP fetch helper -------------------------------------- */

static int http_get(const char *url, Buffer *response, long timeout_secs) {
    CURL *curl;
    CURLcode res;

    curl = curl_easy_init();
    if (!curl) return -1;

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, USER_AGENT);
    curl_easy_setopt(curl, CURLOPT_COOKIE, "over18=1");
    {
        const char *ca = get_ca_bundle();
        if (ca) curl_easy_setopt(curl, CURLOPT_CAINFO, ca);
    }
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, buffer_write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, response);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout_secs);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

    res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);

    return (res == CURLE_OK) ? 0 : -1;
}

/* Download a URL to a file, with size limit. Returns bytes written or -1. */
static long http_download_file(const char *url, const char *filepath,
                               size_t max_bytes, long timeout_secs) {
    CURL *curl;
    CURLcode res;
    FileWriter fw;

    fw.fp = fopen(filepath, "wb");
    if (!fw.fp) return -1;
    fw.written = 0;
    fw.limit = max_bytes;

    curl = curl_easy_init();
    if (!curl) { fclose(fw.fp); return -1; }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_USERAGENT, USER_AGENT);
    curl_easy_setopt(curl, CURLOPT_COOKIE, "over18=1");
    {
        const char *ca = get_ca_bundle();
        if (ca) curl_easy_setopt(curl, CURLOPT_CAINFO, ca);
    }
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, file_write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &fw);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout_secs);
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(curl, CURLOPT_MAXREDIRS, 5L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

    res = curl_easy_perform(curl);
    curl_easy_cleanup(curl);
    fclose(fw.fp);

    if (res != CURLE_OK || fw.written == 0) {
        unlink(filepath);
        return -1;
    }
    return (long)fw.written;
}

/* --- Internal: thumbnail cache ---------------------------------------- */

/*
 * Download a thumbnail to the cache directory.
 * Returns the local file path (caller frees) or NULL on failure.
 */
/* Detect image format from file magic bytes. Returns extension string. */
static const char *detect_image_format(const char *filepath) {
    FILE *f;
    unsigned char magic[16];
    size_t n;

    f = fopen(filepath, "rb");
    if (!f) return NULL;
    n = fread(magic, 1, sizeof(magic), f);
    fclose(f);
    if (n < 8) return NULL;

    /* JPEG: FF D8 FF */
    if (magic[0] == 0xFF && magic[1] == 0xD8 && magic[2] == 0xFF)
        return "jpg";
    /* PNG: 89 50 4E 47 */
    if (magic[0] == 0x89 && magic[1] == 0x50 && magic[2] == 0x4E && magic[3] == 0x47)
        return "png";
    /* GIF: GIF8 */
    if (magic[0] == 'G' && magic[1] == 'I' && magic[2] == 'F' && magic[3] == '8')
        return "gif";
    /* WebP: RIFF....WEBP */
    if (magic[0] == 'R' && magic[1] == 'I' && magic[2] == 'F' && magic[3] == 'F' &&
        n >= 12 && magic[8] == 'W' && magic[9] == 'E' && magic[10] == 'B' && magic[11] == 'P')
        return "webp";
    /* BMP: BM */
    if (magic[0] == 'B' && magic[1] == 'M')
        return "bmp";
    /* TIFF: II or MM */
    if ((magic[0] == 'I' && magic[1] == 'I') || (magic[0] == 'M' && magic[1] == 'M'))
        return "tiff";
    /* If it starts with < or { it's HTML/JSON error response, not an image */
    if (magic[0] == '<' || magic[0] == '{' || magic[0] == '\n')
        return NULL;

    return "jpg"; /* assume JPEG as fallback */
}

char *reddit_cache_thumbnail(const char *thumb_url) {
    unsigned int hash;
    char filepath[MAX_PATH_LEN];
    char final_path[MAX_PATH_LEN];
    struct stat st;
    const char *real_ext;

    if (!thumb_url || strncmp(thumb_url, "http", 4) != 0) return NULL;

    ensure_cache_dir();

    /* Hash the original URL (including query params) for cache key */
    hash = fnv_hash(thumb_url);

    /* Check if we already have this cached (try common extensions) */
    {
        static const char *try_exts[] = {"jpg", "png", "gif", NULL};
        int i;
        for (i = 0; try_exts[i]; i++) {
            snprintf(filepath, sizeof(filepath), "%s/reddit_%08x.%s",
                     g_cache_dir, hash, try_exts[i]);
            if (stat(filepath, &st) == 0 && st.st_size > 500 &&
                detect_image_format(filepath) != NULL) {
                return strdup_safe(filepath);
            }
        }
    }

    /* Download to a temp file first (use .tmp extension) */
    snprintf(filepath, sizeof(filepath), "%s/reddit_%08x.tmp", g_cache_dir, hash);

    /* Download using the ORIGINAL URL with all query params intact */
    if (http_download_file(thumb_url, filepath, THUMB_MAX_BYTES, THUMB_TIMEOUT) <= 0) {
        unlink(filepath);
        return NULL;
    }

    /* Detect actual format from magic bytes */
    real_ext = detect_image_format(filepath);
    if (!real_ext) {
        /* Not a valid image (probably HTML error page) — delete and fail */
        fprintf(stderr, "DEBUG: Downloaded non-image data for %s\n", thumb_url);
        unlink(filepath);
        return NULL;
    }

    /* WebP: Tiger/Leopard NSImage can't decode it — skip for now */
    if (strcmp(real_ext, "webp") == 0) {
        fprintf(stderr, "DEBUG: Skipping WebP thumbnail (unsupported on Tiger)\n");
        unlink(filepath);
        return NULL;
    }

    /* Rename to final path with correct extension */
    snprintf(final_path, sizeof(final_path), "%s/reddit_%08x.%s",
             g_cache_dir, hash, real_ext);
    rename(filepath, final_path);

    return strdup_safe(final_path);
}

/* --- Internal: parse a single post from Reddit JSON ------------------- */

static void parse_post(cJSON *item, RedditPost *post) {
    cJSON *f;
    const char *url_str;
    const char *ctype;

    memset(post, 0, sizeof(*post));

    /* Basic fields */
    f = cJSON_GetObjectItem(item, "title");
    post->title = strdup_safe(f && cJSON_IsString(f) ? f->valuestring : "[No Title]");

    f = cJSON_GetObjectItem(item, "author");
    post->author = strdup_safe(f && cJSON_IsString(f) ? f->valuestring : "[deleted]");

    f = cJSON_GetObjectItem(item, "subreddit");
    post->subreddit = strdup_safe(f && cJSON_IsString(f) ? f->valuestring : "");

    f = cJSON_GetObjectItem(item, "score");
    post->score = (f && cJSON_IsNumber(f)) ? f->valueint : 0;

    f = cJSON_GetObjectItem(item, "num_comments");
    post->num_comments = (f && cJSON_IsNumber(f)) ? f->valueint : 0;

    f = cJSON_GetObjectItem(item, "url");
    url_str = (f && cJSON_IsString(f)) ? f->valuestring : "";
    post->url = strdup_safe(url_str);

    f = cJSON_GetObjectItem(item, "permalink");
    if (f && cJSON_IsString(f)) {
        char buf[MAX_URL_LEN];
        snprintf(buf, sizeof(buf), "https://reddit.com%s", f->valuestring);
        post->permalink = strdup_safe(buf);
    } else {
        post->permalink = strdup_safe("");
    }

    f = cJSON_GetObjectItem(item, "is_self");
    post->is_self = (f && cJSON_IsTrue(f)) ? 1 : 0;

    f = cJSON_GetObjectItem(item, "selftext");
    if (f && cJSON_IsString(f) && f->valuestring[0]) {
        /* Keep full self text — gallery and self posts both can have it */
        post->selftext = strdup_safe(f->valuestring);
    } else {
        post->selftext = strdup_safe("");
    }

    f = cJSON_GetObjectItem(item, "over_18");
    post->is_nsfw = (f && cJSON_IsTrue(f)) ? 1 : 0;

    /* Content type detection */
    ctype = get_content_type(item, url_str);
    post->content_type = strdup_safe(ctype);

    /* Content-type-specific handling */
    if (strcmp(ctype, "video") == 0) {
        post->is_video = 1;
        post->image_type = strdup_safe("video");
        post->thumbnail = extract_video_thumbnail(item, url_str);
        post->has_image = (post->thumbnail != NULL) ? 1 : 0;

        /* Extract Reddit-hosted video fallback_url from media.reddit_video */
        {
            cJSON *media = cJSON_GetObjectItem(item, "media");
            if (media) {
                cJSON *reddit_video = cJSON_GetObjectItem(media, "reddit_video");
                if (reddit_video) {
                    cJSON *fallback = cJSON_GetObjectItem(reddit_video, "fallback_url");
                    if (fallback && cJSON_IsString(fallback)) {
                        post->video_url = strdup_safe(fallback->valuestring);
                    }
                }
            }
            /* Also check secure_media */
            if (!post->video_url || post->video_url[0] == '\0') {
                cJSON *smedia = cJSON_GetObjectItem(item, "secure_media");
                if (smedia) {
                    cJSON *reddit_video = cJSON_GetObjectItem(smedia, "reddit_video");
                    if (reddit_video) {
                        cJSON *fallback = cJSON_GetObjectItem(reddit_video, "fallback_url");
                        if (fallback && cJSON_IsString(fallback)) {
                            free(post->video_url);
                            post->video_url = strdup_safe(fallback->valuestring);
                        }
                    }
                }
            }
            /* Extract HLS URL for VLC streaming */
            if (media) {
                cJSON *reddit_video2 = cJSON_GetObjectItem(media, "reddit_video");
                if (reddit_video2) {
                    cJSON *hls = cJSON_GetObjectItem(reddit_video2, "hls_url");
                    if (hls && cJSON_IsString(hls)) {
                        post->hls_url = strdup_safe(hls->valuestring);
                    }
                }
            }
            if (!post->hls_url) {
                cJSON *smedia = cJSON_GetObjectItem(item, "secure_media");
                if (smedia) {
                    cJSON *reddit_video2 = cJSON_GetObjectItem(smedia, "reddit_video");
                    if (reddit_video2) {
                        cJSON *hls = cJSON_GetObjectItem(reddit_video2, "hls_url");
                        if (hls && cJSON_IsString(hls)) {
                            post->hls_url = strdup_safe(hls->valuestring);
                        }
                    }
                }
            }

            /* Fallback to post URL */
            if (!post->video_url || post->video_url[0] == '\0') {
                free(post->video_url);
                post->video_url = strdup_safe(url_str);
            }
        }
    }
    else if (strcmp(ctype, "article") == 0) {
        post->is_article = 1;
        post->article_url = strdup_safe(url_str);
        post->image_type = strdup_safe("article");
        post->thumbnail = get_reddit_thumbnail(item);
        post->has_image = (post->thumbnail != NULL) ? 1 : 0;
    }
    else {
        /* Check for gallery */
        int is_gallery = 0;
        cJSON *gallery_flag = cJSON_GetObjectItem(item, "is_gallery");
        if (gallery_flag && cJSON_IsTrue(gallery_flag)) is_gallery = 1;
        if (strstr(url_str, "reddit.com/gallery/")) is_gallery = 1;

        if (is_gallery) {
            cJSON *media_metadata = cJSON_GetObjectItem(item, "media_metadata");
            if (media_metadata) {
                /* Get first gallery image */
                cJSON *first = media_metadata->child;
                if (first && first->string) {
                    cJSON *s = cJSON_GetObjectItem(first, "s");
                    if (s) {
                        cJSON *u = cJSON_GetObjectItem(s, "u");
                        if (u && cJSON_IsString(u)) {
                            char *img = str_replace(u->valuestring, "&amp;", "&");
                            /* Try direct i.redd.it URL */
                            cJSON *m = cJSON_GetObjectItem(first, "m");
                            if (m && cJSON_IsString(m) && strstr(img, "preview.redd.it")) {
                                const char *ext = strrchr(m->valuestring, '/');
                                if (ext) ext++; else ext = "jpg";
                                free(img);
                                img = malloc(256);
                                if (img) {
                                    snprintf(img, 256, "https://i.redd.it/%s.%s",
                                             first->string, ext);
                                }
                            }
                            post->image_url = img;
                            post->has_image = 1;
                        }
                    }
                }
                post->image_type = strdup_safe("gallery");
                post->thumbnail = get_reddit_thumbnail(item);
                if (!post->thumbnail && post->image_url) {
                    post->thumbnail = strdup_safe(post->image_url);
                }
            }
        }
        /* Direct image */
        else if (is_image_url(url_str)) {
            post->image_url = clean_image_url(url_str);
            post->has_image = 1;
            post->image_type = strdup_safe("direct");
            post->thumbnail = get_reddit_thumbnail(item);
            if (!post->thumbnail) {
                post->thumbnail = clean_image_url(url_str);
            }
        }
        /* Preview images */
        else {
            cJSON *preview = cJSON_GetObjectItem(item, "preview");
            if (preview) {
                cJSON *images = cJSON_GetObjectItem(preview, "images");
                if (images && cJSON_IsArray(images) && cJSON_GetArraySize(images) > 0) {
                    cJSON *first_img = cJSON_GetArrayItem(images, 0);
                    cJSON *source = cJSON_GetObjectItem(first_img, "source");
                    if (source) {
                        cJSON *src_url = cJSON_GetObjectItem(source, "url");
                        if (src_url && cJSON_IsString(src_url)) {
                            post->image_url = str_replace(src_url->valuestring, "&amp;", "&");
                            post->has_image = 1;
                            post->image_type = strdup_safe("preview");

                            /* Find smallest suitable resolution for thumbnail */
                            {
                                cJSON *resolutions = cJSON_GetObjectItem(first_img, "resolutions");
                                if (resolutions && cJSON_IsArray(resolutions)) {
                                    int r;
                                    for (r = 0; r < cJSON_GetArraySize(resolutions); r++) {
                                        cJSON *res = cJSON_GetArrayItem(resolutions, r);
                                        cJSON *w = cJSON_GetObjectItem(res, "width");
                                        if (w && cJSON_IsNumber(w) && w->valueint >= 150) {
                                            cJSON *res_url = cJSON_GetObjectItem(res, "url");
                                            if (res_url && cJSON_IsString(res_url)) {
                                                post->thumbnail = str_replace(res_url->valuestring, "&amp;", "&");
                                            }
                                            break;
                                        }
                                    }
                                }
                                if (!post->thumbnail) {
                                    post->thumbnail = strdup_safe(post->image_url);
                                }
                            }
                        }
                    }
                }
            }
            /* Fallback to Reddit thumbnail */
            if (!post->has_image) {
                post->thumbnail = get_reddit_thumbnail(item);
                if (post->thumbnail) {
                    post->has_image = 1;
                    post->image_url = strdup_safe(post->thumbnail);
                    post->image_type = strdup_safe("thumbnail");
                }
            }
        }
    }

    /* Defaults for unset fields */
    if (!post->image_type)  post->image_type  = strdup_safe("none");
    if (!post->video_url)   post->video_url   = strdup_safe("");
    if (!post->hls_url)     post->hls_url     = strdup_safe("");
    if (!post->article_url) post->article_url = strdup_safe("");
    if (!post->image_url)   post->image_url   = strdup_safe("");
    if (!post->thumbnail)   post->thumbnail   = strdup_safe("");
}

static void free_post_fields(RedditPost *p) {
    free(p->title);
    free(p->author);
    free(p->subreddit);
    free(p->url);
    free(p->permalink);
    free(p->selftext);
    free(p->image_url);
    free(p->thumbnail);
    free(p->image_type);
    free(p->content_type);
    free(p->video_url);
    free(p->hls_url);
    free(p->article_url);
}

/* --- Public API ------------------------------------------------------- */

int reddit_fetcher_init(void) {
    CURLcode res = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (res != CURLE_OK) return -1;
    ensure_cache_dir();
    return 0;
}

void reddit_fetcher_cleanup(void) {
    curl_global_cleanup();
}

int reddit_cache_purge(int max_age_days) {
    DIR *dir;
    struct dirent *entry;
    struct stat st;
    time_t now;
    time_t max_age_secs;
    int deleted = 0;
    char filepath[MAX_PATH_LEN];

    if (max_age_days <= 0) return 0;

    ensure_cache_dir();
    dir = opendir(g_cache_dir);
    if (!dir) return 0;

    now = time(NULL);
    max_age_secs = (time_t)max_age_days * 86400;

    while ((entry = readdir(dir)) != NULL) {
        /* Only purge reddit_ prefixed files (our cached data) */
        if (strncmp(entry->d_name, "reddit_", 7) != 0) continue;

        snprintf(filepath, sizeof(filepath), "%s/%s", g_cache_dir, entry->d_name);
        if (stat(filepath, &st) == 0) {
            if (now - st.st_mtime > max_age_secs) {
                unlink(filepath);
                deleted++;
            }
        }
    }

    closedir(dir);
    if (deleted > 0) {
        fprintf(stderr, "DEBUG: Purged %d cached files older than %d days\n",
                deleted, max_age_days);
    }
    return deleted;
}

RedditResult reddit_fetch_posts(const char *subreddit,
                                const char *sort,
                                int limit,
                                const char *after,
                                const char *before) {
    RedditResult result;
    char url[MAX_URL_LEN];
    Buffer buf;
    cJSON *root, *data, *children;
    int count, i;

    memset(&result, 0, sizeof(result));
    buffer_init(&buf);

    /* Build URL */
    if (sort && (strcmp(sort, "new") == 0 || strcmp(sort, "top") == 0 || strcmp(sort, "rising") == 0)) {
        snprintf(url, sizeof(url), "https://old.reddit.com/r/%s/%s/.json?limit=%d&raw_json=1",
                 subreddit, sort, limit > 100 ? 100 : limit);
    } else {
        snprintf(url, sizeof(url), "https://old.reddit.com/r/%s/.json?limit=%d&raw_json=1",
                 subreddit, limit > 100 ? 100 : limit);
    }

    if (after && after[0]) {
        char encoded[512];
        url_encode(after, encoded, sizeof(encoded));
        {
            size_t len = strlen(url);
            snprintf(url + len, sizeof(url) - len, "&after=%s", encoded);
        }
    } else if (before && before[0]) {
        char encoded[512];
        url_encode(before, encoded, sizeof(encoded));
        {
            size_t len = strlen(url);
            snprintf(url + len, sizeof(url) - len, "&before=%s", encoded);
        }
    }

    fprintf(stderr, "DEBUG: Fetching %s\n", url);

    /* Fetch */
    if (http_get(url, &buf, API_TIMEOUT) != 0 || !buf.data) {
        result.error = strdup_safe("Network error fetching Reddit data");
        buffer_free(&buf);
        return result;
    }

    /* Parse */
    root = cJSON_Parse(buf.data);
    buffer_free(&buf);

    if (!root) {
        result.error = strdup_safe("Failed to parse Reddit JSON");
        return result;
    }

    data = cJSON_GetObjectItem(root, "data");
    if (!data) {
        result.error = strdup_safe("Unexpected Reddit response format");
        cJSON_Delete(root);
        return result;
    }

    /* Pagination */
    {
        cJSON *af = cJSON_GetObjectItem(data, "after");
        cJSON *bf = cJSON_GetObjectItem(data, "before");
        if (af && cJSON_IsString(af) && af->valuestring[0])
            result.pagination_after = strdup_safe(af->valuestring);
        if (bf && cJSON_IsString(bf) && bf->valuestring[0])
            result.pagination_before = strdup_safe(bf->valuestring);
    }

    children = cJSON_GetObjectItem(data, "children");
    if (!children || !cJSON_IsArray(children)) {
        result.error = strdup_safe("No posts in response");
        cJSON_Delete(root);
        return result;
    }

    count = cJSON_GetArraySize(children);
    result.posts = calloc(count, sizeof(RedditPost));
    if (!result.posts) {
        result.error = strdup_safe("Out of memory");
        cJSON_Delete(root);
        return result;
    }

    /* Parse each post */
    for (i = 0; i < count; i++) {
        cJSON *child = cJSON_GetArrayItem(children, i);
        cJSON *child_data = cJSON_GetObjectItem(child, "data");
        if (child_data) {
            parse_post(child_data, &result.posts[i]);
            result.post_count++;
        }
    }

    cJSON_Delete(root);

    /* Thumbnails are NOT downloaded here — the ObjC side does it
       asynchronously via reddit_cache_thumbnail() + NSTimer so the
       UI can display posts immediately. */

    result.success = 1;
    return result;
}

CommentsResult reddit_fetch_comments(const char *permalink) {
    CommentsResult result;
    char url[MAX_URL_LEN];
    Buffer buf;

    memset(&result, 0, sizeof(result));
    buffer_init(&buf);

    /* Build URL - add .json suffix */
    if (permalink[0] != '/') {
        snprintf(url, sizeof(url), "https://reddit.com/%s", permalink);
    } else {
        snprintf(url, sizeof(url), "https://reddit.com%s", permalink);
    }

    /* Ensure .json suffix */
    {
        size_t len = strlen(url);
        if (len < 5 || strcmp(url + len - 5, ".json") != 0) {
            if (url[len-1] != '/') strcat(url, "/");
            strcat(url, ".json");
        }
    }

    fprintf(stderr, "DEBUG: Fetching comments from: %s\n", url);

    if (http_get(url, &buf, COMMENT_TIMEOUT) != 0 || !buf.data) {
        result.error = strdup_safe("Network error fetching comments");
        buffer_free(&buf);
        return result;
    }

    result.success = 1;
    result.json = buf.data;
    buf.data = NULL; /* transfer ownership */
    buffer_free(&buf);
    return result;
}

DownloadResult reddit_download_image(const char *image_url,
                                     const char *post_title) {
    DownloadResult result;
    char *cleaned;
    char filepath[MAX_PATH_LEN];
    char filename[256];
    char safe_title[64];
    const char *home;
    long bytes;

    memset(&result, 0, sizeof(result));

    if (!image_url || strncmp(image_url, "http", 4) != 0) {
        result.error = strdup_safe("Invalid image URL");
        return result;
    }

    cleaned = clean_image_url(image_url);
    if (!cleaned) {
        result.error = strdup_safe("Failed to clean URL");
        return result;
    }

    home = get_home_dir();

    /* Build filename */
    if (post_title && post_title[0]) {
        char path[MAX_URL_LEN];
        const char *ext;
        sanitize_filename(post_title, safe_title, sizeof(safe_title));
        url_path(cleaned, path, sizeof(path));
        ext = get_extension(path);
        if (!ext[0]) ext = "jpg";
        snprintf(filename, sizeof(filename), "reddit_%s.%s", safe_title, ext);
    } else {
        unsigned int hash = fnv_hash(cleaned);
        snprintf(filename, sizeof(filename), "reddit_image_%08x.jpg", hash);
    }

    snprintf(filepath, sizeof(filepath), "%s/Desktop/%s", home, filename);

    /* Avoid overwriting */
    {
        struct stat st;
        int counter = 1;
        while (stat(filepath, &st) == 0) {
            char base[256];
            const char *dot = strrchr(filename, '.');
            if (dot) {
                size_t base_len = dot - filename;
                memcpy(base, filename, base_len);
                base[base_len] = '\0';
                snprintf(filepath, sizeof(filepath), "%s/Desktop/%s_%d%s",
                         home, base, counter, dot);
            } else {
                snprintf(filepath, sizeof(filepath), "%s/Desktop/%s_%d",
                         home, filename, counter);
            }
            counter++;
        }
    }

    bytes = http_download_file(cleaned, filepath, 50 * 1024 * 1024, DOWNLOAD_TIMEOUT);
    free(cleaned);

    if (bytes > 0) {
        result.success = 1;
        result.path = strdup_safe(filepath);
        result.filename = strdup_safe(filename);
    } else {
        result.error = strdup_safe("Download failed");
    }

    return result;
}

DownloadResult reddit_cache_full_image(const char *image_url) {
    DownloadResult result;
    unsigned int hash;
    char filepath[MAX_PATH_LEN];
    char final_path[MAX_PATH_LEN];
    const char *real_ext;
    long bytes;
    struct stat st;

    memset(&result, 0, sizeof(result));

    if (!image_url || strncmp(image_url, "http", 4) != 0) {
        result.error = strdup_safe("Invalid image URL");
        return result;
    }

    ensure_cache_dir();
    hash = fnv_hash(image_url);

    /* Check if already cached */
    {
        static const char *try_exts[] = {"jpg", "png", "gif", NULL};
        int i;
        for (i = 0; try_exts[i]; i++) {
            snprintf(filepath, sizeof(filepath), "%s/reddit_full_%08x.%s",
                     g_cache_dir, hash, try_exts[i]);
            if (stat(filepath, &st) == 0 && st.st_size > 500 &&
                detect_image_format(filepath) != NULL) {
                result.success = 1;
                result.path = strdup_safe(filepath);
                return result;
            }
        }
    }

    /* Download to temp file — use original URL with auth tokens intact */
    snprintf(filepath, sizeof(filepath), "%s/reddit_full_%08x.tmp", g_cache_dir, hash);

    bytes = http_download_file(image_url, filepath, 20 * 1024 * 1024, DOWNLOAD_TIMEOUT);
    if (bytes <= 0) {
        unlink(filepath);
        result.error = strdup_safe("Download failed");
        return result;
    }

    /* Validate it's an actual image */
    real_ext = detect_image_format(filepath);
    if (!real_ext) {
        fprintf(stderr, "DEBUG: Full image download is not a valid image\n");
        unlink(filepath);
        result.error = strdup_safe("Not a valid image");
        return result;
    }

    /* WebP: unsupported on Tiger/Leopard */
    if (strcmp(real_ext, "webp") == 0) {
        unlink(filepath);
        result.error = strdup_safe("WebP format not supported");
        return result;
    }

    /* Rename with correct extension */
    snprintf(final_path, sizeof(final_path), "%s/reddit_full_%08x.%s",
             g_cache_dir, hash, real_ext);
    rename(filepath, final_path);

    result.success = 1;
    result.path = strdup_safe(final_path);
    return result;
}

/*
 * Remux fragmented MP4 (CMAF) to regular MP4 using bundled Python script.
 * Returns 0 on success, -1 on failure.
 */
static int remux_fmp4_to_mp4(const char *input_path, const char *output_path) {
    char cmd[MAX_PATH_LEN * 3];
    int ret;

    /* Try to find the remux script: bundled in .app, or next to the binary */
    static const char *script_paths[] = {
        NULL, /* will be filled with bundle path */
        "./remux_fmp4.py",
        NULL
    };
    static const char *python_paths[] = {
        "/usr/local/bin/python3",
        "/usr/local/bin/python3.10",
        "/usr/bin/python3",
        NULL
    };
    const char *python = NULL;
    const char *script = NULL;
    int pi, si;
    struct stat st;

    /* Find Python */
    for (pi = 0; python_paths[pi]; pi++) {
        if (stat(python_paths[pi], &st) == 0) {
            python = python_paths[pi];
            break;
        }
    }
    if (!python) return -1;

    /* Find script — check several common locations */
    {
        static char try_paths[4][MAX_PATH_LEN];
        const char *paths[5];
        int num_paths = 0;

        /* App bundle: <exec>/../Resources/remux_fmp4.py */
        snprintf(try_paths[0], MAX_PATH_LEN, "%s/.reddit_viewer_cache/../Public/tigerreddit/remux_fmp4.py", get_home_dir());
        paths[num_paths++] = try_paths[0];

        /* Home-relative */
        snprintf(try_paths[1], MAX_PATH_LEN, "%s/Development/tigerreddit-build/remux_fmp4.py", get_home_dir());
        paths[num_paths++] = try_paths[1];

        /* Current directory */
        paths[num_paths++] = "./remux_fmp4.py";

        /* Cache dir (we'll copy it there as fallback) */
        snprintf(try_paths[2], MAX_PATH_LEN, "%s/remux_fmp4.py", g_cache_dir);
        paths[num_paths++] = try_paths[2];

        paths[num_paths] = NULL;

        for (si = 0; si < num_paths; si++) {
            if (stat(paths[si], &st) == 0) {
                script = paths[si];
                break;
            }
        }
    }
    if (!script) {
        fprintf(stderr, "DEBUG: remux_fmp4.py not found\n");
        return -1;
    }

    snprintf(cmd, sizeof(cmd), "%s '%s' '%s' '%s' 2>&1",
             python, script, input_path, output_path);
    fprintf(stderr, "DEBUG: Remuxing: %s\n", cmd);
    ret = system(cmd);
    return (ret == 0) ? 0 : -1;
}

DownloadResult reddit_download_video(const char *video_url) {
    DownloadResult result;
    char filepath[MAX_PATH_LEN];
    char remuxed_path[MAX_PATH_LEN];
    unsigned int hash;
    long bytes;
    struct stat st;

    memset(&result, 0, sizeof(result));

    if (!video_url || strncmp(video_url, "http", 4) != 0) {
        result.error = strdup_safe("Invalid video URL");
        return result;
    }

    ensure_cache_dir();
    hash = fnv_hash(video_url);

    /* Check for already-remuxed cached file */
    snprintf(remuxed_path, sizeof(remuxed_path), "%s/reddit_video_%08x_qt.mp4", g_cache_dir, hash);
    if (stat(remuxed_path, &st) == 0 && st.st_size > 1000) {
        result.success = 1;
        result.path = strdup_safe(remuxed_path);
        return result;
    }

    snprintf(filepath, sizeof(filepath), "%s/reddit_video_%08x.mp4", g_cache_dir, hash);

    /*
     * Reddit now uses CMAF_ prefix (not DASH_).
     * Try low-res variants first: CMAF_96, CMAF_360, CMAF_480.
     * These are fragmented MP4 which QuickTime 7 can't play directly.
     */
    bytes = 0;
    if (strstr(video_url, "v.redd.it")) {
        /* Find the CMAF_ or DASH_ portion and try lower resolutions */
        const char *prefix_pos = strstr(video_url, "CMAF_");
        if (!prefix_pos) prefix_pos = strstr(video_url, "DASH_");

        if (prefix_pos) {
            char base_url[MAX_URL_LEN];
            size_t base_len = prefix_pos - video_url;
            /* CMAF_96 is too small (init-only). Start from 360p for real content. */
            static const char *try_res[] = {
                "CMAF_360.mp4", "CMAF_480.mp4", "CMAF_720.mp4",
                "DASH_360.mp4", "DASH_480.mp4",
                NULL
            };
            int i;

            if (base_len < sizeof(base_url)) {
                memcpy(base_url, video_url, base_len);
                base_url[base_len] = '\0';

                for (i = 0; try_res[i]; i++) {
                    char try_url[MAX_URL_LEN];
                    snprintf(try_url, sizeof(try_url), "%s%s", base_url, try_res[i]);
                    fprintf(stderr, "DEBUG: Trying video: %s\n", try_url);

                    bytes = http_download_file(try_url, filepath, 50 * 1024 * 1024, 60);
                    if (bytes > 1000) {
                        fprintf(stderr, "DEBUG: Video downloaded: %ld bytes (%s)\n", bytes, try_res[i]);
                        break;
                    }
                    unlink(filepath);
                    bytes = 0;
                }
            }
        }
    }

    /* Fallback: try original URL */
    if (bytes <= 0) {
        fprintf(stderr, "DEBUG: Trying original video URL: %s\n", video_url);
        bytes = http_download_file(video_url, filepath, 50 * 1024 * 1024, 60);
    }

    if (bytes <= 1000) {
        unlink(filepath);
        result.error = strdup_safe("Video download failed");
        return result;
    }

    /* Validate it's a real video (not an HTML error page).
       NSFW content returns tiny error stubs without authentication. */
    if (bytes < 50000) {
        /* Check if it's HTML/XML instead of video */
        FILE *f = fopen(filepath, "rb");
        if (f) {
            unsigned char hdr[8];
            size_t n = fread(hdr, 1, sizeof(hdr), f);
            fclose(f);
            if (n >= 4 && (hdr[0] == '<' || hdr[0] == '\n' || hdr[0] == '{')) {
                fprintf(stderr, "DEBUG: Video download is error page (%ld bytes), not video\n", bytes);
                unlink(filepath);
                result.error = strdup_safe("NSFW content requires login - opening in browser");
                return result;
            }
        }
    }

    result.success = 1;
    result.path = strdup_safe(filepath);
    return result;
}

/* --- Memory management ------------------------------------------------ */

void reddit_result_free(RedditResult *r) {
    int i;
    if (!r) return;
    free(r->error);
    free(r->pagination_after);
    free(r->pagination_before);
    if (r->posts) {
        for (i = 0; i < r->post_count; i++) {
            free_post_fields(&r->posts[i]);
        }
        free(r->posts);
    }
    memset(r, 0, sizeof(*r));
}

void comments_result_free(CommentsResult *r) {
    if (!r) return;
    free(r->json);
    free(r->error);
    memset(r, 0, sizeof(*r));
}

void download_result_free(DownloadResult *r) {
    if (!r) return;
    free(r->path);
    free(r->filename);
    free(r->error);
    memset(r, 0, sizeof(*r));
}
