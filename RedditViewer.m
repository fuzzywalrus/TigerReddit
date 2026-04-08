// Tiger-Compatible RedditViewer.m
// Compatible with Mac OS X 10.4 Tiger and GCC 4.0
// No blocks, no modern Objective-C features
// Uses native C reddit_fetcher instead of Python/NSTask

#import <Cocoa/Cocoa.h>
#include "cJSON.h"
#include "reddit_fetcher.h"

// === Utility Classes ===

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

// === SaveableImageView ===

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

// === RDPost Model ===

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

// === CommentViewController ===

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

// === RedditController Interface ===

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
    int cacheAgeDays;
    int thumbDownloadIndex;
    NSTimer *thumbTimer;

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
- (void)startThumbnailDownloads;
- (void)downloadNextThumbnail:(NSTimer *)timer;
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

// === RedditController Implementation ===

/* Main application controller implementation */
@implementation RedditController

- (id)init {
    self = [super init];
    if (self) {
        posts = [[NSMutableArray alloc] init];
        currentSubreddit = [@"all" retain];
        currentPostCount = 25;
        maxComments = 50;
        cacheAgeDays = 7;
        [self loadPreferences];

        /* Purge old cached files on launch */
        {
            int purged = reddit_cache_purge(cacheAgeDays);
            if (purged > 0) {
                NSLog(@"Purged %d cached files older than %d days", purged, cacheAgeDays);
            }
        }

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

#include "RedditController+UI.inc"
#include "RedditController+Data.inc"
#include "RedditController+PostDetail.inc"
#include "RedditController+Comments.inc"
#include "RedditController+Actions.inc"
#include "RedditController+Preferences.inc"

@end

// === Main Entry Point ===

/* Main entry point */
int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSApplication *app = [NSApplication sharedApplication];
    RedditController *controller;
    int initResult;

    /* Point libcurl to the bundled CA certificate bundle */
    {
        NSString *caPath = [[NSBundle mainBundle] pathForResource:@"ca-bundle" ofType:@"crt"];
        if (caPath) {
            setenv("TIGERREDDIT_CA_BUNDLE", [caPath UTF8String], 1);
            NSLog(@"CA bundle: %@", caPath);
        }
    }

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
