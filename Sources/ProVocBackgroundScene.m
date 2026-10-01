//
//  ProVocBackgroundScene.m
//  ProVoc
//

#import "ProVocBackgroundScene.h"

#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>

@implementation ProVocBackgroundScene

+(NSString *)kindOfBundle:(NSBundle *)inBundle
{
	NSString *kind = [[[inBundle bundleIdentifier] componentsSeparatedByString:@"."] lastObject];
	return [@[@"plantshades", @"ocean", @"globe", @"nature"] containsObject:kind] ? kind : nil;
}

+(BOOL)canDrawBackgroundOfBundle:(NSBundle *)inBundle
{
	return [self kindOfBundle:inBundle] != nil;
}

-(id)initWithFrame:(NSRect)inFrame
{
	if (self = [super initWithFrame:inFrame]) {
		mInputValues = [[NSMutableDictionary alloc] init];
		[self setLayer:[CALayer layer]];
		[self setWantsLayer:YES];
		[[self layer] setMasksToBounds:YES];
	}
	return self;
}

-(void)dealloc
{
	[mTimer invalidate];
	[mBundle release];
	[mKind release];
	[mInputValues release];
	[mPictures release];
	[super dealloc];
}

-(void)setBundle:(NSBundle *)inBundle
{
	if (mBundle != inBundle) {
		[mBundle release];
		mBundle = [inBundle retain];
		[mKind release];
		mKind = [[[self class] kindOfBundle:inBundle] copy];
		[mPictures release];
		mPictures = nil;
		if (mRendering)
			[self rebuild];
	}
}

#pragma mark Inputs (same names as the published inputs of the compositions)

-(NSArray *)inputKeys
{
	if ([mKind isEqualToString:@"plantshades"])
		return @[@"CorrectAnswer", @"WrongAnswer", @"Color", @"Random"];
	if ([mKind isEqualToString:@"ocean"])
		return @[@"WrongAnswer", @"CorrectAnswer", @"Random"];
	if ([mKind isEqualToString:@"globe"])
		return @[@"ChangeQuestion", @"PreviousQuestion", @"Question", @"ChangeAnswer", @"PreviousAnswer", @"Answer", @"Random"];
	if ([mKind isEqualToString:@"nature"])
		return @[@"Color", @"Random", @"Reset", @"CorrectAnswer", @"NewQuestion", @"Start"];
	return @[];
}

-(id)valueForInputKey:(NSString *)inKey
{
	return mInputValues[inKey];
}

-(BOOL)setValue:(id)inValue forInputKey:(NSString *)inKey
{
	if (![[self inputKeys] containsObject:inKey])
		return NO;
	BOOL wasOn = [mInputValues[inKey] isKindOfClass:[NSNumber class]] && [mInputValues[inKey] boolValue];
	if (inValue)
		mInputValues[inKey] = inValue;
	else
		[mInputValues removeObjectForKey:inKey];
	if (!mRendering)
		return YES;
	BOOL triggered = [inValue isKindOfClass:[NSNumber class]] && [inValue boolValue] && !wasOn;
	if ([inKey isEqualToString:@"Color"])
		[self applyColor];
	else if ([inKey isEqualToString:@"Question"] || [inKey isEqualToString:@"Answer"])
		[self applyTexts];
	else if (triggered && [inKey isEqualToString:@"CorrectAnswer"])
		[self celebrate];
	else if (triggered && [inKey isEqualToString:@"WrongAnswer"])
		[self regret];
	else if (triggered && [inKey isEqualToString:@"NewQuestion"] && [mKind isEqualToString:@"nature"])
		[self showNextPicture];
	return YES;
}

-(BOOL)isRendering
{
	return mRendering;
}

-(BOOL)startRendering
{
	mRendering = YES;
	[self rebuild];
	return YES;
}

-(void)stopRendering
{
	mRendering = NO;
	[mTimer invalidate];
	mTimer = nil;
	[[self layer] setSublayers:nil];
}

-(void)setFrameSize:(NSSize)inSize
{
	BOOL changed = !NSEqualSizes(inSize, [self frame].size);
	[super setFrameSize:inSize];
	if (changed && mRendering)
		[self rebuild];
}

