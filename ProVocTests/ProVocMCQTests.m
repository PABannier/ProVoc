//
//  ProVocMCQTests.m
//
//  Multiple-choice tests driven with the keyboard (and a double click), in a sheet
//  and in the dimmed modal panel.
//

#import "PVScenarioTestCase.h"
#import "ProVocMCQView.h"
#import "ProVocInspector.h"

@interface ProVocMCQView (Layout)
-(NSRect)rectForSpeakerIconAtIndex:(int)inIndex;
@end

@interface ProVocMCQTests : PVScenarioTestCase
@end

@implementation ProVocMCQTests

-(NSArray *)words
{
	NSArray *words = @[@[@"house", @"maison"], @[@"cat", @"chat"], @[@"dog", @"chien"], @[@"summer", @"été"], @[@"bread", @"pain"], @[@"water", @"eau"]];
	// the grid of pictures needs ten words to show its four columns
	if ([NSStringFromSelector([[self invocation] selector]) rangeOfString:@"Picture"].location != NSNotFound)
		words = [words arrayByAddingObjectsFromArray:@[@[@"book", @"livre"], @[@"tree", @"arbre"], @[@"sun", @"soleil"], @[@"sea", @"mer"]]];
	return words;
}

// A picture of its own for a word: a colored square with the number of the word
-(NSString *)pictureFileForWordAtIndex:(NSUInteger)inIndex
{
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVMCQPicture-%i-%lu.png", [[NSProcessInfo processInfo] processIdentifier], (unsigned long)inIndex]];
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:200 pixelsHigh:150 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
																	  colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
		[[NSColor colorWithCalibratedHue:inIndex / 10.0 saturation:0.8 brightness:0.9 alpha:1.0] set];
		NSRectFill(NSMakeRect(0, 0, 200, 150));
		[[NSString stringWithFormat:@"%lu", (unsigned long)inIndex + 1] drawAtPoint:NSMakePoint(75, 40) withAttributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:64], NSForegroundColorAttributeName: [NSColor whiteColor]}];
		[NSGraphicsContext restoreGraphicsState];
		[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
	}
	return path;
}

-(void)setUp
{
	[super setUp];
	[mDocument setValue:@YES forKey:@"testMCQ"];
	[mDocument setValue:@4 forKey:@"testMCQNumber"];
	[mDocument setValue:@NO forKey:@"delayedMCQ"];
	[mDocument setValue:@NO forKey:@"imageMCQ"];
	[mDocument setValue:@2 forKey:@"numberOfRetries"];
}

-(ProVocMCQView *)mcqView
{
	return [[self tester] valueForKey:@"mMCQView"];
}

-(NSArray *)choices
{
	return [[self mcqView] valueForKey:@"mAnswers"];
}

-(int)selectedIndex
{
	return [[[self mcqView] valueForKey:@"mSelectedIndex"] intValue];
}

-(int)solutionIndex
{
	return [[[self mcqView] valueForKey:@"mSolutionIndex"] intValue];
}

-(BOOL)choicesAreDisplayed
{
	return [[[self mcqView] valueForKey:@"mDisplayAnswers"] boolValue];
}

// The multiple-choice panel is up, the choice list has the keyboard focus and nothing is selected yet
-(BOOL)showsMCQQuestionNumber:(int)inNumber
{
	ProVocMCQView *view = [self mcqView];
	return [self tester] && [[self testPanel] isVisible] && [[self testPanel] isKeyWindow] && [[self testPanel] firstResponder] == view
		&& [self progress] == inNumber && [self selectedIndex] < 0 && [[self choices] count] > 0;
}

-(void)pressDigit:(int)inDigit
{
	// the physical digit keys of the top row, without Shift
	static const unsigned short keyCodes[10] = {29, 18, 19, 20, 21, 23, 22, 26, 28, 25};
	PVPostKey(keyCodes[inDigit], nil, 0);
}

