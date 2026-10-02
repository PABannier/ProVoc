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
#import "ProVocInspector.h"
#import "ProVocStartingPoint.h"
#import "ARAboutDialog.h"

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
