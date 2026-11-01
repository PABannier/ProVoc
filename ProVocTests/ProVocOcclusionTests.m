//
//  ProVocOcclusionTests.m
//
//  Boxes on a picture: one word per box. These tests call the actions of the windows
//  directly and do not need the keyboard; ProVocOcclusionScenarioTests types.
//

#import "PVScenarioTestCase.h"
#import "ProVocBoxesSheet.h"
#import "ProVocInspector.h"
#import "ProVocMCQView.h"
#import "ProVocMCQTester.h"
#import "ProVocPage.h"
#import "ProVocData.h"
#import "ArchiverExtensions.h"

@interface ProVocTester (Boxes)
-(IBAction)verifyTestPanel:(id)inSender;
-(NSImage *)image;
-(void)closePanelWithCode:(int)inCode;
@end

@interface ProVocOcclusionTests : XCTestCase {
	ProVocDocument *mDocument;
}
@end

// A picture of 640 x 440 points, white, with one label of its own color per box
static NSString *PVBoxesPicture(void)
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVCascade-%i.png", [[NSProcessInfo processInfo] processIdentifier]]];
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:640 pixelsHigh:440 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
		[[NSColor whiteColor] set];
		NSRectFill(NSMakeRect(0, 0, 640, 440));
		[[NSColor colorWithCalibratedRed:0.2 green:0.5 blue:0.3 alpha:1] set];
		NSRectFill(NSMakeRect(40, 40, 560, 360));
		NSDictionary *attributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:30], NSForegroundColorAttributeName: [NSColor whiteColor]};
		[@"RAS" drawAtPoint:NSMakePoint(80, 340) withAttributes:attributes];
		[@"RAF" drawAtPoint:NSMakePoint(80, 200) withAttributes:attributes];
		[@"MEK" drawAtPoint:NSMakePoint(80, 60) withAttributes:attributes];
		[NSGraphicsContext restoreGraphicsState];
		[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
	}
	return path;
}

static NSMutableDictionary *PVBox(float inY, NSString *inAnswer)
{
	return [NSMutableDictionary dictionaryWithDictionary:@{@"rect": [NSValue valueWithRect:NSMakeRect(0.1, inY, 0.25, 0.14)], @"answer": inAnswer}];
}

static NSArray *PVBoxes(void)
{
	return @[PVBox(0.1, @"RAS"), PVBox(0.42, @"RAF"), PVBox(0.74, @"MEK")];
}

static NSRect PVFractionOfRep(NSBitmapImageRep *inRep, float inX, float inY, NSColor **outColor)
{
	*outColor = [[inRep colorAtX:inX * [inRep pixelsWide] y:inY * [inRep pixelsHigh]] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
	return NSZeroRect;
}

// What is on the picture, at a point of a box: gold, grey, or the picture
static BOOL PVIsGold(NSImage *inImage, float inX, float inY)
{
	NSColor *color;
	PVFractionOfRep((NSBitmapImageRep *)[[inImage representations] lastObject], inX, inY, &color);
	return [color redComponent] > 0.9 && [color blueComponent] < 0.45;
}

static BOOL PVIsGrey(NSImage *inImage, float inX, float inY)
{
	NSColor *color;
	PVFractionOfRep((NSBitmapImageRep *)[[inImage representations] lastObject], inX, inY, &color);
	return fabs([color redComponent] - [color blueComponent]) < 0.1 && [color greenComponent] > 0.7 && [color greenComponent] < 0.9;
}

// Sees the picture of the test panel at each change
@interface PVImageObserver : NSObject {
	void (^mBlock)(NSImage *);
}
-(id)initWithBlock:(void (^)(NSImage *))inBlock;
@end

@implementation PVImageObserver

-(id)initWithBlock:(void (^)(NSImage *))inBlock
{
	if (self = [super init])
		mBlock = [inBlock copy];
	return self;
}

-(void)observeValueForKeyPath:(NSString *)inKeyPath ofObject:(id)inObject change:(NSDictionary *)inChange context:(void *)inContext
{
	mBlock([inObject image]);
}

@end

@implementation ProVocOcclusionTests

-(void)setUp
{
	PVResetPreferences();
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PVDimTestBackground];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PVSlideShowWithWrongWords];
	mDocument = [PVNewDocumentWithWords(@[@[@"house", @"maison"], @[@"cat", @"chat"]]) retain];
	[mDocument setValue:@NO forKey:@"testMCQ"];
	[mDocument setValue:@0 forKey:@"timer"];
	[mDocument setValue:@0 forKey:@"lateComments"];
	[mDocument setValue:@NO forKey:@"useSpeechSynthesizer"];
	[mDocument setValue:@NO forKey:@"initialSlideshow"];
	[mDocument setValue:@0 forKey:@"testDirection"];
	[mDocument setValue:@0 forKey:@"testKind"];
	[mDocument setValue:@2 forKey:@"numberOfRetries"];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	[mDocument setMainTab:1];
}

