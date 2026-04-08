/* RedditController+UI.inc
 * UI creation, table view delegate and data source methods.
 * Included from RedditViewer.m inside @implementation RedditController.
 */

- (NSImage *)createPlaceholderImage {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    [[NSColor lightGrayColor] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    [[NSColor darkGrayColor] set];
    NSFrameRect(NSMakeRect(0, 0, 60, 60));

    [[NSColor darkGrayColor] set];
    NSRectFill(NSMakeRect(15, 20, 30, 20));
    NSRectFill(NSMakeRect(25, 35, 10, 10));

    [img unlockFocus];
    return [img autorelease];
}

- (NSImage *)createLoadingImage {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    [[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1.0] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    [[NSColor blueColor] set];
    NSFrameRect(NSMakeRect(0, 0, 60, 60));

    {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSFont boldSystemFontOfSize:14] forKey:NSFontAttributeName];
        [attributes setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];
        [@"..." drawAtPoint:NSMakePoint(22, 23) withAttributes:attributes];
    }

    [img unlockFocus];
    return [img autorelease];
}

- (NSImage *)createVideoThumbnailPlaceholder {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    /* Dark background for video */
    [[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:1.0] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    /* Red border for video */
    [[NSColor redColor] set];
    NSFrameRect(NSMakeRect(0, 0, 60, 60));

    /* Play button triangle */
    [[NSColor whiteColor] set];
    {
        NSBezierPath *triangle = [NSBezierPath bezierPath];
        [triangle moveToPoint:NSMakePoint(20, 15)];
        [triangle lineToPoint:NSMakePoint(45, 30)];
        [triangle lineToPoint:NSMakePoint(20, 45)];
        [triangle closePath];
        [triangle fill];
    }

    /* "VIDEO" text */
    {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSFont boldSystemFontOfSize:8] forKey:NSFontAttributeName];
        [attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
        [@"VIDEO" drawAtPoint:NSMakePoint(15, 5) withAttributes:attributes];
    }

    [img unlockFocus];
    return [img autorelease];
}

- (NSImage *)createArticleThumbnailPlaceholder {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    /* Light blue background for articles */
    [[NSColor colorWithCalibratedRed:0.9 green:0.95 blue:1.0 alpha:1.0] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    /* Blue border for article */
    [[NSColor blueColor] set];
    NSFrameRect(NSMakeRect(0, 0, 60, 60));

    /* Document icon (simple rectangles representing text lines) */
    [[NSColor blueColor] set];
    NSRectFill(NSMakeRect(10, 40, 40, 3));
    NSRectFill(NSMakeRect(10, 35, 35, 2));
    NSRectFill(NSMakeRect(10, 30, 40, 2));
    NSRectFill(NSMakeRect(10, 25, 30, 2));

    /* "LINK" text */
    {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSFont boldSystemFontOfSize:8] forKey:NSFontAttributeName];
        [attributes setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];
        [@"LINK" drawAtPoint:NSMakePoint(18, 5) withAttributes:attributes];
    }

    [img unlockFocus];
    return [img autorelease];
}

- (NSImage *)createNSFWOverlay {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    /* Semi-transparent red overlay */
    [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.3] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    /* NSFW text */
    {
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSFont boldSystemFontOfSize:10] forKey:NSFontAttributeName];
        [attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
        [@"NSFW" drawAtPoint:NSMakePoint(15, 25) withAttributes:attributes];
    }

    [img unlockFocus];
    return [img autorelease];
}

