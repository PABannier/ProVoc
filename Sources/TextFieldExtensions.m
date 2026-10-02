//
//  TextFieldExtensions.m
//  ProVoc
//
//  Created by Simon Bovet on 14.02.06.
//  Copyright 2006 Arizona Software. All rights reserved.
//

#import "TextFieldExtensions.h"

#import "MenuExtensions.h"
#import "SpeechSynthesizerExtensions.h"

@implementation NSTextField (ProVoc)

-(NSMenu *)menu
{
	NSMenu *menu = [super menu];
	if (!menu)
		menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	if ([menu numberOfItems] > 0)
		[menu addItem:[NSMenuItem separatorItem]];
	[menu addItemWithTitle:NSLocalizedString(@"Start Speaking", @"") target:self selector:@selector(startSpeaking:)];
	[menu addItemWithTitle:NSLocalizedString(@"Stop Speaking", @"") target:self selector:@selector(stopSpeaking:)];
	return menu;
}

-(NSSpeechSynthesizer *)speechSynthesizer
{
	return [NSSpeechSynthesizer commonSpeechSynthesizer];
}

-(void)startSpeaking:(id)inSender
{
	[[self speechSynthesizer] stopSpeaking]; // ++++ v4.2.2 ++++
	[[self speechSynthesizer] startSpeakingString:[self stringValue]];
}

-(BOOL)validateMenuItem:(NSMenuItem *)inItem
{
	SEL selector = [inItem action];
	if (selector == @selector(stopSpeaking:))
		return [[self speechSynthesizer] isSpeaking];
	else
		return [self respondsToSelector:selector];
}

-(void)stopSpeaking:(id)inSender
{
	[[self speechSynthesizer] stopSpeaking];
}

// The labels of the nibs were given the exact width of their text in Lucida Grande, and
// they wrap. With the system font of today the text is a little wider: its last letters
// went to a second line that the label has no room for ("Fas", "Piccol", "Contrassegn").
// A label of one line does not wrap; when its text needs more width it takes the room
// its neighbours leave, on the side it is not aligned to.
-(CGFloat)roomOnTheLeft:(BOOL)inLeft
{
	NSRect frame = [self frame];
	NSRect bounds = [[self superview] bounds];
	CGFloat room = inLeft ? NSMinX(frame) - NSMinX(bounds) : NSMaxX(bounds) - NSMaxX(frame);
	NSEnumerator *enumerator = [[[self superview] subviews] objectEnumerator];
	NSView *sibling;
	while (sibling = [enumerator nextObject]) {
		NSRect other = [sibling frame];
		if (sibling == self || [sibling isHidden] || NSMaxY(other) <= NSMinY(frame) || NSMinY(other) >= NSMaxY(frame))
			continue;
		if (inLeft && NSMaxX(other) <= NSMinX(frame) + 1)
			room = MIN(room, NSMinX(frame) - NSMaxX(other));
		if (!inLeft && NSMinX(other) >= NSMaxX(frame) - 1)
			room = MIN(room, NSMinX(other) - NSMaxX(frame));
	}
	return MAX(0, room);
}

-(void)awakeFromNib
{
	[super awakeFromNib];
	NSCell *cell = [self cell];
	if ([self isEditable] || [self isBezeled] || [self isBordered] || ![cell wraps] || !isfinite([cell cellSize].height) || NSHeight([self frame]) >= 2 * [cell cellSize].height - 4)
		return;
	[cell setWraps:NO];
	[cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[self setAllowsDefaultTighteningForTruncation:YES];
	CGFloat missing = ceil([cell cellSize].width - NSWidth([self frame]));
	if (missing <= 0)
		return;
	NSTextAlignment alignment = [self alignment];
	CGFloat left = alignment == NSTextAlignmentRight ? MIN(missing, [self roomOnTheLeft:YES]) : alignment == NSTextAlignmentCenter ? MIN(missing / 2, [self roomOnTheLeft:YES]) : 0;
	CGFloat right = alignment == NSTextAlignmentRight ? 0 : MIN(missing - left, [self roomOnTheLeft:NO]);
	NSRect frame = [self frame];
	frame.origin.x -= left;
	frame.size.width += left + right;
	[self setFrame:frame];
	// Several words that still do not fit (they never did: "Dimensioni scheda:" of the
	// Italian card panel is half as wide again as its label): the first words, as before.
	if (missing - left - right > 3 && [[self stringValue] rangeOfString:@" "].location != NSNotFound) {
		[cell setWraps:YES];
		[cell setLineBreakMode:NSLineBreakByWordWrapping];
	}
}

-(void)setWritingDirection:(NSWritingDirection)inDirection
{
	[[self cell] setBaseWritingDirection:inDirection];
	[[self cell] setAlignment:inDirection == NSWritingDirectionRightToLeft ? NSRightTextAlignment : NSLeftTextAlignment];
}

@end
