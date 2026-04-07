// Tiger-Compatible RedditViewer.m
// Compatible with Mac OS X 10.4 Tiger and GCC 4.0
// No blocks, no modern Objective-C features

#import <Cocoa/Cocoa.h>
#include "cJSON.h"

// Simple image utilities for Tiger
@interface ImageUtils : NSObject
+ (NSImage *)resizeImage:(NSImage *)sourceImage toSize:(NSSize)targetSize;
+ (NSImage *)createThumbnail:(NSImage *)sourceImage maxSize:(float)maxSize;
+ (BOOL)saveImageAsJPEG:(NSImage *)image toPath:(NSString *)path;
@end

@implementation ImageUtils

+ (NSImage *)resizeImage:(NSImage *)sourceImage toSize:(NSSize)targetSize {
    if (!sourceImage) return nil;

    NSImage *resizedImage = [[NSImage alloc] initWithSize:targetSize];
    [resizedImage lockFocus];

    NSRect targetRect = NSMakeRect(0, 0, targetSize.width, targetSize.height);
    [sourceImage drawInRect:targetRect
                   fromRect:NSZeroRect
                  operation:NSCompositeSourceOver
                   fraction:1.0];

    [resizedImage unlockFocus];
    return [resizedImage autorelease];
}

+ (NSImage *)createThumbnail:(NSImage *)sourceImage maxSize:(float)maxSize {
    if (!sourceImage) return nil;

    NSSize sourceSize = [sourceImage size];
    if (sourceSize.width <= maxSize && sourceSize.height <= maxSize) {
        return sourceImage;
    }

    float aspectRatio = sourceSize.width / sourceSize.height;
    NSSize targetSize;

    if (sourceSize.width > sourceSize.height) {
        targetSize.width = maxSize;
        targetSize.height = maxSize / aspectRatio;
    } else {
        targetSize.height = maxSize;
        targetSize.width = maxSize * aspectRatio;
    }

    return [self resizeImage:sourceImage toSize:targetSize];
}

+ (BOOL)saveImageAsJPEG:(NSImage *)image toPath:(NSString *)path {
    if (!image || !path) return NO;

    // Create bitmap representation
    NSBitmapImageRep *bitmapRep = nil;
    NSEnumerator *repEnum = [[image representations] objectEnumerator];
    NSImageRep *rep;

    while ((rep = [repEnum nextObject])) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapRep = (NSBitmapImageRep *)rep;
            break;
        }
    }

    // If no bitmap rep found, create one
    if (!bitmapRep) {
        [image lockFocus];
        bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:
                      NSMakeRect(0, 0, [image size].width, [image size].height)] autorelease];
        [image unlockFocus];
    }

    // Save as JPEG with Tiger-compatible method
    NSDictionary *properties = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.8]
                                                           forKey:NSImageCompressionFactor];
    NSData *imageData = [bitmapRep representationUsingType:NSJPEGFileType properties:properties];

    return [imageData writeToFile:path atomically:YES];
}

@end

// RedditPost model
@interface RedditPost : NSObject {
    NSString *title;
    NSString *author;
    NSString *subreddit;
    int score;
    int numComments;
    NSString *url;
    NSString *permalink;
    BOOL hasImage;
    NSString *imageUrl;
    NSString *thumbnailUrl;
    NSString *imageType;
    NSString *contentType;  // New: 'video', 'article', 'image', 'self', 'link'
    NSString *selfText;
    BOOL isVideo;
    NSString *videoUrl;
    BOOL isArticle;
    NSString *articleUrl;
    BOOL isNSFW;
}
- (NSString *)title;
- (void)setTitle:(NSString *)aTitle;
- (NSString *)author;
- (void)setAuthor:(NSString *)anAuthor;
- (NSString *)subreddit;
- (void)setSubreddit:(NSString *)aSubreddit;
- (int)score;
- (void)setScore:(int)aScore;
- (int)numComments;
- (void)setNumComments:(int)count;
- (NSString *)url;
- (void)setUrl:(NSString *)aUrl;
- (NSString *)permalink;
- (void)setPermalink:(NSString *)aPermalink;
- (BOOL)hasImage;
- (void)setHasImage:(BOOL)hasImg;
- (NSString *)imageUrl;
- (void)setImageUrl:(NSString *)imgUrl;
- (NSString *)thumbnailUrl;
- (void)setThumbnailUrl:(NSString *)thumbUrl;
- (NSString *)imageType;
- (void)setImageType:(NSString *)imgType;
- (NSString *)selfText;
- (void)setSelfText:(NSString *)text;
- (NSString *)contentType;
- (void)setContentType:(NSString *)cType;
- (BOOL)isVideo;
- (void)setIsVideo:(BOOL)video;
- (NSString *)videoUrl;
- (void)setVideoUrl:(NSString *)vUrl;
- (BOOL)isArticle;
- (void)setIsArticle:(BOOL)article;
- (NSString *)articleUrl;
- (void)setArticleUrl:(NSString *)aUrl;
- (BOOL)isNSFW;
- (void)setIsNSFW:(BOOL)nsfw;
@end

@implementation RedditPost

- (NSString *)title { return title; }
- (void)setTitle:(NSString *)aTitle {
    [aTitle retain];
    [title release];
    title = aTitle;
}

- (NSString *)author { return author; }
- (void)setAuthor:(NSString *)anAuthor {
    [anAuthor retain];
    [author release];
    author = anAuthor;
}

- (NSString *)subreddit { return subreddit; }
- (void)setSubreddit:(NSString *)aSubreddit {
    [aSubreddit retain];
    [subreddit release];
    subreddit = aSubreddit;
}

- (int)score { return score; }
- (void)setScore:(int)aScore { score = aScore; }

- (int)numComments { return numComments; }
- (void)setNumComments:(int)count { numComments = count; }

- (NSString *)url { return url; }
- (void)setUrl:(NSString *)aUrl {
    [aUrl retain];
    [url release];
    url = aUrl;
}

- (NSString *)permalink { return permalink; }
- (void)setPermalink:(NSString *)aPermalink {
    [aPermalink retain];
    [permalink release];
    permalink = aPermalink;
}

- (BOOL)hasImage { return hasImage; }
- (void)setHasImage:(BOOL)hasImg { hasImage = hasImg; }

- (NSString *)imageUrl { return imageUrl; }
- (void)setImageUrl:(NSString *)imgUrl {
    [imgUrl retain];
    [imageUrl release];
    imageUrl = imgUrl;
}

- (NSString *)thumbnailUrl { return thumbnailUrl; }
- (void)setThumbnailUrl:(NSString *)thumbUrl {
    [thumbUrl retain];
    [thumbnailUrl release];
    thumbnailUrl = thumbUrl;
}

- (NSString *)imageType { return imageType; }
- (void)setImageType:(NSString *)imgType {
    [imgType retain];
    [imageType release];
    imageType = imgType;
}

- (NSString *)selfText { return selfText; }
- (void)setSelfText:(NSString *)text {
    [text retain];
    [selfText release];
    selfText = text;
}
- (NSString *)contentType { return contentType; }
- (void)setContentType:(NSString *)cType {
    [cType retain];
    [contentType release];
    contentType = cType;
}

- (BOOL)isVideo { return isVideo; }
- (void)setIsVideo:(BOOL)video { isVideo = video; }

- (NSString *)videoUrl { return videoUrl; }
- (void)setVideoUrl:(NSString *)vUrl {
    [vUrl retain];
    [videoUrl release];
    videoUrl = vUrl;
}

- (BOOL)isArticle { return isArticle; }
- (void)setIsArticle:(BOOL)article { isArticle = article; }

- (NSString *)articleUrl { return articleUrl; }
- (void)setArticleUrl:(NSString *)aUrl {
    [aUrl retain];
    [articleUrl release];
    articleUrl = aUrl;
}

- (BOOL)isNSFW { return isNSFW; }
- (void)setIsNSFW:(BOOL)nsfw { isNSFW = nsfw; }

- (void)dealloc {
    [title release];
    [author release];
    [subreddit release];
    [url release];
    [permalink release];
    [imageUrl release];
    [thumbnailUrl release];
    [imageType release];
    [contentType release];
    [selfText release];
    [videoUrl release];
    [articleUrl release];
    [super dealloc];
}

@end

// Comment View Controller
@interface CommentViewController : NSWindowController {
    NSWindow *commentWindow;
    NSTextView *commentTextView;
    RedditPost *currentPost;
}

- (id)initWithPost:(RedditPost *)post;
- (void)showComments;
- (void)fetchComments;
- (void)parseAndDisplayComments:(NSString *)jsonString;
- (void)showCommentsWithJSON:(NSString *)jsonString;

@end

@implementation CommentViewController

- (id)initWithPost:(RedditPost *)post {
    self = [super init];
    if (self) {
        currentPost = [post retain];
    }
    return self;
}

- (void)showCommentsWithJSON:(NSString *)jsonString {
    [self showComments];
    [self parseAndDisplayComments:jsonString];
}

- (void)dealloc {
    [currentPost release];
    [commentWindow release];
    [super dealloc];
}