#pragma mark Building blocks

-(NSColor *)baseColor
{
	NSColor *color = [mInputValues[@"Color"] isKindOfClass:[NSColor class]] ? mInputValues[@"Color"] : [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
	color = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
	return color ? color : [NSColor darkGrayColor];
}

-(CGFloat)random
{
	return (CGFloat)arc4random_uniform(10000) / 10000.0;
}

-(NSImage *)imageNamed:(NSString *)inName
{
	NSString *path = [mBundle pathForResource:inName ofType:@"png"];
	return path ? [[[NSImage alloc] initWithContentsOfFile:path] autorelease] : nil;
}

// A layer showing the shape of an image (its alpha) in one flat color
-(CALayer *)layerWithShape:(NSImage *)inImage color:(NSColor *)inColor frame:(CGRect)inFrame
{
	CALayer *layer = [CALayer layer];
	[layer setFrame:inFrame];
	[layer setBackgroundColor:[inColor CGColor]];
	CALayer *mask = [CALayer layer];
	[mask setFrame:[layer bounds]];
	[mask setContents:inImage];
	[mask setContentsGravity:kCAGravityResizeAspect];
	[layer setMask:mask];
	return layer;
}

-(CALayer *)layerWithImage:(NSImage *)inImage frame:(CGRect)inFrame gravity:(NSString *)inGravity
{
	CALayer *layer = [CALayer layer];
	[layer setFrame:inFrame];
	[layer setContents:inImage];
	[layer setContentsGravity:inGravity];
	[layer setMasksToBounds:YES];
	return layer;
}

-(void)animate:(CALayer *)inLayer keyPath:(NSString *)inKeyPath from:(id)inFrom to:(id)inTo duration:(CFTimeInterval)inDuration autoreverses:(BOOL)inAutoreverses
{
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:inKeyPath];
	[animation setFromValue:inFrom];
	[animation setToValue:inTo];
	[animation setDuration:inDuration];
	[animation setAutoreverses:inAutoreverses];
	[animation setRepeatCount:HUGE_VALF];
	[animation setTimingFunction:[CAMediaTimingFunction functionWithName:inAutoreverses ? kCAMediaTimingFunctionEaseInEaseOut : kCAMediaTimingFunctionLinear]];
	[animation setTimeOffset:[self random] * inDuration];
	[inLayer addAnimation:animation forKey:inKeyPath];
}

-(CAEmitterLayer *)emitterWithImage:(NSImage *)inImage birthRate:(float)inBirthRate
{
	CAEmitterLayer *emitter = [CAEmitterLayer layer];
	CAEmitterCell *cell = [CAEmitterCell emitterCell];
	[cell setContents:(id)[inImage CGImageForProposedRect:NULL context:nil hints:nil]];
	[cell setBirthRate:inBirthRate];
	[emitter setEmitterCells:@[cell]];
	return emitter;
}

// A short flash over the whole background
-(void)flashWithColor:(NSColor *)inColor
{
	CALayer *flash = [CALayer layer];
	[flash setFrame:[[self layer] bounds]];
	[flash setBackgroundColor:[inColor CGColor]];
	[flash setOpacity:0.0];
	[[self layer] addSublayer:flash];
	CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
	[animation setFromValue:@0.35];
	[animation setToValue:@0.0];
	[animation setDuration:0.8];
	[flash addAnimation:animation forKey:@"flash"];
	[flash performSelector:@selector(removeFromSuperlayer) withObject:nil afterDelay:1.0 inModes:@[NSRunLoopCommonModes]];
}

-(CALayer *)sublayerNamed:(NSString *)inName
{
	for (CALayer *layer in [[self layer] sublayers])
		if ([[layer name] isEqualToString:inName])
			return layer;
	return nil;
}

#pragma mark Scenes

