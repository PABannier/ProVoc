//
//  QTKitCompat.m
//  ProVoc
//

#import "QTKitCompat.h"

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation QTMovie

+(NSArray *)movieUnfilteredFileTypes
{
	static NSArray *fileTypes = nil;
	if (!fileTypes) {
		NSMutableArray *extensions = [NSMutableArray array];
		NSEnumerator *enumerator = [[AVURLAsset audiovisualTypes] objectEnumerator];
		NSString *identifier;
		while (identifier = [enumerator nextObject]) {
			UTType *type = [UTType typeWithIdentifier:identifier];
			if ([type conformsToType:UTTypeMovie] || [type conformsToType:UTTypeVideo])
				[extensions addObjectsFromArray:[type tags][UTTagClassFilenameExtension]];
		}
		fileTypes = [extensions copy];
	}
	return fileTypes;
}

+(BOOL)canInitWithFile:(NSString *)inFile
{
	return [[self movieUnfilteredFileTypes] containsObject:[[inFile pathExtension] lowercaseString]];
}

+(id)movieWithFile:(NSString *)inFile error:(NSError **)outError
{
	return [[[self alloc] initWithFile:inFile error:outError] autorelease];
}

-(id)initWithFile:(NSString *)inFile error:(NSError **)outError
{
	if (!inFile || ![[NSFileManager defaultManager] fileExistsAtPath:inFile]) {
		[self release];
		return nil;
	}
	if (self = [super init]) {
		mFile = [inFile copy];
		AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:inFile] options:nil];
		AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
		mPlayable = [asset isPlayable];
		if (track) {
			CGSize size = CGSizeApplyAffineTransform([track naturalSize], [track preferredTransform]);
			mNaturalSize = NSMakeSize(fabs(size.width), fabs(size.height));
		}
		if (mPlayable)
			mPlayer = [[AVPlayer alloc] initWithPlayerItem:[AVPlayerItem playerItemWithAsset:asset]];
		else
			// Old QuickTime-only codecs: keep the movie (so the UI can say so), it just cannot play.
			NSLog(@"ProVoc: movie %@ cannot be decoded by AVFoundation", [inFile lastPathComponent]);
	}
	return self;
}

-(id)initWithCoder:(NSCoder *)inCoder
{
	// Empty placeholder movies are archived in the old nibs.
	return [super init];
}

-(void)encodeWithCoder:(NSCoder *)inCoder
{
}

-(void)dealloc
{
	[mPlayer pause];
	[mPlayer release];
	[mFile release];
	[super dealloc];
}

-(NSString *)file
{
	return mFile;
}

-(AVPlayer *)player
{
	return mPlayer;
}

-(BOOL)isPlayable
{
	return mPlayable;
}

-(NSSize)naturalSize
{
	return mNaturalSize;
}

-(float)rate
{
	return [mPlayer rate];
}

-(NSImage *)posterImage
{
	if (!mPlayable || !mFile)
		return nil;
	AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:mFile] options:nil]];
	[generator setAppliesPreferredTrackTransform:YES];
	CGImageRef image = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
	if (!image)
		return nil;
	NSImage *poster = [[[NSImage alloc] initWithCGImage:image size:mNaturalSize] autorelease];
	CGImageRelease(image);
	return poster;
}

@end

@implementation QTMovieView

