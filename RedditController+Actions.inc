/* RedditController+Actions.inc
 * User actions, navigation, download, and playback.
 * Included from RedditViewer.m inside @implementation RedditController.
 */

/* Navigation and refresh */
- (void)refreshPosts:(id)sender {
    [statusText setString:@"Fetching Reddit posts..."];
    [progressIndicator startAnimation:nil];
    [self fetchRedditData];
}

- (void)browseAll:(id)sender {
    [currentSubreddit release];
    currentSubreddit = [@"all" retain];
    [subredditField setStringValue:@"all"];
    [self refreshPosts:nil];
}

- (void)browsePopular:(id)sender {
    [currentSubreddit release];
    currentSubreddit = [@"popular" retain];
    [subredditField setStringValue:@"popular"];
    [self refreshPosts:nil];
}

- (void)nextPage:(id)sender {
    if (currentAfter && [currentAfter length] > 0) {
        [self fetchRedditDataWithAfter:currentAfter];
    }
}

- (void)previousPage:(id)sender {
    if (currentBefore && [currentBefore length] > 0) {
        [self fetchRedditDataWithBefore:currentBefore];
    }
}

- (void)viewComments:(id)sender {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        RDPost *post = [posts objectAtIndex:selectedRow];
        NSLog(@"Opening comments for post: %@", [post title]);
        [self fetchCommentsForPost:post];
    } else {
        [statusText setString:@"Please select a post to view comments"];
    }
}

- (void)openFullImage:(id)sender {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        RDPost *post = [posts objectAtIndex:selectedRow];
        NSString *cType = [post contentType];

        NSLog(@"Opening content type: %@ for post: %@", cType, [post title]);

        if ([cType isEqualToString:@"video"] || [post isVideo]) {
            /* Handle video content (including NSFW from redgifs, etc.) */
            NSString *videoUrl = [post videoUrl] ? [post videoUrl] : [post url];
            NSAlert *alert;
            int result;

            alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Video Content"];

            if ([post isNSFW]) {
                [alert setInformativeText:@"This is NSFW video content. Would you like to download it or open in browser?"];
            } else {
                [alert setInformativeText:@"Would you like to download this video to Desktop or open it in your browser?"];
            }

            [alert addButtonWithTitle:@"Download"];
            [alert addButtonWithTitle:@"Open in Browser"];
            [alert addButtonWithTitle:@"Cancel"];

            result = [alert runModal];
            [alert release];

            if (result == NSAlertFirstButtonReturn) {
                [self downloadVideoToDesktop:videoUrl forPost:post];
            } else if (result == NSAlertSecondButtonReturn) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:videoUrl]];
                [statusText setString:@"Opening video in browser"];
            }
        }
        else if ([cType isEqualToString:@"article"] || [post isArticle]) {
            /* Handle article/external link */
            NSString *artUrl = [post articleUrl] ? [post articleUrl] : [post url];
            NSAlert *alert;
            int result;

            alert = [[NSAlert alloc] init];
            [alert setMessageText:@"External Link"];
            [alert setInformativeText:[NSString stringWithFormat:@"Open this link in your browser?\n\n%@", artUrl]];
            [alert addButtonWithTitle:@"Open"];
            [alert addButtonWithTitle:@"Cancel"];

            result = [alert runModal];
            [alert release];

            if (result == NSAlertFirstButtonReturn) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:artUrl]];
                [statusText setString:@"Opening article in browser"];
            }
        }
        else if ([cType isEqualToString:@"self"]) {
            /* Handle text post - show the self text */
            if ([post selfText] && [[post selfText] length] > 0) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:[post title]];
                [alert setInformativeText:[post selfText]];
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
                [alert release];
            } else {
                [statusText setString:@"This is a text post with no content"];
            }
        }
        else if ([[post imageType] isEqualToString:@"gallery"]) {
            /* Handle gallery */
            [self downloadGalleryToDesktop:post];
        }
        else if ([post hasImage] && [post imageUrl]) {
            /* Handle regular image */
            NSString *imgUrl = [post imageUrl];
            [self downloadFullImageToDesktop:imgUrl forPost:post];
        }
        else {
            /* Handle generic link */
            NSString *linkUrl = [post url];
            if (linkUrl && [linkUrl length] > 0) {
                NSAlert *alert;
                int result;

                alert = [[NSAlert alloc] init];
                [alert setMessageText:@"External Link"];
                [alert setInformativeText:[NSString stringWithFormat:@"Open this link in your browser?\n\n%@", linkUrl]];
                [alert addButtonWithTitle:@"Open"];
                [alert addButtonWithTitle:@"Cancel"];

                result = [alert runModal];
                [alert release];

                if (result == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:linkUrl]];
                    [statusText setString:@"Opening link in browser"];
                }
            } else {
                [statusText setString:@"No content available for this post"];
            }
        }
    } else {
        [statusText setString:@"Please select a post to view content"];
    }
}

