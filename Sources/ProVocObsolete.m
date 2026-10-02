//
//  ProVocObsolete.m
//  ProVoc
//
//  What is left of two features that cannot exist any more: sending notes to an
//  iPod (no Mac mounts an iPod with the Notes feature today) and the update check
//  against the Arizona Software server (gone). The nibs of every localization still
//  contain their controls, so the outlets, bindings and actions are kept alive here:
//  the iPod controls stay hidden as they always were when no iPod was plugged in,
//  and the menu commands say what to use instead.
//

#import "ProVocDocument.h"
#import "ProVocPreferences.h"
#import "ProVocAppDelegate.h"

@implementation ProVocDocument (iPod)

-(BOOL)iPodConnected
{
	return NO;
}

-(NSImage *)sendToiPodImage
{
	return nil;
}

-(IBAction)sendToiPod:(id)inSender
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:NSLocalizedString(@"iPod Obsolete Title", @"")];
	[alert setInformativeText:NSLocalizedString(@"iPod Obsolete Message", @"")];
	[alert addButtonWithTitle:NSLocalizedString(@"iPod Obsolete Export Button", @"")];
	[alert addButtonWithTitle:NSLocalizedString(@"iPod Obsolete Cancel Button", @"")];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\033"];
	[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse inResponse) {
		if (inResponse == NSAlertFirstButtonReturn)
			[self performSelector:@selector(export:) withObject:nil afterDelay:0.0];
	}];
}

-(IBAction)displayiPodPreferences:(id)inSender
{
	[self sendToiPod:inSender];
}

-(IBAction)ejectiPod:(id)inSender
{
}

@end

@implementation ProVocPreferences (iPod)

-(BOOL)iPodConnected
{
	return NO;
}

-(BOOL)tooManyiPodNotes
{
	return NO;
}

-(int)iPodTotal
{
	return 0;
}

-(int)iPodContentCount
{
	return 0;
}

-(void)setIPodContentCount:(int)inCount
{
}

-(BOOL)canDeleteSelectediPodContent
{
	return NO;
}

-(IBAction)deleteSelectediPodContent:(id)inSender
{
}

-(IBAction)deleteiPodNotes:(id)inSender
{
}

-(IBAction)removeUnusedAudio:(id)inSender
{
}

-(IBAction)updateiPodIndex:(id)inSender
{
}

-(NSInteger)outlineView:(NSOutlineView *)inOutlineView numberOfChildrenOfItem:(id)inItem
{
	return 0;
}

-(id)outlineView:(NSOutlineView *)inOutlineView child:(NSInteger)inIndex ofItem:(id)inItem
{
	return nil;
}

-(BOOL)outlineView:(NSOutlineView *)inOutlineView isItemExpandable:(id)inItem
{
	return NO;
}

-(id)outlineView:(NSOutlineView *)inOutlineView objectValueForTableColumn:(NSTableColumn *)inTableColumn byItem:(id)inItem
{
	return nil;
}

@end

@implementation ProVocAppDelegate (Updates)

-(IBAction)checkForUpdates:(id)inSender
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:NSLocalizedString(@"Updates Obsolete Title", @"")];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Updates Obsolete Message (v=%@)", @""), [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"]]];
	[alert runModal];
}

@end
