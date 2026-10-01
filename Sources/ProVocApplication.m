//
//  ProVocApplication.m
//  ProVoc
//
//  Created by Simon Bovet on 14.10.05.
//  Copyright 2005 Arizona Software. All rights reserved.
//

#import "ProVocApplication.h"

#import "ProVocTextField.h"
#import "ProVocInspector.h"
#import "ProVocTester.h"
#import "ProVocFontNameField.h"
#import "ProVocHelpController.h"

@implementation ProVocApplication

-(BOOL)sendAction:(SEL)inAction to:(id)inTarget from:(id)inSender
{
	if (inAction == @selector(changeFont:) && [ProVocFontNameField changeFont:inSender])
		return YES;
	return [super sendAction:inAction to:inTarget from:inSender];
}

-(void)showHelp:(id)inSender
{
	// NSApplication would ask the Help Viewer, which cannot open the old help book format.
	[[ProVocHelpController sharedController] showPage:@"index"];
}

-(int)firstResponderChangeForKeyDownEvent:(NSEvent *)inEvent
{
	// Tab / Shift-Tab only. Every other key (dead keys, option-combinations, input
	// methods) must reach the text system untouched.
	if ([inEvent keyCode] != 48)
		return 0;
	NSEventModifierFlags flags = [inEvent modifierFlags] & (NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand);
	if (flags == 0)
		return 1;
	if (flags == NSEventModifierFlagShift)
		return -1;
	return 0;
}

-(void)sendEvent:(NSEvent *)inEvent
{
	if ([inEvent type] == NSEventTypeKeyDown) {
		int firstResponderChange = [self firstResponderChangeForKeyDownEvent:inEvent];
		if (firstResponderChange != 0) {
			id firstResponder = [[NSApp keyWindow] firstResponder];
			BOOL composing = [firstResponder respondsToSelector:@selector(hasMarkedText)] && [firstResponder hasMarkedText];
			if ([firstResponder respondsToSelector:@selector(delegate)])
				firstResponder = [firstResponder delegate];
			if (!composing && [firstResponder isKindOfClass:[ProVocTextField class]]) {
				id next = [firstResponder chainedResponder:firstResponderChange];
				if (next) {
					[[firstResponder window] performSelector:@selector(makeFirstResponder:) withObject:next afterDelay:0.0 inModes:@[NSDefaultRunLoopMode, NSModalPanelRunLoopMode]];
					return;
				}
			}
		}

		NSEnumerator *enumerator = [[ProVocTester currentTesters] objectEnumerator];
		ProVocTester *tester;
		while (tester = [enumerator nextObject])
			if ([tester handleKeyDownEvent:inEvent])
				return;

		if ([[ProVocInspector sharedInspector] handleKeyDownEvent:inEvent])
			return;
	}
	[super sendEvent:inEvent];
}

@end

@implementation NSApplication (ProVoc)

-(long)systemVersion
{
	// Same encoding as the old Gestalt selector (0x1040 = 10.4); anything newer than
	// 10.15 is reported as at least 0x1100 so that every ">= 0x10xx" check holds.
	static long systemVersion = 0;
	if (systemVersion == 0) {
		NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
		if (version.majorVersion > 10)
			systemVersion = version.majorVersion << 8;
		else
			systemVersion = 0x1000 + (MIN(version.minorVersion, 15) << 4) + MIN(version.patchVersion, 15);
	}
	return systemVersion;
}

@end