-(void)rebuild
{
	[mTimer invalidate];
	mTimer = nil;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	[[self layer] setSublayers:nil];
	if ([mKind isEqualToString:@"plantshades"])
		[self buildPlantShades];
	else if ([mKind isEqualToString:@"ocean"])
		[self buildOcean];
	else if ([mKind isEqualToString:@"globe"])
		[self buildGlobe];
	else if ([mKind isEqualToString:@"nature"])
		[self buildNature];
	[self applyColor];
	[CATransaction commit];
}

-(void)applyColor
{
	if ([mKind isEqualToString:@"plantshades"] || [mKind isEqualToString:@"nature"]) {
		NSColor *color = [self baseColor];
		[[self layer] setBackgroundColor:[color CGColor]];
		NSColor *light = [color blendedColorWithFraction:0.35 ofColor:[NSColor whiteColor]];
		for (CALayer *layer in [[self layer] sublayers])
			if ([[layer name] hasPrefix:@"shade"])
				[layer setBackgroundColor:[light CGColor]];
	}
}

// Plant Shades: silhouettes of plants, in lighter shades of the background color,
// swaying slowly, and a few blossoms drifting down.
-(void)buildPlantShades
{
	CGRect bounds = [[self layer] bounds];
	CGFloat w = bounds.size.width, h = bounds.size.height;
	CALayer *pattern = [self layerWithShape:[self imageNamed:@"Pattern"] color:[NSColor whiteColor] frame:CGRectInset(bounds, -w * 0.05, -h * 0.05)];
	[pattern setName:@"shade pattern"];
	[pattern setOpacity:0.1];
	[[pattern mask] setContentsGravity:kCAGravityResizeAspectFill];
	[[pattern mask] setTransform:CATransform3DMakeScale(1, -1, 1)];	// its faded edge at the bottom
	[[self layer] addSublayer:pattern];
	[self animate:pattern keyPath:@"transform.translation.x" from:@(-w * 0.03) to:@(w * 0.03) duration:45 autoreverses:YES];

	CALayer *foliage = [self layerWithShape:[self imageNamed:@"Foliage"] color:[NSColor whiteColor] frame:CGRectMake(w * 0.45, h * 0.3, h * 0.9, h * 0.9)];
	[foliage setName:@"shade foliage"];
	[foliage setOpacity:0.3];
	[[self layer] addSublayer:foliage];
	[self animate:foliage keyPath:@"transform.rotation.z" from:@(-0.02) to:@(0.02) duration:17 autoreverses:YES];

	NSImage *branch = [self imageNamed:@"Branch"];
	CGFloat branchHeight = h * 0.75, branchWidth = branchHeight * 307.0 / 504.0;
	for (int i = 0; i < 3; i++) {
		CALayer *layer = [self layerWithShape:branch color:[NSColor whiteColor] frame:CGRectMake(w * (-0.02 + 0.13 * i), -h * (0.05 + 0.1 * i), branchWidth, branchHeight)];
		[layer setName:@"shade branch"];
		[layer setOpacity:0.75 - 0.2 * i];
		[layer setAnchorPoint:CGPointMake(0.2, 0.0)];
		[layer setPosition:CGPointMake(w * (0.03 + 0.13 * i), -h * (0.05 + 0.1 * i))];
		[[self layer] addSublayer:layer];
		[self animate:layer keyPath:@"transform.rotation.z" from:@(-0.012 - 0.004 * i) to:@(0.015 + 0.004 * i) duration:7 + 2 * i autoreverses:YES];
	}

	CAEmitterLayer *blossoms = [self emitterWithImage:[self imageNamed:@"Flower"] birthRate:0.8];
	[blossoms setName:@"blossoms"];
	[blossoms setEmitterShape:kCAEmitterLayerLine];
	[blossoms setEmitterPosition:CGPointMake(w / 2, h + 20)];
	[blossoms setEmitterSize:CGSizeMake(w, 1)];
	CAEmitterCell *cell = [[blossoms emitterCells] objectAtIndex:0];
	[cell setLifetime:70];
	[cell setVelocity:h / 45];
	[cell setVelocityRange:h / 90];
	[cell setEmissionLongitude:-M_PI_2];
	[cell setEmissionRange:0.5];
	[cell setScale:0.13];
	[cell setScaleRange:0.07];
	[cell setSpin:0.3];
	[cell setSpinRange:0.6];
	[cell setAlphaSpeed:-0.008];
	[cell setColor:[[NSColor colorWithCalibratedWhite:1.0 alpha:0.75] CGColor]];
	[blossoms setBeginTime:CACurrentMediaTime() - 60];	// as if it had been running for a while
	[[self layer] addSublayer:blossoms];
}

