/* RedditController+PostDetail.inc
 * Post detail view (double-click) and comment rendering.
 * Included from RedditViewer.m inside @implementation RedditController.
 */

/* --- Post Detail View (double-click) ---------------------------------- */

- (void)openPostDetail:(id)sender {
    int selectedRow = [tableView selectedRow];
    RDPost *post;
    NSString *permalink;
    CommentsResult result;

    if (selectedRow < 0 || selectedRow >= (int)[posts count]) return;

    post = [posts objectAtIndex:selectedRow];
    [statusText setString:@"Loading post..."];
    [progressIndicator startAnimation:nil];

    /* Fetch comments */
    permalink = [post permalink];
    if ([permalink hasPrefix:@"https://reddit.com"]) {
        permalink = [permalink substringFromIndex:18];
    } else if ([permalink hasPrefix:@"http://reddit.com"]) {
        permalink = [permalink substringFromIndex:17];
    }
    if (![permalink hasPrefix:@"/"]) {
        permalink = [@"/" stringByAppendingString:permalink];
    }

    result = reddit_fetch_comments([permalink UTF8String]);

    if (result.success && result.json) {
        NSString *jsonString = [NSString stringWithUTF8String:result.json];
        [self showPostDetailWindow:post withCommentsJSON:jsonString];
    } else {
        [self showPostDetailWindow:post withCommentsJSON:nil];
    }

    comments_result_free(&result);
    [progressIndicator stopAnimation:nil];
    [statusText setString:@""];
}