- (void)showComments {
    NSRect frame = NSMakeRect(150, 150, 800, 600);
    commentWindow = [[NSWindow alloc] initWithContentRect:frame
                                               styleMask:(NSTitledWindowMask |
                                                         NSClosableWindowMask |
                                                         NSMiniaturizableWindowMask |
                                                         NSResizableWindowMask)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];

    NSString *title = [NSString stringWithFormat:@"Comments: %.60@", [currentPost title]];
    [commentWindow setTitle:title];

    NSView *contentView = [commentWindow contentView];
    NSRect scrollFrame = NSMakeRect(10, 10, frame.size.width - 20, frame.size.height - 20);

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    commentTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, scrollFrame.size.width, scrollFrame.size.height)];
    [commentTextView setEditable:NO];
    [commentTextView setString:@"Loading comments..."];
    [commentTextView setFont:[NSFont systemFontOfSize:12]];

    [scrollView setDocumentView:commentTextView];
    [contentView addSubview:scrollView];

    [commentWindow makeKeyAndOrderFront:nil];
    [self fetchComments];
}

- (void)fetchComments {
    NSString *commentsUrl = [NSString stringWithFormat:@"%@.json", [currentPost permalink]];
    NSString *curlCommand = [NSString stringWithFormat:@"/usr/bin/curl -s -A 'RedditViewer/1.0' '%@'", commentsUrl];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:[NSArray arrayWithObjects:@"-c", curlCommand, nil]];

    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];

    [task launch];
    [task waitUntilExit];

    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    [self parseAndDisplayComments:jsonString];
    [task release];
}

