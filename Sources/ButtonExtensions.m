//
//  ButtonExtensions.m
//  ProVoc
//
//  The push buttons of the nibs stand edge to edge ("Finish" at x = 14, 82 wide; "Pause"
//  at x = 96): the Aqua button of 2008 drew its bezel 6 points inside its frame, which
//  gave the gaps. Today's button fills its frame, and the buttons touched. A push button
//  that comes from a nib gets those margins back, as far as its title lets it.
//

#import <Cocoa/Cocoa.h>

@implementation NSButton (ProVoc)

-(void)awakeFromNib
{
	[super awakeFromNib];
	if ([self bezelStyle] != NSBezelStyleRounded || [self superview] == nil)
		return;
	CGFloat margin = [self controlSize] == NSControlSizeRegular ? 6 : [self controlSize] == NSControlSizeSmall ? 5 : 4;
	CGFloat room = (NSWidth([self frame]) - [[self cell] cellSize].width) / 2;
	margin = MIN(margin, floor(room));
	if (margin > 0)
		[self setFrame:NSInsetRect([self frame], margin, 0)];
}

@end
