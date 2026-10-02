//
//  ProVocAppFeatureTests.m
//
//  The About window, the help book, the "Translate with ProVoc" service, the Spotlight
//  search of the application, and the commands whose purpose is gone (iPod, updates,
//  the Arizona Software web site and server, the Dashboard widget): each one still
//  does something sensible and says what to use instead.
//

#import "PVScenarioTestCase.h"
#import <WebKit/WebKit.h>
#import "ARAboutDialog.h"
#import "ProVocHelpController.h"
#import "ProVocServiceProvider.h"
#import "ProVocSpotlighter.h"

// (what the service provider implements; its header declares nothing)
@interface ProVocServiceProvider (Tested)
-(void)translate:(NSPasteboard *)inPasteboard userData:(NSString *)inUserData error:(NSString **)outError;
-(NSArray *)translationsOfString:(NSString *)inString withDocumentAtPath:(NSString *)inPath;
@end

@interface ProVocAppFeatureTests : PVScenarioTestCase
@end

@implementation ProVocAppFeatureTests

// Chooses a menu item from the event loop (the command may run a modal window, and the
// script that follows must go on meanwhile).
-(void)chooseLater:(NSString *)inAction
{
	[self chooseMenuItemWithAction:NSSelectorFromString(inAction) tag:0];
}

-(void)choose:(SEL)inAction in:(PVScript *)inScript
{
	[inScript then:^{ [self performSelector:@selector(chooseLater:) withObject:NSStringFromSelector(inAction) afterDelay:0.0 inModes:@[NSRunLoopCommonModes]]; }];
}

// An alert on screen: the modal window, or the sheet of the document
-(NSWindow *)alert
{
	NSWindow *window = [NSApp modalWindow] ?: [[mDocument window] attachedSheet];
	return [window isVisible] ? window : nil;
}

