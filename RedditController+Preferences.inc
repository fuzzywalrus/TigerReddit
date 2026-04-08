/* RedditController+Preferences.inc
 * Preferences, about dialog, and app lifecycle.
 * Included from RedditViewer.m inside @implementation RedditController.
 */

- (void)showAbout:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"TigerReddit"];
    [alert setInformativeText:@"A native Reddit client for Mac OS X 10.4 Tiger and 10.5 Leopard.\n\nVersion 2.0 - Native C build\nNo Python dependency required.\n\nOriginal TigerReddit by Harry Fornasier.\nNative C port by Greg Gant (greggant.com)\nBuilt with libcurl + cJSON.\n\nhttps://github.com/fuzzywalrus/TigerReddit"];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    [alert release];
}

- (void)loadPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedSub = [defaults stringForKey:@"DefaultSubreddit"];
    int savedMax = [defaults integerForKey:@"MaxComments"];

    if (savedSub && [savedSub length] > 0) {
        [currentSubreddit release];
        currentSubreddit = [savedSub retain];
    }
    if (savedMax > 0) {
        maxComments = savedMax;
    }
    {
        int savedAge = [defaults integerForKey:@"CacheAgeDays"];
        if (savedAge > 0) {
            cacheAgeDays = savedAge;
        }
    }
}

- (void)savePreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:currentSubreddit forKey:@"DefaultSubreddit"];
    [defaults setInteger:maxComments forKey:@"MaxComments"];
    [defaults setInteger:cacheAgeDays forKey:@"CacheAgeDays"];
    [defaults synchronize];
}

- (void)showPreferences:(id)sender {
    NSRect prefsFrame = NSMakeRect(200, 200, 400, 240);
    NSWindow *prefsWindow;
    NSView *content;
    NSTextField *subLabel, *subField, *maxLabel, *maxField, *ageLabel, *ageField;
    NSButton *saveBtn;

    prefsWindow = [[NSWindow alloc] initWithContentRect:prefsFrame
                                              styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [prefsWindow setTitle:@"TigerReddit Preferences"];
    content = [prefsWindow contentView];

    /* Default subreddit */
    subLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 180, 140, 20)] autorelease];
    [subLabel setStringValue:@"Default Subreddit:"];
    [subLabel setBezeled:NO];
    [subLabel setDrawsBackground:NO];
    [subLabel setEditable:NO];
    [content addSubview:subLabel];

    subField = [[[NSTextField alloc] initWithFrame:NSMakeRect(165, 178, 200, 24)] autorelease];
    [subField setStringValue:currentSubreddit ? currentSubreddit : @"vintageapple"];
    [subField setEditable:YES];
    [subField setBezeled:YES];
    [subField setDrawsBackground:YES];
    [subField setTag:100];
    [content addSubview:subField];

    /* Max comments */
    maxLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 140, 140, 20)] autorelease];
    [maxLabel setStringValue:@"Max Comments:"];
    [maxLabel setBezeled:NO];
    [maxLabel setDrawsBackground:NO];
    [maxLabel setEditable:NO];
    [content addSubview:maxLabel];

    maxField = [[[NSTextField alloc] initWithFrame:NSMakeRect(165, 138, 80, 24)] autorelease];
    [maxField setIntValue:maxComments];
    [maxField setEditable:YES];
    [maxField setBezeled:YES];
    [maxField setDrawsBackground:YES];
    [maxField setTag:101];
    [content addSubview:maxField];

    /* Cache age */
    ageLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 100, 140, 20)] autorelease];
    [ageLabel setStringValue:@"Cache Age (days):"];
    [ageLabel setBezeled:NO];
    [ageLabel setDrawsBackground:NO];
    [ageLabel setEditable:NO];
    [content addSubview:ageLabel];

    ageField = [[[NSTextField alloc] initWithFrame:NSMakeRect(165, 98, 80, 24)] autorelease];
    [ageField setIntValue:cacheAgeDays];
    [ageField setEditable:YES];
    [ageField setBezeled:YES];
    [ageField setDrawsBackground:YES];
    [ageField setTag:102];
    [content addSubview:ageField];

    /* Save button */
    saveBtn = [[[NSButton alloc] initWithFrame:NSMakeRect(150, 20, 100, 30)] autorelease];
    [saveBtn setTitle:@"Save"];
    [saveBtn setBezelStyle:NSRoundedBezelStyle];
    [saveBtn setTarget:self];
    [saveBtn setAction:@selector(savePreferencesFromWindow:)];
    [saveBtn setTag:200];
    [content addSubview:saveBtn];

    /* Store window ref in button tooltip for retrieval */
    [prefsWindow makeKeyAndOrderFront:nil];
}

- (void)savePreferencesFromWindow:(id)sender {
    NSWindow *prefsWindow = [sender window];
    NSView *content = [prefsWindow contentView];
    NSTextField *subField = [content viewWithTag:100];
    NSTextField *maxField = [content viewWithTag:101];

    if (subField) {
        [currentSubreddit release];
        currentSubreddit = [[subField stringValue] retain];
        [subredditField setStringValue:currentSubreddit];
    }
    if (maxField) {
        int val = [maxField intValue];
        if (val > 0 && val <= 200) {
            maxComments = val;
        }
    }
    {
        NSTextField *ageField = [content viewWithTag:102];
        if (ageField) {
            int val = [ageField intValue];
            if (val > 0 && val <= 365) {
                cacheAgeDays = val;
            }
        }
    }

    [self savePreferences];
    [prefsWindow close];
    [statusText setString:[NSString stringWithFormat:@"Preferences saved (sub: %@, comments: %d, cache: %d days)",
        currentSubreddit, maxComments, cacheAgeDays]];
}