- (void)createUI {
    NSRect frame = NSMakeRect(100, 100, 1300, 700);
    NSView *contentView;
    NSRect toolbarFrame;
    NSBox *toolbar;
    NSRect scrollFrame;
    NSScrollView *scrollView;
    NSRect statusFrame;

    window = [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:(NSTitledWindowMask |
                                                   NSClosableWindowMask |
                                                   NSMiniaturizableWindowMask |
                                                   NSResizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setTitle:@"TigerReddit"];

    contentView = [window contentView];

    /* Create toolbar */
    toolbarFrame = NSMakeRect(10, frame.size.height - 80, frame.size.width - 20, 70);
    toolbar = [[NSBox alloc] initWithFrame:toolbarFrame];
    [toolbar setBoxType:NSBoxPrimary];
    [toolbar setBorderType:NSLineBorder];
    [toolbar setTitlePosition:NSNoTitle];
    [toolbar setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    /* All button */
    {
        NSRect allFrame = NSMakeRect(10, 15, 60, 25);
        allButton = [[NSButton alloc] initWithFrame:allFrame];
        [allButton setTitle:@"All"];
        [allButton setBezelStyle:NSRoundedBezelStyle];
        [allButton setTarget:self];
        [allButton setAction:@selector(browseAll:)];
        [[toolbar contentView] addSubview:allButton];
    }

    /* Popular button */
    {
        NSRect popularFrame = NSMakeRect(80, 15, 80, 25);
        popularButton = [[NSButton alloc] initWithFrame:popularFrame];
        [popularButton setTitle:@"Popular"];
        [popularButton setBezelStyle:NSRoundedBezelStyle];
        [popularButton setTarget:self];
        [popularButton setAction:@selector(browsePopular:)];
        [[toolbar contentView] addSubview:popularButton];
    }

    /* Separator */
    {
        NSRect sepFrame = NSMakeRect(170, 17, 35, 20);
        NSTextField *sepLabel = [[NSTextField alloc] initWithFrame:sepFrame];
        [sepLabel setStringValue:@"|"];
        [sepLabel setBezeled:NO];
        [sepLabel setDrawsBackground:NO];
        [sepLabel setEditable:NO];
        [sepLabel setSelectable:NO];
        [[toolbar contentView] addSubview:sepLabel];
    }

    /* Subreddit label */
    {
        NSRect labelFrame = NSMakeRect(190, 17, 80, 20);
        NSTextField *subLabel = [[NSTextField alloc] initWithFrame:labelFrame];
        [subLabel setStringValue:@"Subreddit:"];
        [subLabel setBezeled:NO];
        [subLabel setDrawsBackground:NO];
        [subLabel setEditable:NO];
        [subLabel setSelectable:NO];
        [[toolbar contentView] addSubview:subLabel];
    }

    /* Subreddit field */
    {
        NSRect fieldFrame = NSMakeRect(270, 15, 150, 25);
        subredditField = [[NSTextField alloc] initWithFrame:fieldFrame];
        [subredditField setStringValue:@"vintageapple"];
        [subredditField setEditable:YES];
        [subredditField setSelectable:YES];
        [subredditField setBezeled:YES];
        [subredditField setDrawsBackground:YES];
        [[toolbar contentView] addSubview:subredditField];
    }

    /* Sort popup */
    {
        NSRect sortFrame = NSMakeRect(430, 15, 100, 25);
        sortButton = [[NSPopUpButton alloc] initWithFrame:sortFrame];
        [sortButton addItemWithTitle:@"Hot"];
        [sortButton addItemWithTitle:@"New"];
        [sortButton addItemWithTitle:@"Top"];
        [sortButton addItemWithTitle:@"Rising"];
        [[toolbar contentView] addSubview:sortButton];
    }

    /* Refresh button */
    {
        NSRect refreshFrame = NSMakeRect(540, 15, 80, 25);
        refreshButton = [[NSButton alloc] initWithFrame:refreshFrame];
        [refreshButton setTitle:@"Refresh"];
        [refreshButton setBezelStyle:NSRoundedBezelStyle];
        [refreshButton setTarget:self];
        [refreshButton setAction:@selector(refreshPosts:)];
        [refreshButton setKeyEquivalent:@"\r"];
        [[toolbar contentView] addSubview:refreshButton];
    }

    /* Comments button */
    /* Preferences button (replaces old Comments + View Image buttons) */
    {
        NSRect prefsFrame = NSMakeRect(630, 15, 100, 25);
        NSButton *prefsButton = [[NSButton alloc] initWithFrame:prefsFrame];
        [prefsButton setTitle:@"Preferences"];
        [prefsButton setBezelStyle:NSRoundedBezelStyle];
        [prefsButton setTarget:self];
        [prefsButton setAction:@selector(showPreferences:)];
        [[toolbar contentView] addSubview:prefsButton];
    }

    /* Post count popup */
    {
        NSRect countFrame = NSMakeRect(950, 15, 80, 25);
        postCountButton = [[NSPopUpButton alloc] initWithFrame:countFrame];
        [postCountButton addItemWithTitle:@"10"];
        [postCountButton addItemWithTitle:@"25"];
        [postCountButton addItemWithTitle:@"50"];
        [postCountButton selectItemWithTitle:@"25"];
        [postCountButton setTarget:self];
        [postCountButton setAction:@selector(postCountChanged:)];
        [[toolbar contentView] addSubview:postCountButton];
    }

    /* Previous/Next buttons */
    {
        NSRect prevFrame = NSMakeRect(1040, 15, 60, 25);
        NSButton *prevButton = [[NSButton alloc] initWithFrame:prevFrame];
        [prevButton setTitle:@"Prev"];
        [prevButton setBezelStyle:NSRoundedBezelStyle];
        [prevButton setTarget:self];
        [prevButton setAction:@selector(previousPage:)];
        [[toolbar contentView] addSubview:prevButton];
    }

    {
        NSRect nextFrame = NSMakeRect(1110, 15, 60, 25);
        NSButton *nextButton = [[NSButton alloc] initWithFrame:nextFrame];
        [nextButton setTitle:@"Next"];
        [nextButton setBezelStyle:NSRoundedBezelStyle];
        [nextButton setTarget:self];
        [nextButton setAction:@selector(nextPage:)];
        [[toolbar contentView] addSubview:nextButton];
    }

    /* Progress indicator */
    {
        NSRect progressFrame = NSMakeRect(1185, 17, 20, 20);
        progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressFrame];
        [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
        [progressIndicator setDisplayedWhenStopped:NO];
        [[toolbar contentView] addSubview:progressIndicator];
    }

    [contentView addSubview:toolbar];

    /* Create scroll view and table */
    scrollFrame = NSMakeRect(10, 50, frame.size.width - 20, frame.size.height - 120);
    scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    tableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, scrollFrame.size.width, scrollFrame.size.height)];
    [tableView setDataSource:self];
    [tableView setDelegate:self];
    [tableView setUsesAlternatingRowBackgroundColors:YES];
    [tableView setRowHeight:70.0];
    [tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [tableView setTarget:self];
    [tableView setDoubleAction:@selector(openPostDetail:)];

    /* Tiger-specific table setup */
    [tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
    [tableView setAllowsMultipleSelection:NO];
    [tableView setAllowsEmptySelection:YES];
    [tableView setAllowsColumnSelection:NO];

    /* Add columns */
    {
        NSTableColumn *thumbColumn = [[NSTableColumn alloc] initWithIdentifier:@"thumbnail"];
        NSImageCell *imageCell;
        [[thumbColumn headerCell] setStringValue:@"Image"];
        [thumbColumn setWidth:80];
        [thumbColumn setMinWidth:80];
        [thumbColumn setMaxWidth:80];
        imageCell = [[NSImageCell alloc] init];
        [thumbColumn setDataCell:imageCell];
        [imageCell release];
        [tableView addTableColumn:thumbColumn];
    }

    {
        NSTableColumn *titleColumn = [[NSTableColumn alloc] initWithIdentifier:@"title"];
        [[titleColumn headerCell] setStringValue:@"Title"];
        [titleColumn setWidth:400];
        [tableView addTableColumn:titleColumn];
    }

    {
        NSTableColumn *authorColumn = [[NSTableColumn alloc] initWithIdentifier:@"author"];
        [[authorColumn headerCell] setStringValue:@"Author"];
        [authorColumn setWidth:100];
        [tableView addTableColumn:authorColumn];
    }

    {
        NSTableColumn *scoreColumn = [[NSTableColumn alloc] initWithIdentifier:@"score"];
        [[scoreColumn headerCell] setStringValue:@"Score"];
        [scoreColumn setWidth:60];
        [tableView addTableColumn:scoreColumn];
    }

    {
        NSTableColumn *commentsColumn = [[NSTableColumn alloc] initWithIdentifier:@"comments"];
        [[commentsColumn headerCell] setStringValue:@"Comments"];
        [commentsColumn setWidth:80];
        [tableView addTableColumn:commentsColumn];
    }

    {
        NSTableColumn *subredditColumn = [[NSTableColumn alloc] initWithIdentifier:@"subreddit"];
        [[subredditColumn headerCell] setStringValue:@"Subreddit"];
        [subredditColumn setWidth:100];
        [tableView addTableColumn:subredditColumn];
    }

    [scrollView setDocumentView:tableView];
    [contentView addSubview:scrollView];

    /* Status text area */
    statusFrame = NSMakeRect(10, 10, frame.size.width - 20, 30);
    statusText = [[NSTextView alloc] initWithFrame:statusFrame];
    [statusText setEditable:NO];
    [statusText setRichText:NO];
    [statusText setString:@"Ready to fetch Reddit posts (native C version)..."];
    [statusText setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:statusText];

    [window makeKeyAndOrderFront:nil];

    /* Add some test data to verify table is working (Tiger debugging) */
    [self addTestData];

    /* First launch: show MPlayer notice */
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:@"HasLaunchedBefore"]) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Welcome to TigerReddit"];
            [alert setInformativeText:@"Video playback requires MPlayer OSX Extended to be installed in your Applications folder.\n\nYou can download it from:\nmacintoshgarden.org/apps/mplayer-os-x\n\nWithout MPlayer, videos will not play. Everything else works without it."];
            [alert addButtonWithTitle:@"Download MPlayer"];
            [alert addButtonWithTitle:@"Continue"];
            {
                int result = [alert runModal];
                if (result == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] openURL:
                        [NSURL URLWithString:@"https://macintoshgarden.org/apps/mplayer-os-x"]];
                }
            }
            [alert release];
            [defaults setBool:YES forKey:@"HasLaunchedBefore"];
            [defaults synchronize];
        }
    }

    /* Auto-load saved default subreddit */
    [subredditField setStringValue:currentSubreddit];
    [self refreshPosts:nil];
}