- (void)parseAndDisplayComments:(NSString *)jsonString {
    if (!jsonString || [jsonString length] == 0) {
        [commentTextView setString:@"Failed to load comments."];
        return;
    }

    NSMutableString *commentsText = [NSMutableString string];
    [commentsText appendString:[NSString stringWithFormat:@"Post: %@\n\n", [currentPost title]]];
    [commentsText appendString:[NSString stringWithFormat:@"Author: %@ | Score: %d | Comments: %d\n\n",
        [currentPost author], [currentPost score], [currentPost numComments]]];

    if ([currentPost selfText] && [[currentPost selfText] length] > 0) {
        [commentsText appendString:[NSString stringWithFormat:@"Text: %@\n\n", [currentPost selfText]]];
    }

    [commentsText appendString:@"Comments:\n"];
    [commentsText appendString:@"===============================================\n\n"];

    @try {
        cJSON *root = cJSON_Parse([jsonString UTF8String]);
        if (!root) {
            [commentsText appendString:@"Error parsing comments data."];
            [commentTextView setString:commentsText];
            return;
        }

        // Check if we have the expected structure
        if (!cJSON_IsArray(root) || cJSON_GetArraySize(root) < 2) {
            [commentsText appendString:@"Unexpected comments format."];
            cJSON_Delete(root);
            [commentTextView setString:commentsText];
            return;
        }

        cJSON *commentsData = cJSON_GetArrayItem(root, 1);
        if (commentsData) {
            cJSON *data = cJSON_GetObjectItem(commentsData, "data");
            if (data) {
                cJSON *children = cJSON_GetObjectItem(data, "children");
                if (children && cJSON_IsArray(children)) {
                    int commentCount = cJSON_GetArraySize(children);
                    int i;
                    int validComments = 0;

                    for (i = 0; i < commentCount && validComments < 15; i++) {
                        cJSON *comment = cJSON_GetArrayItem(children, i);
                        if (comment) {
                            cJSON *commentData = cJSON_GetObjectItem(comment, "data");
                            if (commentData) {
                                cJSON *author = cJSON_GetObjectItem(commentData, "author");
                                cJSON *body = cJSON_GetObjectItem(commentData, "body");
                                cJSON *score = cJSON_GetObjectItem(commentData, "score");

                                if (author && body && cJSON_IsString(author) && cJSON_IsString(body) &&
                                    author->valuestring && body->valuestring) {

                                    NSString *authorStr = [NSString stringWithUTF8String:author->valuestring];
                                    NSString *bodyStr = [NSString stringWithUTF8String:body->valuestring];
                                    int scoreVal = (score && cJSON_IsNumber(score)) ? score->valueint : 0;

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

        cJSON_Delete(root);
    }
    @catch (NSException *exception) {
        NSLog(@"Exception parsing comments: %@", [exception reason]);
        [commentsText appendString:@"Error processing comments."];
    }

    [commentTextView setString:commentsText];
}

@end

// Forward declarations for RedditController
@interface RedditController : NSObject {
    NSWindow *window;
    NSTableView *tableView;
    NSTextField *subredditField;
    NSPopUpButton *sortButton;
    NSButton *refreshButton;
    NSButton *allButton;
    NSButton *popularButton;
    NSButton *commentsButton;
    NSProgressIndicator *progressIndicator;
    NSTextView *statusText;
    NSMutableArray *posts;
    NSString *currentSubreddit;
    NSString *currentAfter;
    NSString *currentBefore;
    NSPopUpButton *postCountButton;
    int currentPostCount;

    // Image cache
    NSImage *placeholderImage;
    NSImage *loadingImage;
}

// Method declarations to avoid compiler warnings
- (void)createUI;
- (void)refreshPosts:(id)sender;
- (void)browseAll:(id)sender;
- (void)browsePopular:(id)sender;
- (void)viewComments:(id)sender;
- (void)openFullImage:(id)sender;
- (void)fetchRedditData;
- (NSArray *)parseJSONString:(NSString *)jsonString;
- (void)updateWithJSON:(NSString *)jsonString;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (float)tableView:(NSTableView *)aTableView heightOfRow:(int)row;
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (NSImage *)createPlaceholderImage;
- (NSImage *)createLoadingImage;
- (NSString *)getPythonPath;
- (NSString *)getScriptPath;
- (NSString *)getBundledScriptPath;
- (NSString *)getScriptPathWithSimple:(BOOL)useSimple;
- (void)addTestData;
- (void)testTableDisplay:(id)sender;
- (void)downloadFullImageToDesktop:(NSString *)imageUrl forPost:(RedditPost *)post;
- (void)fetchRedditDataWithAfter:(NSString *)after;
- (void)fetchRedditDataWithBefore:(NSString *)before;
- (void)runPythonScriptWithSubreddit:(NSString *)subreddit sort:(NSString *)sort count:(int)count after:(NSString *)after before:(NSString *)before;
- (void)fetchCommentsForPost:(RedditPost *)post;
- (void)showCommentsWindow:(NSString *)jsonString forPost:(RedditPost *)post;
- (void)postCountChanged:(id)sender;
- (void)nextPage:(id)sender;
- (void)previousPage:(id)sender;
- (void)downloadVideoToDesktop:(NSString *)videoUrl forPost:(RedditPost *)post;
- (void)downloadGalleryToDesktop:(RedditPost *)post;
- (NSString *)getYtDlpPath;
- (NSString *)sanitizeFilename:(NSString *)filename;
- (void)parseCommentsJSON:(NSString *)jsonString intoTextView:(NSTextView *)textView forPost:(RedditPost *)post;
- (void)runPythonScript:(NSTimer *)timer;
- (void)runPythonScriptSync:(NSString *)subreddit sort:(NSString *)sort;

@end

// Main application controller implementation
@implementation RedditController

- (id)init {
    self = [super init];
    if (self) {
        posts = [[NSMutableArray alloc] init];
        currentSubreddit = [@"all" retain];
        currentPostCount = 25;

        placeholderImage = [[self createPlaceholderImage] retain];
        loadingImage = [[self createLoadingImage] retain];
    }
    return self;
}

- (void)dealloc {
    [posts release];
    [currentSubreddit release];
    [currentAfter release];
    [currentBefore release];
    [placeholderImage release];
    [loadingImage release];
    [super dealloc];
}

- (NSString *)getBundledScriptPath {
    NSString *resourcesPath = [[[NSBundle mainBundle] resourcePath] retain];
    NSString *scriptPath = [resourcesPath stringByAppendingPathComponent:@"reddit_fetcher.py"];
    [resourcesPath release];

    if ([[NSFileManager defaultManager] fileExistsAtPath:scriptPath]) {
        return scriptPath;
    }

    // Fallback to local version
    return @"./reddit_fetcher.py";
}

- (NSString *)getYtDlpPath {
    NSString *resourcesPath = [[[NSBundle mainBundle] resourcePath] retain];
    NSString *ytDlpPath = [resourcesPath stringByAppendingPathComponent:@"yt-dlp-master/yt-dlp"];
    [resourcesPath release];

    // Check if bundled version exists
    if ([[NSFileManager defaultManager] fileExistsAtPath:ytDlpPath]) {
        return ytDlpPath;
    }

    // Fallback to system installation or local version
    NSString *localPath = @"./yt-dlp-master/yt-dlp";
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        return localPath;
    }

    return nil;
}

- (NSString *)sanitizeFilename:(NSString *)filename {
    // Remove or replace characters that aren't safe for filenames
    NSMutableString *safe = [NSMutableString stringWithString:filename];

    // Replace problematic characters
    [safe replaceOccurrencesOfString:@"/" withString:@"-" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@":" withString:@"-" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"?" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"\"" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"<" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@">" withString:@"" options:0 range:NSMakeRange(0, [safe length])];
    [safe replaceOccurrencesOfString:@"|" withString:@"-" options:0 range:NSMakeRange(0, [safe length])];

    // Truncate if too long
    if ([safe length] > 50) {
        [safe deleteCharactersInRange:NSMakeRange(50, [safe length] - 50)];
    }

    return safe;
}

- (NSString *)getPythonPath {
    // Try common Python 3 installation paths for Tiger
    NSArray *pythonPaths = [NSArray arrayWithObjects:
        @"/usr/local/bin/python3.11",
        @"/usr/local/bin/python3",
        @"/opt/local/bin/python3.11",
        @"/opt/local/bin/python3",
        @"/usr/bin/python3",
        nil];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSEnumerator *pathEnum = [pythonPaths objectEnumerator];
    NSString *path;

    while ((path = [pathEnum nextObject])) {
        if ([fileManager fileExistsAtPath:path]) {
            NSLog(@"Found Python at: %@", path);
            return path;
        }
    }

    NSLog(@"Warning: Python 3 not found, using default python3");
    return @"python3"; // Fallback
}

- (NSString *)getScriptPath {
    // Try bundled version first
    NSString *bundledPath = [self getBundledScriptPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bundledPath]) {
        return bundledPath;
    }

    // Fallback to local version
    return @"./reddit_fetcher.py";
}

- (NSImage *)createVideoThumbnailPlaceholder {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    // Dark background for video
    [[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:1.0] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    // Red border for video
    [[NSColor redColor] set];
    NSFrameRect(NSMakeRect(0, 0, 60, 60));

    // Play button triangle
    [[NSColor whiteColor] set];
    NSBezierPath *triangle = [NSBezierPath bezierPath];
    [triangle moveToPoint:NSMakePoint(20, 15)];
    [triangle lineToPoint:NSMakePoint(45, 30)];
    [triangle lineToPoint:NSMakePoint(20, 45)];
    [triangle closePath];
    [triangle fill];

    // "VIDEO" text
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSFont boldSystemFontOfSize:8] forKey:NSFontAttributeName];
    [attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    [@"VIDEO" drawAtPoint:NSMakePoint(15, 5) withAttributes:attributes];

    [img unlockFocus];
    return [img autorelease];
}

- (NSImage *)createArticleThumbnailPlaceholder {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    // Light blue background for articles
    [[NSColor colorWithCalibratedRed:0.9 green:0.95 blue:1.0 alpha:1.0] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    // Blue border for article
    [[NSColor blueColor] set];
    NSFrameRect(NSMakeRect(0, 0, 60, 60));

    // Document icon (simple rectangles representing text lines)
    [[NSColor blueColor] set];
    NSRectFill(NSMakeRect(10, 40, 40, 3));
    NSRectFill(NSMakeRect(10, 35, 35, 2));
    NSRectFill(NSMakeRect(10, 30, 40, 2));
    NSRectFill(NSMakeRect(10, 25, 30, 2));

    // "LINK" text
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSFont boldSystemFontOfSize:8] forKey:NSFontAttributeName];
    [attributes setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];
    [@"LINK" drawAtPoint:NSMakePoint(18, 5) withAttributes:attributes];

    [img unlockFocus];
    return [img autorelease];
}

- (NSImage *)createNSFWOverlay {
    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(60, 60)];
    [img lockFocus];

    // Semi-transparent red overlay
    [[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.3] set];
    NSRectFill(NSMakeRect(0, 0, 60, 60));

    // NSFW text
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSFont boldSystemFontOfSize:10] forKey:NSFontAttributeName];
    [attributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
    [@"NSFW" drawAtPoint:NSMakePoint(15, 25) withAttributes:attributes];

    [img unlockFocus];
    return [img autorelease];
}

// Enhanced table cell display method
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    if ([[aTableColumn identifier] isEqualToString:@"thumbnail"]) {
        // Clear any existing image first
        if ([cell respondsToSelector:@selector(setImage:)]) {
            [cell setImage:nil];
        }

        if (rowIndex >= [posts count]) {
            [cell setImage:placeholderImage];
            return;
        }

        RedditPost *post = [posts objectAtIndex:rowIndex];
        NSImage *displayImage = nil;

        // Determine what image to show based on content type
        NSString *contentType = [post contentType];

        if ([contentType isEqualToString:@"video"]) {
            if ([post hasImage] && [post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]) {
                // Load actual video thumbnail if available
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
        else if ([contentType isEqualToString:@"article"]) {
            if ([post hasImage] && [post thumbnailUrl] && [[post thumbnailUrl] hasPrefix:@"/"]) {
                // Load actual article thumbnail if available
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

            // Check if it's a local file path (from Python script)
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

        // Add NSFW overlay if needed
        if ([post isNSFW] && displayImage) {
            NSImage *combinedImage = [[NSImage alloc] initWithSize:[displayImage size]];
            [combinedImage lockFocus];

            // Draw base image
            [displayImage drawAtPoint:NSZeroPoint
                             fromRect:NSZeroRect
                            operation:NSCompositeSourceOver
                             fraction:1.0];

            // Draw NSFW overlay
            NSImage *nsfwOverlay = [self createNSFWOverlay];
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

    // Enhanced title column display with content type indicators
    else if ([[aTableColumn identifier] isEqualToString:@"title"]) {
        if (rowIndex < [posts count]) {
            RedditPost *post = [posts objectAtIndex:rowIndex];
            NSString *title = [post title];
            NSString *contentType = [post contentType];

            // Add content type prefix to title
            NSString *prefix = @"";
            if ([contentType isEqualToString:@"video"]) {
                prefix = @"▶ ";
            } else if ([contentType isEqualToString:@"article"]) {
                prefix = @"🔗 ";
            } else if ([contentType isEqualToString:@"self"]) {
                prefix = @"💬 ";
            }

            // Add NSFW indicator
            if ([post isNSFW]) {
                prefix = [prefix stringByAppendingString:@"[NSFW] "];
            }

            NSString *displayTitle = [prefix stringByAppendingString:title];
            [cell setStringValue:displayTitle];
        }
    }
}

- (NSString *)getScriptPathWithSimple:(BOOL)useSimple {
    NSString *scriptName = useSimple ? @"reddit_fetcher_simple" : @"reddit_fetcher";

    // First try to find the script in the app bundle's Resources folder
    NSString *bundleScriptPath = [[NSBundle mainBundle] pathForResource:scriptName ofType:@"py"];
    if (bundleScriptPath) {
        NSLog(@"Found %@ script in app bundle: %@", scriptName, bundleScriptPath);
        return bundleScriptPath;
    }

    // Try the same directory as the executable (for development)
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSString *appDir = [appPath stringByDeletingLastPathComponent];
    NSString *scriptPath = [appDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.py", scriptName]];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:scriptPath]) {
        NSLog(@"Found %@ script next to app: %@", scriptName, scriptPath);
        return scriptPath;
    }

    // Try current working directory
    NSString *currentDir = [[NSFileManager defaultManager] currentDirectoryPath];
    scriptPath = [currentDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.py", scriptName]];
    if ([fileManager fileExistsAtPath:scriptPath]) {
        NSLog(@"Found %@ script in current directory: %@", scriptName, scriptPath);
        return scriptPath;
    }

    NSLog(@"Warning: %@ script not found in any location, using relative path", scriptName);
    return [NSString stringWithFormat:@"%@.py", scriptName];
}

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

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:[NSFont boldSystemFontOfSize:14] forKey:NSFontAttributeName];
    [attributes setObject:[NSColor blueColor] forKey:NSForegroundColorAttributeName];

    [@"..." drawAtPoint:NSMakePoint(22, 23) withAttributes:attributes];

    [img unlockFocus];
    return [img autorelease];
}

- (void)createUI {
    NSRect frame = NSMakeRect(100, 100, 1300, 700);
    window = [[NSWindow alloc] initWithContentRect:frame
                                         styleMask:(NSTitledWindowMask |
                                                   NSClosableWindowMask |
                                                   NSMiniaturizableWindowMask |
                                                   NSResizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setTitle:@"TigerReddit"];

    NSView *contentView = [window contentView];

    // Create toolbar
    NSRect toolbarFrame = NSMakeRect(10, frame.size.height - 80, frame.size.width - 20, 70);
    NSBox *toolbar = [[NSBox alloc] initWithFrame:toolbarFrame];
    [toolbar setBoxType:NSBoxPrimary];
    [toolbar setBorderType:NSLineBorder];
    [toolbar setTitlePosition:NSNoTitle];
    [toolbar setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    // All button
    NSRect allFrame = NSMakeRect(10, 15, 60, 25);
    allButton = [[NSButton alloc] initWithFrame:allFrame];
    [allButton setTitle:@"All"];
    [allButton setBezelStyle:NSRoundedBezelStyle];
    [allButton setTarget:self];
    [allButton setAction:@selector(browseAll:)];
    [[toolbar contentView] addSubview:allButton];

    // Popular button
    NSRect popularFrame = NSMakeRect(80, 15, 80, 25);
    popularButton = [[NSButton alloc] initWithFrame:popularFrame];
    [popularButton setTitle:@"Popular"];
    [popularButton setBezelStyle:NSRoundedBezelStyle];
    [popularButton setTarget:self];
    [popularButton setAction:@selector(browsePopular:)];
    [[toolbar contentView] addSubview:popularButton];

    // Separator
    NSRect sepFrame = NSMakeRect(170, 17, 35, 20);
    NSTextField *sepLabel = [[NSTextField alloc] initWithFrame:sepFrame];
    [sepLabel setStringValue:@"|"];
    [sepLabel setBezeled:NO];
    [sepLabel setDrawsBackground:NO];
    [sepLabel setEditable:NO];
    [sepLabel setSelectable:NO];
    [[toolbar contentView] addSubview:sepLabel];

    // Subreddit label
    NSRect labelFrame = NSMakeRect(190, 17, 80, 20);
    NSTextField *subLabel = [[NSTextField alloc] initWithFrame:labelFrame];
    [subLabel setStringValue:@"Subreddit:"];
    [subLabel setBezeled:NO];
    [subLabel setDrawsBackground:NO];
    [subLabel setEditable:NO];
    [subLabel setSelectable:NO];
    [[toolbar contentView] addSubview:subLabel];

    // Subreddit field
    NSRect fieldFrame = NSMakeRect(270, 15, 150, 25);
    subredditField = [[NSTextField alloc] initWithFrame:fieldFrame];
    [subredditField setStringValue:@"programming"];
    [subredditField setEditable:YES];
    [subredditField setSelectable:YES];
    [subredditField setBezeled:YES];
    [subredditField setDrawsBackground:YES];
    [[toolbar contentView] addSubview:subredditField];

    // Sort popup
    NSRect sortFrame = NSMakeRect(430, 15, 100, 25);
    sortButton = [[NSPopUpButton alloc] initWithFrame:sortFrame];
    [sortButton addItemWithTitle:@"Hot"];
    [sortButton addItemWithTitle:@"New"];
    [sortButton addItemWithTitle:@"Top"];
    [sortButton addItemWithTitle:@"Rising"];
    [[toolbar contentView] addSubview:sortButton];

    // Refresh button
    NSRect refreshFrame = NSMakeRect(540, 15, 80, 25);
    refreshButton = [[NSButton alloc] initWithFrame:refreshFrame];
    [refreshButton setTitle:@"Refresh"];
    [refreshButton setBezelStyle:NSRoundedBezelStyle];
    [refreshButton setTarget:self];
    [refreshButton setAction:@selector(refreshPosts:)];
    [refreshButton setKeyEquivalent:@"\r"];
    [[toolbar contentView] addSubview:refreshButton];

    // Comments button
    NSRect commentsFrame = NSMakeRect(630, 15, 100, 25);
    commentsButton = [[NSButton alloc] initWithFrame:commentsFrame];
    [commentsButton setTitle:@"Comments"];
    [commentsButton setBezelStyle:NSRoundedBezelStyle];
    [commentsButton setTarget:self];
    [commentsButton setAction:@selector(viewComments:)];
    [[toolbar contentView] addSubview:commentsButton];

    // Full Image button
    NSRect fullImageFrame = NSMakeRect(740, 15, 100, 25);
    NSButton *fullImageButton = [[NSButton alloc] initWithFrame:fullImageFrame];
    [fullImageButton setTitle:@"View Image"];
    [fullImageButton setBezelStyle:NSRoundedBezelStyle];
    [fullImageButton setTarget:self];
    [fullImageButton setAction:@selector(openFullImage:)];
    [[toolbar contentView] addSubview:fullImageButton];

    // Post count popup
    NSRect countFrame = NSMakeRect(950, 15, 80, 25);
    postCountButton = [[NSPopUpButton alloc] initWithFrame:countFrame];
    [postCountButton addItemWithTitle:@"10"];
    [postCountButton addItemWithTitle:@"25"];
    [postCountButton addItemWithTitle:@"50"];
    [postCountButton selectItemWithTitle:@"25"];
    [postCountButton setTarget:self];
    [postCountButton setAction:@selector(postCountChanged:)];
    [[toolbar contentView] addSubview:postCountButton];

    // Previous/Next buttons
    NSRect prevFrame = NSMakeRect(1040, 15, 60, 25);
    NSButton *prevButton = [[NSButton alloc] initWithFrame:prevFrame];
    [prevButton setTitle:@"Prev"];
    [prevButton setBezelStyle:NSRoundedBezelStyle];
    [prevButton setTarget:self];
    [prevButton setAction:@selector(previousPage:)];
    [[toolbar contentView] addSubview:prevButton];

    NSRect nextFrame = NSMakeRect(1110, 15, 60, 25);
    NSButton *nextButton = [[NSButton alloc] initWithFrame:nextFrame];
    [nextButton setTitle:@"Next"];
    [nextButton setBezelStyle:NSRoundedBezelStyle];
    [nextButton setTarget:self];
    [nextButton setAction:@selector(nextPage:)];
    [[toolbar contentView] addSubview:nextButton];

    // Progress indicator
    NSRect progressFrame = NSMakeRect(1130, 17, 20, 20);
    progressIndicator = [[NSProgressIndicator alloc] initWithFrame:progressFrame];
    [progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [progressIndicator setDisplayedWhenStopped:NO];
    [[toolbar contentView] addSubview:progressIndicator];

    [contentView addSubview:toolbar];

    // Create scroll view and table
    NSRect scrollFrame = NSMakeRect(10, 50, frame.size.width - 20, frame.size.height - 120);
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    tableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, scrollFrame.size.width, scrollFrame.size.height)];
    [tableView setDataSource:self];
    [tableView setDelegate:self];
    [tableView setUsesAlternatingRowBackgroundColors:YES];
    [tableView setRowHeight:70.0];
    [tableView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    // Tiger-specific table setup
    [tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
    [tableView setAllowsMultipleSelection:NO];
    [tableView setAllowsEmptySelection:YES];
    [tableView setAllowsColumnSelection:NO];

    // Add columns
    NSTableColumn *thumbColumn = [[NSTableColumn alloc] initWithIdentifier:@"thumbnail"];
    [[thumbColumn headerCell] setStringValue:@"Image"];
    [thumbColumn setWidth:80];
    [thumbColumn setMinWidth:80];
    [thumbColumn setMaxWidth:80];
    NSImageCell *imageCell = [[NSImageCell alloc] init];
    [thumbColumn setDataCell:imageCell];
    [imageCell release];
    [tableView addTableColumn:thumbColumn];

    NSTableColumn *titleColumn = [[NSTableColumn alloc] initWithIdentifier:@"title"];
    [[titleColumn headerCell] setStringValue:@"Title"];
    [titleColumn setWidth:400];
    [tableView addTableColumn:titleColumn];

    NSTableColumn *authorColumn = [[NSTableColumn alloc] initWithIdentifier:@"author"];
    [[authorColumn headerCell] setStringValue:@"Author"];
    [authorColumn setWidth:100];
    [tableView addTableColumn:authorColumn];

    NSTableColumn *scoreColumn = [[NSTableColumn alloc] initWithIdentifier:@"score"];
    [[scoreColumn headerCell] setStringValue:@"Score"];
    [scoreColumn setWidth:60];
    [tableView addTableColumn:scoreColumn];

    NSTableColumn *commentsColumn = [[NSTableColumn alloc] initWithIdentifier:@"comments"];
    [[commentsColumn headerCell] setStringValue:@"Comments"];
    [commentsColumn setWidth:80];
    [tableView addTableColumn:commentsColumn];

    NSTableColumn *subredditColumn = [[NSTableColumn alloc] initWithIdentifier:@"subreddit"];
    [[subredditColumn headerCell] setStringValue:@"Subreddit"];
    [subredditColumn setWidth:100];
    [tableView addTableColumn:subredditColumn];

    [scrollView setDocumentView:tableView];
    [contentView addSubview:scrollView];

    // Status text area
    NSRect statusFrame = NSMakeRect(10, 10, frame.size.width - 20, 30);
    statusText = [[NSTextView alloc] initWithFrame:statusFrame];
    [statusText setEditable:NO];
    [statusText setRichText:NO];
    [statusText setString:@"Ready to fetch Reddit posts (Tiger-compatible version)..."];
    [statusText setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:statusText];

    [window makeKeyAndOrderFront:nil];

    // Add some test data to verify table is working (Tiger debugging)
    [self addTestData];

    // Auto-load data
    [self browseAll:nil];
}

- (void)addTestData {
    NSLog(@"Adding test data for debugging...");

    // Create a few test posts to verify the table works
    RedditPost *testPost1 = [[RedditPost alloc] init];
    [testPost1 setTitle:@"Test Post 1 - Table Display Test"];
    [testPost1 setAuthor:@"test_user"];
    [testPost1 setSubreddit:@"test"];
    [testPost1 setScore:42];
    [testPost1 setNumComments:5];
    [testPost1 setHasImage:NO];

    RedditPost *testPost2 = [[RedditPost alloc] init];
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

- (void)openFullImage:(id)sender {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        RedditPost *post = [posts objectAtIndex:selectedRow];
        NSString *contentType = [post contentType];

        NSLog(@"Opening content type: %@ for post: %@", contentType, [post title]);

        if ([contentType isEqualToString:@"video"] || [post isVideo]) {
            // Handle video content (including NSFW from redgifs, etc.)
            NSString *videoUrl = [post videoUrl] ? [post videoUrl] : [post url];

            // Show dialog for video action
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"Video Content"];

            if ([post isNSFW]) {
                [alert setInformativeText:@"This is NSFW video content. Would you like to download it or open in browser?"];
            } else {
                [alert setInformativeText:@"Would you like to download this video to Desktop or open it in your browser?"];
            }

            [alert addButtonWithTitle:@"Download"];
            [alert addButtonWithTitle:@"Open in Browser"];
            [alert addButtonWithTitle:@"Cancel"];

            int result = [alert runModal];
            [alert release];

            if (result == NSAlertFirstButtonReturn) {
                // Download video (works for Reddit videos, YouTube, redgifs, etc.)
                [self downloadVideoToDesktop:videoUrl forPost:post];
            } else if (result == NSAlertSecondButtonReturn) {
                // Open in browser
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:videoUrl]];
                [statusText setString:@"Opening video in browser"];
            }
        }
        else if ([contentType isEqualToString:@"article"] || [post isArticle]) {
            // Handle article/external link
            NSString *articleUrl = [post articleUrl] ? [post articleUrl] : [post url];

            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText:@"External Link"];
            [alert setInformativeText:[NSString stringWithFormat:@"Open this link in your browser?\n\n%@", articleUrl]];
            [alert addButtonWithTitle:@"Open"];
            [alert addButtonWithTitle:@"Cancel"];

            int result = [alert runModal];
            [alert release];

            if (result == NSAlertFirstButtonReturn) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:articleUrl]];
                [statusText setString:@"Opening article in browser"];
            }
        }
        else if ([contentType isEqualToString:@"self"]) {
            // Handle text post - show the self text
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
            // Handle gallery
            [self downloadGalleryToDesktop:post];
        }
        else if ([post hasImage] && [post imageUrl]) {
            // Handle regular image
            NSString *imageUrl = [post imageUrl];
            [self downloadFullImageToDesktop:imageUrl forPost:post];
        }
        else {
            // Handle generic link
            NSString *url = [post url];
            if (url && [url length] > 0) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:@"External Link"];
                [alert setInformativeText:[NSString stringWithFormat:@"Open this link in your browser?\n\n%@", url]];
                [alert addButtonWithTitle:@"Open"];
                [alert addButtonWithTitle:@"Cancel"];

                int result = [alert runModal];
                [alert release];

                if (result == NSAlertFirstButtonReturn) {
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
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

- (void)downloadGalleryToDesktop:(RedditPost *)post {
    [statusText setString:@"Downloading gallery to Desktop..."];
    [progressIndicator startAnimation:nil];

    NSString *pythonPath = [self getPythonPath];
    NSString *scriptPath = [self getScriptPath];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];

    // For gallery support, we'll need to modify the RedditPost class to store gallery URLs
    // For now, just download the main image
    NSString *imageUrl = [post imageUrl];
    [task setArguments:[NSArray arrayWithObjects:scriptPath, @"download_full_image", imageUrl, [post title], nil]];

    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setCurrentDirectoryPath:NSHomeDirectory()];

    [task launch];
    [task waitUntilExit];

    NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    if ([task terminationStatus] == 0 && [result length] > 0) {
        [statusText setString:@"Gallery downloaded to Desktop"];
    } else {
        [statusText setString:@"Failed to download gallery"];
    }

    [progressIndicator stopAnimation:nil];
    [task release];
}

- (void)downloadVideoToDesktop:(NSString *)videoUrl forPost:(RedditPost *)post {
    NSString *ytDlpPath = [self getYtDlpPath];
    if (!ytDlpPath) {
        [statusText setString:@"yt-dlp not found in bundle"];
        NSLog(@"ERROR: yt-dlp not found");
        return;
    }

    // Check if yt-dlp is executable
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm isExecutableFileAtPath:ytDlpPath]) {
        NSLog(@"Making yt-dlp executable: %@", ytDlpPath);
        // Try to make it executable
        NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0755]
                                                          forKey:NSFilePosixPermissions];
        [fm changeFileAttributes:attrs atPath:ytDlpPath];
    }

    [statusText setString:@"Downloading video to Desktop..."];
    [progressIndicator startAnimation:nil];

    NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];

    // Create safe filename from post title
    NSString *safeTitle = [self sanitizeFilename:[post title]];
    NSString *outputTemplate = [NSString stringWithFormat:@"%@/%@.%%(ext)s", desktopPath, safeTitle];

    // Use shell to properly quote the URL and call yt-dlp directly
    NSString *quotedUrl = [NSString stringWithFormat:@"'%@'", videoUrl];
    NSString *quotedOutput = [NSString stringWithFormat:@"'%@'", outputTemplate];
    NSString *quotedYtDlp = [NSString stringWithFormat:@"'%@'", ytDlpPath];

    // Build the complete command as a shell command string with proper environment
    // Set PATH to include common locations where ffmpeg might be installed
    NSString *fullCommand = [NSString stringWithFormat:@"export PATH=\"/usr/local/bin:/opt/local/bin:/usr/bin:$PATH\" && cd '%@' && %@ --no-playlist --max-filesize 100M --output %@ --verbose %@",
                            desktopPath, quotedYtDlp, quotedOutput, quotedUrl];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments:[NSArray arrayWithObjects:@"-c", fullCommand, nil]];

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task setCurrentDirectoryPath:desktopPath];

    NSLog(@"Running shell command: %@", fullCommand);
    NSLog(@"Video URL (quoted): %@", quotedUrl);
    NSLog(@"yt-dlp path: %@", ytDlpPath);

    [task launch];

    // Wait with timeout and progress updates
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:120.0]; // 2 minute timeout
    while ([task isRunning] && [timeout timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        int elapsed = 120 - (int)[timeout timeIntervalSinceNow];
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

    NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSString *errors = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];

    NSLog(@"yt-dlp exit status: %d", [task terminationStatus]);
    NSLog(@"yt-dlp output: %@", output);
    if ([errors length] > 0) {
        NSLog(@"yt-dlp errors: %@", errors);
    }

    if ([task terminationStatus] == 0) {
        [statusText setString:@"Video downloaded to Desktop"];
        // Open Desktop folder
        [[NSWorkspace sharedWorkspace] openFile:desktopPath];
    } else {
        NSString *errorMsg = [NSString stringWithFormat:@"Video download failed (exit %d)", [task terminationStatus]];
        [statusText setString:errorMsg];
        NSLog(@"yt-dlp failed with exit code: %d", [task terminationStatus]);
        NSLog(@"Full command that failed: %@", fullCommand);
    }

    [progressIndicator stopAnimation:nil];
    [task release];
}

