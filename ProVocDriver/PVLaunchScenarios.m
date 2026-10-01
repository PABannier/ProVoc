//
//  PVLaunchScenarios.m
//
//  Launching the application: alone, with a document, in each language.
//

#import "PVDriver.h"

@interface PVScenarios (Launch)
@end

@implementation PVScenarios (Launch)

-(NSWindow *)startingPointWindow
{
	return [[NSClassFromString(@"ProVocStartingPoint") performSelector:@selector(defaultStartingPoint)] window];
}

-(NSButton *)buttonWithAction:(SEL)inAction inView:(NSView *)inView
{
	if ([inView isKindOfClass:[NSButton class]] && [(NSButton *)inView action] == inAction)
		return (NSButton *)inView;
	for (NSView *subview in [inView subviews]) {
		NSButton *button = [self buttonWithAction:inAction inView:subview];
		if (button)
			return button;
	}
	return nil;
}

// File > Open Recent > Clear Menu, so that the next launch has no document to reopen
-(void)clearRecentDocuments:(PVScript *)inScript
{
	[inScript then:^{
		NSMenuItem *item = [PVScenarios menuItemWithAction:@selector(clearRecentDocuments:)];
		PVExpect(item != nil, @"no Clear Menu item in File > Open Recent");
		[[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]];
	}];
	[inScript wait:@"no recent document" until:^BOOL { return [[[NSDocumentController sharedDocumentController] recentDocumentURLs] count] == 0; }];
}

// Launched without document and with factory settings: the principal class is in place
// and the starting point window offers to create, open or download a document.
-(void)launch:(PVScript *)inScript
{
	NSWindow *(^startingPoint)(void) = ^{ return [self startingPointWindow]; };
	// (shown once the About window of a first launch has gone, and drawn on the screen)
	[inScript wait:@"the starting point window" timeout:15 until:^BOOL {
		return [startingPoint() isKeyWindow] && ([startingPoint() occlusionState] & NSWindowOcclusionStateVisible) && ![startingPoint() viewsNeedDisplay];
	}];
	[inScript then:^{
		PVExpectEqualObjects([NSApp className], @"ProVocApplication", @"NSPrincipalClass");
		PVExpectEqual([[[NSDocumentController sharedDocumentController] documents] count], 0, @"no document yet");
		PVExpect([[[NSApp mainMenu] itemArray] count] >= 6, @"main menu: %@", [[[NSApp mainMenu] itemArray] valueForKey:@"title"]);
		PVSaveWindowScreenshot(startingPoint(), @"windows/starting-point");
		// "Download": the web site is gone, an alert says so
		PVClickView([self buttonWithAction:@selector(downloadDocument:) inView:[startingPoint() contentView]], 1, 0);
	}];
	[inScript wait:@"the alert about the web site" until:^BOOL { return [[NSApp modalWindow] isKeyWindow] && [NSApp modalWindow] != startingPoint(); }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the alert to close" until:^BOOL { return [NSApp modalWindow] == nil && [startingPoint() isKeyWindow]; }];
	// "Open": the open panel; Esc comes back to the starting point
	[inScript then:^{ PVClickView([self buttonWithAction:NSSelectorFromString(@"openDocument:") inView:[startingPoint() contentView]], 1, 0); }];
	[inScript wait:@"the open panel" timeout:15 until:^BOOL { return [[NSApp keyWindow] isKindOfClass:[NSOpenPanel class]]; }];
	// (the panel is drawn by another process: it is answered through its object, see PVDocumentScenarios.m)
	[inScript then:^{
		NSOpenPanel *panel = (NSOpenPanel *)[NSApp keyWindow];
		NSArray *types = [[panel allowedFileTypes] valueForKey:@"lowercaseString"];
		PVExpect([types containsObject:@"pvoc"] && [types containsObject:@"provoc"], @"the open panel should offer .pvoc and .provoc documents: %@", types);
		[panel cancel:nil];
	}];
	[inScript wait:@"the starting point again after Cancel" timeout:10 until:^BOOL { return ![[NSApp keyWindow] isKindOfClass:[NSOpenPanel class]] && [startingPoint() isKeyWindow]; }];
	// "New": an untitled document
	[inScript then:^{ PVClickView([self buttonWithAction:NSSelectorFromString(@"newDocument:") inView:[startingPoint() contentView]], 1, 0); }];
	[inScript wait:@"an untitled document window" until:^BOOL { return [[PVScenarios document] isKindOfClass:[ProVocDocument class]] && [[[PVScenarios document] window] isKeyWindow]; }];
	[inScript then:^{
		PVExpect(![startingPoint() isVisible], @"the starting point window stays");
		PVExpect([[PVScenarios document] fileURL] == nil, @"the document should be untitled");
		PVExpect(![[PVScenarios document] isDocumentEdited], @"a new document should not be edited");
	}];
}

@end
