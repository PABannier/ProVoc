//
//  ProVocMediaTests.m
//
//  Sounds, pictures and movies of the words: formats, the Inspector, and the
//  function keys (with their fn-free shortcuts) while editing and during a test.
//

#import "PVScenarioTestCase.h"
#import "ProVocInspector.h"
#import "ProVocApplication.h"
#import "QTKitCompat.h"
#import "ProVocMovieView.h"
#import "ProVocImageView.h"

@interface ProVocMediaTests : PVScenarioTestCase
@end

@implementation ProVocMediaTests

-(void)setUp
{
	[super setUp];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NoShiftRecord"];
	[mDocument setMainTab:1];
	// "house" gets everything; "cat" only a source sound
	ProVocWord *house = [self wordWithSource:@"house"];
	[mDocument setAudioFile:PVMediaFile(@"aiff") forKey:@"Source" ofWord:house];
	[mDocument setAudioFile:PVMediaFile(@"m4a") forKey:@"Target" ofWord:house];
	[mDocument setImageFile:PVMediaFile(@"png") ofWord:house];
	[mDocument setMovieFile:PVMediaFile(@"mov") ofWord:house];
	[mDocument setAudioFile:PVMediaFile(@"wav") forKey:@"Source" ofWord:[self wordWithSource:@"cat"]];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	[mDocument setValue:@NO forKey:@"autoPlayMedia"];
}

-(void)tearDown
{
	[[ProVocInspector sharedInspector] stopPlayingSound];
	if ([[ProVocInspector sharedInspector] isVisible])
		[[ProVocInspector sharedInspector] toggle];
	[super tearDown];
}

-(ProVocInspector *)inspector
{
	return [ProVocInspector sharedInspector];
}

-(NSString *)playingAudioKey
{
	return [[self inspector] valueForKey:@"mPlayingSoundKey"];
}

// A window showing a picture or a movie over everything else ("full size")
-(NSWindow *)fullSizeWindowWithViewOfClass:(Class)inClass
{
	for (NSWindow *window in [NSApp windows])
		if ([window isVisible] && [window level] == NSModalPanelWindowLevel && [[window contentView] isKindOfClass:inClass])
			return window;
	return nil;
}

-(QTMovieView *)movieViewIn:(NSView *)inView
{
	return (QTMovieView *)[self view:inView ofClass:[QTMovieView class]];
}

-(NSView *)view:(NSView *)inView ofClass:(Class)inClass
{
	if ([inView isKindOfClass:inClass])
		return inView;
	for (NSView *subview in [inView subviews]) {
		NSView *found = [self view:subview ofClass:inClass];
		if (found)
			return found;
	}
	return nil;
}

#pragma mark Formats

-(void)testCommonSoundFormatsPlay
{
	for (NSString *kind in @[@"aiff", @"wav", @"m4a", @"mp3"]) {
		NSSound *sound = [[[NSSound alloc] initWithContentsOfFile:PVMediaFile(kind) byReference:YES] autorelease];
		XCTAssertNotNil(sound, @"%@ cannot be opened", kind);
		XCTAssertTrue([sound duration] > 0.1, @"%@ has no duration", kind);
		XCTAssertTrue([sound play], @"%@ does not play", kind);
		[sound stop];
	}
}