- (void)testTableDisplay:(id)sender {
    NSLog(@"=== MANUAL TABLE TEST ===");

    // Clear existing data
    [posts removeAllObjects];

    // Add fresh test data (Tiger-compatible C89 loop)
    int i;
    for (i = 0; i < 3; i++) {
        RedditPost *testPost = [[RedditPost alloc] init];
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

    // Force multiple refresh attempts
    [tableView reloadData];
    [tableView setNeedsDisplay:YES];
    [[tableView superview] setNeedsDisplay:YES];

    [statusText setString:[NSString stringWithFormat:@"Manual test: Added %d posts. Table should refresh now.", [posts count]]];

    NSLog(@"Manual table test completed");
}

- (float)tableView:(NSTableView *)aTableView heightOfRow:(int)row {
    return 70.0;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        RedditPost *post = [posts objectAtIndex:selectedRow];
        [statusText setString:[NSString stringWithFormat:@"Selected: %@", [post title]]];
    }
}

// Table data source methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
    int count = [posts count];
    NSLog(@"numberOfRowsInTableView called, returning %d", count);
    return count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    if (rowIndex >= [posts count]) {
        NSLog(@"WARNING: Row %d requested but only have %d posts", rowIndex, [posts count]);
        return @"";
    }

    RedditPost *post = [posts objectAtIndex:rowIndex];
    NSString *identifier = [aTableColumn identifier];

    if ([identifier isEqualToString:@"thumbnail"]) {
        return nil; // Image will be handled in willDisplayCell
    } else if ([identifier isEqualToString:@"title"]) {
        NSString *title = [post title];
        if (rowIndex < 3) { // Log first few for debugging
            NSLog(@"Row %d title: %@", rowIndex, title);
        }
        return title;
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

// Additional Tiger-specific delegate methods
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex {
    return YES;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    // Do nothing - read-only table
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
    return NO; // Read-only
}

- (void)postCountChanged:(id)sender {
    currentPostCount = [[[sender selectedItem] title] intValue];
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

- (void)fetchRedditDataWithAfter:(NSString *)after {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    [statusText setString:@"Loading next page..."];
    [progressIndicator startAnimation:nil];

    [self runPythonScriptWithSubreddit:subreddit sort:sort count:currentPostCount after:after before:nil];
}

- (void)fetchRedditDataWithBefore:(NSString *)before {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    [statusText setString:@"Loading previous page..."];
    [progressIndicator startAnimation:nil];

    [self runPythonScriptWithSubreddit:subreddit sort:sort count:currentPostCount after:nil before:before];
}

// JSON parsing
- (NSArray *)parseJSONString:(NSString *)jsonString {
    NSLog(@"=== JSON PARSING START ===");

    if (!jsonString || [jsonString length] == 0) {
        NSLog(@"ERROR: Empty JSON string received");
        return [NSArray array];
    }

    NSLog(@"JSON string length: %d characters", [jsonString length]);
    NSLog(@"JSON preview (first 300 chars): %.300@", jsonString);

    // Check if it looks like valid JSON
    if (![jsonString hasPrefix:@"{"] && ![jsonString hasPrefix:@"["]) {
        NSLog(@"ERROR: JSON doesn't start with { or [");
        NSLog(@"Full content: %@", jsonString);
        return [NSArray array];
    }

    cJSON *root = cJSON_Parse([jsonString UTF8String]);
    NSMutableArray *result = [NSMutableArray array];

    if (!root) {
        NSLog(@"ERROR: cJSON_Parse failed");
        const char *error = cJSON_GetErrorPtr();
        if (error) {
            NSLog(@"JSON Parse Error at: %.50s", error);
        }
        NSLog(@"Raw JSON that failed: %@", jsonString);
        return result;
    }

    NSLog(@"JSON parsed successfully by cJSON");

    cJSON *pagination = cJSON_GetObjectItem(root, "pagination");
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

    cJSON *success = cJSON_GetObjectItem(root, "success");
    if (!success) {
        NSLog(@"ERROR: No 'success' field in JSON");
        cJSON_Delete(root);
        return result;
    }

    if (!cJSON_IsBool(success)) {
        NSLog(@"ERROR: 'success' field is not boolean, type: %d", success->type);
        cJSON_Delete(root);
        return result;
    }

    if (!cJSON_IsTrue(success)) {
        NSLog(@"JSON indicates failure (success=false)");

        // Check for error message
        cJSON *error = cJSON_GetObjectItem(root, "error");
        if (error && cJSON_IsString(error)) {
            NSLog(@"Error from Python script: %s", error->valuestring);
        }

        cJSON_Delete(root);
        return result;
    }

    NSLog(@"JSON indicates success=true");

    cJSON *postsArray = cJSON_GetObjectItem(root, "posts");
    if (!postsArray) {
        NSLog(@"ERROR: No 'posts' field in JSON");
        cJSON_Delete(root);
        return result;
    }

    if (!cJSON_IsArray(postsArray)) {
        NSLog(@"ERROR: 'posts' field is not an array, type: %d", postsArray->type);
        cJSON_Delete(root);
        return result;
    }

    int count = cJSON_GetArraySize(postsArray);
    NSLog(@"Found %d posts in JSON array", count);

    if (count == 0) {
        NSLog(@"WARNING: Posts array is empty");
        cJSON_Delete(root);
        return result;
    }

    // Tiger-compatible C89 for loop
    int i;
    for (i = 0; i < count; i++) {
        cJSON *item = cJSON_GetArrayItem(postsArray, i);
        if (!item) {
            NSLog(@"WARNING: Post %d is null", i);
            continue;
        }

        NSLog(@"Parsing post %d/%d", i+1, count);

        RedditPost *post = [[RedditPost alloc] init];

        // Parse all existing fields
        cJSON *title = cJSON_GetObjectItem(item, "title");
        cJSON *author = cJSON_GetObjectItem(item, "author");
        cJSON *subreddit = cJSON_GetObjectItem(item, "subreddit");
        cJSON *score = cJSON_GetObjectItem(item, "score");
        cJSON *num_comments = cJSON_GetObjectItem(item, "num_comments");
        cJSON *url = cJSON_GetObjectItem(item, "url");
        cJSON *permalink = cJSON_GetObjectItem(item, "permalink");
        cJSON *thumbnail = cJSON_GetObjectItem(item, "thumbnail");
        cJSON *image_url = cJSON_GetObjectItem(item, "image_url");
        cJSON *image_type = cJSON_GetObjectItem(item, "image_type");
        cJSON *selftext = cJSON_GetObjectItem(item, "selftext");
        cJSON *has_image = cJSON_GetObjectItem(item, "has_image");

        // Parse new fields
        cJSON *content_type = cJSON_GetObjectItem(item, "content_type");
        cJSON *is_video = cJSON_GetObjectItem(item, "is_video");
        cJSON *video_url = cJSON_GetObjectItem(item, "video_url");
        cJSON *is_article = cJSON_GetObjectItem(item, "is_article");
        cJSON *article_url = cJSON_GetObjectItem(item, "article_url");
        cJSON *is_nsfw = cJSON_GetObjectItem(item, "is_nsfw");

        // Set existing fields with validation
        NSString *titleStr = (title && cJSON_IsString(title)) ? [NSString stringWithUTF8String:title->valuestring] : @"[No Title]";
        [post setTitle:titleStr];

        [post setAuthor:author && cJSON_IsString(author) ? [NSString stringWithUTF8String:author->valuestring] : @""];
        [post setSubreddit:subreddit && cJSON_IsString(subreddit) ? [NSString stringWithUTF8String:subreddit->valuestring] : @""];
        [post setScore:score && cJSON_IsNumber(score) ? score->valueint : 0];
        [post setNumComments:num_comments && cJSON_IsNumber(num_comments) ? num_comments->valueint : 0];
        [post setUrl:url && cJSON_IsString(url) ? [NSString stringWithUTF8String:url->valuestring] : @""];
        [post setPermalink:permalink && cJSON_IsString(permalink) ? [NSString stringWithUTF8String:permalink->valuestring] : @""];
        [post setSelfText:selftext && cJSON_IsString(selftext) ? [NSString stringWithUTF8String:selftext->valuestring] : @""];

        BOOL hasImg = has_image && cJSON_IsBool(has_image) && cJSON_IsTrue(has_image);
        [post setHasImage:hasImg];

        if (thumbnail && cJSON_IsString(thumbnail) && strlen(thumbnail->valuestring) > 0) {
            [post setThumbnailUrl:[NSString stringWithUTF8String:thumbnail->valuestring]];
        }
        if (image_url && cJSON_IsString(image_url) && strlen(image_url->valuestring) > 0) {
            [post setImageUrl:[NSString stringWithUTF8String:image_url->valuestring]];
        }
        [post setImageType:image_type && cJSON_IsString(image_type) ? [NSString stringWithUTF8String:image_type->valuestring] : @""];

        // Set new fields
        [post setContentType:content_type && cJSON_IsString(content_type) ? [NSString stringWithUTF8String:content_type->valuestring] : @"link"];

        BOOL isVid = is_video && cJSON_IsBool(is_video) && cJSON_IsTrue(is_video);
        [post setIsVideo:isVid];

        if (video_url && cJSON_IsString(video_url) && strlen(video_url->valuestring) > 0) {
            [post setVideoUrl:[NSString stringWithUTF8String:video_url->valuestring]];
        }

        BOOL isArt = is_article && cJSON_IsBool(is_article) && cJSON_IsTrue(is_article);
        [post setIsArticle:isArt];

        if (article_url && cJSON_IsString(article_url) && strlen(article_url->valuestring) > 0) {
            [post setArticleUrl:[NSString stringWithUTF8String:article_url->valuestring]];
        }

        BOOL nsfw = is_nsfw && cJSON_IsBool(is_nsfw) && cJSON_IsTrue(is_nsfw);
        [post setIsNSFW:nsfw];

        NSLog(@"Post %d: '%@' by %@ (type: %@, score: %d, hasImage: %d, isVideo: %d, isNSFW: %d)",
              i+1, [titleStr length] > 50 ? [[titleStr substringToIndex:50] stringByAppendingString:@"..."] : titleStr,
              [post author], [post contentType], [post score], [post hasImage], [post isVideo], [post isNSFW]);

        [result addObject:post];
        [post release];
    }

    cJSON_Delete(root);
    NSLog(@"Successfully parsed %d posts", [result count]);
    NSLog(@"=== JSON PARSING END ===");
    return result;
}

- (void)updateWithJSON:(NSString *)jsonString {
    NSLog(@"=== UPDATE WITH JSON START ===");
    NSLog(@"JSON length: %d", [jsonString length]);

    if (!jsonString || [jsonString length] < 10) {
        NSLog(@"ERROR: Invalid JSON string");
        [statusText setString:@"Error: Invalid response"];
        return;
    }

    // Clear existing posts to free memory
    [posts removeAllObjects];
    [tableView reloadData];

    // Force memory cleanup
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    NSArray *parsedPosts = [self parseJSONString:jsonString];
    NSLog(@"Parsed %d posts", [parsedPosts count]);

    if ([parsedPosts count] == 0) {
        NSLog(@"WARNING: No posts parsed");
        [statusText setString:@"No posts found"];
        return;
    }

    // Add posts gradually to prevent memory spikes
    [posts addObjectsFromArray:parsedPosts];

    // Reload table
    [tableView reloadData];
    [tableView setNeedsDisplay:YES];

    NSString *statusMsg = [NSString stringWithFormat:@"Loaded %d posts from r/%@",
        [posts count], [subredditField stringValue]];
    [statusText setString:statusMsg];

    NSLog(@"=== UPDATE WITH JSON END ===");
}

// Navigation and refresh
- (void)refreshPosts:(id)sender {
    [statusText setString:@"Fetching Reddit posts..."];
    [progressIndicator startAnimation:nil];
    [self fetchRedditData];
}

- (void)viewComments:(id)sender {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        RedditPost *post = [posts objectAtIndex:selectedRow];
        NSLog(@"Opening comments for post: %@", [post title]);
        [self fetchCommentsForPost:post];
    } else {
        [statusText setString:@"Please select a post to view comments"];
    }
}

- (void)runPythonScriptWithSubreddit:(NSString *)subreddit sort:(NSString *)sort count:(int)count after:(NSString *)after before:(NSString *)before {
    NSString *pythonPath = [self getPythonPath];
    NSString *scriptPath = [self getScriptPath];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];

    NSMutableArray *args = [NSMutableArray arrayWithObjects:scriptPath, subreddit, [sort lowercaseString], nil];
    [args addObject:[NSString stringWithFormat:@"%d", count]];

    if (after && [after length] > 0) {
        [args addObject:after];
        [args addObject:@"None"];
    } else if (before && [before length] > 0) {
        [args addObject:@"None"];
        [args addObject:before];
    } else {
        [args addObject:@"None"];
        [args addObject:@"None"];
    }

    [task setArguments:args];

    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setCurrentDirectoryPath:NSHomeDirectory()];

    [task launch];
    [task waitUntilExit];

    NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    if ([task terminationStatus] == 0 && [jsonString length] > 0) {
        [self updateWithJSON:jsonString];
    } else {
        [statusText setString:@"Failed to fetch data"];
    }

    [progressIndicator stopAnimation:nil];
    [task release];
}