- (void)showPostDetailWindow:(RDPost *)post withCommentsJSON:(NSString *)jsonString {
    NSRect winFrame = NSMakeRect(80, 60, 800, 700);
    NSWindow *detailWindow;
    NSView *contentView;
    NSScrollView *scrollView;
    NSView *docView;
    float yOffset;
    float contentWidth;

    detailWindow = [[NSWindow alloc] initWithContentRect:winFrame
                                               styleMask:(NSTitledWindowMask |
                                                         NSClosableWindowMask |
                                                         NSMiniaturizableWindowMask |
                                                         NSResizableWindowMask)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    [detailWindow setTitle:[post title]];

    contentView = [detailWindow contentView];
    contentWidth = winFrame.size.width - 40;

    /* We build content bottom-up (Cocoa coordinates: 0,0 is bottom-left)
       then flip at the end by setting the docView height. */

    /* First pass: calculate total height needed */
    {
        float totalHeight = 20; /* top padding */
        NSFont *titleFont = [NSFont boldSystemFontOfSize:16];
        NSFont *bodyFont = [NSFont systemFontOfSize:12];

        /* Title */
        {
            NSDictionary *attrs = [NSDictionary dictionaryWithObject:titleFont forKey:NSFontAttributeName];
            NSAttributedString *attrTitle = [[[NSAttributedString alloc] initWithString:[post title] attributes:attrs] autorelease];
            NSRect titleBounds = [attrTitle boundingRectWithSize:NSMakeSize(contentWidth, 10000) options:0];
            totalHeight += titleBounds.size.height + 10;
        }

        /* Meta line */
        totalHeight += 20;

        /* NSFW badge */
        if ([post isNSFW]) totalHeight += 20;

        /* Separator */
        totalHeight += 15;

        /* Image at top — max 500px tall + padding */
        if ([post hasImage] && (([post imageUrl] && [[post imageUrl] hasPrefix:@"http"]) ||
            ([post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]))) {
            totalHeight += 520;
        }

        /* Video: thumbnail + play button */
        if ([post isVideo]) {
            totalHeight += 380;
        }

        /* Self text */
        if ([post selfText] && [[post selfText] length] > 0) {
            NSDictionary *attrs = [NSDictionary dictionaryWithObject:bodyFont forKey:NSFontAttributeName];
            NSAttributedString *attrBody = [[[NSAttributedString alloc] initWithString:[post selfText] attributes:attrs] autorelease];
            NSRect bodyBounds = [attrBody boundingRectWithSize:NSMakeSize(contentWidth, 10000) options:0];
            totalHeight += bodyBounds.size.height + 20;
        }

        /* Link */
        if ([post url] && [[post url] length] > 0 && ![[post contentType] isEqualToString:@"self"]) {
            totalHeight += 25;
        }

        /* Comments header */
        totalHeight += 40;

        /* Comments — use generous estimate for deep threaded comments */
        totalHeight += 5000;

        totalHeight += 40; /* bottom padding */
        if (totalHeight < winFrame.size.height) totalHeight = winFrame.size.height;

        /* Create scrollable document view */
        docView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, winFrame.size.width - 20, totalHeight)] autorelease];
        yOffset = totalHeight - 20; /* start from top */
    }

    /* Now lay out the content top-down using yOffset */

    /* Image or Video at top */
    if ([post isVideo] && [post videoUrl] && [[post videoUrl] length] > 0) {
        /* VIDEO: show thumbnail + play button. Download only on click. */
        float btnHeight = 60;
        NSImage *thumbImg = nil;
        NSString *videoUrlStr = [post videoUrl];

        /* Show thumbnail if available */
        if ([post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]) {
            @try {
                thumbImg = [[[NSImage alloc] initWithContentsOfFile:[post thumbnailUrl]] autorelease];
            }
            @catch (NSException *e) { /* ignore */ }
        }

        if (thumbImg) {
            NSSize imgSize = [thumbImg size];
            float maxW = contentWidth;
            float maxH = 300;
            float scale = 1.0;
            float displayW, displayH, xPos;

            if (imgSize.width > maxW) scale = maxW / imgSize.width;
            if (imgSize.height * scale > maxH) scale = maxH / imgSize.height;
            displayW = imgSize.width * scale;
            displayH = imgSize.height * scale;
            xPos = 20 + (contentWidth - displayW) / 2;

            {
                NSImageView *thumbView = [[[NSImageView alloc] initWithFrame:
                    NSMakeRect(xPos, yOffset - displayH, displayW, displayH)] autorelease];
                [thumbView setImage:thumbImg];
                [thumbView setImageScaling:NSScaleProportionally];
                [thumbView setImageFrameStyle:NSImageFramePhoto];
                [docView addSubview:thumbView];
                yOffset -= (displayH + 5);
            }
        }

        /* Play button — stores video URL in title for retrieval */
        {
            NSButton *playBtn = [[[NSButton alloc] initWithFrame:
                NSMakeRect(20 + (contentWidth - 200) / 2, yOffset - 35, 200, 30)] autorelease];
            [playBtn setTitle:@"Download & Play Video"];
            [playBtn setBezelStyle:NSRoundedBezelStyle];
            /* Store the video URL so we can retrieve it on click.
               We use the button's identifier (available on 10.4+). */
            /* Store "hlsUrl|videoUrl" in toolTip for retrieval */
            {
                NSString *hlsStr = [post hlsUrl] ? [post hlsUrl] : @"";
                NSString *combined = [NSString stringWithFormat:@"%@|%@", hlsStr, videoUrlStr];
                [playBtn setToolTip:combined];
            }
            [playBtn setTarget:self];
            [playBtn setAction:@selector(playVideoFromButton:)];
            [docView addSubview:playBtn];
            yOffset -= 45;
        }
    }
    else {
        /* IMAGE: download full image and display */
        NSImage *img = nil;
        NSString *imgPath = nil;

        if ([post hasImage] && [post imageUrl] && [[post imageUrl] length] > 0 &&
            [[post imageUrl] hasPrefix:@"http"]) {
            DownloadResult dlResult = reddit_cache_full_image([[post imageUrl] UTF8String]);
            if (dlResult.success && dlResult.path) {
                imgPath = [NSString stringWithUTF8String:dlResult.path];
            }
            download_result_free(&dlResult);
        }

        if (!imgPath && [post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]) {
            imgPath = [post thumbnailUrl];
        }

        if (imgPath) {
            @try {
                img = [[[NSImage alloc] initWithContentsOfFile:imgPath] autorelease];
            }
            @catch (NSException *e) {
                NSLog(@"Exception loading image: %@", [e reason]);
            }
        }

        if (img) {
            /* Get pixel dimensions from the image rep, not [img size] which can be DPI-dependent */
            float pixW = 0, pixH = 0;
            {
                NSEnumerator *repEnum = [[img representations] objectEnumerator];
                NSImageRep *rep;
                while ((rep = [repEnum nextObject])) {
                    pixW = [rep pixelsWide];
                    pixH = [rep pixelsHigh];
                    if (pixW > 0 && pixH > 0) break;
                }
                if (pixW <= 0 || pixH <= 0) {
                    pixW = [img size].width;
                    pixH = [img size].height;
                }
            }

            NSLog(@"Detail image: %@ (%gx%g pixels)", imgPath, pixW, pixH);

            if (pixW > 0 && pixH > 0) {
                float maxW = 600;
                float maxH = 500;
                float scale = 1.0;
                float displayW, displayH;

                if (pixW > maxW) scale = maxW / pixW;
                if (pixH * scale > maxH) scale = maxH / pixH;
                displayW = pixW * scale;
                displayH = pixH * scale;

                NSLog(@"Detail image display: %gx%g (scale %g)", displayW, displayH, scale);

                {
                    float xPos = 20 + (contentWidth - displayW) / 2;
                    SaveableImageView *imageView = [[[SaveableImageView alloc] initWithFrame:
                        NSMakeRect(xPos, yOffset - displayH, displayW, displayH)] autorelease];

                    /* Create a properly scaled copy for display */
                    NSImage *displayImg = [[NSImage alloc] initWithSize:NSMakeSize(displayW, displayH)];
                    [displayImg lockFocus];
                    [img drawInRect:NSMakeRect(0, 0, displayW, displayH)
                           fromRect:NSMakeRect(0, 0, pixW, pixH)
                          operation:NSCompositeSourceOver
                           fraction:1.0];
                    [displayImg unlockFocus];

                    [imageView setImage:[displayImg autorelease]];
                    [imageView setImageScaling:NSScaleNone];
                    [imageView setImageFrameStyle:NSImageFrameNone];
                    [imageView setImagePath:imgPath];
                    [docView addSubview:imageView];
                    yOffset -= (displayH + 15);
                }
            }
        }
    }

    /* Title */
    {
        NSTextField *titleLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, yOffset - 50, contentWidth, 50)] autorelease];
        [titleLabel setStringValue:[post title]];
        [titleLabel setFont:[NSFont boldSystemFontOfSize:16]];
        [titleLabel setBezeled:NO];
        [titleLabel setDrawsBackground:NO];
        [titleLabel setEditable:NO];
        [titleLabel setSelectable:YES];
        [titleLabel sizeToFit];
        {
            NSRect f = [titleLabel frame];
            f.origin.y = yOffset - f.size.height;
            f.size.width = contentWidth;
            [titleLabel setFrame:f];
            yOffset = f.origin.y - 5;
        }
        [docView addSubview:titleLabel];
    }

    /* Meta: author, score, comments, subreddit */
    {
        NSString *meta = [NSString stringWithFormat:@"by %@ in r/%@  |  %d points  |  %d comments",
                          [post author], [post subreddit], [post score], [post numComments]];
        NSTextField *metaLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, yOffset - 18, contentWidth, 18)] autorelease];
        [metaLabel setStringValue:meta];
        [metaLabel setFont:[NSFont systemFontOfSize:11]];
        [metaLabel setTextColor:[NSColor grayColor]];
        [metaLabel setBezeled:NO];
        [metaLabel setDrawsBackground:NO];
        [metaLabel setEditable:NO];
        [metaLabel setSelectable:YES];
        [docView addSubview:metaLabel];
        yOffset -= 22;
    }

    /* NSFW badge */
    if ([post isNSFW]) {
        NSTextField *nsfwLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, yOffset - 18, 50, 18)] autorelease];
        [nsfwLabel setStringValue:@" NSFW "];
        [nsfwLabel setFont:[NSFont boldSystemFontOfSize:10]];
        [nsfwLabel setTextColor:[NSColor whiteColor]];
        [nsfwLabel setBackgroundColor:[NSColor redColor]];
        [nsfwLabel setDrawsBackground:YES];
        [nsfwLabel setBezeled:NO];
        [nsfwLabel setEditable:NO];
        [docView addSubview:nsfwLabel];
        yOffset -= 22;
    }

    /* Separator */
    {
        NSBox *sep = [[[NSBox alloc] initWithFrame:NSMakeRect(20, yOffset - 2, contentWidth, 2)] autorelease];
        [sep setBoxType:NSBoxSeparator];
        [docView addSubview:sep];
        yOffset -= 12;
    }

    /* Self text */
    if ([post selfText] && [[post selfText] length] > 0) {
        NSTextField *selfLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, yOffset - 100, contentWidth, 100)] autorelease];
        [selfLabel setStringValue:[post selfText]];
        [selfLabel setFont:[NSFont systemFontOfSize:12]];
        [selfLabel setBezeled:NO];
        [selfLabel setDrawsBackground:NO];
        [selfLabel setEditable:NO];
        [selfLabel setSelectable:YES];
        [selfLabel sizeToFit];
        {
            NSRect f = [selfLabel frame];
            f.origin.y = yOffset - f.size.height;
            f.size.width = contentWidth;
            [selfLabel setFrame:f];
            yOffset = f.origin.y - 10;
        }
        [docView addSubview:selfLabel];
    }

    /* Link URL — clickable button */
    if ([post url] && [[post url] length] > 0 && ![[post contentType] isEqualToString:@"self"]) {
        NSString *fullUrl = [post url];
        NSString *displayUrl = fullUrl;
        NSButton *linkBtn;
        NSMutableAttributedString *attrTitle;

        if ([displayUrl length] > 80) {
            displayUrl = [[displayUrl substringToIndex:80] stringByAppendingString:@"..."];
        }

        linkBtn = [[[NSButton alloc] initWithFrame:NSMakeRect(20, yOffset - 18, contentWidth, 18)] autorelease];
        attrTitle = [[[NSMutableAttributedString alloc] initWithString:displayUrl] autorelease];
        [attrTitle addAttribute:NSForegroundColorAttributeName
                          value:[NSColor blueColor]
                          range:NSMakeRange(0, [attrTitle length])];
        [attrTitle addAttribute:NSFontAttributeName
                          value:[NSFont systemFontOfSize:11]
                          range:NSMakeRange(0, [attrTitle length])];
        [attrTitle addAttribute:NSUnderlineStyleAttributeName
                          value:[NSNumber numberWithInt:1]
                          range:NSMakeRange(0, [attrTitle length])];
        [linkBtn setAttributedTitle:attrTitle];
        [linkBtn setBordered:NO];
        [linkBtn setToolTip:fullUrl];
        [linkBtn setTarget:self];
        [linkBtn setAction:@selector(openLinkFromButton:)];
        [docView addSubview:linkBtn];
        yOffset -= 25;
    }

    /* Comments section header */
    {
        NSBox *sep2 = [[[NSBox alloc] initWithFrame:NSMakeRect(20, yOffset - 2, contentWidth, 2)] autorelease];
        [sep2 setBoxType:NSBoxSeparator];
        [docView addSubview:sep2];
        yOffset -= 12;
    }
    {
        NSTextField *commentsHeader = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, yOffset - 22, contentWidth, 22)] autorelease];
        [commentsHeader setStringValue:@"Comments"];
        [commentsHeader setFont:[NSFont boldSystemFontOfSize:14]];
        [commentsHeader setBezeled:NO];
        [commentsHeader setDrawsBackground:NO];
        [commentsHeader setEditable:NO];
        [docView addSubview:commentsHeader];
        yOffset -= 28;
    }

    /* Comments */
    if (jsonString) {
        cJSON *root = cJSON_Parse([jsonString UTF8String]);
        if (root && cJSON_IsArray(root) && cJSON_GetArraySize(root) >= 2) {
            cJSON *commentsSection = cJSON_GetArrayItem(root, 1);
            cJSON *cdata = cJSON_GetObjectItem(commentsSection, "data");
            if (cdata) {
                cJSON *children = cJSON_GetObjectItem(cdata, "children");
                if (children && cJSON_IsArray(children)) {
                    int ci;
                    int shown = 0;
                    for (ci = 0; ci < cJSON_GetArraySize(children) && shown < 30; ci++) {
                        cJSON *child = cJSON_GetArrayItem(children, ci);
                        [self renderComment:child depth:0 yOffset:&yOffset
                              docView:docView contentWidth:contentWidth
                              permalink:[post permalink] shown:&shown];
                    }

                    if (shown == 0) {
                        NSTextField *noComments = [[[NSTextField alloc] initWithFrame:NSMakeRect(30, yOffset - 18, contentWidth, 18)] autorelease];
                        [noComments setStringValue:@"No comments yet."];
                        [noComments setFont:[NSFont systemFontOfSize:12]];
                        [noComments setTextColor:[NSColor grayColor]];
                        [noComments setBezeled:NO];
                        [noComments setDrawsBackground:NO];
                        [noComments setEditable:NO];
                        [docView addSubview:noComments];
                        yOffset -= 22;
                    }
                }
            }
            cJSON_Delete(root);
        }
    } else {
        NSTextField *noComments = [[[NSTextField alloc] initWithFrame:NSMakeRect(30, yOffset - 18, contentWidth, 18)] autorelease];
        [noComments setStringValue:@"Could not load comments."];
        [noComments setFont:[NSFont systemFontOfSize:12]];
        [noComments setTextColor:[NSColor grayColor]];
        [noComments setBezeled:NO];
        [noComments setDrawsBackground:NO];
        [noComments setEditable:NO];
        [docView addSubview:noComments];
    }

    /* Adjust docView to actual content height — shift all subviews so
       content starts at the top of the view (Cocoa coords are bottom-up) */
    {
        float usedHeight = [docView frame].size.height - yOffset + 20;
        float currentHeight = [docView frame].size.height;
        if (usedHeight < winFrame.size.height) usedHeight = winFrame.size.height;

        if (usedHeight != currentHeight) {
            float delta = usedHeight - currentHeight;
            NSEnumerator *subEnum = [[docView subviews] objectEnumerator];
            NSView *sub;
            while ((sub = [subEnum nextObject])) {
                NSRect f = [sub frame];
                f.origin.y += delta;
                [sub setFrame:f];
            }
            [docView setFrame:NSMakeRect(0, 0, winFrame.size.width - 20, usedHeight)];
        }
    }

    /* Wrap in scroll view */
    scrollView = [[[NSScrollView alloc] initWithFrame:[[detailWindow contentView] bounds]] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [scrollView setDocumentView:docView];

    /* Scroll to top */
    [docView scrollPoint:NSMakePoint(0, [docView frame].size.height)];

    [[detailWindow contentView] addSubview:scrollView];
    [detailWindow makeKeyAndOrderFront:nil];
}