-(void)testCommonMovieFormatsPlayAndOthersFailGracefully
{
	for (NSString *kind in @[@"mov", @"mp4"]) {
		XCTAssertTrue([QTMovie canInitWithFile:PVMediaFile(kind)], @"%@", kind);
		QTMovie *movie = [QTMovie movieWithFile:PVMediaFile(kind) error:NULL];
		XCTAssertTrue([movie isPlayable], @"%@ is not playable", kind);
		XCTAssertTrue(NSEqualSizes([movie imageSize], NSMakeSize(320, 240)), @"%@: size %@", kind, NSStringFromSize([movie imageSize]));
		XCTAssertNotNil([movie posterImage], @"%@ has no poster image", kind);
	}
	XCTAssertTrue([[QTMovie movieUnfilteredFileTypes] containsObject:@"mov"]);
	XCTAssertTrue([[QTMovie movieUnfilteredFileTypes] containsObject:@"mp4"]);
	XCTAssertTrue([[QTMovie movieUnfilteredFileTypes] containsObject:@"m4v"]);

	// a file AVFoundation cannot decode: no exception, no crash, and the view says so
	QTMovie *bad = [QTMovie movieWithFile:PVMediaFile(@"bad.mov") error:NULL];
	XCTAssertNotNil(bad);
	XCTAssertFalse([bad isPlayable]);
	QTMovieView *view = [[[QTMovieView alloc] initWithFrame:NSMakeRect(0, 0, 200, 150)] autorelease];
	[view setMovie:bad];
	[view play:nil];
	XCTAssertFalse([view isPlaying]);
	NSTextField *message = (NSTextField *)[self view:view ofClass:[NSTextField class]];
	XCTAssertFalse([message isHidden], @"no message for an unsupported movie");
	XCTAssertTrue([[message stringValue] length] > 10 && ![[message stringValue] isEqualToString:@"Movie Unsupported Format Message"], @"message: %@", [message stringValue]);
	XCTAssertNil([QTMovie movieWithFile:@"/nonexistent/movie.mov" error:NULL]);
}

#pragma mark Inspector