-(void)tearDown
{
	NSWindow *sheet = [[mDocument window] attachedSheet];
	if (sheet) {
		[sheet orderOut:nil];
		[NSApp endSheet:sheet];
	}
	PVCloseDocument(mDocument);
	[mDocument release];
	mDocument = nil;
}

-(NSArray *)boxedWords
{
	return [[mDocument allWords] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"occlusion != nil"]];
}

-(void)addBoxes
{
	[mDocument applyBoxes:PVBoxes() title:@"Cascade" showOthers:NO imageFile:PVBoxesPicture() row:2 oldWords:nil];
}

#pragma mark The words

-(void)testABoxIsAWordWithOnePictureShared
{
	[self addBoxes];
	NSArray *words = [self boxedWords];
	XCTAssertEqual([words count], 3u);
	XCTAssertEqualObjects([words valueForKey:@"sourceWord"], (@[@"Cascade", @"Cascade", @"Cascade"]));
	XCTAssertEqualObjects([words valueForKey:@"targetWord"], (@[@"RAS", @"RAF", @"MEK"]));
	XCTAssertEqual([[NSSet setWithArray:[words valueForKey:@"imageMedia"]] count], 1u);
	XCTAssertEqual([[NSSet setWithArray:[[words valueForKey:@"occlusion"] valueForKey:@"group"]] count], 1u);
	XCTAssertEqual([[words[1] occlusionSiblings] count], 3u);
	XCTAssertEqualWithAccuracy([[words[1] occlusion][@"box"][@"y"] floatValue], 0.42, 1e-5);
	XCTAssertEqualObjects([[words[0] copy] occlusion], [words[0] occlusion]);
	XCTAssertNil([[mDocument allWords][0] occlusion], @"a word without box has no dictionary");
}

-(void)testAnEmptyAnswerAddsNoWord
{
	NSArray *boxes = @[PVBox(0.1, @"RAS"), PVBox(0.42, @"  ")];
	[mDocument applyBoxes:boxes title:@"Cascade" showOthers:YES imageFile:PVBoxesPicture() row:2 oldWords:nil];
	XCTAssertEqual([[self boxedWords] count], 1u);
	XCTAssertTrue([[[self boxedWords][0] occlusion][@"showOthers"] boolValue]);
}

-(void)testAddIsOneUndoStepAndEditingAndDeletingToo
{
	[[mDocument undoManager] removeAllActions];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	[self addBoxes];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqual([[mDocument allWords] count], 5u);
	[[mDocument undoManager] undo];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqual([[mDocument allWords] count], 2u);
	[[mDocument undoManager] redo];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqual([[mDocument allWords] count], 5u);
	NSDictionary *occlusion = [[self boxedWords][1] occlusion];
	XCTAssertEqualWithAccuracy([occlusion[@"box"][@"h"] floatValue], 0.14, 1e-5, @"redo keeps the box");

	// a box moved and renamed, a box deleted, a box added
	NSArray *words = [self boxedWords];
	NSMutableDictionary *moved = PVBox(0.5, @"RAF1");
	moved[@"word"] = words[1];
	NSMutableDictionary *kept = PVBox(0.1, @"RAS");
	kept[@"word"] = words[0];
	[mDocument applyBoxes:@[kept, moved, PVBox(0.8, @"ERK")] title:@"Cascade 2" showOthers:NO imageFile:nil row:0 oldWords:words];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqualObjects([[self boxedWords] valueForKey:@"targetWord"], (@[@"RAS", @"RAF1", @"ERK"]));
	XCTAssertEqualObjects([[self boxedWords][2] imageMedia], [[self boxedWords][0] imageMedia]);
	XCTAssertEqualObjects([[self boxedWords][2] occlusion][@"group"], occlusion[@"group"]);
	[[mDocument undoManager] undo];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqualObjects([[self boxedWords] valueForKey:@"targetWord"], (@[@"RAS", @"RAF", @"MEK"]));
	XCTAssertEqualObjects([[self boxedWords] valueForKey:@"sourceWord"], (@[@"Cascade", @"Cascade", @"Cascade"]));

	// one word changed, undone from its own archive
	[mDocument setImageFile:PVMediaFile(@"png") ofWord:[self boxedWords][1]];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqual([[self boxedWords] count], 2u);
	[[mDocument undoManager] undo];
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertEqual([[self boxedWords] count], 3u);
	XCTAssertEqualObjects([[self boxedWords][1] occlusion][@"group"], occlusion[@"group"]);
	XCTAssertEqualObjects([[self boxedWords][1] imageMedia], [[self boxedWords][0] imageMedia]);

	// removing the row of a box
	[[self boxedWords][0] removeFromParent];
	XCTAssertEqual([[[self boxedWords][0] occlusionSiblings] count], 2u);
}