- (void)addTestData {
    RDPost *testPost1;
    RDPost *testPost2;

    NSLog(@"Adding test data for debugging...");

    testPost1 = [[RDPost alloc] init];
    [testPost1 setTitle:@"Test Post 1 - Table Display Test"];
    [testPost1 setAuthor:@"test_user"];
    [testPost1 setSubreddit:@"test"];
    [testPost1 setScore:42];
    [testPost1 setNumComments:5];
    [testPost1 setHasImage:NO];

    testPost2 = [[RDPost alloc] init];
    [testPost2 setTitle:@"Test Post 2 - Tiger Compatibility Check"];
    [testPost2 setAuthor:@"tiger_user"];
    [testPost2 setSubreddit:@"macosx"];
    [testPost2 setScore:123];
    [testPost2 setNumComments:15];
    [testPost2 setHasImage:NO];

    [posts addObject:testPost1];
    [posts addObject:testPost2];

    [testPost1 release];
    [testPost2 release];

    NSLog(@"Added %d test posts", [posts count]);
    [tableView reloadData];
    [statusText setString:@"Test data loaded - table should show 2 test posts above"];

    NSLog(@"Test data setup complete");
}

/* Table data source methods */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
    int count = [posts count];
    NSLog(@"numberOfRowsInTableView called, returning %d", count);
    return count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    RDPost *post;
    NSString *identifier;

    if (rowIndex >= [posts count]) {
        NSLog(@"WARNING: Row %d requested but only have %d posts", rowIndex, [posts count]);
        return @"";
    }

    post = [posts objectAtIndex:rowIndex];
    identifier = [aTableColumn identifier];

    if ([identifier isEqualToString:@"thumbnail"]) {
        return nil; /* Image will be handled in willDisplayCell */
    } else if ([identifier isEqualToString:@"title"]) {
        NSString *postTitle = [post title];
        if (rowIndex < 3) {
            NSLog(@"Row %d title: %@", rowIndex, postTitle);
        }
        return postTitle;
    } else if ([identifier isEqualToString:@"author"]) {
        return [post author];
    } else if ([identifier isEqualToString:@"score"]) {
        return [NSNumber numberWithInt:[post score]];
    } else if ([identifier isEqualToString:@"comments"]) {
        return [NSNumber numberWithInt:[post numComments]];
    } else if ([identifier isEqualToString:@"subreddit"]) {
        return [post subreddit];
    }
    return @"";
}

