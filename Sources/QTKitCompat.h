//
//  QTKitCompat.h
//  ProVoc
//
//  QTKit does not exist on arm64. These classes keep the small part of the
//  QTMovie / QTMovieView API that ProVoc uses (and the class names archived
//  in the nibs), implemented on top of AVFoundation / AVKit.
//

#import <Cocoa/Cocoa.h>

@class AVPlayer, AVPlayerView;

@interface QTMovie : NSObject <NSCoding> {
	NSString *mFile;
	AVPlayer *mPlayer;
	NSSize mNaturalSize;
	BOOL mPlayable;
}

+(NSArray *)movieUnfilteredFileTypes;
+(BOOL)canInitWithFile:(NSString *)inFile;
+(id)movieWithFile:(NSString *)inFile error:(NSError **)outError;
-(id)initWithFile:(NSString *)inFile error:(NSError **)outError;

-(NSString *)file;
-(AVPlayer *)player;
-(BOOL)isPlayable;
-(NSSize)naturalSize;
-(float)rate;

@end

@interface QTMovieView : NSView {
	QTMovie *mMovie;
	AVPlayerView *mPlayerView;
	NSTextField *mMessageField;
	BOOL mControllerVisible;
}

-(QTMovie *)movie;
-(void)setMovie:(QTMovie *)inMovie;

-(IBAction)play:(id)inSender;
-(IBAction)pause:(id)inSender;
-(BOOL)isPlaying;

-(void)setControllerVisible:(BOOL)inVisible;
-(void)setPreservesAspectRatio:(BOOL)inPreserve;
-(void)setFillColor:(NSColor *)inColor;
-(float)controllerBarHeight;

@end