-(void)expectAlertSaying:(NSArray *)inKeys dismissedWith:(unsigned short)inKeyCode in:(PVScript *)inScript
{
	NSMutableArray *texts = [NSMutableArray array];
	for (NSString *key in inKeys) {
		NSString *text = NSLocalizedString(key, @"");
		XCTAssertFalse([text isEqualToString:key], @"%@ is not localized", key);
		// (a format: what precedes its first argument)
		[texts addObject:[[text componentsSeparatedByString:@"%@"] objectAtIndex:0]];
	}
	[inScript wait:[NSString stringWithFormat:@"an alert saying \"%@\"", texts[0]] timeout:10 until:^BOOL {
		NSString *shown = PVTextOfWindow([self alert]);
		for (NSString *text in texts)
			if ([shown rangeOfString:text].location == NSNotFound)
				return NO;
		return [[self alert] isKeyWindow];
	}];
	[inScript then:^{
		PVSaveWindowScreenshot([self alert], [NSString stringWithFormat:@"windows/alert-%@", [[inKeys[0] lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"-"]]);
		PVPostKey(inKeyCode, nil, 0);
	}];
	[inScript wait:@"the alert to close" until:^BOOL { return [self alert] == nil && [[mDocument window] isKeyWindow]; }];
}

#pragma mark About and Help

// About ProVoc: the credits scroll by themselves; any key closes the window.
-(void)testAboutWindowScrollsItsCredits
{
	NSWindow *(^about)(void) = ^{ return [[ARAboutDialog sharedAboutDialog] window]; };
	NSScrollView *(^credits)(void) = ^{ return (NSScrollView *)[[ARAboutDialog sharedAboutDialog] valueForKey:@"mCreditsScroll"]; };
	__block CGFloat firstOffset = 0;
	PVScript *script = [PVScript script];
	// (the same window is shown for three seconds when the application starts)
	[script wait:@"the About window of the launch to go away" timeout:10 until:^BOOL { return ![about() isVisible]; }];
	[self choose:@selector(orderFrontStandardAboutPanel:) in:script];
	[script wait:@"the About window" until:^BOOL { return [about() isVisible] && [about() alphaValue] == 1; }];
	[script then:^{
		XCTAssertTrue([[[(NSTextView *)[credits() documentView] textStorage] string] length] > 100, @"no credits in the About window");
		XCTAssertTrue(NSHeight([[credits() documentView] frame]) > NSHeight([credits() frame]), @"nothing to scroll");
		PVSaveWindowScreenshot(about(), @"windows/about-start");
	}];
	// the credits wait two seconds, then scroll at 20 points per second
	[script wait:@"the credits to start scrolling" timeout:8 until:^BOOL { firstOffset = [[credits() contentView] bounds].origin.y; return firstOffset > 5; }];
	[script wait:@"the credits to go on scrolling" timeout:8 until:^BOOL { return [[credits() contentView] bounds].origin.y > firstOffset + 20; }];
	[script then:^{
		PVSaveWindowScreenshot(about(), @"windows/about-scrolled");
		PVPostKey(PVKeySpace, @" ", 0);
	}];
	[script wait:@"a key to close the About window" until:^BOOL { return ![about() isVisible] && [[mDocument window] isKeyWindow]; }];
	[self runScript:script];
}

// Command-? opens the help book of the application (its own pages, in a window of the
// application: Help Viewer cannot open a help book of 2008); Discover ProVoc Features
// shows the quick tour.
-(void)testHelpOpensTheLocalHelpBook
{
	ProVocHelpController *help = [ProVocHelpController sharedController];
	WKWebView *(^webView)(void) = ^{ return (WKWebView *)[help valueForKey:@"mWebView"]; };
	// the text shown by the page (asked again until it has what is expected: a page is laid out a moment after it is loaded)
	__block NSString *text = nil;
	__block BOOL reading = NO;
	BOOL (^pageSays)(NSString *) = ^BOOL(NSString *expected) {
		if ([text rangeOfString:expected].location != NSNotFound)
			return YES;
		if (!reading) {
			reading = YES;
			[webView() evaluateJavaScript:@"document.body.innerText" completionHandler:^(id inResult, NSError *inError) {
				[text release];
				text = [[inResult description] copy];
				reading = NO;
			}];
		}
		return NO;
	};
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"?", 0); }];
	[script wait:@"the help window with the first page of the help book (Command-?)" timeout:15 until:^BOOL {
		return [[help window] isKeyWindow] && ![webView() isLoading] && [[[webView() URL] path] hasSuffix:@"ProVoc Help/index.html"];
	}];
	[script wait:@"the first page of the help book to show its links" timeout:10 until:^BOOL { return pageSays(@"Quick Tour") && pageSays(@"Shortcuts") && pageSays(@"ProVoc Help"); }];
	[script then:^{
		XCTAssertTrue([[[webView() URL] path] hasPrefix:[[NSBundle mainBundle] bundlePath]], @"the help page is not in the application: %@", [webView() URL]);
		XCTAssertEqualObjects([[help window] title], NSLocalizedString(@"Help Window Title", @""));
		PVSaveWindowScreenshot([help window], @"windows/help");
		[text release];
		text = nil;
		[[mDocument window] makeKeyAndOrderFront:nil];
	}];
	[self choose:@selector(discoverProvoc:) in:script];
	[script wait:@"the quick tour (Discover ProVoc Features)" timeout:15 until:^BOOL {
		return [[help window] isKeyWindow] && ![webView() isLoading] && [[[webView() URL] lastPathComponent] isEqualToString:@"quicktour.html"];
	}];
	[script wait:@"the text of the quick tour" timeout:10 until:^BOOL { return pageSays(@"Easily repeat your vocabulary with ProVoc") && pageSays(@"Enter your words"); }];
	// every page the help book links to from its first page is in the application
	[script then:^{
		NSString *directory = [[[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"ProVoc Help"] stringByDeletingLastPathComponent];
		NSString *index = [NSString stringWithContentsOfFile:[directory stringByAppendingPathComponent:@"index.html"] usedEncoding:NULL error:NULL];
		NSRegularExpression *links = [NSRegularExpression regularExpressionWithPattern:@"href=\"([^\"#:]+\\.html)" options:NSRegularExpressionCaseInsensitive error:NULL];
		NSArray *matches = [links matchesInString:index options:0 range:NSMakeRange(0, [index length])];
		XCTAssertTrue([matches count] > 0, @"no link in the first page of the help book");
		for (NSTextCheckingResult *match in matches) {
			NSString *page = [[index substringWithRange:[match rangeAtIndex:1]] stringByRemovingPercentEncoding];
			XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:[directory stringByAppendingPathComponent:page]], @"the help page %@ is missing", page);
		}
		PVTypeCommand(@"w", 0);
	}];
	[script wait:@"Command-W to close the help window" until:^BOOL { return ![[help window] isVisible] && [[mDocument window] isKeyWindow]; }];
	[self runScript:script];
	[text release];
}

