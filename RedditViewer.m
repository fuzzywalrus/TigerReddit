// Tiger-Compatible RedditViewer.m
// Compatible with Mac OS X 10.4 Tiger and GCC 4.0
// No blocks, no modern Objective-C features
// Uses native C reddit_fetcher instead of Python/NSTask

#import <Cocoa/Cocoa.h>
#include "cJSON.h"
#include "reddit_fetcher.h"

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

    /* Create bitmap representation */
    NSBitmapImageRep *bitmapRep = nil;
    NSEnumerator *repEnum = [[image representations] objectEnumerator];
    NSImageRep *rep;

    while ((rep = [repEnum nextObject])) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapRep = (NSBitmapImageRep *)rep;
            break;
        }
    }

    /* If no bitmap rep found, create one */
    if (!bitmapRep) {
        [image lockFocus];
        bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:
                      NSMakeRect(0, 0, [image size].width, [image size].height)] autorelease];
        [image unlockFocus];
    }

    /* Save as JPEG with Tiger-compatible method */
    NSDictionary *properties = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.8]
                                                           forKey:NSImageCompressionFactor];
    NSData *imageData = [bitmapRep representationUsingType:NSJPEGFileType properties:properties];

    return [imageData writeToFile:path atomically:YES];
}

@end

/* Custom NSImageView with right-click "Save Image" context menu */
@interface SaveableImageView : NSImageView {
    NSString *imagePath;
}
- (void)setImagePath:(NSString *)path;
@end

@implementation SaveableImageView

- (void)setImagePath:(NSString *)path {
    [path retain];
    [imagePath release];
    imagePath = path;
}

- (void)dealloc {
    [imagePath release];
    [super dealloc];
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"Image"] autorelease];
    NSMenuItem *saveItem = [[[NSMenuItem alloc] initWithTitle:@"Save Image to Desktop"
                                                      action:@selector(saveImageToDesktop:)
                                               keyEquivalent:@""] autorelease];
    [saveItem setTarget:self];
    [menu addItem:saveItem];
    return menu;
}

- (void)saveImageToDesktop:(id)sender {
    NSImage *img = [self image];
    NSString *desktopPath;
    NSString *filename;
    NSString *filepath;
    NSData *imageData;
    NSBitmapImageRep *bitmapRep;
    NSDictionary *properties;

    if (!img) return;

    desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];

    /* If we have the original file path, just copy it */
    if (imagePath && [[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        filename = [imagePath lastPathComponent];
        filepath = [desktopPath stringByAppendingPathComponent:filename];
        /* Avoid overwriting */
        {
            int counter = 1;
            while ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
                NSString *base = [filename stringByDeletingPathExtension];
                NSString *ext = [filename pathExtension];
                filepath = [desktopPath stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"%@_%d.%@", base, counter, ext]];
                counter++;
            }
        }
        if ([[NSFileManager defaultManager] copyPath:imagePath toPath:filepath handler:nil]) {
            NSLog(@"Image saved to %@", filepath);
        }
        return;
    }

    /* Fallback: save from NSImage data */
    [img lockFocus];
    bitmapRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:
                  NSMakeRect(0, 0, [img size].width, [img size].height)] autorelease];
    [img unlockFocus];

    properties = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.9]
                                             forKey:NSImageCompressionFactor];
    imageData = [bitmapRep representationUsingType:NSJPEGFileType properties:properties];
    filepath = [desktopPath stringByAppendingPathComponent:@"reddit_image.jpg"];
    {
        int counter = 1;
        while ([[NSFileManager defaultManager] fileExistsAtPath:filepath]) {
            filepath = [desktopPath stringByAppendingPathComponent:
                [NSString stringWithFormat:@"reddit_image_%d.jpg", counter]];
            counter++;
        }
    }
    [imageData writeToFile:filepath atomically:YES];
    NSLog(@"Image saved to %@", filepath);
}

@end