-(void)testDeckWithBoxesSurvivesSaveAndReopenWithOneFileInMedia
{
	[self addBoxes];
	NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
	NSURL *url = [NSURL fileURLWithPath:[folder stringByAppendingPathComponent:@"Boxes.pvoc"]];
	NSError *error = nil;
	XCTAssertTrue([mDocument writeToURL:url ofType:[mDocument fileType] forSaveOperation:NSSaveAsOperation originalContentsURL:nil error:&error], @"%@", error);
	NSArray *media = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[url path] stringByAppendingPathComponent:@"Media"] error:nil];
	XCTAssertEqual([media count], 1u, @"%@", media);
	NSArray *package = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:[url path] error:nil] sortedArrayUsingSelector:@selector(compare:)];
	XCTAssertEqualObjects(package, (@[@"Data", @"Media", @"PublicSettings", @"Settings"]), @"nothing new in the package");

	ProVocDocument *reopened = PVOpenCopyOfDeck([url path]);
	XCTAssertNotNil(reopened);
	NSArray *words = [[reopened allWords] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"occlusion != nil"]];
	XCTAssertEqual([words count], 3u);
	XCTAssertEqualObjects([[words valueForKey:@"occlusion"] valueForKey:@"box"], [[[self boxedWords] valueForKey:@"occlusion"] valueForKey:@"box"]);
	XCTAssertEqual([[[words[0] occlusion][@"group"] description] length], 36u);
	XCTAssertNotNil([reopened imageOfWord:words[2]]);
	PVCloseDocument(reopened);
}

-(void)testADeckFromBeforeTheBoxesHasNoBoxAndAWordArchiveOnlyGainsTheKey
{
	NSString *root = [PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated"];
	for (NSString *name in @[@"Plain.pvoc", @"Rich.pvoc", @"Old format.provoc"]) {
		ProVocDocument *document = PVOpenCopyOfDeck([root stringByAppendingPathComponent:name]);
		XCTAssertNotNil(document, @"%@", name);
		XCTAssertEqual([[[document allWords] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"occlusion != nil"]] count], 0u);
		PVCloseDocument(document);
	}
	// without the key, as an older build reads the archive of a word with a box
	[self addBoxes];
	NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:NO] autorelease];
	[archiver encodeObject:[self boxedWords][0] forKey:@"word"];
	[archiver finishEncoding];
	NSDictionary *archive = [NSPropertyListSerialization propertyListWithData:[archiver encodedData] options:NSPropertyListMutableContainersAndLeaves format:NULL error:nil];
	NSArray *objects = archive[@"$objects"];
	XCTAssertNotEqual([[objects description] rangeOfString:@"Occlusion"].location, (NSUInteger)NSNotFound);
	for (NSMutableDictionary *object in objects)
		if ([object isKindOfClass:[NSDictionary class]])
			[object removeObjectForKey:@"Occlusion"];
	NSData *stripped = [NSPropertyListSerialization dataWithPropertyList:archive format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
	NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingFromData:stripped error:nil] autorelease];
	[unarchiver setRequiresSecureCoding:NO];
	ProVocWord *word = [unarchiver decodeObjectForKey:@"word"];
	XCTAssertEqualObjects([word targetWord], @"RAS");
	XCTAssertNil([word occlusion]);
	XCTAssertEqualObjects([word imageMedia], [[self boxedWords][0] imageMedia]);
}

-(void)testSwapAndFindDoublesLeaveBoxesAlone
{
	[self addBoxes];
	NSButton *sender = [[[NSButton alloc] init] autorelease];
	[sender setTag:0];
	[[self boxedWords][0] swapSourceAndTarget:sender];
	XCTAssertEqualObjects([[self boxedWords][0] sourceWord], @"Cascade");
	XCTAssertEqual([[mDocument doubleWordsIn:[mDocument allWords] progressDelegate:nil] count], 0u);
}

-(void)testAttachingAnotherPictureOrRemovingItRemovesTheBox
{
	[self addBoxes];
	ProVocWord *word = [self boxedWords][0];
	[mDocument setImageFile:PVMediaFile(@"png") ofWord:word];
	XCTAssertNil([word occlusion]);
	word = [self boxedWords][0];
	[word removeImage];
	XCTAssertNil([word occlusion]);
}

#pragma mark The drops

-(PVDragInfo *)imageDrag
{
	return [PVDragInfo infoWithFiles:@[PVBoxesPicture()]];
}

-(NSWindow *)boxesSheet
{
	return [[mDocument window] attachedSheet];
}