-(void)setUpPlayerView
{
	mControllerVisible = YES;
	mPlayerView = [[AVPlayerView alloc] initWithFrame:[self bounds]];
	[mPlayerView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[mPlayerView setVideoGravity:AVLayerVideoGravityResizeAspect];
	[self updateControlsStyle];
	[mPlayerView setHidden:YES];
	[self addSubview:mPlayerView];

	mMessageField = [[NSTextField wrappingLabelWithString:NSLocalizedString(@"Movie Unsupported Format Message", @"")] retain];
	[mMessageField setAlignment:NSTextAlignmentCenter];
	[mMessageField setTextColor:[NSColor secondaryLabelColor]];
	[mMessageField setFrame:NSInsetRect([self bounds], 4, 4)];
	[mMessageField setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[mMessageField setHidden:YES];
	[self addSubview:mMessageField];
}

-(id)initWithFrame:(NSRect)inFrame
{
	if (self = [super initWithFrame:inFrame])
		[self setUpPlayerView];
	return self;
}

-(id)initWithCoder:(NSCoder *)inCoder
{
	if (self = [super initWithCoder:inCoder])
		[self setUpPlayerView];
	return self;
}

-(void)dealloc
{
	[mPlayerView setPlayer:nil];
	[mPlayerView release];
	[mMessageField release];
	[mMovie release];
	[super dealloc];
}

-(QTMovie *)movie
{
	return mMovie;
}

-(void)setMovie:(QTMovie *)inMovie
{
	if (![inMovie isKindOfClass:[QTMovie class]])
		inMovie = nil;
	if (mMovie != inMovie) {
		[self pause:nil];
		[mMovie release];
		mMovie = [inMovie retain];
		[mPlayerView setPlayer:[mMovie player]];
	}
	[mPlayerView setHidden:![mMovie isPlayable]];
	[mMessageField setHidden:!mMovie || [mMovie isPlayable]];
}

-(BOOL)isPlaying
{
	return [mMovie rate] != 0;
}

-(IBAction)play:(id)inSender
{
	AVPlayer *player = [mMovie player];
	AVPlayerItem *item = [player currentItem];
	if (item && CMTIME_IS_NUMERIC([item duration]) && CMTimeCompare([player currentTime], [item duration]) >= 0)
		[player seekToTime:kCMTimeZero];
	[player play];
}

-(IBAction)pause:(id)inSender
{
	[[mMovie player] pause];
}

-(IBAction)gotoBeginning:(id)inSender
{
	[[mMovie player] seekToTime:kCMTimeZero];
}

// The inline controls of AVKit need about 200 points: in a narrower view they are left
// out (they would not fit, and Auto Layout says so in the log at every layout), and a
// click on the picture plays or pauses.
-(BOOL)showsControls
{
	return mControllerVisible && NSWidth([self bounds]) >= 200;
}

-(void)updateControlsStyle
{
	AVPlayerViewControlsStyle style = [self showsControls] ? AVPlayerViewControlsStyleInline : AVPlayerViewControlsStyleNone;
	if ([mPlayerView controlsStyle] != style)
		[mPlayerView setControlsStyle:style];
}

-(void)setControllerVisible:(BOOL)inVisible
{
	mControllerVisible = inVisible;
	[self updateControlsStyle];
}

-(void)setFrameSize:(NSSize)inSize
{
	[super setFrameSize:inSize];
	[self updateControlsStyle];
}

-(NSView *)hitTest:(NSPoint)inPoint
{
	// without controls the player view has nothing to click: the clicks are for this view
	NSView *view = [super hitTest:inPoint];
	return view && ![self showsControls] ? self : view;
}

-(void)mouseDown:(NSEvent *)inEvent
{
	if (![self showsControls] && [inEvent clickCount] == 1 && [mMovie isPlayable]) {
		if ([self isPlaying])
			[self pause:nil];
		else
			[self play:nil];
	} else
		[super mouseDown:inEvent];
}

-(void)setPreservesAspectRatio:(BOOL)inPreserve
{
	[mPlayerView setVideoGravity:inPreserve ? AVLayerVideoGravityResizeAspect : AVLayerVideoGravityResize];
}

-(void)setFillColor:(NSColor *)inColor
{
	// AVPlayerView letterboxes in black; there is no fill color to set.
}

-(float)controllerBarHeight
{
	// AVKit draws its controls over the picture, not in a bar below it.
	return 0;
}

-(BOOL)acceptsFirstResponder
{
	// Only when the movie is alone in its window (full size). Next to the answer field of
	// a test, a click on the movie must not take the keyboard away from the field.
	return [[self window] contentView] == self;
}

-(NSMenu *)menuForEvent:(NSEvent *)inEvent
{
	return [[[NSMenu alloc] initWithTitle:@""] autorelease];
}

-(BOOL)validateMenuItem:(NSMenuItem *)inItem
{
	return YES;
}

-(void)keyDown:(NSEvent *)inEvent
{
	if ([[inEvent characters] isEqualToString:@" "]) {
		if ([self isPlaying])
			[self pause:nil];
		else
			[self play:nil];
	} else
		[super keyDown:inEvent];
}

@end