- (void)fetchCommentsForPost:(RedditPost *)post {
    [statusText setString:@"Fetching comments..."];
    [progressIndicator startAnimation:nil];

    NSLog(@"Fetching comments for permalink: %@", [post permalink]);

    // Store the post for the async callback
    RedditPost *postCopy = [post retain]; // Retain for async operation

    // Create a timer to run the fetch asynchronously with a small delay
    NSDictionary *taskInfo = [NSDictionary dictionaryWithObjectsAndKeys:
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
    RedditPost *post = [taskInfo objectForKey:@"post"];

    NSString *pythonPath = [self getPythonPath];
    NSString *scriptPath = [self getScriptPath];

    // Clean up the permalink - make sure it's just the path part
    NSString *permalink = [post permalink];
    if ([permalink hasPrefix:@"https://reddit.com"]) {
        permalink = [permalink substringFromIndex:18]; // Remove "https://reddit.com"
    } else if ([permalink hasPrefix:@"http://reddit.com"]) {
        permalink = [permalink substringFromIndex:17]; // Remove "http://reddit.com"
    }
    // Ensure it starts with /
    if (![permalink hasPrefix:@"/"]) {
        permalink = [@"/" stringByAppendingString:permalink];
    }

    NSLog(@"Cleaned permalink: %@", permalink);

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];
    [task setArguments:[NSArray arrayWithObjects:scriptPath, @"fetch_comments", permalink, nil]];

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];
    [task setCurrentDirectoryPath:NSHomeDirectory()];

    NSLog(@"Launching comments task: %@ %@ fetch_comments %@", pythonPath, scriptPath, permalink);

    NS_DURING
    {
        [task launch];
        NSLog(@"Comments task launched, PID: %d", [task processIdentifier]);

        // Wait with shorter timeout and better progress updates
        int timeoutCounter = 0;
        int maxTimeout = 40; // 20 seconds total

        while ([task isRunning] && timeoutCounter < maxTimeout) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            timeoutCounter++;

            if (timeoutCounter % 2 == 0) { // Update every second
                int seconds = timeoutCounter / 2;
                [statusText setString:[NSString stringWithFormat:@"Fetching comments... (%d sec)", seconds]];
            }
        }

        if ([task isRunning]) {
            NSLog(@"Comments fetch timeout after %d seconds - terminating", maxTimeout/2);
            [task terminate];
            [statusText setString:@"Comments fetch timed out"];
            [progressIndicator stopAnimation:nil];
            [post release];
            [task release];
            return;
        }

        NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
        NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
        NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        NSString *errorString = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];

        NSLog(@"Comments task completed with exit status: %d", [task terminationStatus]);
        NSLog(@"Comments JSON length: %d", [jsonString length]);
        if ([errorString length] > 0) {
            NSLog(@"Comments stderr: %@", errorString);
        }

        if ([task terminationStatus] == 0 && [jsonString length] > 10) {
            // Clean up any extra whitespace/newlines
            jsonString = [jsonString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSLog(@"Comments JSON preview: %.200@", jsonString);

            // Check if it looks like valid JSON
            if ([jsonString hasPrefix:@"["] || [jsonString hasPrefix:@"{"]) {
                [self showCommentsWindow:jsonString forPost:post];
            } else {
                NSLog(@"Comments response doesn't look like JSON: %@", jsonString);
                [statusText setString:@"Invalid comments response format"];
            }
        } else {
            [statusText setString:@"Failed to fetch comments - check Console for details"];
            NSLog(@"Comments fetch failed - JSON output: %@", jsonString);
            NSLog(@"Comments fetch failed - Error output: %@", errorString);
        }
    }
    NS_HANDLER
    {
        NSLog(@"Exception fetching comments: %@", [localException reason]);
        [statusText setString:@"Error fetching comments"];
    }
    NS_ENDHANDLER

    [progressIndicator stopAnimation:nil];
    [post release];
    [task release];
}