// Command-I opens the Inspector; it follows the selection and shows the media of the word.
// F1 / F2 (and Command-K / Command-L) play the sounds, F3 (Command-B) shows the picture in
// full size until Esc, F4 (Command-E) plays the movie, Option-F4 (Option-Command-E) in full size.
-(void)testInspectorFollowsSelectionAndMediaKeys
{
	NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
	PVScript *script = [PVScript script];
	[script then:^{ XCTAssertFalse([[self inspector] isVisible]); PVTypeCommand(@"i", 0); }];
	[script wait:@"Command-I to open the Inspector" until:^BOOL { return [[self inspector] isVisible]; }];
	[script then:^{
		[[mDocument window] makeFirstResponder:table];
		[table selectRowIndexes:[NSIndexSet indexSetWithIndex:[[mDocument valueForKey:@"mVisibleWords"] indexOfObject:[self wordWithSource:@"house"]]] byExtendingSelection:NO];
	}];
	[script wait:@"the Inspector to show the selected word and its media" until:^BOOL {
		ProVocInspector *inspector = [self inspector];
		return [[inspector valueForKey:@"sourceText"] isEqualToString:@"house"] && [[inspector valueForKey:@"targetText"] isEqualToString:@"maison"]
			&& [[inspector valueForKey:@"canPlaySourceAudio"] boolValue] && [[inspector valueForKey:@"canPlayTargetAudio"] boolValue]
			&& [inspector valueForKey:@"image"] != nil && [[inspector valueForKey:@"movie"] isPlayable];
	}];
	[script then:^{ PVSaveWindowScreenshot([[self inspector] window], @"windows/inspector-with-media"); }];

	// sounds
	for (NSArray *key in @[@[@(PVKeyF1), @"Source", @"k"], @[@(PVKeyF2), @"Target", @"l"]]) {
		[script then:^{ PVPostKey([key[0] unsignedShortValue], nil, NSEventModifierFlagFunction); }];
		[script wait:[NSString stringWithFormat:@"the %@ sound to play (function key)", key[1]] until:^BOOL { return [[self playingAudioKey] isEqualToString:key[1]]; }];
		[script wait:@"the sound to end" until:^BOOL { return [self playingAudioKey] == nil; }];
		[script then:^{ PVTypeCommand(key[2], 0); }];
		[script wait:[NSString stringWithFormat:@"the %@ sound to play (Command-%@)", key[1], key[2]] until:^BOOL { return [[self playingAudioKey] isEqualToString:key[1]]; }];
		[script wait:@"the sound to end" until:^BOOL { return [self playingAudioKey] == nil; }];
	}

	// picture in full size, twice: F3 then Command-B; any key (Esc) closes it
	for (int pass = 0; pass < 2; pass++) {
		[script then:^{ if (pass == 0) PVPostKey(PVKeyF3, nil, NSEventModifierFlagFunction); else PVTypeCommand(@"b", 0); }];
		[script wait:@"the picture in full size" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[NSImageView class]] != nil; }];
		[script then:^{
			if (pass == 0)
				PVSaveWindowScreenshot([self fullSizeWindowWithViewOfClass:[NSImageView class]], @"windows/image-full-size");
			PVPostKey(PVKeyEscape, nil, 0);
		}];
		[script wait:@"Esc to close the picture" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[NSImageView class]] == nil; }];
	}

	// movie in the Inspector: F4 then Command-E
	[script then:^{ PVPostKey(PVKeyF4, nil, NSEventModifierFlagFunction); }];
	[script wait:@"the movie to play in the Inspector (F4)" until:^BOOL { return [[self movieViewIn:[[[self inspector] window] contentView]] isPlaying]; }];
	[script wait:@"the movie to end" until:^BOOL { return ![[self movieViewIn:[[[self inspector] window] contentView]] isPlaying]; }];
	[script then:^{ PVTypeCommand(@"e", 0); }];
	[script wait:@"the movie to play again (Command-E)" until:^BOOL { return [[self movieViewIn:[[[self inspector] window] contentView]] isPlaying]; }];
	[script wait:@"the movie to end" until:^BOOL { return ![[self movieViewIn:[[[self inspector] window] contentView]] isPlaying]; }];

	// movie in full size: Option-F4, Shift-F4, Option-Command-E; Esc closes
	for (int pass = 0; pass < 3; pass++) {
		[script then:^{
			if (pass == 0) PVPostKey(PVKeyF4, nil, NSEventModifierFlagFunction | NSEventModifierFlagOption);
			else if (pass == 1) PVPostKey(PVKeyF4, nil, NSEventModifierFlagFunction | NSEventModifierFlagShift);
			else PVTypeCommand(@"e", NSEventModifierFlagOption);
		}];
		[script wait:@"the movie in full size, playing" until:^BOOL {
			NSWindow *window = [self fullSizeWindowWithViewOfClass:[ProVocMovieView class]];
			return window && [(QTMovieView *)[window contentView] isPlaying];
		}];
		[script then:^{
			if (pass == 0)
				PVSaveWindowScreenshot([self fullSizeWindowWithViewOfClass:[ProVocMovieView class]], @"windows/movie-full-size");
			PVPostKey(PVKeyEscape, nil, 0);
		}];
		[script wait:@"Esc to close the movie" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[ProVocMovieView class]] == nil && ![NSApp modalWindow]; }];
	}

	// another word: the Inspector follows
	[script then:^{ [table selectRowIndexes:[NSIndexSet indexSetWithIndex:[[mDocument valueForKey:@"mVisibleWords"] indexOfObject:[self wordWithSource:@"dog"]]] byExtendingSelection:NO]; }];
	[script wait:@"the Inspector to follow the selection" until:^BOOL {
		ProVocInspector *inspector = [self inspector];
		return [[inspector valueForKey:@"sourceText"] isEqualToString:@"dog"] && ![[inspector valueForKey:@"canPlaySourceAudio"] boolValue] && [inspector valueForKey:@"image"] == nil;
	}];
	[script then:^{ PVTypeCommand(@"i", 0); }];
	[script wait:@"Command-I to close the Inspector" until:^BOOL { return ![[self inspector] isVisible]; }];
	[self runScript:script];
}

#pragma mark During a test

