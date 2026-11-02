//
//  ProVocVisualTests.m
//
//  Takes real screenshots of the main windows (as composited on screen) so that
//  blank panels, clipped layouts and wrong colors can be looked at, and checks
//  that nothing is blank.
//

#import <XCTest/XCTest.h>
#import "PVTestSupport.h"
#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocPreferences.h"
#import "ProVocTester.h"
#import "ProVocInspector.h"
#import "ProVocStartingPoint.h"
#import "ARAboutDialog.h"
#import "ProVocBoxesSheet.h"

@interface ProVocVisualTests : XCTestCase
@end

@implementation ProVocVisualTests

-(void)shoot:(NSWindow *)inWindow as:(NSString *)inName
{
	XCTAssertNotNil(inWindow, @"%@: no window", inName);
	XCTAssertTrue([inWindow isVisible], @"%@ is not on screen", inName);
	[inWindow display];
	PVWaitUntil(0.4, ^BOOL { return NO; });
	NSBitmapImageRep *bitmap = PVSaveWindowScreenshot(inWindow, [@"windows/" stringByAppendingString:inName]);
	XCTAssertNotNil(bitmap, @"%@", inName);
	XCTAssertTrue(PVNumberOfDistinctColors(bitmap) >= 3, @"%@ looks blank", inName);
	// ProVoc keeps its light appearance whatever the system appearance is (its nibs and
	// custom views were drawn for it): the windows must not come out dark.
	NSArray *appearances = @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua];
	XCTAssertEqualObjects([[inWindow effectiveAppearance] bestMatchFromAppearancesWithNames:appearances], NSAppearanceNameAqua, @"%@", inName);
}

-(void)testBoxesSheetAndTestPanelRender
{
	PVWaitUntil(10, ^BOOL { return [NSApp isActive]; });
	PVResetPreferences();
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PVDimTestBackground];
	ProVocDocument *document = PVNewDocumentWithWords(@[]);
	[document setValue:@NO forKey:@"testMCQ"];
	[document setValue:@NO forKey:@"initialSlideshow"];
	[document setValue:@0 forKey:@"timer"];
	[document setMainTab:1];
	[document addBoxesOnImageFile:PVMediaFile(@"png") row:0];
	NSWindow *sheet = [[document window] attachedSheet];
	PVWaitUntil(0.5, ^BOOL { return NO; });
	[self shoot:sheet as:@"boxes-sheet"];
	[sheet orderOut:nil];
	[NSApp endSheet:sheet];
	PVWaitUntil(0.5, ^BOOL { return NO; });
	NSArray *boxes = @[[NSMutableDictionary dictionaryWithDictionary:@{@"rect": [NSValue valueWithRect:NSMakeRect(0.1, 0.1, 0.4, 0.3)], @"answer": @"one"}],
					   [NSMutableDictionary dictionaryWithDictionary:@{@"rect": [NSValue valueWithRect:NSMakeRect(0.1, 0.6, 0.4, 0.3)], @"answer": @"two"}]];
	[document applyBoxes:boxes title:@"Picture" showOthers:NO imageFile:PVMediaFile(@"png") row:0 oldWords:nil];
	[document startTest:nil];
	id tester = [document valueForKey:@"mTester"];
	PVWaitUntil(0.8, ^BOOL { return NO; });
	[self shoot:[tester valueForKey:@"testPanel"] as:@"boxes-test-panel"];
	[tester performSelector:@selector(closePanelWithCode:) withObject:nil];
	PVWaitUntil(0.5, ^BOOL { return NO; });
	PVCloseDocument(document);
}

-(void)testMainWindowsRender
{
	PVWaitUntil(10, ^BOOL { return [NSApp isActive]; });
	ProVocDocument *document = PVNewDocumentWithWords(@[@[@"house", @"maison", @"a building"], @[@"cat", @"chat"], @[@"dog", @"chien"], @[@"summer", @"été"], @[@"to be", @"être", @"irregular"]]);
	PVWaitUntil(1, ^BOOL { return NO; });
	[document setMainTab:1];
	[self shoot:[document window] as:@"document-editing"];
	[document setMainTab:0];
	[self shoot:[document window] as:@"document-training"];
	[document setValue:@YES forKey:@"editingPreset"];
	[self shoot:[document window] as:@"document-training-editing-preset"];
	[document setMainTab:2];
	[self shoot:[document window] as:@"document-history"];
	[document setMainTab:1];

	ProVocPreferences *preferences = [ProVocPreferences sharedPreferences];
	[preferences showWindow:nil];
	for (unsigned pane = 0; pane < 5; pane++) {
		[preferences selectPaneAtIndex:pane];
		PVWaitUntil(0.6, ^BOOL { return NO; });
		[self shoot:[preferences window] as:[NSString stringWithFormat:@"preferences-%u", pane]];
	}
	[[preferences window] orderOut:nil];

	ProVocInspector *inspector = [ProVocInspector sharedInspector];
	if (![inspector isVisible])
		[inspector toggle];
	NSTableView *wordTable = [document valueForKey:@"mWordTableView"];
	[wordTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	PVWaitUntil(0.5, ^BOOL { return NO; });
	[self shoot:[inspector window] as:@"inspector"];
	[inspector toggle];

	[[ARAboutDialog sharedAboutDialog] show:nil];
	[self shoot:[[ARAboutDialog sharedAboutDialog] window] as:@"about"];
	[[ARAboutDialog sharedAboutDialog] hide:nil];

	PVCloseDocument(document);
}

@end
