//
//  ProVocImageView.m
//  ProVoc
//
//  Created by Simon Bovet on 09.04.06.
//  Copyright 2006 Arizona Software. All rights reserved.
//

#import "ProVocImageView.h"
#import "ProVocWord.h"


@implementation ProVocImageView

-(BOOL)acceptsFirstMouse:(NSEvent *)inEvent
{
	return YES;
}

-(IBAction)displayFullImage:(id)inSender
{
	[[self image] displayInFullSize];
}

-(void)mouseDown:(NSEvent *)inEvent
{
	if ([inEvent clickCount] == 2 && NSPointInRect([self convertPoint:[inEvent locationInWindow] fromView:nil], [self bounds]))
		[self displayFullImage:nil];
}

-(void)insertText:(NSString *)inString
{
	if ([inString isEqual:@" "])
		[self displayFullImage:nil];
}

-(void)insertNewline:(id)inSender
{
	if ([self tag] == 314)
		[super keyDown:[NSApp currentEvent]];
	else
		[self displayFullImage:nil];
}

-(void)delete:(id)inSender
{
	SEL selector = @selector(removeImage:);
	if ([mDelegate respondsToSelector:selector])
		[mDelegate performSelector:selector withObject:nil];
}

-(void)deleteBackward:(id)inSender
{
	[self delete:inSender];
}

-(void)doCommandBySelector:(SEL)inSelector
{
//	NSLog(@"%@@selector(%@)", NSStringFromClass([self class]), NSStringFromSelector(inSelector));
	if ([self respondsToSelector:inSelector])
		[self performSelector:inSelector withObject:nil];
	else
		[super doCommandBySelector:inSelector];
}

-(void)keyDown:(NSEvent *)inEvent
{
	[self interpretKeyEvents:@[inEvent]];
}

-(void)concludeDragOperation:(id <NSDraggingInfo>)inSender
{
	BOOL concluded = NO;
	if ([mDelegate respondsToSelector:@selector(imageView:didReceiveDraggedImageFile:)]) {

		NSArray *fileTypes = [NSImage imageUnfilteredFileTypes];
		NSEnumerator *enumerator = [[[inSender draggingPasteboard] propertyListForType:NSFilenamesPboardType] reverseObjectEnumerator];
		NSString *fileName;
		while (fileName = [enumerator nextObject])
			if ([fileTypes containsObject:[fileName pathExtension]]) {
				[mDelegate imageView:self didReceiveDraggedImageFile:fileName];
				concluded = YES;
				break;
			}
	}
	if (!concluded)
		[super concludeDragOperation:inSender];
}

@end

@implementation NSScreen (FullScreen)

+(NSRect)totalFrame
{
	NSRect frame = NSZeroRect;
	NSEnumerator *enumerator = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while (screen = [enumerator nextObject])
		frame = NSUnionRect(frame, [screen frame]);
	return frame;
}

@end

@implementation NSImage (ProVocImageView)

-(NSSize)pixelSize // ++++ 4.2.2 ++++
{
	NSImageRep *imageRep = [[self representations] lastObject];
	if (imageRep)
		return NSMakeSize([imageRep pixelsWide], [imageRep pixelsHigh]);
	else
		return [self size];
}

-(void)displayInFullSize
{
	NSSize maxSize = [[NSScreen mainScreen] frame].size;
	maxSize.width -= 50;
	maxSize.height -= 50;
	NSSize imageSize = [self pixelSize]; // ++++ 4.2.2 ++++
	[self setSize:imageSize]; // ++++ 4.2.2 ++++
	NSRect contentRect = NSZeroRect;
	float k = MIN(1, MIN(maxSize.width / imageSize.width, maxSize.height / imageSize.height));
	contentRect.size.width = MIN(imageSize.width * k, maxSize.width);
	contentRect.size.height = round(contentRect.size.width / imageSize.width * imageSize.height);
	NSWindow *background = [[NSWindow alloc] initWithContentRect:[NSScreen totalFrame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
	[background setOpaque:NO];
	[background setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
	[background setLevel:NSModalPanelWindowLevel];
	[background orderFront:nil];
	NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
	NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSZeroRect] autorelease];
	[window setOpaque:NO];
	[window setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.0]];
	[imageView setImageScaling:NSScaleProportionally];
	[window setContentView:imageView];
	[window setLevel:NSModalPanelWindowLevel];
	[imageView setImage:self];
	[window center];
	[window setHasShadow:YES];
	[window makeKeyAndOrderFront:nil];
	[window nextEventMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyDownMask];
	[window setContentView:nil];
	[window close];
	[background close];
}