-(void)testDroppingBetweenRowsPastTheEndAndOnALessonOpensTheSheetAndOnARowAttaches
{
	NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
	NSOutlineView *outline = [mDocument valueForKey:@"mPageOutlineView"];
	id<NSTableViewDataSource> source = (id)mDocument;
	PVDragInfo *drag = [self imageDrag];

	// on a row: as before
	XCTAssertEqual([source tableView:table validateDrop:drag proposedRow:0 proposedDropOperation:NSTableViewDropOn], NSDragOperationCopy);
	XCTAssertTrue([source tableView:table acceptDrop:drag row:0 dropOperation:NSTableViewDropOn]);
	PVWaitUntil(0.1, ^BOOL { return NO; });
	XCTAssertNil([self boxesSheet]);
	ProVocWord *first = [mDocument allWords][0];
	XCTAssertNotNil([first imageMedia]);
	XCTAssertNil([first occlusion]);

	// a sound is not a picture
	PVDragInfo *sound = [PVDragInfo infoWithFiles:@[PVMediaFile(@"wav")]];
	XCTAssertEqual([source tableView:table validateDrop:sound proposedRow:1 proposedDropOperation:NSTableViewDropAbove], NSDragOperationNone);

	for (NSNumber *row in @[@1, @2]) {
		XCTAssertEqual([source tableView:table validateDrop:drag proposedRow:[row intValue] proposedDropOperation:NSTableViewDropAbove], NSDragOperationCopy);
		XCTAssertTrue([source tableView:table acceptDrop:drag row:[row intValue] dropOperation:NSTableViewDropAbove]);
		XCTAssertTrue(PVWaitUntil(2, ^BOOL { return [self boxesSheet] != nil; }));
		[self cancelSheet];
	}

	ProVocPage *page = [[[mDocument valueForKey:@"mProVocData"] rootChapter] children][0];
	id<NSOutlineViewDataSource> outlineSource = (id)mDocument;
	XCTAssertEqual([outlineSource outlineView:outline validateDrop:drag proposedItem:page proposedChildIndex:-1], NSDragOperationCopy);
	XCTAssertEqual([outlineSource outlineView:outline validateDrop:drag proposedItem:page proposedChildIndex:0], NSDragOperationNone);
	XCTAssertTrue([outlineSource outlineView:outline acceptDrop:drag item:page childIndex:-1]);
	XCTAssertTrue(PVWaitUntil(2, ^BOOL { return [self boxesSheet] != nil; }));
	PVSaveWindowSnapshot([self boxesSheet], @"boxes/sheet-empty");
	[self cancelSheet];
}

-(void)cancelSheet
{
	NSWindow *sheet = [self boxesSheet];
	[[[self sheetController] valueForKey:@"mPanel"] orderOut:nil];
	[NSApp endSheet:sheet];
	XCTAssertTrue(PVWaitUntil(2, ^BOOL { return [self boxesSheet] == nil; }));
}

-(id)sheetController
{
	return [[self boxesView:[[self boxesSheet] contentView]] valueForKey:@"mDelegate"];
}

-(ProVocBoxesView *)boxesView:(NSView *)inView
{
	for (NSView *subview in [inView subviews])
		if ([subview isKindOfClass:[ProVocBoxesView class]])
			return (ProVocBoxesView *)subview;
	return nil;
}

#pragma mark The sheet

-(NSEvent *)mouse:(NSEventType)inType at:(NSPoint)inPoint in:(NSView *)inView clicks:(NSInteger)inClicks
{
	return [NSEvent mouseEventWithType:inType location:[inView convertPoint:inPoint toView:nil] modifierFlags:0 timestamp:0 windowNumber:[[inView window] windowNumber] context:nil eventNumber:0 clickCount:inClicks pressure:1];
}

-(void)drag:(ProVocBoxesView *)inView from:(NSPoint)inFrom to:(NSPoint)inTo
{
	[inView mouseDown:[self mouse:NSEventTypeLeftMouseDown at:inFrom in:inView clicks:1]];
	[inView mouseDragged:[self mouse:NSEventTypeLeftMouseDragged at:inTo in:inView clicks:1]];
	[inView mouseUp:[self mouse:NSEventTypeLeftMouseUp at:inTo in:inView clicks:1]];
}