- (void)showCommentsWindow:(NSString *)jsonString forPost:(RedditPost *)post {
    NSLog(@"Creating comments window...");

    @try {
        // Create a simple window instead of using CommentViewController for now
        NSRect windowFrame = NSMakeRect(100, 100, 600, 400);
        NSWindow *commentWindow = [[NSWindow alloc] initWithContentRect:windowFrame
                                                              styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                                backing:NSBackingStoreBuffered
                                                                  defer:NO];
        [commentWindow setTitle:[NSString stringWithFormat:@"Comments: %@", [post title]]];

        // Create text view
        NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:[[commentWindow contentView] bounds]];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        NSTextView *textView = [[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
        [textView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [textView setEditable:NO];

        [scrollView setDocumentView:textView];
        [[commentWindow contentView] addSubview:scrollView];

        // Parse and display comments
        [self parseCommentsJSON:jsonString intoTextView:textView forPost:post];

        [commentWindow makeKeyAndOrderFront:nil];

        [textView release];
        [scrollView release];
        // Don't release commentWindow - it will release itself when closed

        NSLog(@"Comments window created successfully");
    }
    @catch (NSException *exception) {
        NSLog(@"Exception creating comments window: %@", [exception reason]);
        [statusText setString:@"Error opening comments window"];
    }
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

- (void)runPythonScriptSync:(NSString *)subreddit sort:(NSString *)sort {
    NSLog(@"=== SYNC PYTHON SCRIPT START ===");

    NSTask *task = [[NSTask alloc] init];

    // Get Python and script paths
    NSString *pythonPath = [self getPythonPath];
    NSString *scriptPath = [self getScriptPath];

    NSLog(@"Using Python: %@", pythonPath);
    NSLog(@"Using Script: %@", scriptPath);

    // Verify files exist
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:pythonPath]) {
        NSLog(@"ERROR: Python executable not found at: %@", pythonPath);
        [statusText setString:@"ERROR: Python not found"];
        [progressIndicator stopAnimation:nil];
        [task release];
        return;
    }

    if (![fm fileExistsAtPath:scriptPath]) {
        NSLog(@"ERROR: Script not found at: %@", scriptPath);
        [statusText setString:@"ERROR: Script not found"];
        [progressIndicator stopAnimation:nil];
        [task release];
        return;
    }

    [task setLaunchPath:pythonPath];
    [task setArguments:[NSArray arrayWithObjects:scriptPath, subreddit, [sort lowercaseString], @"15", nil]]; // Reduced to 15 posts

    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardError:errPipe];

    // Set working directory
    [task setCurrentDirectoryPath:NSHomeDirectory()];

    NSLog(@"Launching Python script...");
    [statusText setString:@"Running Python script..."];

    NS_DURING
    {
        [task launch];
        NSLog(@"Task launched, waiting for completion...");

        // Wait for completion with a reasonable timeout
        NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:30.0]; // 30 seconds
        while ([task isRunning] && [timeout timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            // Update UI to show we're still working
            [statusText setString:[NSString stringWithFormat:@"Fetching r/%@... (%.0f sec)",
                                  subreddit, 30.0 + [timeout timeIntervalSinceNow]]];
        }

        if ([task isRunning]) {
            NSLog(@"TIMEOUT: Terminating task");
            [task terminate];
            [statusText setString:@"Timeout - try again"];
            [progressIndicator stopAnimation:nil];
            [task release];
            return;
        }

        // Read output
        NSFileHandle *outHandle = [outPipe fileHandleForReading];
        NSData *data = [outHandle readDataToEndOfFile];
        NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

        // Read errors
        NSFileHandle *errHandle = [errPipe fileHandleForReading];
        NSData *errData = [errHandle readDataToEndOfFile];
        if ([errData length] > 0) {
            NSString *errorString = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];
            NSLog(@"Python stderr: %@", errorString);
        }

        int exitStatus = [task terminationStatus];
        NSLog(@"Task completed with exit status: %d", exitStatus);
        NSLog(@"JSON output length: %d", [jsonString length]);

        if (exitStatus == 0 && [jsonString length] > 10) {
            NSLog(@"Processing JSON response...");
            [self updateWithJSON:jsonString];
        } else {
            NSLog(@"ERROR: No valid JSON received");
            [statusText setString:@"No data received - check network"];
        }
    }
    NS_HANDLER
    {
        NSLog(@"EXCEPTION: %@", [localException reason]);
        [statusText setString:@"Script execution failed"];
    }
    NS_ENDHANDLER

    [progressIndicator stopAnimation:nil];
    [task release];
    NSLog(@"=== SYNC PYTHON SCRIPT END ===");
}

