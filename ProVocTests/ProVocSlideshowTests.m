//
//  ProVocSlideshowTests.m
//
//  The slideshow (Shift-Command-R) driven with the keyboard.
//

#import "PVScenarioTestCase.h"
#import "ProVocDocument+Slideshow.h"

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

@end