-(void)testDrawingMovingResizingAndDeletingBoxesThenAddingWords
{
	[mDocument addBoxesOnImageFile:PVBoxesPicture() row:2];
	ProVocBoxesView *view = [self boxesView:[[self boxesSheet] contentView]];
	NSButton *add = [[self sheetController] valueForKey:@"mAddButton"];
	XCTAssertFalse([add isEnabled]);
	XCTAssertEqualObjects([[[self sheetController] valueForKey:@"mTitleField"] stringValue], [[PVBoxesPicture() lastPathComponent] stringByDeletingPathExtension]);
	NSSize size = [view bounds].size;
	XCTAssertEqualWithAccuracy(size.width / size.height, 640.0 / 440.0, 0.01);

	// too small: no box
	[self drag:view from:NSMakePoint(10, 10) to:NSMakePoint(14, 12)];
	XCTAssertEqual([[view boxes] count], 0u);

	// a drag draws a box and gives the caret to its answer
	[self drag:view from:NSMakePoint(50, size.height - 50) to:NSMakePoint(200, size.height - 100)];
	XCTAssertEqual([[view boxes] count], 1u);
	NSTextField *editor = [view editor];
	XCTAssertNotNil(editor);
	[editor setStringValue:@"RAS"];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:editor];
	XCTAssertEqualObjects([add title], @"Add 1 Word");
	XCTAssertTrue([add isEnabled]);
	XCTAssertTrue([[self sheetController] control:editor textView:nil doCommandBySelector:@selector(insertNewline:)]);
	XCTAssertNil([view editor]);
	XCTAssertEqualObjects([view boxes][0][@"answer"], @"RAS");
	NSRect rect = [[view boxes][0][@"rect"] rectValue];
	XCTAssertEqualWithAccuracy(NSMinX(rect), 50 / size.width, 1e-4);
	XCTAssertEqualWithAccuracy(NSMinY(rect), 50 / size.height, 1e-4, @"origin top left");
	XCTAssertEqualWithAccuracy(NSHeight(rect), 50 / size.height, 1e-4);

	// moving it
	[self drag:view from:NSMakePoint(100, size.height - 70) to:NSMakePoint(110, size.height - 90)];
	XCTAssertEqual([[view boxes] count], 1u);
	XCTAssertEqualWithAccuracy(NSMinX([[view boxes][0][@"rect"] rectValue]), 60 / size.width, 1e-4);
	XCTAssertEqualWithAccuracy(NSMinY([[view boxes][0][@"rect"] rectValue]), 70 / size.height, 1e-4);

	// resizing it by its corner, bottom right
	rect = [[view boxes][0][@"rect"] rectValue];
	NSPoint corner = NSMakePoint(NSMaxX(rect) * size.width, (1 - NSMaxY(rect)) * size.height);
	[self drag:view from:corner to:NSMakePoint(corner.x + 20, corner.y - 10)];
	XCTAssertEqualWithAccuracy(NSWidth([[view boxes][0][@"rect"] rectValue]), 170 / size.width, 1e-4);
	XCTAssertEqualWithAccuracy(NSHeight([[view boxes][0][@"rect"] rectValue]), 60 / size.height, 1e-4);
	XCTAssertEqualWithAccuracy(NSMinY([[view boxes][0][@"rect"] rectValue]), 70 / size.height, 1e-4, @"the top does not move");

	// a second box, a double click, Delete
	[self drag:view from:NSMakePoint(50, 200) to:NSMakePoint(200, 150)];
	XCTAssertEqual([[view boxes] count], 2u);
	[[view editor] setStringValue:@"RAF"];
	[view commitEditing];
	[self drag:view from:NSMakePoint(50, 100) to:NSMakePoint(200, 50)];
	[view commitEditing];
	XCTAssertEqualObjects([add title], @"Add 2 Words", @"a box without an answer is not a word");
	PVSaveWindowSnapshot([self boxesSheet], @"boxes/sheet-filled");
	[view mouseDown:[self mouse:NSEventTypeLeftMouseDown at:NSMakePoint(100, 170) in:view clicks:2]];
	XCTAssertEqualObjects([[view editor] stringValue], @"RAF");
	[view commitEditing];
	[view delete:nil];
	XCTAssertEqual([[view boxes] count], 2u);

	[[self sheetController] add:nil];
	XCTAssertTrue(PVWaitUntil(2, ^BOOL { return [self boxesSheet] == nil; }));
	XCTAssertEqualObjects([[self boxedWords] valueForKey:@"targetWord"], (@[@"RAS"]));
}

-(void)testFindLabelsProposesAFilledBoxOnEachLabel
{
	[mDocument addBoxesOnImageFile:PVBoxesPicture() row:2];
	ProVocBoxesView *view = [self boxesView:[[self boxesSheet] contentView]];
	[view addBoxWithRect:NSMakeRect(0.1, 0.1, 0.3, 0.2) answer:@"RAS, by hand"];
	[[self sheetController] findLabels:nil];
	XCTAssertTrue(PVWaitUntil(30, ^BOOL { return [[[self sheetController] valueForKey:@"mFindLabels"] isEnabled]; }));
	NSArray *answers = [[view boxes] valueForKey:@"answer"];
	XCTAssertEqualObjects([answers[0] description], @"RAS, by hand");
	XCTAssertTrue([answers containsObject:@"RAF"], @"%@", answers);
	XCTAssertTrue([answers containsObject:@"MEK"], @"%@", answers);
	XCTAssertFalse([answers containsObject:@"RAS"], @"a box is already there: %@", answers);
	NSRect raf = [[view boxes][[answers indexOfObject:@"RAF"]][@"rect"] rectValue];
	XCTAssertEqualWithAccuracy(NSMidY(raf), 1 - 218.0 / 440, 0.05, @"Y flipped");
	[self cancelSheet];
}