// Digit of the right choice + Return for each question
-(void)scenarioDigitSelectsReturnVerifies
{
	PVScript *script = [PVScript script];
	NSMutableSet *asked = [NSMutableSet set];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 6; number++) {
		[script wait:[NSString stringWithFormat:@"multiple-choice question %i", number] until:^BOOL { return [self showsMCQQuestionNumber:number]; }];
		[script then:^{
			[asked addObject:[self question]];
			XCTAssertEqual([[self choices] count], 4u);
			XCTAssertEqualObjects([self choices][[self solutionIndex]], mAnswers[[self question]]);
			XCTAssertEqual([[NSSet setWithArray:[self choices]] count], 4u, @"the same choice twice: %@", [self choices]);
			[self pressDigit:[self solutionIndex] + 1];
		}];
		[script wait:@"the choice to be selected" until:^BOOL { return [self selectedIndex] == [self solutionIndex]; }];
		if (number == 1)
			[script then:^{ PVSaveWindowScreenshot([self testPanel], [@"tester/mcq-choice-selected" stringByAppendingString:[self variant]]); }];
		[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqual([asked count], 6u);
		XCTAssertEqualObjects([self resultValues], (@[@6, @0]));
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Arrows move the selection (and wrap around); a wrong choice shakes and is counted;
// after the allowed tries the solution is shown and Return goes on.
-(void)scenarioArrowsWrongChoiceAndSolution
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1" until:^BOOL { return [self showsMCQQuestionNumber:1]; }];
	[script then:^{ PVPostKey(PVKeyDown, nil, 0); }];
	[script wait:@"the first choice selected by Down" until:^BOOL { return [self selectedIndex] == 0; }];
	[script then:^{ PVPostKey(PVKeyDown, nil, 0); }];
	[script wait:@"the second choice" until:^BOOL { return [self selectedIndex] == 1; }];
	[script then:^{ PVPostKey(PVKeyUp, nil, 0); }];
	[script wait:@"the first choice again" until:^BOOL { return [self selectedIndex] == 0; }];
	[script then:^{ PVPostKey(PVKeyUp, nil, 0); }];
	[script wait:@"the last choice (wrapped around)" until:^BOOL { return [self selectedIndex] == 3; }];
	// two wrong choices
	for (int attempt = 1; attempt <= 2; attempt++) {
		[script then:^{ [self pressDigit:([self solutionIndex] + attempt) % 4 + 1]; }];
		[script wait:@"a wrong choice selected" until:^BOOL { return [self selectedIndex] >= 0 && [self selectedIndex] != [self solutionIndex]; }];
		[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
		[script wait:[NSString stringWithFormat:@"wrong answer %i counted", attempt] until:^BOOL { return [[self currentWord] wrong] == attempt; }];
	}
	[script wait:@"the solution to be shown" until:^BOOL { return [self showsSolution] && [[[self mcqView] valueForKey:@"mShowSolution"] boolValue] && [self progress] == 1; }];
	[script then:^{
		PVSaveWindowScreenshot([self testPanel], [@"tester/mcq-solution-shown" stringByAppendingString:[self variant]]);
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"question 2" until:^BOOL { return [self showsMCQQuestionNumber:2]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@0, @1, @5]), @"correct / wrong / ignored");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// A double click on a choice selects it and verifies it.
-(void)scenarioDoubleClickSelectsAndVerifies
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsMCQQuestionNumber:number]; }];
		[script then:^{
			PVClickAtPoint([self mcqView], [self pointOfChoice:[self solutionIndex]], 2, 0);
		}];
	}
	[script wait:@"question 3: two double clicks answered two questions" until:^BOOL { return [self showsMCQQuestionNumber:3]; }];
	[script then:^{
		int right = 0;
		for (ProVocWord *word in [mDocument allWords])
			right += [word right];
		XCTAssertEqual(right, 2);
		PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

-(NSPoint)pointOfChoice:(int)inIndex
{
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[[self mcqView] methodSignatureForSelector:NSSelectorFromString(@"rectForChoiceAtIndex:")]];
	[invocation setSelector:NSSelectorFromString(@"rectForChoiceAtIndex:")];
	[invocation setArgument:&inIndex atIndex:2];
	[invocation invokeWithTarget:[self mcqView]];
	NSRect rect;
	[invocation getReturnValue:&rect];
	return NSMakePoint(NSMinX(rect) + 30, NSMidY(rect));
}

// Delayed choices: only the question first, Return reveals the choices. And the
// number of choices is the one asked for.
-(void)scenarioDelayedChoicesAndNumberOfChoices
{
	[mDocument setValue:@YES forKey:@"delayedMCQ"];
	[mDocument setValue:@3 forKey:@"testMCQNumber"];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"question %i with hidden choices", number] until:^BOOL { return [self showsMCQQuestionNumber:number] && ![self choicesAreDisplayed]; }];
		[script then:^{
			XCTAssertEqual([[self choices] count], 3u);
			// a digit must not select a choice that is not shown yet
			[self pressDigit:[self solutionIndex] + 1];
		}];
		[script pause:0.2];
		[script then:^{
			XCTAssertTrue([self selectedIndex] < 0, @"a hidden choice was selected");
			PVPostKey(PVKeyReturn, nil, 0);
		}];
		[script wait:@"the choices to be revealed by Return" until:^BOOL { return [self choicesAreDisplayed] && [self progress] == number; }];
		[script then:^{ [self pressDigit:[self solutionIndex] + 1]; }];
		[script wait:@"the right choice selected" until:^BOOL { return [self selectedIndex] == [self solutionIndex]; }];
		[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	}
	[script wait:@"question 3" until:^BOOL { return [self showsMCQQuestionNumber:3]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// "Multiple choices with images": the choices are the pictures of the words, in a grid
// of 2, 3 or 4 columns; digits and the four arrows select, Return verifies.
-(void)scenarioPictureChoicesInAGrid
{
	NSArray *words = [mDocument allWords];
	XCTAssertEqual([words count], 10u);
	for (NSUInteger i = 0; i < [words count]; i++)
		[mDocument setImageFile:[self pictureFileForWordAtIndex:i] ofWord:words[i]];
	[mDocument setValue:@YES forKey:@"imageMCQ"];
	[mDocument setValue:@1 forKey:@"numberOfRetries"];
	PVScript *script = [PVScript script];
	for (NSArray *grid in @[@[@4, @2, @2], @[@9, @3, @3], @[@10, @4, @3]]) {
		int choices = [grid[0] intValue], columns = [grid[1] intValue], rows = [grid[2] intValue];
		[script then:^{ [mDocument setValue:@(choices) forKey:@"testMCQNumber"]; PVTypeCommand(@"r", 0); }];
		[script wait:[NSString stringWithFormat:@"a grid of %i pictures", choices] until:^BOOL { return [self showsMCQQuestionNumber:1] && (int)[[self choices] count] == choices; }];
		[script then:^{
			ProVocMCQView *view = [self mcqView];
			XCTAssertEqual([view columns], columns, @"%i choices", choices);
			XCTAssertEqual([view rows], rows, @"%i choices", choices);
			XCTAssertEqual((int)[[view valueForKey:@"mImages"] count], choices, @"each choice shows a picture");
			// the solution is the picture of the word asked
			id solution = [self choices][[self solutionIndex]];
			XCTAssertEqualObjects([solution valueForKey:@"imageMedia"], [[self currentWord] imageMedia]);
			if (choices == 9)
				PVPostKey(PVKeyDown, nil, NSEventModifierFlagFunction | NSEventModifierFlagNumericPad);
		}];
		if (choices == 9) {
			// the arrows move in the grid
			[script wait:@"Down to select the first picture" until:^BOOL { return [self selectedIndex] == 0; }];
			[script then:^{ PVPostKey(PVKeyRight, nil, NSEventModifierFlagFunction | NSEventModifierFlagNumericPad); }];
			[script wait:@"Right to select the next picture" until:^BOOL { return [self selectedIndex] == 1; }];
			[script then:^{ PVPostKey(PVKeyDown, nil, NSEventModifierFlagFunction | NSEventModifierFlagNumericPad); }];
			[script wait:@"Down to select the picture below" until:^BOOL { return [self selectedIndex] == 4; }];
			[script then:^{ PVPostKey(PVKeyLeft, nil, NSEventModifierFlagFunction | NSEventModifierFlagNumericPad); }];
			[script wait:@"Left to select the picture before" until:^BOOL { return [self selectedIndex] == 3; }];
			[script then:^{ PVPostKey(PVKeyUp, nil, NSEventModifierFlagFunction | NSEventModifierFlagNumericPad); }];
			[script wait:@"Up to select the picture above" until:^BOOL { return [self selectedIndex] == 0; }];
			[script then:^{ PVSaveWindowScreenshot([self testPanel], [@"tester/mcq-pictures" stringByAppendingString:[self variant]]); }];
		}
		// a digit selects the right picture (the tenth has none: arrows), Return verifies
		__block ProVocWord *word = nil;
		[script then:^{
			word = [self currentWord];
			int solution = [self solutionIndex];
			if (solution < 9)
				[self pressDigit:solution + 1];
			else {
				[self pressDigit:9];
				PVPostKey(PVKeyRight, nil, NSEventModifierFlagFunction | NSEventModifierFlagNumericPad);
			}
		}];
		[script wait:@"the right picture to be selected" until:^BOOL { return [self selectedIndex] == [self solutionIndex]; }];
		[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
		[script wait:@"question 2" until:^BOOL { return [self showsMCQQuestionNumber:2]; }];
		[script then:^{
			XCTAssertEqual([word right], 1);
			XCTAssertEqual([word wrong], 0);
			[word reset];
			PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption);
		}];
		[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	}
	[self runScript:script];
}

// 0 or Space plays the sound of the question; without one, the sound of the selected
// choice. A click on the speaker of a choice plays its sound.
-(void)scenarioZeroAndSpacePlayAudio
{
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	[mDocument setValue:@NO forKey:@"autoPlayMedia"];
	[mDocument setValue:@6 forKey:@"testMCQNumber"];
	// house: a sound for the question; every word: a sound for the answer
	[mDocument setAudioFile:PVMediaFile(@"aiff") forKey:@"Source" ofWord:[self wordWithSource:@"house"]];
	for (ProVocWord *word in [mDocument allWords])
		[mDocument setAudioFile:PVMediaFile(@"wav") forKey:@"Target" ofWord:word];
	NSString *(^playingKey)(void) = ^{ return (NSString *)[[ProVocInspector sharedInspector] valueForKey:@"mPlayingSoundKey"]; };
	NSSound *(^choiceSound)(void) = ^{ return (NSSound *)[[self mcqView] valueForKey:@"mCurrentSound"]; };
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1 (house)" until:^BOOL { return [self showsMCQQuestionNumber:1] && [[self question] isEqualToString:@"house"]; }];
	[script then:^{
		XCTAssertEqual((int)[[[self mcqView] valueForKey:@"mSounds"] count], 6, @"each choice has a sound");
		PVSaveWindowScreenshot([self testPanel], [@"tester/mcq-with-sounds" stringByAppendingString:[self variant]]);
		[self pressDigit:0];
	}];
	[script wait:@"0 to play the sound of the question" until:^BOOL { return [playingKey() isEqualToString:@"Source"]; }];
	[script wait:@"the sound to end" until:^BOOL { return playingKey() == nil; }];
	[script then:^{ PVPostKey(PVKeySpace, @" ", 0); }];
	[script wait:@"Space to play the sound of the question" until:^BOOL { return [playingKey() isEqualToString:@"Source"]; }];
	[script wait:@"the sound to end" until:^BOOL { return playingKey() == nil; }];
	[script then:^{ XCTAssertTrue([self selectedIndex] < 0, @"0 or Space selected a choice"); [self pressDigit:[self solutionIndex] + 1]; }];
	[script wait:@"the right choice to be selected" until:^BOOL { return [self selectedIndex] == [self solutionIndex]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	// cat: no sound for the question
	[script wait:@"question 2 (cat)" until:^BOOL { return [self showsMCQQuestionNumber:2] && [[self question] isEqualToString:@"cat"]; }];
	[script then:^{ [self pressDigit:2]; }];
	[script wait:@"the second choice to be selected" until:^BOOL { return [self selectedIndex] == 1; }];
	[script then:^{ XCTAssertNil(choiceSound(), @"a sound plays although auto-play is off"); PVPostKey(PVKeySpace, @" ", 0); }];
	[script wait:@"Space to play the sound of the selected choice" until:^BOOL { return [choiceSound() isPlaying] && [[[self mcqView] valueForKey:@"mCurrentSoundIndex"] intValue] == 1; }];
	[script wait:@"the sound to end" until:^BOOL { return choiceSound() == nil; }];
	[script then:^{ [self pressDigit:0]; }];
	[script wait:@"0 to play the sound of the selected choice" until:^BOOL { return [choiceSound() isPlaying]; }];
	[script wait:@"the sound to end" until:^BOOL { return choiceSound() == nil; }];
	// a click on the speaker of the fourth choice
	[script then:^{
		NSRect speaker = [[self mcqView] rectForSpeakerIconAtIndex:3];
		PVClickAtPoint([self mcqView], NSMakePoint(NSMidX(speaker), NSMidY(speaker)), 1, 0);
	}];
	[script wait:@"a click on a speaker to select the choice and play its sound" until:^BOOL { return [self selectedIndex] == 3 && [choiceSound() isPlaying] && [[[self mcqView] valueForKey:@"mCurrentSoundIndex"] intValue] == 3; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

@end