// Ocean: sun rays under water, butterflyfish passing by and bubbles rising.
-(void)buildOcean
{
	CGRect bounds = [[self layer] bounds];
	CGFloat w = bounds.size.width, h = bounds.size.height;
	[[self layer] setBackgroundColor:[[NSColor colorWithCalibratedRed:0.0 green:0.05 blue:0.6 alpha:1.0] CGColor]];
	[[self layer] addSublayer:[self layerWithImage:[self imageNamed:@"Water"] frame:bounds gravity:kCAGravityResizeAspectFill]];

	NSImage *fish = [self imageNamed:@"Fish"];
	CALayer *school = [CALayer layer];
	[school setName:@"school"];
	[school setFrame:bounds];
	for (int i = 0; i < 9; i++) {
		CGFloat size = h * (0.05 + 0.07 * [self random]);
		CALayer *layer = [CALayer layer];
		[layer setFrame:CGRectMake(w * 0.12 * [self random], h * (0.3 + 0.25 * [self random]), size, size)];
		CALayer *picture = [self layerWithImage:fish frame:[layer bounds] gravity:kCAGravityResizeAspect];
		[picture setTransform:CATransform3DMakeScale(-1, 1, 1)];	// the picture looks to the left; they swim to the right
		[layer addSublayer:picture];
		[school addSublayer:layer];
		[self animate:layer keyPath:@"transform.translation.y" from:@(-size * 0.2) to:@(size * 0.2) duration:3 + 3 * [self random] autoreverses:YES];
	}
	[[self layer] addSublayer:school];
	[self animate:school keyPath:@"transform.translation.x" from:@(-w * 0.35) to:@(w * 1.1) duration:70 autoreverses:NO];

	for (int i = 0; i < 2; i++) {
		CAEmitterLayer *bubbles = [self emitterWithImage:[self imageNamed:@"Bubble"] birthRate:6];
		[bubbles setName:@"bubbles"];
		[bubbles setEmitterPosition:CGPointMake(w * (i ? 0.82 : 0.3), -10)];
		[bubbles setEmitterShape:kCAEmitterLayerLine];
		[bubbles setEmitterSize:CGSizeMake(w * 0.03, 1)];
		CAEmitterCell *cell = [[bubbles emitterCells] objectAtIndex:0];
		[cell setLifetime:30];
		[cell setVelocity:h / 14];
		[cell setVelocityRange:h / 40];
		[cell setEmissionLongitude:M_PI_2];
		[cell setEmissionRange:0.12];
		[cell setScale:0.012];
		[cell setScaleRange:0.008];
		[cell setScaleSpeed:0.0006];
		[cell setAlphaRange:0.3];
		[bubbles setBeginTime:CACurrentMediaTime() - 20];
		[[self layer] addSublayer:bubbles];
	}
}