-(void)testEditBoxesReopensTheSheet
{
	[self addBoxes];
	[mDocument editBoxesOfWord:[self boxedWords][1]];
	ProVocBoxesView *view = [self boxesView:[[self boxesSheet] contentView]];
	XCTAssertEqual([[view boxes] count], 3u);
	XCTAssertEqualObjects([[[self sheetController] valueForKey:@"mAddButton"] title], @"Save");
	XCTAssertEqualObjects([[[self sheetController] valueForKey:@"mTitleField"] stringValue], @"Cascade");
	[[view boxes][2] setObject:@"MEK1/MEK2" forKey:@"answer"];
	[[self sheetController] add:nil];
	XCTAssertTrue(PVWaitUntil(2, ^BOOL { return [self boxesSheet] == nil; }));
	XCTAssertEqualObjects([[self boxedWords] valueForKey:@"targetWord"], (@[@"RAS", @"RAF", @"MEK1/MEK2"]));

}

#pragma mark The test panel

-(ProVocTester *)startTest
{
	[mDocument startTest:nil];
	ProVocTester *tester = [mDocument valueForKey:@"mTester"];
	XCTAssertTrue(PVWaitUntil(3, ^BOOL { return [[tester valueForKey:@"testPanel"] isVisible]; }));
	PVWaitUntil(0.1, ^BOOL { return NO; });
	return tester;
}

-(void)endTest:(ProVocTester *)inTester
{
	[inTester closePanelWithCode:0];	// CANCEL
	XCTAssertTrue(PVWaitUntil(3, ^BOOL { return [mDocument valueForKey:@"mTester"] == nil; }));
}

-(void)onlyBoxes
{
	for (ProVocWord *word in [[mDocument allWords] copy])
		[word removeFromParent];
	[mDocument selectedPagesDidChange];
	[self addBoxes];
}

-(void)type:(NSString *)inAnswer in:(ProVocTester *)inTester
{
	[[inTester valueForKey:@"mAnswerTextField"] setStringValue:inAnswer];
	[inTester verifyTestPanel:nil];
}

-(void)testRightWrongAndOutOfTries
{
	[self onlyBoxes];
	ProVocTester *tester = [self startTest];
	XCTAssertEqualObjects([tester question], @"Cascade");
	ProVocWord *first = [tester valueForKey:@"mCurrentWord"];
	XCTAssertEqualObjects([first targetWord], @"RAS");
	NSImage *image = [tester image];
	XCTAssertTrue(PVIsGold(image, 0.2, 0.15), @"the box asked");
	XCTAssertTrue(PVIsGrey(image, 0.2, 0.47), @"the others");
	PVSaveWindowSnapshot([tester valueForKey:@"testPanel"], @"boxes/test-asked");

	// the answer of another box of the picture is wrong, whatever the title says
	[self type:@"RAF" in:tester];
	XCTAssertEqualObjects([tester valueForKey:@"mCurrentWord"], first);
	XCTAssertEqual([first wrong], 1);
	[self type:@"RAS" in:tester];
	XCTAssertEqual([first right], 1);
	ProVocWord *second = [tester valueForKey:@"mCurrentWord"];
	XCTAssertEqualObjects([second targetWord], @"RAF");
	XCTAssertTrue(PVIsGold([tester image], 0.2, 0.47));
	XCTAssertTrue(PVIsGrey([tester image], 0.2, 0.15), @"an answered box stays shut for the next ones");

	// out of tries: open, in red
	[self type:@"x" in:tester];
	[self type:@"y" in:tester];
	XCTAssertTrue([tester displayCorrectAnswer]);
	image = [tester image];
	XCTAssertFalse(PVIsGold(image, 0.2, 0.47));
	XCTAssertFalse(PVIsGrey(image, 0.2, 0.47));
	PVSaveWindowSnapshot([tester valueForKey:@"testPanel"], @"boxes/test-solution");
	[tester verifyTestPanel:nil];
	XCTAssertEqualObjects([[tester valueForKey:@"mCurrentWord"] targetWord], @"MEK");
	[self endTest:tester];
}

-(void)testShowTheOtherBoxes
{
	for (ProVocWord *word in [[mDocument allWords] copy])
		[word removeFromParent];
	[mDocument selectedPagesDidChange];
	[mDocument applyBoxes:PVBoxes() title:@"Cascade" showOthers:YES imageFile:PVBoxesPicture() row:0 oldWords:nil];
	ProVocTester *tester = [self startTest];
	NSImage *image = [tester image];
	XCTAssertTrue(PVIsGold(image, 0.2, 0.15));
	XCTAssertFalse(PVIsGrey(image, 0.2, 0.47));
	[self endTest:tester];
}

