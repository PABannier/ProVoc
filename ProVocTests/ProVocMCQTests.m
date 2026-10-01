//
//  ProVocMCQTests.m
//
//  Multiple-choice tests driven with the keyboard (and a double click), in a sheet
//  and in the dimmed modal panel.
//

#import "PVScenarioTestCase.h"
#import "ProVocMCQView.h"

@interface ProVocMCQTests : PVScenarioTestCase
@end

@implementation ProVocMCQTests

-(NSArray *)words
{
	return @[@[@"house", @"maison"], @[@"cat", @"chat"], @[@"dog", @"chien"], @[@"summer", @"été"], @[@"bread", @"pain"], @[@"water", @"eau"]];
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

@end