#pragma mark Service

// "Translate with ProVoc" (Services menu): declared in Info.plist, provided by the
// application, translates the text of the pasteboard with the open documents, then the
// recent ones.
-(void)testTranslationService
{
	NSArray *services = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"NSServices"];
	XCTAssertEqual([services count], 1u);
	NSDictionary *service = [services firstObject];
	XCTAssertEqualObjects(service[@"NSMessage"], @"translate");
	XCTAssertEqualObjects(service[@"NSPortName"], @"ProVoc");
	XCTAssertEqualObjects(service[@"NSMenuItem"][@"default"], @"Translate with ProVoc");
	XCTAssertTrue([service[@"NSSendTypes"] containsObject:@"NSStringPboardType"] && [service[@"NSReturnTypes"] containsObject:@"NSStringPboardType"]);
	// the provider that AppKit calls for the message "translate" (-translate:userData:error:)
	ProVocServiceProvider *provider = [NSApp servicesProvider];
	XCTAssertTrue([provider isKindOfClass:[ProVocServiceProvider class]], @"the services provider is %@", provider);
	XCTAssertTrue([provider respondsToSelector:@selector(translate:userData:error:)]);

	NSString *(^translate)(NSString *, NSString **) = ^(NSString *text, NSString **outError) {
		NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
		[pasteboard declareTypes:@[NSPasteboardTypeString] owner:nil];
		[pasteboard setString:text forType:NSPasteboardTypeString];
		NSString *error = nil;
		[provider translate:pasteboard userData:nil error:&error];
		if (outError)
			*outError = error;
		NSString *result = error ? nil : [pasteboard stringForType:NSPasteboardTypeString];
		[pasteboard releaseGlobally];
		return result;
	};
	NSString *error = nil;
	// with the front document, in both directions, as tolerant as a test
	XCTAssertEqualObjects(translate(@"house", &error), @"maison", @"%@", error);
	XCTAssertEqualObjects(translate(@"Chien", NULL), @"dog");
	XCTAssertEqualObjects(translate(@"été", NULL), @"summer");
	[[self wordWithSource:@"cat"] setTargetWord:@"chat / minet"];	// (the separator of synonyms of the preferences)
	XCTAssertTrue([translate(@"cat", NULL) rangeOfString:@"chat"].location != NSNotFound && [translate(@"cat", NULL) rangeOfString:@"minet"].location != NSNotFound, @"%@", translate(@"cat", NULL));
	XCTAssertEqualObjects(translate(@"minet", NULL), @"cat");

	// with a recent document that is not open
	ProVocDocument *rich = PVOpenCopyOfDeck([PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated/Plain.pvoc"]);
	XCTAssertNotNil(rich);
	NSURL *url = [[[rich fileURL] retain] autorelease];
	PVCloseDocument(rich);
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];
	NSArray *(^recentPaths)(void) = ^{ return [[[[NSDocumentController sharedDocumentController] recentDocumentURLs] valueForKey:@"path"] valueForKey:@"stringByResolvingSymlinksInPath"]; };
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [recentPaths() containsObject:[[url path] stringByResolvingSymlinksInPath]]; }), @"the deck is not a recent document: %@", recentPaths());
	XCTAssertEqualObjects(translate(@"bread", &error), @"pain", @"with a recent document: %@", error);
	[[NSDocumentController sharedDocumentController] clearRecentDocuments:nil];
}