- (void)downloadFullImageToDesktop:(NSString *)imageUrl forPost:(RDPost *)post {
    NSString *postTitle;
    DownloadResult result;

    [statusText setString:@"Downloading full image to Desktop..."];
    [progressIndicator startAnimation:nil];

    postTitle = [post title];

    result = reddit_download_image([imageUrl UTF8String],
                                   postTitle ? [postTitle UTF8String] : NULL);

    if (result.success) {
        [statusText setString:@"Image downloaded to Desktop"];
        if (result.path) {
            NSString *path = [NSString stringWithUTF8String:result.path];
            NSString *folder = [path stringByDeletingLastPathComponent];
            [[NSWorkspace sharedWorkspace] openFile:folder];
        } else {
            NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
            [[NSWorkspace sharedWorkspace] openFile:desktopPath];
        }
    } else {
        NSString *errMsg = result.error ?
            [NSString stringWithUTF8String:result.error] : @"Failed to download image";
        [statusText setString:errMsg];
    }

    download_result_free(&result);
    [progressIndicator stopAnimation:nil];
}

- (void)downloadGalleryToDesktop:(RDPost *)post {
    NSString *imgUrl;
    NSString *postTitle;
    DownloadResult result;

    [statusText setString:@"Downloading gallery to Desktop..."];
    [progressIndicator startAnimation:nil];

    imgUrl = [post imageUrl];
    postTitle = [post title];

    if (!imgUrl || [imgUrl length] == 0) {
        [statusText setString:@"No image URL available for gallery"];
        [progressIndicator stopAnimation:nil];
        return;
    }

    result = reddit_download_image([imgUrl UTF8String],
                                   postTitle ? [postTitle UTF8String] : NULL);

    if (result.success) {
        [statusText setString:@"Gallery downloaded to Desktop"];
        if (result.path) {
            /* Open the containing folder */
            NSString *path = [NSString stringWithUTF8String:result.path];
            NSString *folder = [path stringByDeletingLastPathComponent];
            [[NSWorkspace sharedWorkspace] openFile:folder];
        }
    } else {
        NSString *errMsg = result.error ?
            [NSString stringWithUTF8String:result.error] : @"Failed to download gallery";
        [statusText setString:errMsg];
    }

    download_result_free(&result);
    [progressIndicator stopAnimation:nil];
}

