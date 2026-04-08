/* RedditController+Data.inc
 * Data fetching, JSON parsing, and thumbnail management.
 * Included from RedditViewer.m inside @implementation RedditController.
 */

- (void)fetchRedditData {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    NSLog(@"=== FETCH REQUEST START ===");
    NSLog(@"Subreddit: %@, Sort: %@", subreddit, sort);

    [statusText setString:@"Fetching posts..."];
    [progressIndicator startAnimation:nil];

    /* Clear existing data */
    [posts removeAllObjects];
    [tableView reloadData];

    /* Use native C fetcher directly */
    [self fetchPostsWithSubreddit:subreddit sort:sort count:currentPostCount after:nil before:nil];
}

- (void)fetchRedditDataWithAfter:(NSString *)after {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    [statusText setString:@"Loading next page..."];
    [progressIndicator startAnimation:nil];

    [self fetchPostsWithSubreddit:subreddit sort:sort count:currentPostCount after:after before:nil];
}

- (void)fetchRedditDataWithBefore:(NSString *)before {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    [statusText setString:@"Loading previous page..."];
    [progressIndicator startAnimation:nil];

    [self fetchPostsWithSubreddit:subreddit sort:sort count:currentPostCount after:nil before:before];
}

/*
 * fetchPostsWithSubreddit:sort:count:after:before:
 * Replaces runPythonScriptWithSubreddit: - calls the native C API directly.
 */
- (void)fetchPostsWithSubreddit:(NSString *)subreddit sort:(NSString *)sort count:(int)count after:(NSString *)after before:(NSString *)before {
    const char *afterStr;
    const char *beforeStr;
    RedditResult result;

    NSLog(@"=== NATIVE FETCH START ===");
    NSLog(@"Subreddit: %@, Sort: %@, Count: %d", subreddit, sort, count);

    [statusText setString:[NSString stringWithFormat:@"Fetching r/%@...", subreddit]];

    afterStr = (after && [after length] > 0) ? [after UTF8String] : NULL;
    beforeStr = (before && [before length] > 0) ? [before UTF8String] : NULL;

    result = reddit_fetch_posts([subreddit UTF8String],
                                [[sort lowercaseString] UTF8String],
                                count,
                                afterStr,
                                beforeStr);

    [self updateWithResult:result];

    reddit_result_free(&result);

    [progressIndicator stopAnimation:nil];
    NSLog(@"=== NATIVE FETCH END ===");
}

/*
 * updateWithResult: - Populate the ObjC posts array directly from C RedditResult
 * without JSON round-tripping. This is the primary data path.
 */