// Globe: the map of the world gliding by, with the question and its answer floating on it.
-(void)buildGlobe
{
	CGRect bounds = [[self layer] bounds];
	CGFloat w = bounds.size.width, h = bounds.size.height;
	CAGradientLayer *sky = [CAGradientLayer layer];
	[sky setFrame:bounds];
	[sky setColors:@[(id)[[NSColor colorWithCalibratedWhite:0.72 alpha:1.0] CGColor], (id)[[NSColor colorWithCalibratedWhite:0.5 alpha:1.0] CGColor]]];
	[[self layer] addSublayer:sky];

	// two copies side by side, so that the map can glide around the world for ever
	NSImage *map = [self imageNamed:@"Map"];
	CGFloat mapSize = MAX(w, h) * 1.5;
	CALayer *world = [CALayer layer];
	[world setFrame:CGRectMake(0, (h - mapSize) / 2 - h * 0.1, mapSize * 2, mapSize)];
	for (int i = 0; i < 2; i++) {
		CALayer *copy = [self layerWithImage:map frame:CGRectMake(mapSize * i, 0, mapSize, mapSize) gravity:kCAGravityResize];
		[copy setOpacity:0.55];
		[world addSublayer:copy];
	}
	[[self layer] addSublayer:world];
	[self animate:world keyPath:@"transform.translation.x" from:@0 to:@(-mapSize) duration:240 autoreverses:NO];

	for (NSString *name in @[@"Question", @"Answer"]) {
		CATextLayer *text = [CATextLayer layer];
		[text setName:name];
		BOOL question = [name isEqualToString:@"Question"];
		[text setFrame:CGRectMake(w * 0.05, h * (question ? 0.72 : 0.12), w * 0.9, h * 0.16)];
		[text setFontSize:h * 0.11];
		[text setAlignmentMode:question ? kCAAlignmentLeft : kCAAlignmentRight];
		[text setTruncationMode:kCATruncationEnd];
		[text setForegroundColor:[[NSColor colorWithCalibratedWhite:1.0 alpha:0.28] CGColor]];
		[text setContentsScale:[[self window] backingScaleFactor] > 0 ? [[self window] backingScaleFactor] : 2.0];
		[[self layer] addSublayer:text];
		[self animate:text keyPath:@"transform.translation.x" from:@(-w * 0.02) to:@(w * 0.02) duration:20 autoreverses:YES];
	}
	[self applyTexts];
}

-(void)applyTexts
{
	for (NSString *name in @[@"Question", @"Answer"]) {
		CATextLayer *text = (CATextLayer *)[self sublayerNamed:name];
		NSString *string = [mInputValues[name] isKindOfClass:[NSString class]] ? mInputValues[name] : @"";
		if (text && ![string isEqual:[text string]]) {
			CATransition *transition = [CATransition animation];
			[transition setDuration:0.5];
			[text addAnimation:transition forKey:@"text"];
			[text setString:string];
		}
	}
}

// Nature: landscape pictures, slowly zoomed and panned ("Ken Burns"), a new one now
// and then and after a few questions. The original borrowed the pictures of the system's
// screen savers; today the landscapes that come with the system are used, out of focus.
-(NSArray *)pictures
{
	if (!mPictures) {
		NSMutableArray *pictures = [NSMutableArray array];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSArray *imageTypes = @[@"jpg", @"jpeg", @"png", @"heic", @"tif", @"tiff"];
		NSArray *notLandscapes = @[@"Graphic", @"hello", @"Chroma", @"Grid", @"Dome", @"iMac", @"Calibrate", @"Metallic", @"Radial", @"Dark", @"Night", @"Solid", @"Macintosh", @"Peony", @"Flower", @"Iridescence", @"Ink", @"Abstract", @"Color", @"Stream", @"Ladybug", @"Reflection", @"Bubbles", @"Lake", @"Hand", @"Gradient"];
		for (NSString *directory in @[[[mBundle bundlePath] stringByAppendingPathComponent:@"Images"], @"/Library/Desktop Pictures", @"/System/Library/Desktop Pictures", @"/System/Library/Desktop Pictures/.thumbnails"]) {
			for (NSString *file in [[fileManager subpathsAtPath:directory] sortedArrayUsingSelector:@selector(compare:)]) {
				if (![imageTypes containsObject:[[file pathExtension] lowercaseString]] || [file hasPrefix:@"."] || [[file pathComponents] count] > 2)
					continue;
				BOOL landscape = YES;
				if ([directory hasPrefix:@"/"] && ![directory hasPrefix:[mBundle bundlePath]])
					for (NSString *word in notLandscapes)
						if ([file rangeOfString:word].location != NSNotFound)
							landscape = NO;
				if (landscape)
					[pictures addObject:[directory stringByAppendingPathComponent:file]];
			}
			if ([pictures count] >= 5)
				break;
		}
		mPictures = [pictures copy];
		mPictureIndex = [mPictures count] ? arc4random_uniform((uint32_t)[mPictures count]) : 0;
	}
	return mPictures;
}