- (void)downloadVideoToDesktop:(NSString *)videoUrl forPost:(RDPost *)post {
    NSString *ytDlpPath;
    NSString *desktopPath;
    NSString *safeTitle;
    NSString *outputTemplate;
    NSString *quotedUrl;
    NSString *quotedOutput;
    NSString *quotedYtDlp;
    NSString *fullCommand;
    NSTask *task;
    NSPipe *outPipe;
    NSPipe *errPipe;
    NSDate *timeout;
    NSData *data;
    NSData *errData;
    NSString *output;
    NSString *errors;

    ytDlpPath = [self getYtDlpPath];
    if (!ytDlpPath) {
        [statusText setString:@"yt-dlp not found in bundle"];
        NSLog(@"ERROR: yt-dlp not found");
        return;
    }

    /* Check if yt-dlp is executable */
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm isExecutableFileAtPath:ytDlpPath]) {
            NSDictionary *attrs;
            NSLog(@"Making yt-dlp executable: %@", ytDlpPath);
            attrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0755]
                                                forKey:NSFilePosixPermissions];
            [fm changeFileAttributes:attrs atPath:ytDlpPath];
        }
    }

    [statusText setString:@"Downloading video to Desktop..."];
    [progressIndicator startAnimation:nil];

    desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
    safeTitle = [self sanitizeFilename:[post title]];
    outputTemplate = [NSString stringWithFormat:@"%@/%@.%%(ext)s", desktopPath, safeTitle];

    quotedUrl = [NSString stringWithFormat:@"'%@'", videoUrl];
    quotedOutput = [NSString stringWithFormat:@"'%@'", outputTemplate];
    quotedYtDlp = [NSString stringWithFormat:@"'%@'", ytDlpPath];

    fullCommand = [NSString stringWithFormat:@"export PATH=\"/usr/local/bin:/opt/local/bin:/usr/bin:$PATH\" && cd '%@' && %@ --no-playlist --max-filesize 100M --output %@ --verbose %@",
                    desktopPath, quotedYtDlp, quotedOutput, quotedUrl];

    task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:[NSArray arrayWithObjects:@"-c", fullCommand, nil]];

    outPipe = [NSPipe pipe];
    errPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task setCurrentDirectoryPath:desktopPath];

    NSLog(@"Running shell command: %@", fullCommand);

    [task launch];

    /* Wait with timeout and progress updates */
    timeout = [NSDate dateWithTimeIntervalSinceNow:120.0];
    while ([task isRunning] && [timeout timeIntervalSinceNow] > 0) {
        int elapsed;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        elapsed = 120 - (int)[timeout timeIntervalSinceNow];
        [statusText setString:[NSString stringWithFormat:@"Downloading video... (%d sec)", elapsed]];
    }

    if ([task isRunning]) {
        NSLog(@"Video download timeout - terminating");
        [task terminate];
        [statusText setString:@"Video download timed out"];
        [progressIndicator stopAnimation:nil];
        [task release];
        return;
    }

    [task waitUntilExit];

    data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
    output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    errors = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];

    NSLog(@"yt-dlp exit status: %d", [task terminationStatus]);
    NSLog(@"yt-dlp output: %@", output);
    if ([errors length] > 0) {
        NSLog(@"yt-dlp errors: %@", errors);
    }

    if ([task terminationStatus] == 0) {
        [statusText setString:@"Video downloaded to Desktop"];
        [[NSWorkspace sharedWorkspace] openFile:desktopPath];
    } else {
        NSString *errorMsg = [NSString stringWithFormat:@"Video download failed (exit %d)", [task terminationStatus]];
        [statusText setString:errorMsg];
        NSLog(@"yt-dlp failed with exit code: %d", [task terminationStatus]);
    }

    [progressIndicator stopAnimation:nil];
    [task release];
}