- (float)tableView:(NSTableView *)aTableView heightOfRow:(int)row {
    return 70.0;
}

/* Enhanced table cell display method */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    if ([[aTableColumn identifier] isEqualToString:@"thumbnail"]) {
        RDPost *post;
        NSImage *displayImage = nil;
        NSString *cType;

        /* Clear any existing image first */
        if ([cell respondsToSelector:@selector(setImage:)]) {
            [cell setImage:nil];
        }

        if (rowIndex >= [posts count]) {
            [cell setImage:placeholderImage];
            return;
        }

        post = [posts objectAtIndex:rowIndex];
        cType = [post contentType];

        if ([cType isEqualToString:@"video"]) {
            if ([post hasImage] && [post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]) {
                @try {
                    NSImage *localImage = [[NSImage alloc] initWithContentsOfFile:[post thumbnailUrl]];
                    if (localImage) {
                        displayImage = [ImageUtils createThumbnail:localImage maxSize:50.0];
                        [localImage release];
                    } else {
                        displayImage = [self createVideoThumbnailPlaceholder];
                    }
                }
                @catch (NSException *exception) {
                    displayImage = [self createVideoThumbnailPlaceholder];
                }
            } else {
                displayImage = [self createVideoThumbnailPlaceholder];
            }
        }
        else if ([cType isEqualToString:@"article"]) {
            if ([post hasImage] && [post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]) {
                @try {
                    NSImage *localImage = [[NSImage alloc] initWithContentsOfFile:[post thumbnailUrl]];
                    if (localImage) {
                        displayImage = [ImageUtils createThumbnail:localImage maxSize:50.0];
                        [localImage release];
                    } else {
                        displayImage = [self createArticleThumbnailPlaceholder];
                    }
                }
                @catch (NSException *exception) {
                    displayImage = [self createArticleThumbnailPlaceholder];
                }
            } else {
                displayImage = [self createArticleThumbnailPlaceholder];
            }
        }
        else if ([post hasImage] && [post thumbnailUrl]) {
            NSString *thumbUrl = [post thumbnailUrl];

            /* Check if it's a local file path (from native fetcher cache) */
            if ([thumbUrl hasPrefix:@"/"]) {
                @try {
                    NSImage *localImage = [[NSImage alloc] initWithContentsOfFile:thumbUrl];
                    if (localImage) {
                        displayImage = [ImageUtils createThumbnail:localImage maxSize:50.0];
                        [localImage release];
                    } else {
                        displayImage = placeholderImage;
                    }
                }
                @catch (NSException *exception) {
                    displayImage = placeholderImage;
                }
            } else {
                displayImage = placeholderImage;
            }
        } else {
            displayImage = placeholderImage;
        }

        /* Add NSFW overlay if needed */
        if ([post isNSFW] && displayImage) {
            NSImage *combinedImage = [[NSImage alloc] initWithSize:[displayImage size]];
            NSImage *nsfwOverlay;

            [combinedImage lockFocus];

            /* Draw base image */
            [displayImage drawAtPoint:NSZeroPoint
                             fromRect:NSZeroRect
                            operation:NSCompositeSourceOver
                             fraction:1.0];

            /* Draw NSFW overlay */
            nsfwOverlay = [self createNSFWOverlay];
            [nsfwOverlay drawAtPoint:NSZeroPoint
                            fromRect:NSZeroRect
                           operation:NSCompositeSourceOver
                            fraction:0.7];

            [combinedImage unlockFocus];
            [cell setImage:[combinedImage autorelease]];
        } else {
            [cell setImage:displayImage];
        }
    }

    /* Enhanced title column display with content type indicators */
    else if ([[aTableColumn identifier] isEqualToString:@"title"]) {
        if (rowIndex < [posts count]) {
            RDPost *post = [posts objectAtIndex:rowIndex];
            NSString *postTitle = [post title];
            NSString *cType = [post contentType];
            NSString *prefix = @"";
            NSString *displayTitle;

            /* Add content type prefix to title */
            if ([cType isEqualToString:@"video"]) {
                prefix = @"▶ ";
            } else if ([cType isEqualToString:@"article"]) {
                prefix = @"🔗 ";
            } else if ([cType isEqualToString:@"self"]) {
                prefix = @"💬 ";
            }

            /* Add NSFW indicator */
            if ([post isNSFW]) {
                prefix = [prefix stringByAppendingString:@"[NSFW] "];
            }

            displayTitle = [prefix stringByAppendingString:postTitle];
            [cell setStringValue:displayTitle];
        }
    }
}

