//
//  ProVocStartingPoint.m
//  ProVoc
//
//  Created by Simon Bovet on 07.05.06.
//  Copyright 2006 Arizona Software. All rights reserved.
//

#import "ProVocStartingPoint.h"

#import "ProVocAppDelegate.h"
#import "ARAboutDialog.h"
#import "ProVocInspector.h"

@implementation ProVocStartingPoint

+(ProVocStartingPoint *)defaultStartingPoint
{
	static ProVocStartingPoint *startingPoint = nil;
	if (!startingPoint)
		startingPoint = [[self alloc] init];
	return startingPoint;
}

-(id)init
{
	if (self = [super initWithWindowNibName:@"ProVocStartingPoint"]) {
		[self loadWindow];
	}
	return self;
}

-(void)idle
{
	if ([[[NSDocumentController sharedDocumentController] documents] count] == 0 && [[NSUserDefaults standardUserDefaults] boolForKey:ProVocShowStartingPoint]) {
		if ([[[ARAboutDialog sharedAboutDialog] window] isVisible])
			[self performSelector:_cmd withObject:nil afterDelay:0.5];
		else {
			[[ProVocInspector sharedInspector] setPreferredDisplayState:NO];
			[[self window] center];
			[[self window] makeKeyAndOrderFront:nil];
		}
	} else
		[[self window] orderOut:nil];
}

-(void)hide
{
	[[self window] orderOut:nil];
}

-(IBAction)newDocument:(id)inSender
{
	[self hide];
	[[NSDocumentController sharedDocumentController] newDocument:nil];
}

-(IBAction)openDocument:(id)inSender
{
	[self hide];
	// The open panel no longer blocks until it is closed: the starting point comes back
	// when the panel ends without document (see -[ProVocAppDelegate beginOpenPanelWithCompletionHandler:]).
	[[NSDocumentController sharedDocumentController] openDocument:nil];
}

-(IBAction)downloadDocument:(id)inSender
{
	[[NSApp delegate] downloadDocuments:nil];
}

@end
