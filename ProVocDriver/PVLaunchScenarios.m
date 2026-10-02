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

#import <AVFoundation/AVFoundation.h>

@interface PVScenarios (Capture)
@end

@implementation PVScenarios (Capture)

// scripts/request-capture-access.sh: makes macOS ask (once) whether ProVoc may use the
// microphone and the camera, and waits for the answers. Someone has to click "Allow".
-(void)requestCaptureAccess:(PVScript *)inScript
{
	__block int answers = 0;
	[inScript then:^{
		for (NSString *type in @[AVMediaTypeAudio, AVMediaTypeVideo]) {
			NSLog(@"PVDriver: %@ access status %ld", type, (long)[AVCaptureDevice authorizationStatusForMediaType:type]);
			[AVCaptureDevice requestAccessForMediaType:type completionHandler:^(BOOL inGranted) {
				dispatch_async(dispatch_get_main_queue(), ^{
					NSLog(@"PVDriver: %@ access %@", type, inGranted ? @"granted" : @"refused");
					answers++;
				});
			}];
		}
	}];
	[inScript wait:@"the answers to the two questions of macOS (microphone, camera)" timeout:110 until:^BOOL { return answers == 2; }];
	[inScript then:^{
		PVExpectEqual([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio], AVAuthorizationStatusAuthorized, @"the microphone is not allowed for ProVoc (System Settings > Privacy & Security > Microphone)");
		PVExpectEqual([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo], AVAuthorizationStatusAuthorized, @"the camera is not allowed for ProVoc (System Settings > Privacy & Security > Camera)");
	}];
}

// The proof that an exception cannot go unnoticed (scripts/e2e.py --self-test-exception,
// run by scripts/verify.sh): an exception is raised from the event loop of the
// application; the scenario itself ends well, but the runner must fail because of
// what the application logged.
-(void)raiseOnPurpose:(PVScript *)inScript
{
	__block BOOL raised = NO;
	[inScript then:^{
		[[NSRunLoop currentRunLoop] performInModes:@[NSRunLoopCommonModes] block:^{
			raised = YES;
			[NSException raise:@"PVSelfTestException" format:@"raised on purpose by the self-test of the log scan"];
		}];
	}];
	[inScript wait:@"the raise" until:^BOOL { return raised; }];
	[inScript pause:0.5];
}

// Only reads the two authorizations (nothing is asked)
-(void)captureAccessStatus:(PVScript *)inScript
{
	[inScript then:^{
		NSString *status = [NSString stringWithFormat:@"microphone %ld camera %ld (0 = never asked, 2 = refused, 3 = allowed); microphones %lu, cameras %lu\n",
							(long)[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio], (long)[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo],
							(unsigned long)([AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] != nil), (unsigned long)([AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] != nil)];
		NSLog(@"PVDriver: %@", status);
		[status writeToFile:[[PVScenarios workDirectory] stringByAppendingPathComponent:@"capture-status.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}];
}

@end