// F1 plays the sound of the question, F2 the sound of the answer, F3 shows the picture in
// full size, F4 plays the movie and Option-F4 plays it in full size - with their
// Command-K / L / B / E equivalents - without the answer field losing the focus.
-(void)scenarioMediaKeysDuringATest
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1 (house, with media)" until:^BOOL { return [self showsQuestionNumber:1] && [[self question] isEqualToString:@"house"]; }];
	[script then:^{ PVSaveWindowScreenshot([self testPanel], [@"tester/question-with-media" stringByAppendingString:[self variant]]); }];
	for (NSArray *key in @[@[@(PVKeyF1), @"Source", @"k"], @[@(PVKeyF2), @"Target", @"l"]]) {
		[script then:^{ PVPostKey([key[0] unsignedShortValue], nil, NSEventModifierFlagFunction); }];
		[script wait:[NSString stringWithFormat:@"the %@ sound to play (function key)", key[1]] until:^BOOL { return [[self playingAudioKey] isEqualToString:key[1]]; }];
		[script wait:@"the sound to end" until:^BOOL { return [self playingAudioKey] == nil; }];
		[script then:^{ XCTAssertTrue([self answerFieldHasFocus]); PVTypeCommand(key[2], 0); }];
		[script wait:[NSString stringWithFormat:@"the %@ sound to play (Command-%@)", key[1], key[2]] until:^BOOL { return [[self playingAudioKey] isEqualToString:key[1]]; }];
		[script wait:@"the sound to end" until:^BOOL { return [self playingAudioKey] == nil; }];
	}
	for (int pass = 0; pass < 2; pass++) {
		[script then:^{ if (pass == 0) PVPostKey(PVKeyF3, nil, NSEventModifierFlagFunction); else PVTypeCommand(@"b", 0); }];
		[script wait:@"the picture in full size" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[NSImageView class]] != nil; }];
		[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
		[script wait:@"Esc to close the picture, the test going on" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[NSImageView class]] == nil && [self showsQuestionNumber:1]; }];
	}
	for (int pass = 0; pass < 2; pass++) {
		[script then:^{ if (pass == 0) PVPostKey(PVKeyF4, nil, NSEventModifierFlagFunction); else PVTypeCommand(@"e", 0); }];
		[script wait:@"the movie to play in the test panel" until:^BOOL { return [[self movieViewIn:[[self testPanel] contentView]] isPlaying]; }];
		[script wait:@"the movie to end" until:^BOOL { return ![[self movieViewIn:[[self testPanel] contentView]] isPlaying]; }];
	}
	for (int pass = 0; pass < 2; pass++) {
		[script then:^{ if (pass == 0) PVPostKey(PVKeyF4, nil, NSEventModifierFlagFunction | NSEventModifierFlagOption); else PVTypeCommand(@"e", NSEventModifierFlagOption); }];
		[script wait:@"the movie in full size, playing" until:^BOOL {
			NSWindow *window = [self fullSizeWindowWithViewOfClass:[ProVocMovieView class]];
			return window && [(QTMovieView *)[window contentView] isPlaying];
		}];
		[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
		[script wait:@"Esc to close the movie, the test going on" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[ProVocMovieView class]] == nil && [self showsQuestionNumber:1]; }];
	}
	// a click on the movie plays it, a triple click shows it in full size
	[script then:^{ PVClickView([self movieViewIn:[[self testPanel] contentView]], 1, 0); }];
	[script wait:@"a click to play the movie" until:^BOOL { return [[self movieViewIn:[[self testPanel] contentView]] isPlaying]; }];
	[script then:^{ PVClickView([self movieViewIn:[[self testPanel] contentView]], 1, 0); }];
	[script wait:@"another click to pause it" until:^BOOL { return ![[self movieViewIn:[[self testPanel] contentView]] isPlaying]; }];
	[script then:^{ PVClickView([self movieViewIn:[[self testPanel] contentView]], 3, 0); }];
	[script wait:@"a triple click to show the movie in full size" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[ProVocMovieView class]] != nil; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"Esc to close the movie" until:^BOOL { return [self fullSizeWindowWithViewOfClass:[ProVocMovieView class]] == nil && [self testPanelIsReady]; }];
	// the answer still goes into the field
	[self answerCorrectlyIn:script];
	[script wait:@"question 2 (cat: a sound for the question only)" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{ PVPostKey(PVKeyF2, nil, NSEventModifierFlagFunction); }];
	[script pause:0.3];
	[script then:^{ XCTAssertNil([self playingAudioKey], @"there is no answer sound"); PVPostKey(PVKeyF1, nil, NSEventModifierFlagFunction); }];
	[script wait:@"the question sound" until:^BOOL { return [[self playingAudioKey] isEqualToString:@"Source"]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

#pragma mark Adding, exporting and removing media

-(id)viewOfClassNamed:(NSString *)inClassName in:(NSView *)inView index:(NSUInteger)inIndex
{
	NSMutableArray *found = [NSMutableArray array];
	NSMutableArray *views = [NSMutableArray arrayWithObject:inView];
	while ([views count] > 0) {
		NSView *view = views[0];
		[views removeObjectAtIndex:0];
		if ([[view className] isEqualToString:inClassName])
			[found addObject:view];
		[views addObjectsFromArray:[view subviews]];
	}
	// top to bottom
	[found sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
		CGFloat ya = NSMaxY([a convertRect:[a bounds] toView:nil]), yb = NSMaxY([b convertRect:[b bounds] toView:nil]);
		return ya > yb ? NSOrderedAscending : ya < yb ? NSOrderedDescending : NSOrderedSame;
	}];
	return inIndex < [found count] ? found[inIndex] : nil;
}

-(BOOL)dropFile:(NSString *)inFile onView:(NSView *)inView
{
	PVDragInfo *info = [PVDragInfo infoWithFiles:@[inFile]];
	[info setLocation:NSMakePoint(NSMidX([inView bounds]), NSMidY([inView bounds])) inView:inView];
	if ([(id <NSDraggingDestination>)inView draggingEntered:info] == NSDragOperationNone)
		return NO;
	if ([inView respondsToSelector:@selector(prepareForDragOperation:)] && ![(id <NSDraggingDestination>)inView prepareForDragOperation:info])
		return NO;
	BOOL performed = [(id <NSDraggingDestination>)inView performDragOperation:info];
	if (performed && [inView respondsToSelector:@selector(concludeDragOperation:)])
		[(id <NSDraggingDestination>)inView concludeDragOperation:info];
	return performed;
}

-(BOOL)dropFile:(NSString *)inFile onWord:(NSString *)inSource column:(NSString *)inColumn
{
	NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
	NSInteger row = [[[mDocument valueForKey:@"mVisibleWords"] valueForKey:@"sourceWord"] indexOfObject:inSource];
	NSRect cell = [table frameOfCellAtColumn:[table columnWithIdentifier:inColumn] row:row];
	PVDragInfo *info = [PVDragInfo infoWithFiles:@[inFile]];
	[info setLocation:NSMakePoint(NSMidX(cell), NSMidY(cell)) inView:table];
	id <NSTableViewDataSource> source = (id <NSTableViewDataSource>)mDocument;
	if ([source tableView:table validateDrop:info proposedRow:row proposedDropOperation:NSTableViewDropOn] == NSDragOperationNone)
		return NO;
	return [source tableView:table acceptDrop:info row:row dropOperation:NSTableViewDropOn];
}

// A sound, a picture or a movie file dropped on a word of the list becomes its media
// (a sound: of the column it is dropped on); so do files dropped on the Inspector.
-(void)testDropMediaFilesOnAWordAndOnTheInspector
{
	ProVocWord *dog = [self wordWithSource:@"dog"], *summer = [self wordWithSource:@"summer"];
	XCTAssertTrue([self dropFile:PVMediaFile(@"aiff") onWord:@"dog" column:@"Source"], @"a sound dropped on a word was refused");
	XCTAssertTrue([dog canPlayAudio:@"Source"] && ![dog canPlayAudio:@"Target"], @"the sound dropped on the first column is the sound of the word");
	XCTAssertTrue([self dropFile:PVMediaFile(@"mp3") onWord:@"dog" column:@"Target"]);
	XCTAssertTrue([dog canPlayAudio:@"Target"], @"the sound dropped on the second column is the sound of the translation");
	XCTAssertTrue([self dropFile:PVMediaFile(@"jpg") onWord:@"dog" column:@"Source"], @"a picture dropped on a word was refused");
	XCTAssertNotNil([mDocument imageOfWord:dog]);
	XCTAssertTrue([self dropFile:PVMediaFile(@"mp4") onWord:@"dog" column:@"Target"], @"a movie dropped on a word was refused");
	XCTAssertTrue([[mDocument movieOfWord:dog] isPlayable]);
	NSString *text = [NSTemporaryDirectory() stringByAppendingPathComponent:@"PVNotAMedia.txt"];
	[@"text" writeToFile:text atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	XCTAssertFalse([self dropFile:text onWord:@"dog" column:@"Source"], @"a text file was accepted as media");

	// the Inspector, for the selected word
	NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
	PVScript *script = [PVScript script];
	[script then:^{
		if (![[self inspector] isVisible])
			PVTypeCommand(@"i", 0);
		[[mDocument window] makeFirstResponder:table];
		[table selectRowIndexes:[NSIndexSet indexSetWithIndex:[[mDocument valueForKey:@"mVisibleWords"] indexOfObject:summer]] byExtendingSelection:NO];
	}];
	[script wait:@"the Inspector to show the word, which has no media" until:^BOOL {
		return [[self inspector] isVisible] && [[[self inspector] valueForKey:@"sourceText"] isEqualToString:@"summer"] && [[self inspector] valueForKey:@"image"] == nil;
	}];
	[self runScript:script];
	NSView *content = [[[self inspector] window] contentView];
	NSView *sourceSound = [self viewOfClassNamed:@"ProVocSoundDropView" in:content index:0], *targetSound = [self viewOfClassNamed:@"ProVocSoundDropView" in:content index:1];
	NSView *imageDrop = [self viewOfClassNamed:@"ProVocImageDropView" in:content index:0], *movieDrop = [self viewOfClassNamed:@"ProVocMovieDropView" in:content index:0];
	XCTAssertTrue(sourceSound && targetSound && imageDrop && movieDrop, @"the drop views of the Inspector: %@ %@ %@ %@", sourceSound, targetSound, imageDrop, movieDrop);
	XCTAssertFalse([self dropFile:PVMediaFile(@"png") onView:sourceSound], @"a picture was accepted as a sound");
	XCTAssertTrue([self dropFile:PVMediaFile(@"wav") onView:sourceSound], @"a sound dropped on the Inspector was refused");
	XCTAssertTrue([summer canPlayAudio:@"Source"] && ![summer canPlayAudio:@"Target"]);
	XCTAssertTrue([self dropFile:PVMediaFile(@"m4a") onView:targetSound]);
	XCTAssertTrue([summer canPlayAudio:@"Target"]);
	XCTAssertFalse([self dropFile:PVMediaFile(@"wav") onView:imageDrop], @"a sound was accepted as a picture");
	XCTAssertTrue([self dropFile:PVMediaFile(@"png") onView:imageDrop], @"a picture dropped on the Inspector was refused");
	XCTAssertNotNil([mDocument imageOfWord:summer]);
	XCTAssertFalse([self dropFile:PVMediaFile(@"bad.mov") onView:movieDrop] && [[mDocument movieOfWord:summer] isPlayable], @"a file that is not a movie plays");
	XCTAssertTrue([self dropFile:PVMediaFile(@"mov") onView:movieDrop], @"a movie dropped on the Inspector was refused");
	XCTAssertTrue([[mDocument movieOfWord:summer] isPlayable]);
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [[self inspector] valueForKey:@"image"] != nil && [[[self inspector] valueForKey:@"movie"] isPlayable] && [[[self inspector] valueForKey:@"canPlaySourceAudio"] boolValue]; }), @"the Inspector does not show the media dropped on it");
	PVSaveWindowScreenshot([[self inspector] window], @"windows/inspector-after-drops");
}

