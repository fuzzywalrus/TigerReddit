/* RedditController+Comments.inc
 * Comment fetching and the old-style comment window.
 * Included from RedditViewer.m inside @implementation RedditController.
 */

- (void)fetchCommentsForPost:(RDPost *)post {
    RDPost *postCopy;
    NSDictionary *taskInfo;

    [statusText setString:@"Fetching comments..."];
    [progressIndicator startAnimation:nil];

    NSLog(@"Fetching comments for permalink: %@", [post permalink]);

    postCopy = [post retain];

    taskInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        postCopy, @"post",
        nil];

    [NSTimer scheduledTimerWithTimeInterval:0.1
                                   target:self
                                 selector:@selector(fetchCommentsAsync:)
                                 userInfo:taskInfo
                                  repeats:NO];
}

- (void)fetchCommentsAsync:(NSTimer *)timer {
    NSDictionary *taskInfo = [timer userInfo];
    RDPost *post = [taskInfo objectForKey:@"post"];
    NSString *permalink;
    CommentsResult result;

    /* Clean up the permalink - make sure it's just the path part */
    permalink = [post permalink];
    if ([permalink hasPrefix:@"https://reddit.com"]) {
        permalink = [permalink substringFromIndex:18];
    } else if ([permalink hasPrefix:@"http://reddit.com"]) {
        permalink = [permalink substringFromIndex:17];
    }
    /* Ensure it starts with / */
    if (![permalink hasPrefix:@"/"]) {
        permalink = [@"/" stringByAppendingString:permalink];
    }


    NS_DURING
    {
        result = reddit_fetch_comments([permalink UTF8String]);

        if (result.success && result.json) {
            NSString *jsonString = [NSString stringWithUTF8String:result.json];
            jsonString = [jsonString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            if ([jsonString hasPrefix:@"["] || [jsonString hasPrefix:@"{"]) {
                [self showCommentsWindow:jsonString forPost:post];
            } else {
                NSLog(@"Comments response doesn't look like JSON");
                [statusText setString:@"Invalid comments response format"];
            }
        } else {
            NSString *errMsg = result.error ?
                [NSString stringWithUTF8String:result.error] : @"Failed to fetch comments";
            [statusText setString:errMsg];
            NSLog(@"Comments fetch failed: %@", errMsg);
        }

        comments_result_free(&result);
    }
    NS_HANDLER
    {
        NSLog(@"Exception fetching comments: %@", [localException reason]);
        [statusText setString:@"Error fetching comments"];
    }
    NS_ENDHANDLER

    [progressIndicator stopAnimation:nil];
    [post release];
}

- (void)showCommentsWindow:(NSString *)jsonString forPost:(RDPost *)post {

    @try {
        NSRect windowFrame = NSMakeRect(100, 100, 600, 400);
        NSWindow *commentWindow = [[NSWindow alloc] initWithContentRect:windowFrame
                                                              styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO];
        NSScrollView *scrollView;
        NSTextView *textView;

        [commentWindow setTitle:[NSString stringWithFormat:@"Comments: %@", [post title]]];

        scrollView = [[NSScrollView alloc] initWithFrame:[[commentWindow contentView] bounds]];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        textView = [[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
        [textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [textView setEditable:NO];

        [scrollView setDocumentView:textView];
        [[commentWindow contentView] addSubview:scrollView];

        [self parseCommentsJSON:jsonString intoTextView:textView forPost:post];

        [commentWindow makeKeyAndOrderFront:nil];

        [textView release];
        [scrollView release];

    }
    @catch (NSException *exception) {
        NSLog(@"Exception creating comments window: %@", [exception reason]);
        [statusText setString:@"Error opening comments window"];
    }
}

- (void)parseCommentsJSON:(NSString *)jsonString intoTextView:(NSTextView *)textView forPost:(RDPost *)post {
    int i;
    int commentCount;
    int validComments;
    NSMutableString *commentsText = [NSMutableString string];

    [commentsText appendString:[NSString stringWithFormat:@"Post: %@\n\n", [post title]]];
    [commentsText appendString:[NSString stringWithFormat:@"Author: %@ | Score: %d | Comments: %d\n\n",
        [post author], [post score], [post numComments]]];

    if ([post selfText] && [[post selfText] length] > 0) {
        [commentsText appendString:[NSString stringWithFormat:@"Text: %@\n\n", [post selfText]]];
    }

    [commentsText appendString:@"Comments:\n"];
    [commentsText appendString:@"===============================================\n\n"];

    @try {
        cJSON *root = cJSON_Parse([jsonString UTF8String]);
        if (!root) {
            [commentsText appendString:@"Error parsing comments data."];
            [textView setString:commentsText];
            return;
        }

        /* Reddit API returns an array with post data at [0] and comments at [1] */
        if (cJSON_IsArray(root) && cJSON_GetArraySize(root) >= 2) {
            cJSON *commentsSection = cJSON_GetArrayItem(root, 1);
            if (commentsSection) {
                cJSON *data = cJSON_GetObjectItem(commentsSection, "data");
                if (data) {
                    cJSON *children = cJSON_GetObjectItem(data, "children");
                    if (children && cJSON_IsArray(children)) {
                        commentCount = cJSON_GetArraySize(children);
                        validComments = 0;

                        for (i = 0; i < commentCount && validComments < 15; i++) {
                            cJSON *commentItem = cJSON_GetArrayItem(children, i);
                            if (commentItem) {
                                cJSON *commentData = cJSON_GetObjectItem(commentItem, "data");
                                if (commentData) {
                                    cJSON *cAuthor = cJSON_GetObjectItem(commentData, "author");
                                    cJSON *body = cJSON_GetObjectItem(commentData, "body");
                                    cJSON *cScore = cJSON_GetObjectItem(commentData, "score");

                                    if (cAuthor && body && cJSON_IsString(cAuthor) && cJSON_IsString(body)) {
                                        NSString *authorStr = [NSString stringWithUTF8String:cAuthor->valuestring];
                                        NSString *bodyStr = [NSString stringWithUTF8String:body->valuestring];
                                        int scoreVal = (cScore && cJSON_IsNumber(cScore)) ? cScore->valueint : 0;

                                        [commentsText appendString:[NSString stringWithFormat:@"%@ (Score: %d):\n%@\n\n",
                                            authorStr, scoreVal, bodyStr]];
                                        validComments++;
                                    }
                                }
                            }
                        }

                        if (validComments == 0) {
                            [commentsText appendString:@"No readable comments found."];
                        }
                    } else {
                        [commentsText appendString:@"No comments data found."];
                    }
                }
            }
        } else {
            [commentsText appendString:@"Unexpected response format."];
        }

        cJSON_Delete(root);
    }
    @catch (NSException *exception) {
        NSLog(@"Exception parsing comments: %@", [exception reason]);
        [commentsText appendString:@"Error processing comments."];
    }

    [textView setString:commentsText];
}
