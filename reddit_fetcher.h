/*
 * reddit_fetcher.h - Native C Reddit API client for TigerReddit
 *
 * Replaces the Python reddit_fetcher.py with pure C code using
 * libcurl for HTTPS (TLS 1.2) and cJSON for JSON parsing.
 *
 * This eliminates the Python 3 runtime dependency, making TigerReddit
 * buildable and runnable on a stock Mac OS X 10.4 Tiger system with
 * only Xcode and Tigerbrew's curl/openssl.
 *
 * All functions are C89-compatible for GCC 4.0 on Tiger.
 */

#ifndef REDDIT_FETCHER_H
#define REDDIT_FETCHER_H

#include <stdlib.h>

/* --- Data structures -------------------------------------------------- */

/* Single Reddit post */
typedef struct {
    char *title;
    char *author;
    char *subreddit;
    int   score;
    int   num_comments;
    char *url;
    char *permalink;
    int   is_self;
    char *selftext;

    int   has_image;
    char *image_url;
    char *thumbnail;      /* local file path after caching, or URL */
    char *image_type;     /* "direct", "preview", "gallery", "video", "article", "thumbnail", "none" */

    char *content_type;   /* "video", "article", "image", "self", "link" */
    int   is_video;
    char *video_url;
    char *hls_url;        /* HLS playlist URL for streaming via VLC */
    int   is_article;
    char *article_url;
    int   is_nsfw;
} RedditPost;

/* Result of a subreddit fetch */
typedef struct {
    int         success;
    char       *error;
    RedditPost *posts;
    int         post_count;
    char       *pagination_after;
    char       *pagination_before;
} RedditResult;

/* Result of a comment fetch (raw JSON string) */
typedef struct {
    int   success;
    char *json;    /* caller must free */
    char *error;
} CommentsResult;

/* Result of an image download */
typedef struct {
    int   success;
    char *path;      /* local file path */
    char *filename;
    char *error;
} DownloadResult;

/* --- Public API ------------------------------------------------------- */

/*
 * Initialize the fetcher (call once at startup).
 * Sets up libcurl global state and the image cache directory.
 * Returns 0 on success, -1 on failure.
 */
int reddit_fetcher_init(void);

/*
 * Clean up (call once at shutdown).
 */
void reddit_fetcher_cleanup(void);

/*
 * Purge cached files older than max_age_days.
 * Call once at startup. Returns number of files deleted.
 */
int reddit_cache_purge(int max_age_days);

/*
 * Fetch posts from a subreddit.
 *
 * Parameters:
 *   subreddit - e.g. "all", "programming"
 *   sort      - "hot", "new", "top", "rising"
 *   limit     - number of posts (1-100)
 *   after     - pagination token, or NULL
 *   before    - pagination token, or NULL
 *
 * Caller must free the result with reddit_result_free().
 */
RedditResult reddit_fetch_posts(const char *subreddit,
                                const char *sort,
                                int limit,
                                const char *after,
                                const char *before);

/*
 * Fetch comments for a post.
 *
 * Parameters:
 *   permalink - Reddit permalink path, e.g. "/r/funny/comments/abc123/title/"
 *
 * Returns raw Reddit API JSON (the two-element array).
 * Caller must free the result with comments_result_free().
 */
CommentsResult reddit_fetch_comments(const char *permalink);

/*
 * Download a full-resolution image to the user's Desktop.
 *
 * Parameters:
 *   image_url  - URL of the image
 *   post_title - used for filename (may be NULL)
 *
 * Caller must free the result with download_result_free().
 */
DownloadResult reddit_download_image(const char *image_url,
                                     const char *post_title);

/*
 * Download a Reddit-hosted video (v.redd.it) to a temp file.
 * Tries low-resolution DASH variants first (240p, 360p).
 *
 * Parameters:
 *   video_url - the fallback_url from Reddit's API
 *
 * Returns path to a local .mp4 file. Caller must free with download_result_free().
 */
DownloadResult reddit_download_video(const char *video_url);

/*
 * Download and cache a single thumbnail image.
 * Returns the local file path (caller must free) or NULL on failure.
 * Safe to call from a timer — downloads one image at a time.
 */
char *reddit_cache_thumbnail(const char *thumb_url);

/*
 * Download an image to the cache directory for viewing (not Desktop).
 * Returns path to a local file. Caller must free with download_result_free().
 */
DownloadResult reddit_cache_full_image(const char *image_url);


/* --- Memory management ------------------------------------------------ */

void reddit_result_free(RedditResult *r);
void comments_result_free(CommentsResult *r);
void download_result_free(DownloadResult *r);

#endif /* REDDIT_FETCHER_H */