-(NSMenuItem *)inspectorMenuItemWithAction:(SEL)inAction
{
	NSMutableArray *views = [NSMutableArray arrayWithObject:[[[self inspector] window] contentView]];
	while ([views count] > 0) {
		NSView *view = views[0];
		[views removeObjectAtIndex:0];
		if ([view isKindOfClass:[NSPopUpButton class]])
			for (NSMenuItem *item in [[(NSPopUpButton *)view menu] itemArray])
				if ([item action] == inAction)
					return item;
		[views addObjectsFromArray:[view subviews]];
	}
	return nil;
}

// The action menus of the Inspector: Import (a panel to choose a file), Export (a panel
// to choose a folder; the file gets the name of the word), Remove (which can be undone).
// The panels of macOS cannot be answered from here: they are checked and cancelled, and
// what follows their OK is called with a file or a folder.
-(void)testInspectorImportExportAndRemoveMedia
{
	ProVocWord *house = [self wordWithSource:@"house"], *dog = [self wordWithSource:@"dog"];
	NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
	PVScript *script = [PVScript script];
	[script then:^{
		if (![[self inspector] isVisible])
			PVTypeCommand(@"i", 0);
		[[mDocument window] makeFirstResponder:table];
		[table selectRowIndexes:[NSIndexSet indexSetWithIndex:[[mDocument valueForKey:@"mVisibleWords"] indexOfObject:dog]] byExtendingSelection:NO];
	}];
	[script wait:@"the Inspector to show a word without media" until:^BOOL { return [[self inspector] isVisible] && [[[self inspector] valueForKey:@"sourceText"] isEqualToString:@"dog"]; }];
	[script then:^{
		// without media there is nothing to export or remove
		for (NSString *action in @[@"exportImage:", @"removeImage:", @"exportMovie:", @"removeMovie:", @"exportSourceAudio:", @"removeSourceAudio:", @"exportTargetAudio:", @"removeTargetAudio:"]) {
			NSMenuItem *item = [self inspectorMenuItemWithAction:NSSelectorFromString(action)];
			XCTAssertNotNil(item, @"no menu item for %@", action);
			XCTAssertFalse([[self inspector] validateMenuItem:item], @"%@ is offered for a word without media", action);
		}
	}];
	// Import: an open panel for the right kind of files; Cancel changes nothing
	for (NSString *action in @[@"importImage:", @"importMovie:", @"importSourceAudio:", @"importTargetAudio:"]) {
		[script then:^{
			NSMenuItem *item = [self inspectorMenuItemWithAction:NSSelectorFromString(action)];
			XCTAssertTrue(item && [[self inspector] validateMenuItem:item], @"%@ is not offered", action);
			// (the action runs the panel modally: it is chosen from the event loop, not from this step)
			dispatch_async(dispatch_get_main_queue(), ^{ [[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]]; });
		}];
		[script wait:[NSString stringWithFormat:@"the open panel of %@", action] timeout:15 until:^BOOL { return [[NSApp modalWindow] isKindOfClass:[NSOpenPanel class]]; }];
		[script then:^{
			NSOpenPanel *panel = (NSOpenPanel *)[NSApp modalWindow];
			NSArray *types = [panel allowedFileTypes];
			// (file name extensions, or uniform type identifiers for the sounds)
			NSArray *expected = [action rangeOfString:@"Image"].location != NSNotFound ? @[@"png", @"jpg"] : [action rangeOfString:@"Movie"].location != NSNotFound ? @[@"mov", @"mp4"] : @[@"public.aiff-audio", @"public.mp3"];
			for (NSString *type in expected)
				XCTAssertTrue([types containsObject:type], @"%@ does not offer %@ files: %@", action, type, types);
			XCTAssertFalse([types containsObject:@"txt"] || [types containsObject:@"public.plain-text"], @"%@ offers text files", action);
			[panel cancel:nil];
		}];
		[script wait:@"the open panel to close" timeout:15 until:^BOOL { return [NSApp modalWindow] == nil; }];
		[script then:^{ XCTAssertEqual([[dog mediaDictionary] count], 0u, @"cancelling %@ changed the word", action); }];
	}
	// a word with everything
	[script then:^{ [table selectRowIndexes:[NSIndexSet indexSetWithIndex:[[mDocument valueForKey:@"mVisibleWords"] indexOfObject:house]] byExtendingSelection:NO]; }];
	[script wait:@"the Inspector to show the word with media" until:^BOOL { return [[[self inspector] valueForKey:@"sourceText"] isEqualToString:@"house"] && [[self inspector] valueForKey:@"image"] != nil; }];
	for (NSString *action in @[@"exportImage:", @"exportMovie:", @"exportSourceAudio:", @"exportTargetAudio:"]) {
		[script then:^{
			NSMenuItem *item = [self inspectorMenuItemWithAction:NSSelectorFromString(action)];
			XCTAssertTrue([[self inspector] validateMenuItem:item], @"%@ is not offered for a word with media", action);
			dispatch_async(dispatch_get_main_queue(), ^{ [[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]]; });
		}];
		[script wait:[NSString stringWithFormat:@"the panel of %@, to choose a folder", action] timeout:15 until:^BOOL { return [[NSApp modalWindow] isKindOfClass:[NSOpenPanel class]]; }];
		[script then:^{
			NSOpenPanel *panel = (NSOpenPanel *)[NSApp modalWindow];
			XCTAssertTrue([panel canChooseDirectories] && ![panel canChooseFiles], @"%@ should ask for a folder", action);
			[panel cancel:nil];
		}];
		[script wait:@"the panel to close" timeout:15 until:^BOOL { return [NSApp modalWindow] == nil; }];
	}
	[self runScript:script];

	// what follows the choice of a folder
	NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVExportedMedia-%i", [[NSProcessInfo processInfo] processIdentifier]]];
	[[NSFileManager defaultManager] removeItemAtPath:folder error:NULL];
	[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
	[house exportImage:@{@"Directory": folder, @"Document": mDocument}];
	[house exportMovie:@{@"Directory": folder, @"Document": mDocument}];
	[house exportAudio:@{@"Directory": folder, @"Key": @"Source", @"NameSelectorName": @"sourceWord", @"OtherNameSelectorName": @"targetWord", @"Document": mDocument}];
	[house exportAudio:@{@"Directory": folder, @"Key": @"Target", @"NameSelectorName": @"targetWord", @"OtherNameSelectorName": @"sourceWord", @"Document": mDocument}];
	NSArray *exported = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL] sortedArrayUsingSelector:@selector(compare:)];
	XCTAssertEqual([exported count], 4u, @"exported files: %@", exported);
	XCTAssertTrue([exported containsObject:@"house.aiff"] && [exported containsObject:@"maison.m4a"], @"the sounds are exported with the names of the word and of its translation: %@", exported);
	for (NSString *file in exported)
		XCTAssertTrue([[[NSFileManager defaultManager] attributesOfItemAtPath:[folder stringByAppendingPathComponent:file] error:NULL] fileSize] > 100, @"%@ is empty", file);

	// Remove, one media after the other
	for (NSArray *removal in @[@[@"removeImage:", @"Image"], @[@"removeMovie:", @"Movie"], @[@"removeSourceAudio:", @"SourceAudio"], @[@"removeTargetAudio:", @"TargetAudio"]]) {
		NSMenuItem *item = [self inspectorMenuItemWithAction:NSSelectorFromString(removal[0])];
		XCTAssertTrue([[self inspector] validateMenuItem:item], @"%@ is not offered", removal[0]);
		XCTAssertNotNil([house mediaDictionary][removal[1]]);
		[[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]];
		XCTAssertNil([house mediaDictionary][removal[1]], @"%@ did not remove the media", removal[0]);
		XCTAssertFalse([[self inspector] validateMenuItem:item], @"%@ is still offered", removal[0]);
	}
	XCTAssertEqual([[house mediaDictionary] count], 0u);
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [[self inspector] valueForKey:@"image"] == nil && ![[[self inspector] valueForKey:@"canPlaySourceAudio"] boolValue]; }), @"the Inspector still shows removed media");
}

// The methods of the open and save panels that the code of 2008 relies on are still there.
-(void)testPanelMethodsOfTheTimeStillExist
{
	for (NSString *selector in @[@"filename", @"filenames", @"runModalForDirectory:file:types:", @"beginSheetForDirectory:file:types:modalForWindow:modalDelegate:didEndSelector:contextInfo:"])
		XCTAssertTrue([NSOpenPanel instancesRespondToSelector:NSSelectorFromString(selector)], @"-[NSOpenPanel %@] is gone", selector);
	for (NSString *selector in @[@"filename", @"setRequiredFileType:", @"beginSheetForDirectory:file:modalForWindow:modalDelegate:didEndSelector:contextInfo:"])
		XCTAssertTrue([NSSavePanel instancesRespondToSelector:NSSelectorFromString(selector)], @"-[NSSavePanel %@] is gone", selector);
}

@end