#pragma mark Spotlight

// The search of the application in the Spotlight index (for the service, when no open
// or recent document has the word): a panel says that ProVoc is searching, the query
// ends, and the documents found are ProVoc documents that contain the text. A document
// opened from a Spotlight search shows the words searched for.
-(void)testSpotlightSearch
{
	__block NSArray *found = nil;
	__block BOOL done = NO;
	__block ProVocSpotlighter *spotlighter = nil;
	PVScript *script = [PVScript script];
	[script then:^{
		dispatch_block_t search = ^{
			spotlighter = [[ProVocSpotlighter alloc] init];
			found = [[spotlighter allProVocFilesContaining:@"maison"] retain];
			done = YES;
		};
		[[NSRunLoop currentRunLoop] performInModes:@[NSRunLoopCommonModes] block:search];
	}];
	[script wait:@"the search panel while Spotlight is queried" timeout:10 until:^BOOL { return done || [[NSApp modalWindow] isVisible]; }];
	[script then:^{
		if (!done) {
			XCTAssertEqualObjects([[NSApp modalWindow] windowController], spotlighter);
			PVSaveWindowScreenshot([NSApp modalWindow], @"windows/spotlight-search");
		}
	}];
	[script wait:@"the end of the Spotlight query" timeout:60 until:^BOOL { return done && [NSApp modalWindow] == nil; }];
	[script then:^{
		XCTAssertNotNil(found, @"the search was cancelled");
		NSLog(@"ProVocSpotlighter found %lu document(s) with \"maison\"", (unsigned long)[found count]);
		ProVocServiceProvider *provider = [NSApp servicesProvider];
		for (NSString *path in found) {
			XCTAssertEqualObjects([path pathExtension], @"pvoc", @"Spotlight found something that is not a ProVoc document: %@", path);
			XCTAssertNotNil([provider translationsOfString:@"maison" withDocumentAtPath:path], @"%@ does not contain the word searched for", path);
		}
		// what a document opened from a Spotlight result does with the text searched for
		[mDocument setSpotlightSearch:@"maison"];
	}];
	[script wait:@"the document to show the word searched for" until:^BOOL {
		NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
		return [[[mDocument valueForKey:@"mSearchField"] stringValue] isEqualToString:@"maison"] && [table numberOfRows] == 1 && [[mDocument valueForKey:@"mainTab"] intValue] == 1;
	}];
	[self runScript:script];
	[found release];
	[spotlighter release];
}

#pragma mark What is gone

// Send to iPod (Option-Command-I): notes cannot be sent to an iPod any more; the sheet
// says so and offers to export the vocabulary.
-(void)testSendToiPodOffersToExport
{
	PVScript *script = [PVScript script];
	XCTAssertFalse([[mDocument valueForKey:@"iPodConnected"] boolValue]);
	[script then:^{ PVTypeCommand(@"i", NSEventModifierFlagOption); }];
	[self expectAlertSaying:@[@"iPod Obsolete Title", @"iPod Obsolete Message", @"iPod Obsolete Export Button"] dismissedWith:PVKeyEscape in:script];
	[script then:^{ PVTypeCommand(@"i", NSEventModifierFlagOption); }];
	[script wait:@"the sheet again" until:^BOOL { return [[self alert] isKeyWindow] && [[[self alert] defaultButtonCell] isEnabled]; }];
	// Return: Export...
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the export panel" timeout:15 until:^BOOL { return [[[mDocument window] attachedSheet] isKindOfClass:[NSSavePanel class]]; }];
	[script then:^{ [(NSSavePanel *)[[mDocument window] attachedSheet] cancel:nil]; }];
	[script wait:@"the export panel to close" timeout:10 until:^BOOL { return [[mDocument window] attachedSheet] == nil && [[mDocument window] isKeyWindow]; }];
	[self runScript:script];
}