-(void)buildNature
{
	[self showNextPicture];
	mTimer = [NSTimer timerWithTimeInterval:25 target:self selector:@selector(showNextPicture) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:mTimer forMode:NSRunLoopCommonModes];
}

-(void)showNextPicture
{
	NSArray *pictures = [self pictures];
	if ([pictures count] == 0)
		return;	// only the background color then
	mPictureIndex = (mPictureIndex + 1) % [pictures count];
	NSImage *image = [[[NSImage alloc] initWithContentsOfFile:pictures[mPictureIndex]] autorelease];
	if (!image)
		return;
	CGRect bounds = [[self layer] bounds];
	CALayer *picture = [self layerWithImage:image frame:bounds gravity:kCAGravityResizeAspectFill];
	[picture setName:@"picture"];
	// small pictures (the system only keeps previews of its landscapes) are shown out of focus
	if ([image size].width < bounds.size.width / 2) {
		CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
		[blur setDefaults];
		[blur setValue:@(bounds.size.width / 110) forKey:kCIInputRadiusKey];
		[self setLayerUsesCoreImageFilters:YES];
		[picture setFilters:@[blur]];
	}
	CALayer *previous = [self sublayerNamed:@"picture"];
	[previous setName:@"old picture"];
	[[self layer] addSublayer:picture];

	CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
	[fade setFromValue:@0.0];
	[fade setToValue:@1.0];
	[fade setDuration:2.0];
	[picture addAnimation:fade forKey:@"fade"];
	CGFloat zoom = 1.12 + 0.1 * [self random];
	BOOL zoomIn = [self random] < 0.5;
	[self animate:picture keyPath:@"transform.scale" from:@(zoomIn ? 1.02 : zoom) to:@(zoomIn ? zoom : 1.02) duration:40 autoreverses:YES];
	[self animate:picture keyPath:@"transform.translation.x" from:@(-bounds.size.width * 0.02) to:@(bounds.size.width * 0.02) duration:31 autoreverses:YES];
	[previous performSelector:@selector(removeFromSuperlayer) withObject:nil afterDelay:2.5 inModes:@[NSRunLoopCommonModes]];
}

#pragma mark Reactions to the answers

-(void)celebrate
{
	if ([mKind isEqualToString:@"plantshades"]) {
		// a gust of blossoms
		CAEmitterLayer *blossoms = (CAEmitterLayer *)[self sublayerNamed:@"blossoms"];
		[blossoms setBirthRate:25];
		[self performSelector:@selector(calmDown) withObject:nil afterDelay:0.6 inModes:@[NSRunLoopCommonModes]];
		[self flashWithColor:[NSColor whiteColor]];
	} else if ([mKind isEqualToString:@"ocean"]) {
		for (CALayer *layer in [[self layer] sublayers])
			if ([[layer name] isEqualToString:@"bubbles"])
				[(CAEmitterLayer *)layer setBirthRate:12];
		[self performSelector:@selector(calmDown) withObject:nil afterDelay:1.0 inModes:@[NSRunLoopCommonModes]];
	} else if ([mKind isEqualToString:@"nature"])
		[self flashWithColor:[NSColor whiteColor]];
}

-(void)calmDown
{
	for (CALayer *layer in [[self layer] sublayers])
		if ([layer isKindOfClass:[CAEmitterLayer class]])
			[(CAEmitterLayer *)layer setBirthRate:1];
}

-(void)regret
{
	if ([mKind isEqualToString:@"plantshades"])
		[self flashWithColor:[NSColor colorWithCalibratedRed:0.6 green:0.0 blue:0.0 alpha:1.0]];
	else if ([mKind isEqualToString:@"ocean"]) {
		// the fish take fright
		CALayer *school = [self sublayerNamed:@"school"];
		CABasicAnimation *fright = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
		[fright setFromValue:@0];
		[fright setToValue:@([[self layer] bounds].size.height * 0.08)];
		[fright setDuration:0.25];
		[fright setAutoreverses:YES];
		[school addAnimation:fright forKey:@"fright"];
		[self flashWithColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.2 alpha:1.0]];
	}
}

@end