- (void)updateWithResult:(RedditResult)result {
    int i;
    NSString *statusMsg;

    NSLog(@"=== UPDATE WITH RESULT START ===");

    [posts removeAllObjects];
    [tableView reloadData];

    if (!result.success || result.post_count == 0) {
        NSString *errMsg = result.error ?
            [NSString stringWithUTF8String:result.error] : @"No posts found";
        [statusText setString:errMsg];
        NSLog(@"Fetch failed or empty: %@", errMsg);
        return;
    }

    /* Update pagination tokens */
    [currentAfter release];
    [currentBefore release];
    currentAfter = result.pagination_after ?
        [[NSString stringWithUTF8String:result.pagination_after] retain] : nil;
    currentBefore = result.pagination_before ?
        [[NSString stringWithUTF8String:result.pagination_before] retain] : nil;

    NSLog(@"Pagination - after: %@, before: %@", currentAfter, currentBefore);

    /* Convert C structs to ObjC objects */
    for (i = 0; i < result.post_count; i++) {
        RedditPost *src = &result.posts[i]; /* C struct from reddit_fetcher.h */
        RDPost *post = [[RDPost alloc] init]; /* ObjC object */

        [post setTitle:src->title ? [NSString stringWithUTF8String:src->title] : @"[No Title]"];
        [post setAuthor:src->author ? [NSString stringWithUTF8String:src->author] : @""];
        [post setSubreddit:src->subreddit ? [NSString stringWithUTF8String:src->subreddit] : @""];
        [post setScore:src->score];
        [post setNumComments:src->num_comments];
        [post setUrl:src->url ? [NSString stringWithUTF8String:src->url] : @""];
        [post setPermalink:src->permalink ? [NSString stringWithUTF8String:src->permalink] : @""];
        [post setSelfText:src->selftext ? [NSString stringWithUTF8String:src->selftext] : @""];
        [post setHasImage:src->has_image];

        if (src->thumbnail && strlen(src->thumbnail) > 0) {
            [post setThumbnailUrl:[NSString stringWithUTF8String:src->thumbnail]];
        }
        if (src->image_url && strlen(src->image_url) > 0) {
            [post setImageUrl:[NSString stringWithUTF8String:src->image_url]];
        }
        [post setImageType:src->image_type ? [NSString stringWithUTF8String:src->image_type] : @""];
        [post setContentType:src->content_type ? [NSString stringWithUTF8String:src->content_type] : @"link"];
        [post setIsVideo:src->is_video];

        if (src->video_url && strlen(src->video_url) > 0) {
            [post setVideoUrl:[NSString stringWithUTF8String:src->video_url]];
        }
        if (src->hls_url && strlen(src->hls_url) > 0) {
            [post setHlsUrl:[NSString stringWithUTF8String:src->hls_url]];
        }

        [post setIsArticle:src->is_article];

        if (src->article_url && strlen(src->article_url) > 0) {
            [post setArticleUrl:[NSString stringWithUTF8String:src->article_url]];
        }

        [post setIsNSFW:src->is_nsfw];

        if (i < 3) {
            NSLog(@"Post %d: '%@' by %@ (type: %@, score: %d, hasImage: %d)",
                  i+1, [post title], [post author], [post contentType], [post score], [post hasImage]);
        }

        [posts addObject:post];
        [post release];
    }

    /* Reload table immediately — thumbnails will fill in asynchronously */
    [tableView reloadData];
    [tableView setNeedsDisplay:YES];

    statusMsg = [NSString stringWithFormat:@"Loaded %d posts from r/%@",
        [posts count], [subredditField stringValue]];
    [statusText setString:statusMsg];

    NSLog(@"=== UPDATE WITH RESULT END (loaded %d posts) ===", [posts count]);

    /* Start downloading thumbnails in the background */
    [self startThumbnailDownloads];
}

- (void)updateWithJSON:(NSString *)jsonString {
    NSArray *parsedPosts;
    NSString *statusMsg;

    NSLog(@"=== UPDATE WITH JSON START ===");
    NSLog(@"JSON length: %d", [jsonString length]);

    if (!jsonString || [jsonString length] < 10) {
        NSLog(@"ERROR: Invalid JSON string");
        [statusText setString:@"Error: Invalid response"];
        return;
    }

    /* Clear existing posts */
    [posts removeAllObjects];
    [tableView reloadData];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    parsedPosts = [self parseJSONString:jsonString];
    NSLog(@"Parsed %d posts", [parsedPosts count]);

    if ([parsedPosts count] == 0) {
        [statusText setString:@"No posts found"];
        return;
    }

    [posts addObjectsFromArray:parsedPosts];

    [tableView reloadData];
    [tableView setNeedsDisplay:YES];

    statusMsg = [NSString stringWithFormat:@"Loaded %d posts from r/%@",
        [posts count], [subredditField stringValue]];
    [statusText setString:statusMsg];

    NSLog(@"=== UPDATE WITH JSON END ===");
}