- (void)playVideoFromButton:(id)sender {
    /* The toolTip stores "hlsUrl|videoUrl" */
    NSString *urls = [sender toolTip];
    NSString *videoUrlStr = nil;
    DownloadResult dlResult;
    NSRange sep;

    if (!urls || [urls length] == 0) return;

    sep = [urls rangeOfString:@"|"];
    if (sep.location != NSNotFound) {
        videoUrlStr = [urls substringFromIndex:sep.location + 1];
    } else {
        videoUrlStr = urls;
    }

    [sender setTitle:@"Downloading..."];
    [sender setEnabled:NO];

    /* Download video with our libcurl (has TLS 1.2), then open in VLC */
    dlResult = reddit_download_video([videoUrlStr UTF8String]);

    if (dlResult.success && dlResult.path) {
        NSString *path = [NSString stringWithUTF8String:dlResult.path];
        BOOL opened = NO;

        /* Try MPlayer first (best H.264 PPC decode), then VLC, then default */
        {
            static const char *players[] = {
                "/Applications/MPlayer OSX.app",
                "/Applications/MPlayer.app",
                "/Applications/MPlayer OSX Extended.app",
                "/Applications/VLC.app",
                NULL
            };
            int pi;
            for (pi = 0; players[pi] && !opened; pi++) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:
                    [NSString stringWithUTF8String:players[pi]]]) {
                    NSTask *openTask = [[NSTask alloc] init];
                    [openTask setLaunchPath:@"/usr/bin/open"];
                    [openTask setArguments:[NSArray arrayWithObjects:@"-a",
                        [NSString stringWithUTF8String:players[pi]], path, nil]];
                    NS_DURING
                    {
                        [openTask launch];
                        opened = YES;
                    }
                    NS_HANDLER
                    {
                        NSLog(@"Player open failed: %@", [localException reason]);
                    }
                    NS_ENDHANDLER
                    [openTask release];
                }
            }
        }

        if (!opened) {
            [[NSWorkspace sharedWorkspace] openFile:path];
        }
        [sender setTitle:@"Playing..."];
    } else {
        /* Download failed — ask user instead of auto-opening browser */
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Video Unavailable"];
        [alert setInformativeText:@"This video could not be downloaded. It may require a Reddit login.\n\nWould you like to view it on old.reddit.com?"];
        [alert addButtonWithTitle:@"Open in Browser"];
        [alert addButtonWithTitle:@"Cancel"];
        {
            int result = [alert runModal];
            [alert release];

            if (result == NSAlertFirstButtonReturn) {
                int row = [tableView selectedRow];
                NSString *openUrl = videoUrlStr;
                if (row >= 0 && row < (int)[posts count]) {
                    RDPost *p = [posts objectAtIndex:row];
                    NSString *plink = [p permalink];
                    if (plink && [plink length] > 0) {
                        openUrl = [plink stringByReplacingOccurrencesOfString:@"https://reddit.com"
                                                                  withString:@"https://old.reddit.com"];
                    }
                }
                if (openUrl) {
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:openUrl]];
                }
            }
        }
        [sender setTitle:@"Download & Play Video"];
        [sender setEnabled:YES];
    }

    download_result_free(&dlResult);
}

- (NSString *)sanitizeFilename:(NSString *)filename {
    /* Remove or replace characters that aren't safe for filenames */
    NSMutableString *safe = [NSMutableString stringWithString:filename];

    [safe replaceOccurrencesOfString:@"/" withString:@"-" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@":" withString:@"-" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"?" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"\"" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"<" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@">" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"|" withString:@"-" options:0 range:NSMakeRange(0, [safe length])];

    /* Truncate if too long */
    if ([safe length] > 50) {
        [safe deleteCharactersInRange:NSMakeRange(50, [safe length] - 50)];
    }

    return safe;
}

- (NSString *)getYtDlpPath {
    NSString *resourcesPath = [[[NSBundle mainBundle] resourcePath] retain];
    NSString *ytDlpPath = [resourcesPath stringByAppendingPathComponent:@"yt-dlp-master/yt-dlp"];
    [resourcesPath release];

    /* Check if bundled version exists */
    if ([[NSFileManager defaultManager] fileExistsAtPath:ytDlpPath]) {
        return ytDlpPath;
    }

    /* Fallback to system installation or local version */
    {
        NSString *localPath = @"./yt-dlp-master/yt-dlp";
        if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
            return localPath;
        }
    }

    return nil;
}
