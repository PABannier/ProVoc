//
//  ProVocBackgroundTests.m
//
//  The four built-in backgrounds are drawn natively and really show something; during
//  a full-screen test the background is behind the test panel and follows the test.
//

#import <XCTest/XCTest.h>
#import "PVTestSupport.h"
#import "PVScenarioTestCase.h"
#import <QuartzCore/QuartzCore.h>
#import "ProVocBackground.h"
#import "ProVocBackgroundScene.h"

@interface ProVocBackgroundTests : XCTestCase
@end

@implementation ProVocBackgroundTests

-(void)testBuiltInBackgroundsAreDrawnNatively
{
	NSArray *styles = [ProVocBackgroundStyle availableBackgroundStyles];
	NSMutableSet *names = [NSMutableSet set];
	for (ProVocBackgroundStyle *style in styles)
		if ([style bundle])
			[names addObject:[style identifier]];
	NSSet *expected = [NSSet setWithArray:@[@"ch.arizona-software.provoc.background.plantshades", @"ch.arizona-software.provoc.background.ocean",
											@"ch.arizona-software.provoc.background.globe", @"ch.arizona-software.provoc.background.nature"]];
	XCTAssertTrue([expected isSubsetOfSet:names], @"built-in backgrounds found: %@", names);

	for (ProVocBackgroundStyle *style in styles) {
		if (![expected containsObject:[style identifier]])
			continue;
		XCTAssertTrue([ProVocBackgroundScene canDrawBackgroundOfBundle:[style bundle]], @"%@", [style name]);
		NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(60, 60, 800, 500) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO] autorelease];
		[window setReleasedWhenClosed:NO];
		ProVocBackgroundScene *scene = [[[ProVocBackgroundScene alloc] initWithFrame:NSMakeRect(0, 0, 800, 500)] autorelease];
		[scene setBundle:[style bundle]];
		[window setContentView:scene];
		XCTAssertTrue([[scene inputKeys] count] > 0, @"%@", [style name]);
		[scene setValue:[NSColor colorWithCalibratedRed:0.2 green:0.3 blue:0.5 alpha:1.0] forInputKey:@"Color"];
		[scene setValue:@"the house" forInputKey:@"Question"];
		[scene setValue:@"la maison" forInputKey:@"Answer"];
		[scene startRendering];
		XCTAssertTrue([scene isRendering]);
		[window orderFront:nil];
		PVWaitUntil(2.5, ^BOOL { return NO; });
		NSBitmapImageRep *bitmap = PVSaveWindowScreenshot(window, [@"backgrounds/" stringByAppendingString:[style name]]);
		XCTAssertNotNil(bitmap, @"no screenshot of %@", [style name]);
		XCTAssertTrue(PVNumberOfDistinctColors(bitmap) >= 4, @"the %@ background is blank (%lu colors)", [style name], (unsigned long)PVNumberOfDistinctColors(bitmap));
		// the reactions to answers must not raise
		[scene setValue:@YES forInputKey:@"CorrectAnswer"];
		[scene setValue:@NO forInputKey:@"CorrectAnswer"];
		[scene setValue:@YES forInputKey:@"WrongAnswer"];
		[scene setValue:@NO forInputKey:@"WrongAnswer"];
		[scene setValue:@YES forInputKey:@"NewQuestion"];
		[scene setValue:@NO forInputKey:@"NewQuestion"];
		PVWaitUntil(0.3, ^BOOL { return NO; });
		[scene stopRendering];
		[window close];
	}
}

@end

// "Dim test background" (the full-screen test): the screen is covered by the animated
// background chosen in the Preferences - or by the plain background color - and the
// background follows the test: the globe shows the question and the answer, the plants
// react to right and wrong answers. It goes away with the test.
@interface ProVocTestBackgroundTests : PVScenarioTestCase
@end

@implementation ProVocTestBackgroundTests

-(NSWindow *)backgroundWindow
{
	return [[ProVocBackground sharedBackground] valueForKey:@"mWindow"];
}

-(ProVocBackgroundScene *)scene
{
	return [[ProVocBackground sharedBackground] valueForKey:@"mRenderer"];
}

// What the user does in the General preferences: animated background on, and which one
-(void)chooseBackground:(NSString *)inKind
{
	ProVocPreferences *preferences = [ProVocPreferences sharedPreferences];
	[preferences setValue:@YES forKey:@"enableBackground"];
	NSArray *styles = [ProVocBackgroundStyle availableBackgroundStyles];
	for (NSUInteger pass = 0; pass < 2; pass++)	// (another one first, so that the choice is a change)
		for (NSUInteger index = 0; index < [styles count]; index++)
			if ([[[styles[index] identifier] pathExtension] isEqualToString:inKind] == (pass == 1)) {
				[preferences setValue:@(index) forKey:@"indexOfSelectedBackgroundStyle"];
				break;
			}
	XCTAssertEqualObjects([[[ProVocBackgroundStyle currentBackgroundStyle] identifier] pathExtension], inKind);
}

-(BOOL)backgroundCoversTheScreen
{
	return [self backgroundCoversTheScreenBehind:[self testPanel]];
}

-(BOOL)backgroundCoversTheScreenBehind:(NSWindow *)inPanel
{
	NSRect screen = [[NSScreen mainScreen] frame];
	NSRect frame = [[self backgroundWindow] frame];
	return [[self backgroundWindow] isVisible] && NSWidth(frame) >= MIN(NSWidth(screen), 2000) && NSHeight(frame) >= MIN(NSHeight(screen), 2000)
		&& [[self backgroundWindow] level] < [inPanel level] && [[self scene] isRendering];
}