/* Additional Tiger-specific delegate methods */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex {
    return YES;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    /* Do nothing - read-only table */
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        [statusText setString:[NSString stringWithFormat:@"Selected: %@", [post title]]];
    }
}

- (void)testTableDisplay:(id)sender {
    int i;
    NSLog(@"=== MANUAL TABLE TEST ===");

    /* Clear existing data */
    [posts removeAllObjects];

    /* Add fresh test data */
    for (i = 0; i < 3; i++) {
        RDPost *testPost = [[RDPost alloc] init];
        [testPost setTitle:[NSString stringWithFormat:@"Manual Test Post %d - %@", i+1, [NSDate date]]];
        [testPost setAuthor:[NSString stringWithFormat:@"test_user_%d", i+1]];
        [testPost setSubreddit:@"manual_test"];
        [testPost setScore:(i+1) * 25];
        [testPost setNumComments:i + 3];
        [testPost setHasImage:NO];

        [posts addObject:testPost];
        [testPost release];
    }

    NSLog(@"Added %d manual test posts", [posts count]);

    [tableView reloadData];
    [tableView setNeedsDisplay:YES];
    [[tableView superview] setNeedsDisplay:YES];

    [statusText setString:[NSString stringWithFormat:@"Manual test: Added %d posts. Table should refresh now.", [posts count]]];

    NSLog(@"Manual table test completed");
}

- (void)postCountChanged:(id)sender {
    currentPostCount = [[[sender selectedItem] title] intValue];
    [self refreshPosts:nil];
}