static NSRect ProVocRectOfBox(NSDictionary *inBox, NSSize inSize)
{
	float x = [inBox[@"x"] floatValue], y = [inBox[@"y"] floatValue], w = [inBox[@"w"] floatValue], h = [inBox[@"h"] floatValue];
	return NSMakeRect(x * inSize.width, (1 - y - h) * inSize.height, w * inSize.width, h * inSize.height);
}

// The boxes are painted in the image itself: wherever the image goes (the test panel, full
// size, the slideshow, the printed cards), what is hidden stays hidden.
-(NSImage *)imageWithBoxOfWord:(ProVocWord *)inWord state:(ProVocBoxState)inState
{
	NSSize size = [self pixelSize];
	if (size.width <= 0 || size.height <= 0)
		size = [self size];
	NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:size.width pixelsHigh:size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
																  colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
	NSRect bounds = {NSZeroPoint, size};
	float lineWidth = MAX(2, round(size.width / 200));
	NSColor *grey = [NSColor colorWithCalibratedRed:0.80 green:0.82 blue:0.85 alpha:1];
	NSColor *greyLine = [NSColor colorWithCalibratedRed:0.61 green:0.64 blue:0.67 alpha:1];
	NSColor *gold = [NSColor colorWithCalibratedRed:0.96 green:0.78 blue:0.29 alpha:1];
	NSColor *dark = [NSColor colorWithCalibratedRed:0.11 green:0.11 blue:0.12 alpha:1];
	NSColor *green = [NSColor colorWithCalibratedRed:0.11 green:0.50 blue:0.23 alpha:1];
	NSColor *red = [NSColor colorWithCalibratedRed:0.79 green:0.19 blue:0.11 alpha:1];

	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
	[self drawInRect:bounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	if (inState != ProVocBoxSelected && ![[inWord occlusion][@"showOthers"] boolValue])
		for (ProVocWord *sibling in [inWord occlusionSiblings])
			if (sibling != inWord) {
				NSRect rect = ProVocRectOfBox([sibling occlusion][@"box"], size);
				[grey set];
				NSRectFill(rect);
				[greyLine set];
				NSFrameRectWithWidth(rect, lineWidth / 2);
			}
	NSRect rect = ProVocRectOfBox([inWord occlusion][@"box"], size);
	if (inState == ProVocBoxAsked || inState == ProVocBoxSelected) {
		[gold set];
		NSRectFill(rect);
	}
	[(inState == ProVocBoxRight ? green : inState == ProVocBoxWrong ? red : dark) set];
	NSFrameRectWithWidth(NSInsetRect(rect, -lineWidth, -lineWidth), lineWidth);
	if (inState == ProVocBoxAsked) {
		NSDictionary *attributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:MIN(NSHeight(rect), NSWidth(rect)) * 0.7], NSForegroundColorAttributeName: dark};
		NSSize mark = [@"?" sizeWithAttributes:attributes];
		[@"?" drawAtPoint:NSMakePoint(NSMidX(rect) - mark.width / 2, NSMidY(rect) - mark.height / 2) withAttributes:attributes];
	}
	[NSGraphicsContext restoreGraphicsState];

	NSImage *image = [[[NSImage alloc] initWithSize:[self size]] autorelease];
	[image addRepresentation:rep];
	return image;
}

@end
