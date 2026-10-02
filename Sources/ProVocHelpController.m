//
//  ProVocHelpController.m
//  ProVoc
//

#import "ProVocHelpController.h"

#import <WebKit/WebKit.h>

@implementation ProVocHelpController

+(ProVocHelpController *)sharedController
{
	static ProVocHelpController *sharedController = nil;
	if (!sharedController)
		sharedController = [[self alloc] init];
	return sharedController;
}

-(id)init
{
	NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 780, 600)
						styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
						backing:NSBackingStoreBuffered defer:YES] autorelease];
	if (self = [super initWithWindow:window]) {
		[window setTitle:NSLocalizedString(@"Help Window Title", @"")];
		[window setFrameAutosaveName:@"ProVocHelp"];
		[window setReleasedWhenClosed:NO];
		mWebView = [[WKWebView alloc] initWithFrame:[[window contentView] bounds]];
		[mWebView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[mWebView setAllowsBackForwardNavigationGestures:YES];
		[mWebView setAccessibilityIdentifier:@"HelpWebView"];
		[[window contentView] addSubview:mWebView];
		[window center];
	}
	return self;
}

-(void)dealloc
{
	[mWebView release];
	[super dealloc];
}

-(void)showPage:(NSString *)inName
{
	NSString *path = [[NSBundle mainBundle] pathForResource:inName ofType:@"html" inDirectory:@"ProVoc Help"];
	if (!path) {
		NSBeep();
		NSLog(@"ProVoc: help page %@ not found", inName);
		return;
	}
	NSURL *url = [NSURL fileURLWithPath:path];
	[mWebView loadFileURL:url allowingReadAccessToURL:[url URLByDeletingLastPathComponent]];
	[self showWindow:nil];
}

@end