/* RDPost model (renamed from RedditPost to avoid collision with C struct in reddit_fetcher.h) */
@interface RDPost : NSObject {
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
    NSString *contentType;
    NSString *selfText;
    BOOL isVideo;
    NSString *videoUrl;
    NSString *hlsUrl;
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
- (NSString *)hlsUrl;
- (void)setHlsUrl:(NSString *)hUrl;
- (BOOL)isArticle;
- (void)setIsArticle:(BOOL)article;
- (NSString *)articleUrl;
- (void)setArticleUrl:(NSString *)aUrl;
- (BOOL)isNSFW;
- (void)setIsNSFW:(BOOL)nsfw;
@end

@implementation RDPost

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

- (NSString *)hlsUrl { return hlsUrl; }
- (void)setHlsUrl:(NSString *)hUrl {
    [hUrl retain];
    [hlsUrl release];
    hlsUrl = hUrl;
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
    [hlsUrl release];
    [articleUrl release];
    [super dealloc];
}

@end

/* Comment View Controller */
@interface CommentViewController : NSWindowController {
    NSWindow *commentWindow;
    NSTextView *commentTextView;
    RDPost *currentPost;
}

- (id)initWithPost:(RDPost *)post;
- (void)showComments;
- (void)fetchComments;
- (void)parseAndDisplayComments:(NSString *)jsonString;
- (void)showCommentsWithJSON:(NSString *)jsonString;

@end

@implementation CommentViewController

- (id)initWithPost:(RDPost *)post {
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
    NSView *contentView;
    NSRect scrollFrame;
    NSScrollView *scrollView;
    NSString *windowTitle;

    commentWindow = [[NSWindow alloc] initWithContentRect:frame
                                               styleMask:(NSTitledWindowMask |
                                                         NSClosableWindowMask |
                                                         NSMiniaturizableWindowMask |
                                                         NSResizableWindowMask)
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];

    windowTitle = [NSString stringWithFormat:@"Comments: %.60@", [currentPost title]];
    [commentWindow setTitle:windowTitle];

    contentView = [commentWindow contentView];
    scrollFrame = NSMakeRect(10, 10, frame.size.width - 20, frame.size.height - 20);

    scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
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
    /* Use native C API instead of curl/NSTask */
    NSString *permalink = [currentPost permalink];
    CommentsResult result;

    if (!permalink || [permalink length] == 0) {
        [commentTextView setString:@"No permalink available for this post."];
        return;
    }

    result = reddit_fetch_comments([permalink UTF8String]);

    if (result.success && result.json) {
        NSString *jsonString = [NSString stringWithUTF8String:result.json];
        [self parseAndDisplayComments:jsonString];
    } else {
        NSString *errMsg = result.error ?
            [NSString stringWithUTF8String:result.error] : @"Failed to load comments.";
        [commentTextView setString:errMsg];
    }

    comments_result_free(&result);
}

- (void)parseAndDisplayComments:(NSString *)jsonString {
    int i;
    int commentCount;
    int validComments;
    NSMutableString *commentsText;

    if (!jsonString || [jsonString length] == 0) {
        [commentTextView setString:@"Failed to load comments."];
        return;
    }

    commentsText = [NSMutableString string];
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

        /* Check if we have the expected structure */
        if (!cJSON_IsArray(root) || cJSON_GetArraySize(root) < 2) {
            [commentsText appendString:@"Unexpected comments format."];
            cJSON_Delete(root);
            [commentTextView setString:commentsText];
            return;
        }

        {
            cJSON *commentsData = cJSON_GetArrayItem(root, 1);
            if (commentsData) {
                cJSON *data = cJSON_GetObjectItem(commentsData, "data");
                if (data) {
                    cJSON *children = cJSON_GetObjectItem(data, "children");
                    if (children && cJSON_IsArray(children)) {
                        commentCount = cJSON_GetArraySize(children);
                        validComments = 0;

                        for (i = 0; i < commentCount && validComments < 15; i++) {
                            cJSON *comment = cJSON_GetArrayItem(children, i);
                            if (comment) {
                                cJSON *commentData = cJSON_GetObjectItem(comment, "data");
                                if (commentData) {
                                    cJSON *cAuthor = cJSON_GetObjectItem(commentData, "author");
                                    cJSON *body = cJSON_GetObjectItem(commentData, "body");
                                    cJSON *cScore = cJSON_GetObjectItem(commentData, "score");

                                    if (cAuthor && body && cJSON_IsString(cAuthor) && cJSON_IsString(body) &&
                                        cAuthor->valuestring && body->valuestring) {

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

/* Forward declarations for RedditController */
@interface RedditController : NSObject {
    NSWindow *window;
    NSTableView *tableView;
    NSTextField *subredditField;
    NSPopUpButton *sortButton;
    NSButton *refreshButton;
    NSButton *allButton;
    NSButton *popularButton;
    NSProgressIndicator *progressIndicator;
    NSTextView *statusText;
    NSMutableArray *posts;
    NSString *currentSubreddit;
    NSString *currentAfter;
    NSString *currentBefore;
    NSPopUpButton *postCountButton;
    int currentPostCount;

    int maxComments;

    /* Image cache */
    NSImage *placeholderImage;
    NSImage *loadingImage;
}

/* Method declarations */
- (void)createUI;
- (void)refreshPosts:(id)sender;
- (void)browseAll:(id)sender;
- (void)browsePopular:(id)sender;
- (void)showPreferences:(id)sender;
- (void)showAbout:(id)sender;
- (void)loadPreferences;
- (void)savePreferences;
- (void)savePreferencesFromWindow:(id)sender;
- (void)fetchRedditData;
- (NSArray *)parseJSONString:(NSString *)jsonString;
- (void)updateWithJSON:(NSString *)jsonString;
- (void)updateWithResult:(RedditResult)result;
- (void)fetchPostsWithSubreddit:(NSString *)subreddit sort:(NSString *)sort count:(int)count after:(NSString *)after before:(NSString *)before;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (float)tableView:(NSTableView *)aTableView heightOfRow:(int)row;
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (NSImage *)createPlaceholderImage;
- (NSImage *)createLoadingImage;
- (void)addTestData;
- (void)testTableDisplay:(id)sender;
- (void)downloadFullImageToDesktop:(NSString *)imageUrl forPost:(RDPost *)post;
- (void)fetchRedditDataWithAfter:(NSString *)after;
- (void)fetchRedditDataWithBefore:(NSString *)before;
- (void)fetchCommentsForPost:(RDPost *)post;
- (void)showCommentsWindow:(NSString *)jsonString forPost:(RDPost *)post;
- (void)postCountChanged:(id)sender;
- (void)nextPage:(id)sender;
- (void)previousPage:(id)sender;
- (void)downloadVideoToDesktop:(NSString *)videoUrl forPost:(RDPost *)post;
- (void)downloadGalleryToDesktop:(RDPost *)post;
- (NSString *)getYtDlpPath;
- (NSString *)sanitizeFilename:(NSString *)filename;
- (void)parseCommentsJSON:(NSString *)jsonString intoTextView:(NSTextView *)textView forPost:(RDPost *)post;
- (void)fetchCommentsAsync:(NSTimer *)timer;
- (void)openPostDetail:(id)sender;
- (void)showPostDetailWindow:(RDPost *)post withCommentsJSON:(NSString *)jsonString;
- (void)playVideoFromButton:(id)sender;
- (void)openLinkFromButton:(id)sender;
- (void)renderComment:(cJSON *)comment depth:(int)depth yOffset:(float *)yOffset
              docView:(NSView *)docView contentWidth:(float)contentWidth
              permalink:(NSString *)permalink shown:(int *)shown;

@end

/* Main application controller implementation */
@implementation RedditController

- (id)init {
    self = [super init];
    if (self) {
        posts = [[NSMutableArray alloc] init];
        currentSubreddit = [@"all" retain];
        currentPostCount = 25;
        maxComments = 50;
        [self loadPreferences];

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
        NSRect progressFrame = NSMakeRect(1130, 17, 20, 20);
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

- (float)tableView:(NSTableView *)aTableView heightOfRow:(int)row {
    return 70.0;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    int selectedRow = [tableView selectedRow];
    if (selectedRow >= 0 && selectedRow < [posts count]) {
        RDPost *post = [posts objectAtIndex:selectedRow];
        [statusText setString:[NSString stringWithFormat:@"Selected: %@", [post title]]];
    }
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

    [self fetchPostsWithSubreddit:subreddit sort:sort count:currentPostCount after:after before:nil];
}

- (void)fetchRedditDataWithBefore:(NSString *)before {
    NSString *subreddit = [subredditField stringValue];
    NSString *sort = [[sortButton selectedItem] title];

    [statusText setString:@"Loading previous page..."];
    [progressIndicator startAnimation:nil];

    [self fetchPostsWithSubreddit:subreddit sort:sort count:currentPostCount after:nil before:before];
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

    /* Reload table */
    [tableView reloadData];
    [tableView setNeedsDisplay:YES];

    statusMsg = [NSString stringWithFormat:@"Loaded %d posts from r/%@",
        [posts count], [subredditField stringValue]];
    [statusText setString:statusMsg];

    NSLog(@"=== UPDATE WITH RESULT END (loaded %d posts) ===", [posts count]);
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

/* Navigation and refresh */
- (void)refreshPosts:(id)sender {
    [statusText setString:@"Fetching Reddit posts..."];
    [progressIndicator startAnimation:nil];
    [self fetchRedditData];
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

    NSLog(@"Cleaned permalink: %@", permalink);

    NS_DURING
    {
        result = reddit_fetch_comments([permalink UTF8String]);

        if (result.success && result.json) {
            NSString *jsonString = [NSString stringWithUTF8String:result.json];
            jsonString = [jsonString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSLog(@"Comments JSON length: %d", [jsonString length]);

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
    NSLog(@"Creating comments window...");

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

        NSLog(@"Comments window created successfully");
    }
    @catch (NSException *exception) {
        NSLog(@"Exception creating comments window: %@", [exception reason]);
        [statusText setString:@"Error opening comments window"];
    }
}

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

- (void)openLinkFromButton:(id)sender {
    NSString *url = [sender toolTip];
    if (url && [url length] > 0) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
    }
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
}

- (void)savePreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:currentSubreddit forKey:@"DefaultSubreddit"];
    [defaults setInteger:maxComments forKey:@"MaxComments"];
    [defaults synchronize];
}

- (void)showPreferences:(id)sender {
    NSRect prefsFrame = NSMakeRect(200, 200, 400, 200);
    NSWindow *prefsWindow;
    NSView *content;
    NSTextField *subLabel, *subField, *maxLabel, *maxField;
    NSButton *saveBtn;

    prefsWindow = [[NSWindow alloc] initWithContentRect:prefsFrame
                                              styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [prefsWindow setTitle:@"TigerReddit Preferences"];
    content = [prefsWindow contentView];

    /* Default subreddit */
    subLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 140, 140, 20)] autorelease];
    [subLabel setStringValue:@"Default Subreddit:"];
    [subLabel setBezeled:NO];
    [subLabel setDrawsBackground:NO];
    [subLabel setEditable:NO];
    [content addSubview:subLabel];

    subField = [[[NSTextField alloc] initWithFrame:NSMakeRect(165, 138, 200, 24)] autorelease];
    [subField setStringValue:currentSubreddit ? currentSubreddit : @"vintageapple"];
    [subField setEditable:YES];
    [subField setBezeled:YES];
    [subField setDrawsBackground:YES];
    [subField setTag:100];
    [content addSubview:subField];

    /* Max comments */
    maxLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 100, 140, 20)] autorelease];
    [maxLabel setStringValue:@"Max Comments:"];
    [maxLabel setBezeled:NO];
    [maxLabel setDrawsBackground:NO];
    [maxLabel setEditable:NO];
    [content addSubview:maxLabel];

    maxField = [[[NSTextField alloc] initWithFrame:NSMakeRect(165, 98, 80, 24)] autorelease];
    [maxField setIntValue:maxComments];
    [maxField setEditable:YES];
    [maxField setBezeled:YES];
    [maxField setDrawsBackground:YES];
    [maxField setTag:101];
    [content addSubview:maxField];

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

    [self savePreferences];
    [prefsWindow close];
    [statusText setString:[NSString stringWithFormat:@"Preferences saved (sub: %@, max comments: %d)",
        currentSubreddit, maxComments]];
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

/*
 * fetchRedditData - Main entry point for fetching posts.
 * Now calls the native C API via fetchPostsWithSubreddit:.
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

@end

/* Main entry point */
int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *app = [NSApplication sharedApplication];
    RedditController *controller;
    int initResult;

    /* Initialize the native C Reddit fetcher (libcurl, cache dir, etc.) */
    initResult = reddit_fetcher_init();
    if (initResult != 0) {
        NSLog(@"WARNING: reddit_fetcher_init() failed with code %d", initResult);
    }

    controller = [[RedditController alloc] init];
    [app setDelegate:controller];

    /* Build the application menu bar */
    {
        NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
        NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@""];
        NSMenuItem *aboutItem, *prefsItem, *quitItem;

        aboutItem = [appMenu addItemWithTitle:@"About TigerReddit"
                                       action:@selector(showAbout:)
                                keyEquivalent:@""];
        [aboutItem setTarget:controller];

        [appMenu addItem:[NSMenuItem separatorItem]];

        prefsItem = [appMenu addItemWithTitle:@"Preferences..."
                                       action:@selector(showPreferences:)
                                keyEquivalent:@","];
        [prefsItem setTarget:controller];

        [appMenu addItem:[NSMenuItem separatorItem]];

        quitItem = [appMenu addItemWithTitle:@"Quit TigerReddit"
                                      action:@selector(terminate:)
                               keyEquivalent:@"q"];
        [quitItem setTarget:app];

        [appMenuItem setSubmenu:appMenu];
        [mainMenu addItem:appMenuItem];

        /* Register as the system app menu (private but functional on Tiger/Leopard) */
        if ([app respondsToSelector:@selector(setAppleMenu:)])
            [app performSelector:@selector(setAppleMenu:) withObject:appMenu];

        [app setMainMenu:mainMenu];

        [appMenu release];
        [appMenuItem release];
        [mainMenu release];
    }

    [controller createUI];
    [app run];
    [controller release];

    /* Clean up the native C Reddit fetcher */
    reddit_fetcher_cleanup();

    [pool release];
    return 0;
}