-(void)testAnyDirectionAsksTheAnswer
{
	[self onlyBoxes];
	for (NSNumber *direction in @[@1, @2, @3]) {
		[mDocument setValue:direction forKey:@"testDirection"];
		[mDocument setValue:@1.0 forKey:@"testDirectionProbability"];
		ProVocTester *tester = [self startTest];
		XCTAssertEqual([[tester valueForKey:@"mWordsArray"] count] + 1, 3u, @"each box once, direction %@", direction);
		XCTAssertEqualObjects([tester question], @"Cascade", @"direction %@", direction);
		XCTAssertEqualObjects([tester answer], @"RAS", @"direction %@", direction);
		[self endTest:tester];
	}
}

-(void)testEveryMediaSettingKeepsThePictureAndTheTitle
{
	[self onlyBoxes];
	for (int hide = 0; hide <= 4; hide++) {
		[mDocument setValue:@(hide) forKey:@"mediaHideQuestion"];
		ProVocTester *tester = [self startTest];
		XCTAssertNotNil([tester image], @"mediaHideQuestion %i", hide);
		XCTAssertTrue(PVIsGold([tester image], 0.2, 0.15));
		XCTAssertEqualObjects([tester question], @"Cascade", @"mediaHideQuestion %i", hide);
		XCTAssertFalse([tester hideQuestion]);
		[self type:@"RAS" in:tester];
		XCTAssertEqualObjects([tester answer], @"RAF", @"one Return for each box, mediaHideQuestion %i", hide);
		[self endTest:tester];
	}
}

-(void)testRightOpensTheBoxInGreenBeforeTheNextOne
{
	[self onlyBoxes];
	ProVocTester *tester = [self startTest];
	__block NSImage *opened = nil;
	id observer = [[[PVImageObserver alloc] initWithBlock:^(NSImage *inImage) {
		if (!opened && inImage && !PVIsGold(inImage, 0.2, 0.15) && !PVIsGrey(inImage, 0.2, 0.15))
			opened = [inImage retain];
	}] autorelease];
	[tester addObserver:observer forKeyPath:@"image" options:NSKeyValueObservingOptionNew context:nil];
	NSDate *start = [NSDate date];
	[self type:@"RAS" in:tester];
	XCTAssertGreaterThan(-[start timeIntervalSinceNow], 0.4, @"the time to see it");
	[tester removeObserver:observer forKeyPath:@"image"];
	XCTAssertNotNil(opened);
	[self endTest:tester];
}

-(void)testFullSizeShowsTheBoxes
{
	[self onlyBoxes];
	ProVocTester *tester = [self startTest];
	ProVocImageView *imageView = (ProVocImageView *)[[[tester valueForKey:@"testPanel"] contentView] subviewOfClass:[ProVocImageView class]];
	XCTAssertTrue(PVIsGold([imageView image], 0.2, 0.15), @"the image that -displayFullImage: shows has the boxes in it");
	XCTAssertTrue(PVIsGrey([imageView image], 0.2, 0.47));
	[self endTest:tester];
}

-(void)testPictureFillsThePanelAndAPlainWordGetsItsLayoutBack
{
	[self addBoxes];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	ProVocTester *tester = [self startTest];
	ProVocImageView *imageView = (ProVocImageView *)[[[tester valueForKey:@"testPanel"] contentView] subviewOfClass:[ProVocImageView class]];
	XCTAssertEqualObjects([tester question], @"house");
	CGFloat plainHeight = NSHeight([[tester valueForKey:@"testPanel"] frame]);
	[self type:@"maison" in:tester];
	[self type:@"chat" in:tester];
	XCTAssertEqualObjects([tester question], @"Cascade");
	PVWaitUntil(0.2, ^BOOL { return NO; });
	XCTAssertGreaterThan(NSWidth([imageView frame]), 500);
	XCTAssertGreaterThan(NSHeight([imageView frame]), 100);
	XCTAssertGreaterThanOrEqual(NSHeight([[tester valueForKey:@"testPanel"] frame]), plainHeight);
	[self endTest:tester];
}

-(void)testChoicesAreTheOtherBoxesFirstAndAlwaysText
{
	[self addBoxes];
	for (ProVocWord *word in [mDocument allWords])
		if (![word occlusion])
			[mDocument setImageFile:PVMediaFile(@"png") ofWord:word];
	[mDocument setValue:@YES forKey:@"testMCQ"];
	[mDocument setValue:@3 forKey:@"testMCQNumber"];
	[mDocument setValue:@NO forKey:@"delayedMCQ"];
	for (NSNumber *imageMCQ in @[@NO, @YES]) {
		[mDocument setValue:imageMCQ forKey:@"imageMCQ"];
		ProVocTester *tester = [self startTest];
		ProVocMCQView *view = [tester valueForKey:@"mMCQView"];
		for (int i = 0; i < 12; i++) {	// the plain words come first, whatever the order
			ProVocWord *word = [tester valueForKey:@"mCurrentWord"];
			NSArray *answers = [view valueForKey:@"mAnswers"];
			if ([word occlusion]) {
				for (id answer in answers)
					XCTAssertTrue([answer isKindOfClass:[NSString class]], @"%@", answers);
				XCTAssertEqualObjects([NSSet setWithArray:answers], ([NSSet setWithObjects:@"RAS", @"RAF", @"MEK", nil]));
				XCTAssertNotNil([tester image], @"imageMCQ %@", imageMCQ);
				PVSaveWindowSnapshot([tester valueForKey:@"testPanel"], [NSString stringWithFormat:@"boxes/mcq-%@", imageMCQ]);
				break;
			}
			[tester setValue:nil forKey:@"mCurrentWord"];
			[tester applyRandomWord];
		}
		[self endTest:tester];
	}
}

