//
//  ProVocSlideshowTests.m
//
//  The slideshow (Shift-Command-R) driven with the keyboard.
//

#import "PVScenarioTestCase.h"
#import "ProVocDocument+Slideshow.h"
#import "QTKitCompat.h"

@interface ProVocSlideshowTests : PVScenarioTestCase
@end

@implementation ProVocSlideshowTests

-(void)setUp
{
	[super setUp];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:NO forKey:PVSlideshowAutoAdvance];
	[defaults setBool:NO forKey:PVSlideshowRandom];
}

// The slide windows on screen, front first: one for the word, one for its translation
-(NSArray *)slideViews
{
	NSMutableArray *views = [NSMutableArray array];
	for (NSWindow *window in [NSApp orderedWindows])
		if ([window isVisible] && [[window contentView] isKindOfClass:NSClassFromString(@"SlideView")])
			[views addObject:[window contentView]];
	return views;
}

-(NSArray *)visibleSlideTexts
{
	NSMutableArray *texts = [NSMutableArray array];
	for (NSView *view in [self slideViews])
		if ([[view window] alphaValue] > 0.9)
			for (NSAttributedString *string in [view valueForKey:@"mAttributedStrings"])
				if ([string length] > 0)
					[texts addObject:[string string]];
	return texts;
}

-(NSWindow *)controlPanel
{
	for (NSWindow *window in [NSApp windows])
		if ([window isVisible] && [[window contentView] isKindOfClass:NSClassFromString(@"ProVocSlideshowControlView")])
			return window;
	return nil;
}

-(BOOL)shows:(NSArray *)inTexts
{
	return [[NSSet setWithArray:[self visibleSlideTexts]] isEqualToSet:[NSSet setWithArray:inTexts]];
}

-(void)testSlideshowKeys
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", NSEventModifierFlagShift); }];
	[script wait:@"the first word alone" timeout:10 until:^BOOL { return [self shows:@[@"house"]]; }];
	[script then:^{
		XCTAssertNotNil([self controlPanel], @"no control panel");
		PVSaveWindowScreenshot([[[self slideViews] lastObject] window], @"slideshow/first-word");
		PVPostKey(PVKeyRight, nil, 0);
	}];
	[script wait:@"its translation (Right)" until:^BOOL { return [self shows:@[@"house", @"maison"]]; }];
	[script then:^{ PVPostKey(PVKeyRight, nil, 0); }];
	[script wait:@"the second word (Right)" until:^BOOL { return [self shows:@[@"cat"]]; }];
	[script then:^{ PVPostKey(PVKeyRight, nil, 0); }];
	[script wait:@"its translation" until:^BOOL { return [self shows:@[@"cat", @"chat"]]; }];
	[script then:^{ PVPostKey(PVKeyRight, nil, 0); }];
	[script wait:@"the third word" until:^BOOL { return [self shows:@[@"dog"]]; }];
	[script then:^{ PVPostKey(PVKeyLeft, nil, 0); }];
	[script wait:@"the second word again (Left)" until:^BOOL { return [self shows:@[@"cat"]]; }];
	// Space: play / pause; the control appears and fades out
	[script then:^{
		XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:PVSlideshowAutoAdvance]);
		XCTAssertTrue([[self controlPanel] alphaValue] < 0.05, @"the control should be invisible");
		PVPostKey(PVKeySpace, nil, 0);
	}];
	[script wait:@"Space to start playing and the control to appear" until:^BOOL {
		return [[NSUserDefaults standardUserDefaults] boolForKey:PVSlideshowAutoAdvance] && [[self controlPanel] alphaValue] > 0.9;
	}];
	[script then:^{
		PVSaveWindowScreenshot([self controlPanel], @"slideshow/control");
		PVPostKey(PVKeySpace, nil, 0);
	}];
	[script wait:@"Space to pause" until:^BOOL { return ![[NSUserDefaults standardUserDefaults] boolForKey:PVSlideshowAutoAdvance]; }];
	[script wait:@"the control to fade out" timeout:8 until:^BOOL { return [[self controlPanel] alphaValue] < 0.05; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"the slideshow to end (Esc)" until:^BOOL { return [[self slideViews] count] == 0 && [[mDocument window] isKeyWindow] && ![self controlPanel]; }];
	[self runScript:script];
}