-(void)testGlobeShowsQuestionAndAnswer
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PVDimTestBackground];
	[self chooseBackground:@"globe"];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	[mDocument setValue:@1 forKey:@"numberOfRetries"];
	PVScript *script = [PVScript script];
	[script then:^{
		XCTAssertFalse([[self backgroundWindow] isVisible], @"the background is on screen before the test");
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"the first question, in front of the background" timeout:15 until:^BOOL { return [self showsQuestionNumber:1] && [self answerFieldHasFocus] && [self backgroundCoversTheScreen]; }];
	[script then:^{
		XCTAssertTrue([[self scene] isKindOfClass:[ProVocBackgroundScene class]], @"the globe is not drawn natively: %@", [self scene]);
		XCTAssertEqualObjects([[self scene] valueForInputKey:@"Question"], @"house");
		XCTAssertNil([[self scene] valueForInputKey:@"Answer"], @"the answer is on the background before it is given");
		PVTypeText(@"wrong");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	// one try only: the solution is displayed, and the background shows it
	[script wait:@"the solution, on the background too" until:^BOOL { return [self showsSolution] && [[[self scene] valueForInputKey:@"Answer"] isEqual:@"maison"]; }];
	[script then:^{
		NSBitmapImageRep *bitmap = PVSaveWindowScreenshot([self backgroundWindow], @"backgrounds/globe-during-test");
		XCTAssertTrue(PVNumberOfDistinctColors(bitmap) >= 4, @"the background is blank during the test");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the second question; the background remembers the first" until:^BOOL {
		return [self showsQuestionNumber:2] && [[[self scene] valueForInputKey:@"Question"] isEqual:@"cat"] && [[[self scene] valueForInputKey:@"PreviousQuestion"] isEqual:@"house"] && [[self scene] valueForInputKey:@"Answer"] == nil;
	}];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"Option-Esc to end the test and remove the background" until:^BOOL { return [self testIsOver] && ![[self backgroundWindow] isVisible] && ![[self scene] isRendering]; }];
	[self runScript:script];
}

-(void)testPlantsReactToAnswersAndResults
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PVDimTestBackground];
	[self chooseBackground:@"plantshades"];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	CAEmitterLayer *(^blossoms)(void) = ^{
		for (CALayer *layer in [[[self scene] layer] sublayers])
			if ([[layer name] isEqualToString:@"blossoms"])
				return (CAEmitterLayer *)layer;
		return (CAEmitterLayer *)nil;
	};
	// the flash of a reaction: a layer that covers the scene, white (right) or red (wrong)
	CALayer *(^flash)(void) = ^{
		for (CALayer *layer in [[[self scene] layer] sublayers])
			if ([layer animationForKey:@"flash"])
				return layer;
		return (CALayer *)nil;
	};
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"the first question, in front of the plants" timeout:15 until:^BOOL { return [self showsQuestionNumber:1] && [self answerFieldHasFocus] && [self backgroundCoversTheScreen] && blossoms() != nil; }];
	[script wait:@"no reaction yet" until:^BOOL { return flash() == nil && [blossoms() birthRate] <= 1; }];
	[script then:^{ PVTypeText(@"wrong"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"a red flash for the wrong answer" until:^BOOL {
		NSColor *color = flash() ? [[NSColor colorWithCGColor:[flash() backgroundColor]] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] : nil;
		return color && [color redComponent] > 0.4 && [color greenComponent] < 0.2;
	}];
	[script wait:@"the flash to fade away" until:^BOOL { return flash() == nil; }];
	[script then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"maison"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"blossoms and a white flash for the right answer" until:^BOOL {
		NSColor *color = flash() ? [[NSColor colorWithCGColor:[flash() backgroundColor]] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] : nil;
		return [blossoms() birthRate] > 10 && color && [color greenComponent] > 0.9;
	}];
	[script wait:@"the next question, the blossoms calm again" until:^BOOL { return [self showsQuestionNumber:2] && [blossoms() birthRate] <= 1; }];
	[script then:^{
		PVSaveWindowScreenshot([self backgroundWindow], @"backgrounds/plants-during-test");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	// Esc: the results, still in front of the background
	[script wait:@"the results in front of the background" until:^BOOL { return [[self resultPanel] isVisible] && [self backgroundCoversTheScreenBehind:[self resultPanel]]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"the end of the test: no background any more" until:^BOOL { return [self testIsOver] && ![[self backgroundWindow] isVisible] && ![[self scene] isRendering]; }];

	// without animated background: the screen is only dimmed, with the color of the Preferences
	[script then:^{
		[[ProVocPreferences sharedPreferences] setValue:@NO forKey:@"enableBackground"];
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"a test without animated background" timeout:15 until:^BOOL { return [self showsQuestionNumber:1] && [self answerFieldHasFocus]; }];
	[script then:^{
		XCTAssertFalse([[self backgroundWindow] isVisible], @"the animated background shows although it is turned off");
		// the windows that dim the screens are there
		NSUInteger dimming = 0;
		for (NSWindow *window in [NSApp windows])
			if ([window isVisible] && [window styleMask] == NSWindowStyleMaskBorderless && NSWidth([window frame]) >= NSWidth([[NSScreen mainScreen] frame]) && window != [self backgroundWindow])
				dimming++;
		XCTAssertTrue(dimming >= 1, @"the screen is not dimmed");
		PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption);
	}];
	[script wait:@"the end of the test" until:^BOOL { return [self testIsOver]; }];
	[script then:^{
		for (NSWindow *window in [NSApp windows])
			XCTAssertFalse([window isVisible] && [window styleMask] == NSWindowStyleMaskBorderless && NSWidth([window frame]) >= NSWidth([[NSScreen mainScreen] frame]), @"the screen is still dimmed after the test");
	}];
	[self runScript:script];
}

@end