// Check for Updates and the commands that opened pages of the Arizona Software web site
-(void)testUpdateAndWebSiteCommandsExplainThemselves
{
	PVScript *script = [PVScript script];
	[self choose:@selector(checkForUpdates:) in:script];
	[self expectAlertSaying:@[@"Updates Obsolete Title", @"Updates Obsolete Message (v=%@)"] dismissedWith:PVKeyReturn in:script];
	[script then:^{ XCTAssertTrue([[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] length] > 0); }];
	for (NSArray *command in @[@[@"visitHomepage:", @"Web Site Gone Homepage Message"], @[@"reportBug:", @"Web Site Gone Feedback Message"], @[@"downloadDocuments:", @"Web Site Gone Vocabulary Message"]]) {
		[self choose:NSSelectorFromString(command[0]) in:script];
		[self expectAlertSaying:@[@"Web Site Gone Title", command[1]] dismissedWith:PVKeyReturn in:script];
	}
	[self runScript:script];
}

// Submit Document: the server is gone; the sheet says so. (With a saved document it
// offers to show the file in the Finder: see the scenario obsoleteSubmitRevealsTheFile
// of the stand-alone suite, which ends in the Finder.)
-(void)testSubmitDocumentExplainsItself
{
	PVScript *script = [PVScript script];
	[script then:^{
		NSMenuItem *item = [self menuItemWithAction:@selector(submitDocument:) tag:0];
		PVPrepareMenu([item menu]);
		XCTAssertTrue([item isEnabled], @"Submit Document is disabled with a document in front");
	}];
	[self choose:@selector(submitDocument:) in:script];
	[self expectAlertSaying:@[@"Submit Obsolete Title", @"Submit Obsolete Message"] dismissedWith:PVKeyReturn in:script];
	[script then:^{ XCTAssertNil([[mDocument window] attachedSheet]); }];
	[self runScript:script];
}

// The log of the Dashboard widget (Widget.log in the document): Dashboard is gone, but a
// document that has such a log still gets the answers given in the widget.
-(void)testWidgetLogOfADocumentIsStillRead
{
	NSString *deck = PVTemporaryCopyOfDeck([PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated/Plain.pvoc"]);
	NSString *log = @"WidgetLog v1.0\n2008-03-01 10:00:00 +0100 = 1 1\n2008-03-01 10:00:20 +0100 = 2 0\n2008-03-01 10:00:40 +0100 = 2 1\n";
	XCTAssertTrue([log writeToFile:[deck stringByAppendingPathComponent:@"Widget.log"] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
	__block ProVocDocument *document = nil;
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:deck] display:YES completionHandler:^(NSDocument *inDocument, BOOL inWasOpen, NSError *inError) { document = (ProVocDocument *)[inDocument retain]; }];
	XCTAssertTrue(PVWaitUntil(20, ^BOOL { return document != nil; }), @"the deck did not open");
	NSArray *words = [document allWords];
	XCTAssertEqual([words[0] right], 1, @"first word: a right answer in the widget");
	XCTAssertEqual([words[0] wrong], 0);
	XCTAssertEqual([words[1] right], 1, @"second word: wrong, then right");
	XCTAssertEqual([words[1] wrong], 1);
	XCTAssertEqual([words[2] right] + [words[2] wrong], 0, @"third word: not asked by the widget");
	XCTAssertEqualObjects([words[0] valueForKey:@"lastAnswered"], [NSDate dateWithString:@"2008-03-01 10:00:00 +0100"]);
	// ... and a history of that session of the widget
	XCTAssertEqual([[document valueForKey:@"mHistories"] count], 1u, @"the history of the widget session");
	PVCloseDocument(document);
	[document release];
	// no offer to download the widget any more: nothing but the document windows at launch (scenario launch of the stand-alone suite)
	XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"IgnoreWidgetInstall"]);
}

@end