// With "advance automatically" on, the slides follow each other up to the end.
-(void)testSlideshowAdvancesAutomatically
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:YES forKey:PVSlideshowAutoAdvance];
	[defaults setFloat:1.0 forKey:PVSlideshowSpeed];	// fastest
	PVScript *script = [PVScript script];
	NSMutableOrderedSet *seen = [NSMutableOrderedSet orderedSet];
	[script then:^{ PVTypeCommand(@"r", NSEventModifierFlagShift); }];
	[script wait:@"the slideshow to start" timeout:10 until:^BOOL { return [[self slideViews] count] > 0; }];
	[script wait:@"the slideshow to run through all words and end by itself" timeout:60 until:^BOOL {
		[seen addObjectsFromArray:[self visibleSlideTexts]];
		return [[self slideViews] count] == 0;
	}];
	[script then:^{
		NSArray *expected = @[@"house", @"maison", @"cat", @"chat", @"dog", @"chien", @"summer", @"été"];
		XCTAssertEqualObjects([seen array], expected);
	}];
	[self runScript:script];
	[defaults setFloat:0.5 forKey:PVSlideshowSpeed];
}

// The picture of a word shows on its slide, its sounds play one after the other, and
// its movie plays.
-(void)testSlideshowShowsAndPlaysMedia
{
	ProVocWord *house = [self wordWithSource:@"house"];
	[mDocument setAudioFile:PVMediaFile(@"aiff") forKey:@"Source" ofWord:house];
	[mDocument setAudioFile:PVMediaFile(@"m4a") forKey:@"Target" ofWord:house];
	[mDocument setImageFile:PVMediaFile(@"png") ofWord:house];
	[mDocument setMovieFile:PVMediaFile(@"mov") ofWord:[self wordWithSource:@"cat"]];
	id sounds = [NSClassFromString(@"SlideShowSoundGenerator") performSelector:@selector(sharedGenerator)];
	NSView *(^slide)(void) = ^{ return (NSView *)[[self slideViews] lastObject]; };
	QTMovieView *(^movieView)(void) = ^{
		for (NSView *view in [self slideViews])
			for (NSView *subview in [view subviews])
				if ([subview isKindOfClass:[QTMovieView class]] && [[view window] alphaValue] > 0.9)
					return (QTMovieView *)subview;
		return (QTMovieView *)nil;
	};
	NSSound *(^playing)(void) = ^{ return (NSSound *)[sounds valueForKey:@"mCurrentSound"]; };
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", NSEventModifierFlagShift); }];
	[script wait:@"the slide of house with its picture, its sound playing" timeout:10 until:^BOOL {
		return [self shows:@[@"house"]] && [slide() valueForKey:@"mImage"] != nil && [playing() isPlaying];
	}];
	[script wait:@"the sound to end" until:^BOOL { return playing() == nil; }];
	[script then:^{
		// the word and its picture are really on the screen
		NSBitmapImageRep *shot = PVSaveWindowScreenshot([slide() window], @"slideshow/word-with-picture");
		XCTAssertTrue(PVNumberOfDistinctColors(shot) >= 4, @"the slide should show a blue and yellow picture and a word (%lu colors)", (unsigned long)PVNumberOfDistinctColors(shot));
		PVPostKey(PVKeyRight, nil, 0);
	}];
	[script wait:@"the translation, its sound playing" until:^BOOL { return [self shows:@[@"house", @"maison"]] && [playing() isPlaying]; }];
	[script wait:@"the sound to end" until:^BOOL { return playing() == nil; }];
	[script then:^{ PVPostKey(PVKeyRight, nil, 0); }];
	[script wait:@"the slide of cat, its movie playing" timeout:10 until:^BOOL { return [self shows:@[@"cat"]] && [movieView() isPlaying]; }];
	[script then:^{
		PVSaveWindowScreenshot([movieView() window], @"slideshow/word-with-movie");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the slideshow to end (Esc)" until:^BOOL { return [[self slideViews] count] == 0 && [[mDocument window] isKeyWindow] && ![self controlPanel]; }];
	[self runScript:script];
}

@end