/* JSON parsing (kept for compatibility, but no longer primary path) */
- (NSArray *)parseJSONString:(NSString *)jsonString {
    int i;
    int count;
    cJSON *root;
    NSMutableArray *result;
    cJSON *pagination;
    cJSON *success;
    cJSON *postsArray;

    NSLog(@"=== JSON PARSING START ===");

    if (!jsonString || [jsonString length] == 0) {
        NSLog(@"ERROR: Empty JSON string received");
        return [NSArray array];
    }

    NSLog(@"JSON string length: %d characters", [jsonString length]);

    if (![jsonString hasPrefix:@"{"] && ![jsonString hasPrefix:@"["]) {
        NSLog(@"ERROR: JSON doesn't start with { or [");
        return [NSArray array];
    }

    root = cJSON_Parse([jsonString UTF8String]);
    result = [NSMutableArray array];

    if (!root) {
        NSLog(@"ERROR: cJSON_Parse failed");
        return result;
    }

    NSLog(@"JSON parsed successfully by cJSON");

    pagination = cJSON_GetObjectItem(root, "pagination");
    if (pagination) {
        cJSON *after = cJSON_GetObjectItem(pagination, "after");
        cJSON *before = cJSON_GetObjectItem(pagination, "before");

        [currentAfter release];
        [currentBefore release];

        currentAfter = (after && cJSON_IsString(after) && strlen(after->valuestring) > 0) ?
            [[NSString stringWithUTF8String:after->valuestring] retain] : nil;
        currentBefore = (before && cJSON_IsString(before) && strlen(before->valuestring) > 0) ?
            [[NSString stringWithUTF8String:before->valuestring] retain] : nil;
    }

    success = cJSON_GetObjectItem(root, "success");
    if (!success || !cJSON_IsBool(success) || !cJSON_IsTrue(success)) {
        NSLog(@"ERROR: JSON indicates failure or missing success field");
        cJSON_Delete(root);
        return result;
    }

    postsArray = cJSON_GetObjectItem(root, "posts");
    if (!postsArray || !cJSON_IsArray(postsArray)) {
        NSLog(@"ERROR: No valid 'posts' array in JSON");
        cJSON_Delete(root);
        return result;
    }

    count = cJSON_GetArraySize(postsArray);
    NSLog(@"Found %d posts in JSON array", count);

    for (i = 0; i < count; i++) {
        cJSON *item = cJSON_GetArrayItem(postsArray, i);
        RDPost *post;
        cJSON *j_title, *j_author, *j_subreddit, *j_score, *j_num_comments;
        cJSON *j_url, *j_permalink, *j_thumbnail, *j_image_url, *j_image_type;
        cJSON *j_selftext, *j_has_image, *j_content_type, *j_is_video;
        cJSON *j_video_url, *j_is_article, *j_article_url, *j_is_nsfw;
        NSString *titleStr;

        if (!item) continue;

        post = [[RDPost alloc] init];

        j_title = cJSON_GetObjectItem(item, "title");
        j_author = cJSON_GetObjectItem(item, "author");
        j_subreddit = cJSON_GetObjectItem(item, "subreddit");
        j_score = cJSON_GetObjectItem(item, "score");
        j_num_comments = cJSON_GetObjectItem(item, "num_comments");
        j_url = cJSON_GetObjectItem(item, "url");
        j_permalink = cJSON_GetObjectItem(item, "permalink");
        j_thumbnail = cJSON_GetObjectItem(item, "thumbnail");
        j_image_url = cJSON_GetObjectItem(item, "image_url");
        j_image_type = cJSON_GetObjectItem(item, "image_type");
        j_selftext = cJSON_GetObjectItem(item, "selftext");
        j_has_image = cJSON_GetObjectItem(item, "has_image");
        j_content_type = cJSON_GetObjectItem(item, "content_type");
        j_is_video = cJSON_GetObjectItem(item, "is_video");
        j_video_url = cJSON_GetObjectItem(item, "video_url");
        j_is_article = cJSON_GetObjectItem(item, "is_article");
        j_article_url = cJSON_GetObjectItem(item, "article_url");
        j_is_nsfw = cJSON_GetObjectItem(item, "is_nsfw");

        titleStr = (j_title && cJSON_IsString(j_title)) ? [NSString stringWithUTF8String:j_title->valuestring] : @"[No Title]";
        [post setTitle:titleStr];
        [post setAuthor:j_author && cJSON_IsString(j_author) ? [NSString stringWithUTF8String:j_author->valuestring] : @""];
        [post setSubreddit:j_subreddit && cJSON_IsString(j_subreddit) ? [NSString stringWithUTF8String:j_subreddit->valuestring] : @""];
        [post setScore:j_score && cJSON_IsNumber(j_score) ? j_score->valueint : 0];
        [post setNumComments:j_num_comments && cJSON_IsNumber(j_num_comments) ? j_num_comments->valueint : 0];
        [post setUrl:j_url && cJSON_IsString(j_url) ? [NSString stringWithUTF8String:j_url->valuestring] : @""];
        [post setPermalink:j_permalink && cJSON_IsString(j_permalink) ? [NSString stringWithUTF8String:j_permalink->valuestring] : @""];
        [post setSelfText:j_selftext && cJSON_IsString(j_selftext) ? [NSString stringWithUTF8String:j_selftext->valuestring] : @""];
        [post setHasImage:(j_has_image && cJSON_IsBool(j_has_image) && cJSON_IsTrue(j_has_image))];

        if (j_thumbnail && cJSON_IsString(j_thumbnail) && strlen(j_thumbnail->valuestring) > 0) {
            [post setThumbnailUrl:[NSString stringWithUTF8String:j_thumbnail->valuestring]];
        }
        if (j_image_url && cJSON_IsString(j_image_url) && strlen(j_image_url->valuestring) > 0) {
            [post setImageUrl:[NSString stringWithUTF8String:j_image_url->valuestring]];
        }
        [post setImageType:j_image_type && cJSON_IsString(j_image_type) ? [NSString stringWithUTF8String:j_image_type->valuestring] : @""];
        [post setContentType:j_content_type && cJSON_IsString(j_content_type) ? [NSString stringWithUTF8String:j_content_type->valuestring] : @"link"];
        [post setIsVideo:(j_is_video && cJSON_IsBool(j_is_video) && cJSON_IsTrue(j_is_video))];

        if (j_video_url && cJSON_IsString(j_video_url) && strlen(j_video_url->valuestring) > 0) {
            [post setVideoUrl:[NSString stringWithUTF8String:j_video_url->valuestring]];
        }

        [post setIsArticle:(j_is_article && cJSON_IsBool(j_is_article) && cJSON_IsTrue(j_is_article))];

        if (j_article_url && cJSON_IsString(j_article_url) && strlen(j_article_url->valuestring) > 0) {
            [post setArticleUrl:[NSString stringWithUTF8String:j_article_url->valuestring]];
        }

        [post setIsNSFW:(j_is_nsfw && cJSON_IsBool(j_is_nsfw) && cJSON_IsTrue(j_is_nsfw))];

        [result addObject:post];
        [post release];
    }

    cJSON_Delete(root);
    NSLog(@"Successfully parsed %d posts", [result count]);
    return result;
}