-(void)testInspectorShowsTheBoxOfTheSelectedWord
{
	[self addBoxes];
	ProVocInspector *inspector = [ProVocInspector sharedInspector];
	NSImage *image = [mDocument imageOfWord:[self boxedWords][1] boxState:ProVocBoxSelected];
	XCTAssertTrue(PVIsGold(image, 0.2, 0.47));
	XCTAssertFalse(PVIsGrey(image, 0.2, 0.15), @"the other boxes are not drawn");
	NSView *imageView = [inspector valueForKey:@"mImageView"];
	NSPopUpButton *actions = (NSPopUpButton *)[imageView subviewOfClass:NSClassFromString(@"ProVocActionPopUpButton")];
	XCTAssertNotNil([[actions menu] itemWithTitle:@"Edit Boxes…"]);
}

@end

// The same with the keys of a real session (the Mac must be idle, as for ProVocInterrogationTests)
@interface ProVocOcclusionScenarioTests : PVScenarioTestCase
@end

@implementation ProVocOcclusionScenarioTests

-(void)setUp
{
	[super setUp];
	[mDocument setMainTab:1];
	for (ProVocWord *word in [[mDocument allWords] copy])
		[word removeFromParent];
	[mDocument selectedPagesDidChange];
	[mDocument applyBoxes:PVBoxes() title:@"Cascade" showOthers:NO imageFile:PVBoxesPicture() row:0 oldWords:nil];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	[mDocument setValue:@2 forKey:@"numberOfRetries"];
}

-(NSArray *)words
{
	return @[@[@"house", @"maison"]];
}

-(NSString *)answer
{
	return [[self tester] answer];
}

-(NSWindow *)fullSizeWindow
{
	for (NSWindow *window in [NSApp windows])
		if ([window isVisible] && [window level] == NSModalPanelWindowLevel && [[window contentView] isKindOfClass:[NSImageView class]])
			return window;
	return nil;
}

-(void)scenarioTypingTheAnswersOfAPicture
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"the first box" until:^BOOL { return [self showsQuestionNumber:1] && [[self question] isEqualToString:@"Cascade"] && [self answerFieldHasFocus]; }];
	[script then:^{ PVPostKey(PVKeyF3, nil, NSEventModifierFlagFunction); }];
	[script wait:@"the picture in full size" until:^BOOL { return [self fullSizeWindow] != nil; }];
	[script then:^{
		XCTAssertTrue(PVIsGold([(NSImageView *)[[self fullSizeWindow] contentView] image], 0.2, 0.15), @"full size shows the box asked");
		XCTAssertTrue(PVIsGrey([(NSImageView *)[[self fullSizeWindow] contentView] image], 0.2, 0.47), @"and the others");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"Esc, the test going on" until:^BOOL { return [self fullSizeWindow] == nil && [self answerFieldHasFocus]; }];
	// the answer of another box: wrong, and the focus stays
	[script then:^{ PVTypeText(@"RAF"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"one wrong answer" until:^BOOL { return [(ProVocWord *)[mDocument allWords][0] wrong] == 1; }];
	[script then:^{ XCTAssertTrue([self showsQuestionNumber:1]); XCTAssertTrue([self answerFieldHasFocus]); PVTypeCommand(@"a", 0); PVTypeText(@"RAS"); }];
	[script wait:@"the answer typed" until:^BOOL { return [[self typedAnswer] isEqualToString:@"RAS"]; }];
	// Return, and the next answer typed at once: nothing is lost while the box is open
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); PVTypeText(@"RAF"); }];
	[script wait:@"the second box, with what was typed ahead" until:^BOOL { return [self showsQuestionNumber:2] && [[self typedAnswer] isEqualToString:@"RAF"] && [self answerFieldHasFocus]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the third box" until:^BOOL { return [self showsQuestionNumber:3] && [self answerFieldHasFocus]; }];
	// out of tries: the solution, then Return
	[script then:^{ PVTypeText(@"x"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"a first wrong answer" until:^BOOL { return [[self typedAnswer] isEqualToString:@"x"] && ![self showsSolution]; }];
	[script pause:0.3];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the results" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"the end" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

@end