- (void)parseCommentsJSON:(NSString *)jsonString intoTextView:(NSTextView *)textView forPost:(RedditPost *)post {
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

        // Reddit API returns an array with post data at [0] and comments at [1]
        if (cJSON_IsArray(root) && cJSON_GetArraySize(root) >= 2) {
            cJSON *commentsSection = cJSON_GetArrayItem(root, 1);
            if (commentsSection) {
                cJSON *data = cJSON_GetObjectItem(commentsSection, "data");
                if (data) {
                    cJSON *children = cJSON_GetObjectItem(data, "children");
                    if (children && cJSON_IsArray(children)) {
                        int commentCount = cJSON_GetArraySize(children);
                        int validComments = 0;
                        int i; // Tiger-compatible C89 for loop declaration

                        for (i = 0; i < commentCount && validComments < 15; i++) {
                            cJSON *commentItem = cJSON_GetArrayItem(children, i);
                            if (commentItem) {
                                cJSON *commentData = cJSON_GetObjectItem(commentItem, "data");
                                if (commentData) {
                                    cJSON *author = cJSON_GetObjectItem(commentData, "author");
                                    cJSON *body = cJSON_GetObjectItem(commentData, "body");
                                    cJSON *score = cJSON_GetObjectItem(commentData, "score");

                                    if (author && body && cJSON_IsString(author) && cJSON_IsString(body)) {
                                        NSString *authorStr = [NSString stringWithUTF8String:author->valuestring];
                                        NSString *bodyStr = [NSString stringWithUTF8String:body->valuestring];
                                        int scoreVal = (score && cJSON_IsNumber(score)) ? score->valueint : 0;

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

// Replace the fetchRedditData method with this simplified version for debugging:
- (void)fetchRedditData {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    NSLog(@"=== FETCH REQUEST START ===");
    NSLog(@"Subreddit: %@, Sort: %@", subreddit, sort);

    [statusText setString:@"Starting Python script..."];
    [progressIndicator startAnimation:nil];

    // Clear existing data
    [posts removeAllObjects];
    [tableView reloadData];

    // Run Python script synchronously for debugging (Tiger-compatible)
    [self runPythonScriptSync:subreddit sort:sort];
}

- (void)downloadFullImageToDesktop:(NSString *)imageUrl forPost:(RedditPost *)post {
    [statusText setString:@"Downloading full image to Desktop..."];
    [progressIndicator startAnimation:nil];

    NSString *pythonPath = [self getPythonPath];
    NSString *scriptPath = [self getScriptPath];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:pythonPath];

    // Use special mode for single image download to desktop
    [task setArguments:[NSArray arrayWithObjects:scriptPath, @"download_full_image", imageUrl, nil]];

    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setCurrentDirectoryPath:NSHomeDirectory()];

    [task launch];
    [task waitUntilExit];

    NSData *data = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

    if ([task terminationStatus] == 0 && [result length] > 0) {
        [statusText setString:@"Image downloaded to Desktop"];
        // Optionally open the downloaded file
        NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
        [[NSWorkspace sharedWorkspace] openFile:desktopPath];
    } else {
        [statusText setString:@"Failed to download image"];
    }

    [progressIndicator stopAnimation:nil];
    [task release];
}

- (void)runPythonScript:(NSTimer *)timer {
    NSDictionary *taskInfo = [timer userInfo];
    NSString *subreddit = [taskInfo objectForKey:@"subreddit"];
    NSString *sort = [taskInfo objectForKey:@"sort"];
    int attempts = [[taskInfo objectForKey:@"attempts"] intValue];

    NSLog(@"=== PYTHON SCRIPT EXECUTION START ===");
    NSLog(@"Running Python script attempt %d for r/%@ (%@)", attempts + 1, subreddit, sort);

    NSTask *task = [[NSTask alloc] init];

    // Get Python and script paths
    NSString *pythonPath = [self getPythonPath];
    BOOL useSimple = [[taskInfo objectForKey:@"use_simple"] boolValue];
    NSString *scriptPath = [self getScriptPathWithSimple:useSimple];

    NSLog(@"Using Python: %@", pythonPath);
    NSLog(@"Using Script: %@ (simple mode: %d)", scriptPath, useSimple);

    // Verify files exist
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:pythonPath]) {
        NSLog(@"ERROR: Python executable not found at: %@", pythonPath);
        [statusText setString:@"ERROR: Python not found. Check installation."];
        [progressIndicator stopAnimation:nil];
        [task release];
        return;
    }

    if (![fm fileExistsAtPath:scriptPath]) {
        NSLog(@"ERROR: Script not found at: %@", scriptPath);
        [statusText setString:@"ERROR: Python script not found in app bundle."];
        [progressIndicator stopAnimation:nil];
        [task release];
        return;
    }

    NSLog(@"Files verified - setting up task");

    [task setLaunchPath:pythonPath];
    [task setArguments:[NSArray arrayWithObjects:scriptPath, subreddit, sort, @"10", nil]]; // Reduced to 10 for faster testing

    NSPipe *outPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardError:errPipe];

    // Set working directory to user's home directory for cache access
    NSString *homeDir = NSHomeDirectory();
    [task setCurrentDirectoryPath:homeDir];
    NSLog(@"Set working directory to: %@", homeDir);

    // Show command being executed
    NSString *command = [NSString stringWithFormat:@"%@ %@ %@ %@ 10", pythonPath, scriptPath, subreddit, sort];
    NSLog(@"Executing command: %@", command);
    [statusText setString:[NSString stringWithFormat:@"Starting: python3 r/%@...", subreddit]];

    // Tiger-compatible try block (no @try on Tiger GCC 4.0)
    NS_DURING
    {
        NSLog(@"Launching task...");
        [task launch];
        NSLog(@"Task launched successfully, PID: %d", [task processIdentifier]);

        // Wait for completion with timeout and progress updates
        int timeoutCounter = 0;
        int maxTimeout = 60; // 30 seconds total

        while ([task isRunning] && timeoutCounter < maxTimeout) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            timeoutCounter++;

            // Update status every 2 seconds
            if (timeoutCounter % 4 == 0) {
                int seconds = timeoutCounter / 2;
                [statusText setString:[NSString stringWithFormat:@"Fetching r/%@ (%d seconds)...", subreddit, seconds]];
                NSLog(@"Task still running after %d seconds", seconds);
            }
        }

        if ([task isRunning]) {
            NSLog(@"TIMEOUT: Task still running after %d seconds - terminating", maxTimeout/2);
            [task terminate];

            // Try fallback to simple script if this was the first attempt
            if (attempts == 0) {
                NSLog(@"Attempting fallback to simple script (no images)...");
                [statusText setString:@"Timeout - trying text-only mode..."];

                NSMutableDictionary *fallbackInfo = [NSMutableDictionary dictionaryWithDictionary:taskInfo];
                [fallbackInfo setObject:[NSNumber numberWithInt:1] forKey:@"attempts"];
                [fallbackInfo setObject:[NSNumber numberWithBool:YES] forKey:@"use_simple"];

                [NSTimer scheduledTimerWithTimeInterval:1.0
                                               target:self
                                             selector:@selector(runPythonScript:)
                                             userInfo:fallbackInfo
                                              repeats:NO];
                [task release];
                return;
            } else {
                [statusText setString:@"Request timed out. Try a smaller subreddit or check network."];
                [progressIndicator stopAnimation:nil];
                [task release];
                return;
            }
        }

        NSLog(@"Task completed, reading output...");

        // Task completed, read output
        NSFileHandle *outHandle = [outPipe fileHandleForReading];
        NSData *data = [outHandle readDataToEndOfFile];
        NSString *jsonString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

        // Read errors
        NSFileHandle *errHandle = [errPipe fileHandleForReading];
        NSData *errData = [errHandle readDataToEndOfFile];
        NSString *errorString = @"";
        if ([errData length] > 0) {
            errorString = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];
            NSLog(@"Python script stderr (%d bytes): %@", [errData length], errorString);
        }

        int exitStatus = [task terminationStatus];
        NSLog(@"Task exit status: %d", exitStatus);
        NSLog(@"JSON output length: %d", [jsonString length]);

        if ([jsonString length] > 0) {
            NSLog(@"JSON preview (first 200 chars): %.200@", jsonString);
        } else {
            NSLog(@"WARNING: No JSON output received");
        }

        if (exitStatus != 0) {
            NSLog(@"ERROR: Python script failed with exit code %d", exitStatus);
            [statusText setString:[NSString stringWithFormat:@"Python script error (code %d). Check Console.app.", exitStatus]];
            [progressIndicator stopAnimation:nil];
            [task release];
            return;
        }

        if ([jsonString length] > 10) {
            NSLog(@"Got JSON output, parsing...");
            [statusText setString:@"Processing data..."];

            // Add a small delay to show the status
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

            [self updateWithJSON:jsonString];
            NSLog(@"JSON processing completed");
        } else {
            NSLog(@"WARNING: JSON output too short or empty");

            // Retry logic
            if (attempts < 1) {
                NSLog(@"No output, retrying... [Output was: '%@'] [Error was: '%@']", jsonString, errorString);
                NSMutableDictionary *retryInfo = [NSMutableDictionary dictionaryWithDictionary:taskInfo];
                [retryInfo setObject:[NSNumber numberWithInt:attempts + 1] forKey:@"attempts"];

                [statusText setString:[NSString stringWithFormat:@"No data received, retrying... (attempt %d)", attempts + 2]];

                [NSTimer scheduledTimerWithTimeInterval:2.0
                                               target:self
                                             selector:@selector(runPythonScript:)
                                             userInfo:retryInfo
                                              repeats:NO];
                [task release];
                return;
            } else {
                [statusText setString:@"Failed: No data after retries. Check network connection."];
                NSLog(@"FAILED: No data after %d attempts", attempts + 1);
            }
        }
    }
    NS_HANDLER
    {
        NSLog(@"EXCEPTION running task: %@", [localException reason]);
        NSLog(@"Exception info: %@", [localException userInfo]);
        [statusText setString:[NSString stringWithFormat:@"Error: %@", [localException reason]]];
    }
    NS_ENDHANDLER

    [progressIndicator stopAnimation:nil];
    [task release];
    NSLog(@"=== PYTHON SCRIPT EXECUTION END ===");
}

@end

// Main entry point
int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *app = [NSApplication sharedApplication];
    RedditController *controller = [[RedditController alloc] init];
    [controller createUI];
    [app run];
    [controller release];
    [pool release];
    return 0;
}
