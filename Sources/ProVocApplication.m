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
#import "ARAboutDialog.h"

@implementation ProVocApplication

-(BOOL)sendAction:(SEL)inAction to:(id)inTarget from:(id)inSender
{
	if (inAction == @selector(changeFont:) && [ProVocFontNameField changeFont:inSender])
		return YES;
	return [super sendAction:inAction to:inTarget from:inSender];
}

// AppKit catches the exceptions raised while the application handles an event or a
// timer, and goes on. It no longer writes them to the standard error, where the logs
// of ProVoc go: no exception may be silent.
-(void)reportException:(NSException *)inException
{
	NSLog(@"*** Exception: %@: %@", [inException name], [inException reason]);
	[super reportException:inException];
}

// (This was a category of NSApplication in ProVocAppDelegate.m. A category cannot be
// relied upon to replace a method that AppKit implements itself: About ProVoc opened
// the standard About panel of macOS.)
-(void)orderFrontStandardAboutPanel:(id)inSender
{
	[[ARAboutDialog sharedAboutDialog] showAboutWindow];
}

-(void)showHelp:(id)inSender
{
	// NSApplication would ask the Help Viewer, which cannot open the old help book format.
	[[ProVocHelpController sharedController] showPage:@"index"];
}

#pragma mark Media commands

// tag, key, modifiers (besides Command), title
static struct { int tag; NSString *key; NSEventModifierFlags modifiers; NSString *title; } sMediaCommands[] = {
	{1, @"k", 0, @"Media Menu Play First Audio"},
	{2, @"l", 0, @"Media Menu Play Second Audio"},
	{3, @"b", 0, @"Media Menu Show Image"},	// not Command-D: it answers "Don't Save" in the sheets of the system
	{4, @"e", 0, @"Media Menu Play Movie"},
	{5, @"e", NSEventModifierFlagOption, @"Media Menu Play Movie Full Size"},
	{11, @"k", NSEventModifierFlagShift, @"Media Menu Record First Audio"},
	{12, @"l", NSEventModifierFlagShift, @"Media Menu Record Second Audio"},
	{13, @"b", NSEventModifierFlagShift, @"Media Menu Capture Image"},
	{14, @"m", NSEventModifierFlagShift, @"Media Menu Record Movie"},
};

// Hands the function key behind a media command to the objects that handle F1...F4
-(BOOL)performMediaCommandWithTag:(int)inTag
{
	static const unsigned short keyCodes[4] = {122, 120, 99, 118};
	static const unichar characters[4] = {NSF1FunctionKey, NSF2FunctionKey, NSF3FunctionKey, NSF4FunctionKey};
	int key = (inTag > 10 ? inTag - 10 : inTag == 5 ? 4 : inTag) - 1;
	if (key < 0 || key > 3)
		return NO;
	// Command means "record", unless the NoShiftRecord preference swaps the two (see ProVocInspector)
	BOOL record = inTag > 10;
	NSEventModifierFlags flags = NSEventModifierFlagFunction;
	if (record != [[NSUserDefaults standardUserDefaults] boolForKey:@"NoShiftRecord"])
		flags |= NSEventModifierFlagCommand;
	if (inTag == 5)
		flags |= NSEventModifierFlagOption;
	NSString *string = [NSString stringWithCharacters:&characters[key] length:1];
	NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:[[NSProcessInfo processInfo] systemUptime]
								  windowNumber:[[self keyWindow] windowNumber] context:nil characters:string charactersIgnoringModifiers:string isARepeat:NO keyCode:keyCodes[key]];
	NSEnumerator *enumerator = [[ProVocTester currentTesters] objectEnumerator];
	ProVocTester *tester;
	while (tester = [enumerator nextObject])
		if ([tester handleKeyDownEvent:event])
			return YES;
	return [[ProVocInspector sharedInspector] handleKeyDownEvent:event];
}

-(IBAction)performMediaCommand:(id)inSender
{
	[self performMediaCommandWithTag:[inSender tag]];
}

-(BOOL)validateMenuItem:(NSMenuItem *)inItem
{
	if ([inItem action] == @selector(performMediaCommand:))
		return [[self orderedDocuments] count] > 0;
	return [super validateMenuItem:inItem];
}

// The shortcuts of the Media menu must also work while a test runs as a modal panel,
// when menu commands are not available: they are recognized here.
-(BOOL)performMediaCommandForKeyDownEvent:(NSEvent *)inEvent
{
	NSEventModifierFlags flags = [inEvent modifierFlags] & (NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand);
	if ((flags & NSEventModifierFlagCommand) == 0 || [inEvent isARepeat])
		return NO;
	NSString *key = [[inEvent charactersIgnoringModifiers] lowercaseString];
	int i;
	for (i = 0; i < sizeof(sMediaCommands) / sizeof(sMediaCommands[0]); i++)
		if ([key isEqualToString:sMediaCommands[i].key] && flags == (sMediaCommands[i].modifiers | NSEventModifierFlagCommand)) {
			[self performMediaCommandWithTag:sMediaCommands[i].tag];
			return YES;
		}
	return NO;
}

-(void)installMediaMenu
{
	NSMenu *vocabularyMenu = nil;
	NSEnumerator *enumerator = [[[self mainMenu] itemArray] objectEnumerator];
	NSMenuItem *item;
	while (item = [enumerator nextObject])
		if ([[item submenu] indexOfItemWithTarget:nil andAction:@selector(startTest:)] >= 0)
			vocabularyMenu = [item submenu];
	if (!vocabularyMenu || [vocabularyMenu indexOfItemWithTitle:NSLocalizedString(@"Media Menu Title", @"")] >= 0)
		return;
	NSMenu *mediaMenu = [[[NSMenu alloc] initWithTitle:NSLocalizedString(@"Media Menu Title", @"")] autorelease];
	int i;
	for (i = 0; i < sizeof(sMediaCommands) / sizeof(sMediaCommands[0]); i++) {
		if (sMediaCommands[i].tag == 11)
			[mediaMenu addItem:[NSMenuItem separatorItem]];
		NSMenuItem *mediaItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(sMediaCommands[i].title, @"") action:@selector(performMediaCommand:) keyEquivalent:sMediaCommands[i].key] autorelease];
		[mediaItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand | sMediaCommands[i].modifiers];
		[mediaItem setTarget:self];
		[mediaItem setTag:sMediaCommands[i].tag];
		[mediaMenu addItem:mediaItem];
	}
	[vocabularyMenu addItem:[NSMenuItem separatorItem]];
	NSMenuItem *mediaMenuItem = [[[NSMenuItem alloc] initWithTitle:[mediaMenu title] action:NULL keyEquivalent:@""] autorelease];
	[mediaMenuItem setSubmenu:mediaMenu];
	[vocabularyMenu addItem:mediaMenuItem];
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

		// (without test the menu itself handles its shortcuts, when it may)
		if ([[ProVocTester currentTesters] count] > 0 && [self performMediaCommandForKeyDownEvent:inEvent])
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