- (void)renderComment:(cJSON *)comment depth:(int)depth yOffset:(float *)yOffset
              docView:(NSView *)docView contentWidth:(float)cWidth
              permalink:(NSString *)permalink shown:(int *)shown {
    cJSON *cd;
    cJSON *cauthor, *cbody, *cscore, *creplies;
    float indent;
    float availWidth;

    if (!comment || *shown > maxComments) return;

    cd = cJSON_GetObjectItem(comment, "data");
    if (!cd) return;

    cauthor = cJSON_GetObjectItem(cd, "author");
    cbody = cJSON_GetObjectItem(cd, "body");
    cscore = cJSON_GetObjectItem(cd, "score");

    if (!cauthor || !cbody || !cJSON_IsString(cauthor) || !cJSON_IsString(cbody))
        return;

    /* Depth 6+: show clickable "Continue on Reddit" link */
    if (depth >= 6) {
        NSString *redditUrl = [permalink stringByReplacingOccurrencesOfString:@"https://reddit.com"
                                                                  withString:@"https://old.reddit.com"];
        indent = 30 + depth * 20;
        availWidth = cWidth - indent - 10;
        {
            NSButton *moreBtn = [[[NSButton alloc] initWithFrame:
                NSMakeRect(indent, *yOffset - 16, availWidth, 16)] autorelease];
            NSMutableAttributedString *attrTitle = [[[NSMutableAttributedString alloc]
                initWithString:@"Continue reading on Reddit..."] autorelease];
            [attrTitle addAttribute:NSForegroundColorAttributeName
                              value:[NSColor colorWithCalibratedRed:0.0 green:0.3 blue:0.8 alpha:1.0]
                              range:NSMakeRange(0, [attrTitle length])];
            [attrTitle addAttribute:NSFontAttributeName
                              value:[NSFont systemFontOfSize:11]
                              range:NSMakeRange(0, [attrTitle length])];
            [attrTitle addAttribute:NSUnderlineStyleAttributeName
                              value:[NSNumber numberWithInt:1]
                              range:NSMakeRange(0, [attrTitle length])];
            [moreBtn setAttributedTitle:attrTitle];
            [moreBtn setBordered:NO];
            [moreBtn setToolTip:redditUrl];
            [moreBtn setTarget:self];
            [moreBtn setAction:@selector(openLinkFromButton:)];
            [docView addSubview:moreBtn];
            *yOffset -= 20;
        }
        return;
    }

    indent = 30 + depth * 20;
    availWidth = cWidth - indent - 10;
    if (availWidth < 100) availWidth = 100;

    {
        NSString *authorStr = [NSString stringWithUTF8String:cauthor->valuestring];
        NSString *bodyStr = [NSString stringWithUTF8String:cbody->valuestring];
        int scoreVal = (cscore && cJSON_IsNumber(cscore)) ? cscore->valueint : 0;
        float commentTopY = *yOffset;

        /* Colored indent line for nested comments */
        if (depth > 0) {
            static float barColors[][3] = {
                {0.2, 0.4, 0.8}, {0.8, 0.2, 0.2}, {0.2, 0.7, 0.3},
                {0.7, 0.5, 0.0}, {0.5, 0.2, 0.7}, {0.0, 0.6, 0.6}
            };
            int colorIdx = (depth - 1) % 6;
            NSBox *indentLine = [[[NSBox alloc] initWithFrame:
                NSMakeRect(indent - 10, *yOffset - 2, 3, 2)] autorelease];
            [indentLine setBoxType:NSBoxCustom];
            [indentLine setBorderType:NSNoBorder];
            [indentLine setFillColor:[NSColor colorWithCalibratedRed:barColors[colorIdx][0]
                                                              green:barColors[colorIdx][1]
                                                               blue:barColors[colorIdx][2]
                                                              alpha:0.4]];
            [docView addSubview:indentLine];
        }

        /* Author + score */
        {
            NSString *authorLine = [NSString stringWithFormat:@"%@ (%d points)", authorStr, scoreVal];
            NSTextField *authorLabel = [[[NSTextField alloc] initWithFrame:
                NSMakeRect(indent, *yOffset - 16, availWidth, 16)] autorelease];
            [authorLabel setStringValue:authorLine];
            [authorLabel setFont:[NSFont boldSystemFontOfSize:11]];
            [authorLabel setTextColor:[NSColor colorWithCalibratedRed:0.0 green:0.3 blue:0.6 alpha:1.0]];
            [authorLabel setBezeled:NO];
            [authorLabel setDrawsBackground:NO];
            [authorLabel setEditable:NO];
            [docView addSubview:authorLabel];
            *yOffset -= 18;
        }

        /* Comment body */
        {
            NSTextField *bodyLabel = [[[NSTextField alloc] initWithFrame:
                NSMakeRect(indent, *yOffset - 60, availWidth, 60)] autorelease];
            [bodyLabel setStringValue:bodyStr];
            [bodyLabel setFont:[NSFont systemFontOfSize:12]];
            [bodyLabel setBezeled:NO];
            [bodyLabel setDrawsBackground:NO];
            [bodyLabel setEditable:NO];
            [bodyLabel setSelectable:YES];
            [bodyLabel sizeToFit];
            {
                NSRect f = [bodyLabel frame];
                f.origin.y = *yOffset - f.size.height;
                f.size.width = availWidth;
                [bodyLabel setFrame:f];
                *yOffset = f.origin.y - 4;
            }
            [docView addSubview:bodyLabel];
        }

        (*shown)++;

        /* Process replies recursively - all expanded up to depth 6 */
        creplies = cJSON_GetObjectItem(cd, "replies");
        if (creplies && cJSON_IsObject(creplies)) {
            cJSON *repliesData = cJSON_GetObjectItem(creplies, "data");
            if (repliesData) {
                cJSON *replyChildren = cJSON_GetObjectItem(repliesData, "children");
                if (replyChildren && cJSON_IsArray(replyChildren)) {
                    int ri;
                    int numReplies = cJSON_GetArraySize(replyChildren);
                    for (ri = 0; ri < numReplies && *shown < maxComments; ri++) {
                        cJSON *reply = cJSON_GetArrayItem(replyChildren, ri);
                        [self renderComment:reply depth:depth + 1 yOffset:yOffset
                              docView:docView contentWidth:cWidth
                              permalink:permalink shown:shown];
                    }
                }
            }
        }

        /* Update indent line height to span full comment + replies */
        if (depth > 0) {
            float lineHeight = commentTopY - *yOffset;
            if (lineHeight > 0) {
                NSArray *subviews = [docView subviews];
                int sv;
                for (sv = [subviews count] - 1; sv >= 0; sv--) {
                    NSView *v = [subviews objectAtIndex:sv];
                    if ([v isKindOfClass:[NSBox class]]) {
                        NSRect f = [v frame];
                        if (f.origin.x == indent - 10 && f.size.width == 3) {
                            f.origin.y = *yOffset;
                            f.size.height = lineHeight;
                            [v setFrame:f];
                            break;
                        }
                    }
                }
            }
        }

        /* Separator after top-level comments only */
        if (depth == 0) {
            NSBox *csep = [[[NSBox alloc] initWithFrame:
                NSMakeRect(30, *yOffset - 1, cWidth - 20, 1)] autorelease];
            [csep setBoxType:NSBoxSeparator];
            [docView addSubview:csep];
            *yOffset -= 10;
        } else {
            *yOffset -= 3;
        }
    }
}

- (void)openLinkFromButton:(id)sender {
    NSString *url = [sender toolTip];
    if (url && [url length] > 0) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
    }
}
