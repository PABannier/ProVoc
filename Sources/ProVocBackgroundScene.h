//
//  ProVocBackgroundScene.h
//  ProVoc
//
//  The backgrounds shown behind the test panel were Quartz Composer compositions.
//  Quartz Composer is deprecated and crashes on current systems, so the four
//  built-in backgrounds (Plant Shades, Ocean, Globe, Nature) are drawn with Core
//  Animation instead, from the artwork of the original compositions. The view
//  answers the part of the QCView interface that ProVocBackground uses.
//

#import <Cocoa/Cocoa.h>

@interface ProVocBackgroundScene : NSView {
	NSBundle *mBundle;
	NSString *mKind;
	NSMutableDictionary *mInputValues;
	BOOL mRendering;
	NSArray *mPictures;
	NSUInteger mPictureIndex;
	NSTimer *mTimer;
}

// YES for the backgrounds this class knows how to draw (by bundle identifier).
+(BOOL)canDrawBackgroundOfBundle:(NSBundle *)inBundle;
-(void)setBundle:(NSBundle *)inBundle;

-(NSArray *)inputKeys;
-(BOOL)setValue:(id)inValue forInputKey:(NSString *)inKey;
-(id)valueForInputKey:(NSString *)inKey;

-(BOOL)startRendering;
-(void)stopRendering;
-(BOOL)isRendering;

@end
