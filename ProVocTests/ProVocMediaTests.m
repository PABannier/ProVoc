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
// F1 / F2 (and Command-K / Command-L) play the sounds, F3 (Command-D) shows the picture in
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

	// picture in full size, twice: F3 then Command-D; any key (Esc) closes it
	for (int pass = 0; pass < 2; pass++) {
		[script then:^{ if (pass == 0) PVPostKey(PVKeyF3, nil, NSEventModifierFlagFunction); else PVTypeCommand(@"d", 0); }];
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
// Command-K / L / D / E equivalents - without the answer field losing the focus.
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
		[script then:^{ if (pass == 0) PVPostKey(PVKeyF3, nil, NSEventModifierFlagFunction); else PVTypeCommand(@"d", 0); }];
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

@end