- (void)startThumbnailDownloads {
    /* Cancel any existing thumbnail timer */
    if (thumbTimer) {
        [thumbTimer invalidate];
        thumbTimer = nil;
    }
    thumbDownloadIndex = 0;

    /* Fire immediately, then every 0.05s for fast sequential downloads */
    thumbTimer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                 target:self
                                               selector:@selector(downloadNextThumbnail:)
                                               userInfo:nil
                                                repeats:YES];
    /* Fire the first one right away */
    [self downloadNextThumbnail:thumbTimer];
}

- (void)downloadNextThumbnail:(NSTimer *)timer {
    RDPost *post;

    /* Find the next post that needs a thumbnail */
    while (thumbDownloadIndex < (int)[posts count]) {
        post = [posts objectAtIndex:thumbDownloadIndex];
        if ([post hasImage] && [post thumbnailUrl] &&
            [[post thumbnailUrl] hasPrefix:@"http"]) {
            /* This one needs downloading */
            break;
        }
        thumbDownloadIndex++;
    }

    if (thumbDownloadIndex >= (int)[posts count]) {
        /* All done */
        [timer invalidate];
        thumbTimer = nil;
        NSLog(@"Thumbnail downloads complete");
        return;
    }

    post = [posts objectAtIndex:thumbDownloadIndex];
    {
        const char *url = [[post thumbnailUrl] UTF8String];
        char *local = reddit_cache_thumbnail(url);
        if (local) {
            [post setThumbnailUrl:[NSString stringWithUTF8String:local]];
            free(local);

            /* Reload just this row for smooth progressive loading */
            [tableView reloadData];
        }
    }

    thumbDownloadIndex++;
}
