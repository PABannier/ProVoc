//
//  ProVocInterrogationTests.m
//
//  Written tests driven with key events posted to the application's event queue
//  (they travel through -[ProVocApplication sendEvent:] like real keystrokes), checking
//  what the user would see. Every scenario runs twice: with the test panel as a sheet
//  and as the modal panel used when "Dim test background" is on.
//

#import "PVScenarioTestCase.h"

@interface ProVocInterrogationTests : PVScenarioTestCase
@end

@implementation ProVocInterrogationTests

-(NSArray *)words
{
	if ([NSStringFromSelector([[self invocation] selector]) rangeOfString:@"DeadKeys"].location != NSNotFound)
		return @[@[@"forest", @"forêt"], @[@"naive", @"naïve"], @[@"child", @"niño"], @[@"pupil", @"élève"], @[@"boy", @"garçon"], @[@"where", @"où"], @[@"coffee", @"café"], @[@"there", @"là"]];
	return [super words];
}

#pragma mark Scenarios

// Type the answer, Return, type the answer, Return... never touching the mouse.
-(void)allCorrectWithReturnKeyCode:(unsigned short)inReturnKeyCode
{
	PVScript *script = [PVScript script];
	NSMutableArray *asked = [NSMutableArray array];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i with the answer field empty and focused", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{
			XCTAssertFalse([asked containsObject:[self question]], @"%@ asked twice", [self question]);
			[asked addObject:[self question]];
		}];
		[self answerCorrectlyIn:script withReturnKeyCode:inReturnKeyCode];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqual([asked count], 4u);
		for (ProVocWord *word in [mDocument allWords]) {
			XCTAssertEqual([word right], 1, @"%@", word);
			XCTAssertEqual([word wrong], 0, @"%@", word);
		}
		// nothing to repeat: Return means Done
		PVPostKey(inReturnKeyCode, nil, 0);
	}];
	[script wait:@"the result panel to close and the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

-(void)scenarioAllCorrect
{
	[self allCorrectWithReturnKeyCode:PVKeyReturn];
}

-(void)scenarioKeypadEnterBehavesLikeReturn
{
	[self allCorrectWithReturnKeyCode:PVKeyKeypadEnter];
}

// Wrong answer: shake, counted wrong, the field keeps the focus for another try. After
// the allowed number of tries the solution is shown; Return then goes on (wrong),
// Y accepts the answer, N rejects it. The result panel offers to repeat the wrong words.
-(void)scenarioWrongAnswersSolutionAcceptRejectAndRepeat
{
	[mDocument setValue:@2 forKey:@"numberOfRetries"];
	PVScript *script = [PVScript script];
	NSMutableDictionary *outcome = [NSMutableDictionary dictionary];	// question -> what was done
	[script then:^{ PVTypeCommand(@"r", 0); }];
	NSArray *plan = @[@"return", @"y", @"n", @"correct"];
	for (int number = 1; number <= 4; number++) {
		NSString *what = plan[number - 1];
		[script wait:[NSString stringWithFormat:@"question %i with the answer field empty and focused", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{ outcome[[self question]] = what; }];
		if ([what isEqualToString:@"correct"]) {
			[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
			continue;
		}
		// first try
		[script then:^{ PVTypeText(@"oops"); }];
		[script wait:@"oops typed" until:^BOOL { return [[self typedAnswer] isEqualToString:@"oops"]; }];
		if (number == 1)
			[script then:^{
				PVSaveWindowSnapshot([self testPanel], [@"tester/question-with-typed-answer" stringByAppendingString:[self variant]]);
				PVSaveWindowScreenshot([self testPanel], [@"tester/screen-question" stringByAppendingString:[self variant]]);
				NSWindow *background = [[ProVocBackground sharedBackground] valueForKey:@"mWindow"];
				if ([background isVisible]) {
					NSBitmapImageRep *bitmap = PVSaveWindowScreenshot(background, @"tester/screen-background-behind-dimmed-test");
					XCTAssertTrue(PVNumberOfDistinctColors(bitmap) >= 4, @"the background behind the test panel is blank");
				}
			}];
		[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
		[script wait:@"first wrong answer counted, same question, field focused with its text selected" until:^BOOL {
			return [[self currentWord] wrong] == 1 && [self progress] == number && ![self showsSolution] && [self answerFieldHasFocus] && [self answerTextIsSelectedOrEmpty];
		}];
		// second and last try: typing replaces the selected text
		[script then:^{ PVTypeText(@"nope"); }];
		[script wait:@"nope typed over the previous answer" until:^BOOL { return [[self typedAnswer] isEqualToString:@"nope"]; }];
		[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
		[script wait:@"the solution to be shown" until:^BOOL { return [self showsSolution] && [self progress] == number; }];
		[script then:^{
			if (number == 1)
				PVSaveWindowSnapshot([self testPanel], [@"tester/solution-shown" stringByAppendingString:[self variant]]);
			XCTAssertEqual([[self currentWord] wrong], 2);
			XCTAssertEqualObjects([self displayedSolution], mAnswers[[self question]]);
			if ([what isEqualToString:@"return"])
				PVPostKey(PVKeyReturn, nil, 0);
			else
				PVTypeText(what);
		}];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{
		for (NSString *question in outcome) {
			ProVocWord *word = [self wordWithSource:question];
			NSString *what = outcome[question];
			if ([what isEqualToString:@"correct"]) {
				XCTAssertEqual([word right], 1, @"%@", question); XCTAssertEqual([word wrong], 0, @"%@", question);
			} else if ([what isEqualToString:@"y"]) {
				XCTAssertEqual([word right], 1, @"accepted with Y: %@", question);
			} else {
				XCTAssertEqual([word right], 0, @"%@ (%@)", question, what);
				XCTAssertTrue([word wrong] >= 2, @"%@ (%@)", question, what);
			}
		}
		PVSaveWindowSnapshot([self resultPanel], [@"tester/result-with-wrong-words" stringByAppendingString:[self variant]]);
		XCTAssertEqualObjects([self resultValues], (@[@2, @2]), @"correct / wrong");
		XCTAssertFalse([[self retryButton] isHidden]);
		// there are wrong words: Return means "Repeat Incorrect Words"
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	// second round: only the two wrong words
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"repeated question %i with the answer field empty and focused", number] until:^BOOL { return [self showsQuestionNumber:number] && [[[self tester] valueForKey:@"progressMax"] intValue] == 2; }];
		[script then:^{ XCTAssertTrue(([@[@"return", @"n"] containsObject:outcome[[self question]]]), @"%@ should not be asked again", [self question]); }];
		[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	}
	[script wait:@"the result panel again" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@2, @0]), @"correct / wrong");
		XCTAssertTrue([[self retryButton] isHidden]);
		// nothing wrong any more: Return means Done
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Two deliberate Returns 50 ms apart both count ("check", then "next word"); a Return
// held down (auto-repeat) does not rush through the following words.
-(void)scenarioQuickDoubleReturnAndHeldReturn
{
	// "house" has two accepted answers: answering one of them is correct, the full answer
	// is then displayed and a second Return goes on.
	[[self wordWithSource:@"house"] setTargetWord:@"maison/demeure"];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1 (house)" until:^BOOL { return [self showsQuestionNumber:1] && [[self question] isEqualToString:@"house"]; }];
	[script then:^{ PVTypeText(@"maison"); }];
	[script wait:@"maison typed" until:^BOOL { return [[self typedAnswer] isEqualToString:@"maison"]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script pause:0.05];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 2: both Returns were taken into account" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{ XCTAssertEqual([[self wordWithSource:@"house"] right], 1); }];
	// Return held down on a correct answer: one word forward, not more, and no wrong answer recorded
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script then:^{
		for (int i = 0; i < 10; i++)
			PVPostKeyRepeat(PVKeyReturn, nil, 0, YES);
	}];
	[script pause:0.5];
	[script wait:@"question 3, untouched by the repeated Returns" until:^BOOL { return [self showsQuestionNumber:3]; }];
	[script then:^{
		XCTAssertEqual([[self currentWord] wrong], 0, @"auto-repeat was taken for an (empty, wrong) answer");
		XCTAssertFalse([self showsSolution]);
	}];
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script wait:@"question 4" until:^BOOL { return [self showsQuestionNumber:4]; }];
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@4, @0]));
		// Esc means Done as well
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Command-G gives the solution, Command-A accepts the answer, Shift-Command-F flags the
// word and Command-0...9 set its label, all without leaving the answer field.
-(void)scenarioGiveSolutionAcceptFlagAndLabelShortcuts
{
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1" until:^BOOL { return [self showsQuestionNumber:1]; }];
	// flag, unflag, flag
	[script then:^{ XCTAssertEqual([[self currentWord] mark], 0); PVTypeCommand(@"f", NSEventModifierFlagShift); }];
	[script wait:@"the word to be flagged" until:^BOOL { return [[self currentWord] mark] == 1 && [self answerFieldHasFocus]; }];
	[script then:^{ PVTypeCommand(@"f", NSEventModifierFlagShift); }];
	[script wait:@"the word to be unflagged" until:^BOOL { return [[self currentWord] mark] == 0 && [self answerFieldHasFocus]; }];
	[script then:^{ PVTypeCommand(@"f", NSEventModifierFlagShift); }];
	[script wait:@"the word to be flagged again" until:^BOOL { return [[self currentWord] mark] == 1; }];
	// labels
	for (int label = 9; label >= 0; label -= 3) {
		[script then:^{ PVTypeCommand([NSString stringWithFormat:@"%i", label], 0); }];
		[script wait:[NSString stringWithFormat:@"label %i", label] until:^BOOL { return [[self currentWord] label] == label && [self answerFieldHasFocus]; }];
	}
	[script then:^{ PVTypeCommand(@"3", 0); }];
	[script wait:@"label 3" until:^BOOL { return [[self currentWord] label] == 3; }];
	// Command-G: solution, then Return: counted wrong
	[script then:^{ PVTypeCommand(@"g", 0); }];
	[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
	[script then:^{ XCTAssertEqualObjects([self displayedSolution], mAnswers[[self question]]); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{
		ProVocWord *first = [self wordWithSource:@"house"];
		XCTAssertEqual([first right], 0); XCTAssertTrue([first wrong] > 0); XCTAssertEqual([first mark], 1); XCTAssertEqual([first label], 3);
		// Command-G then Command-A: accepted as correct
		PVTypeCommand(@"g", 0);
	}];
	[script wait:@"the solution of question 2" until:^BOOL { return [self showsSolution]; }];
	[script then:^{ PVTypeCommand(@"a", 0); }];
	[script wait:@"question 3" until:^BOOL { return [self showsQuestionNumber:3]; }];
	[script then:^{
		ProVocWord *second = [self wordWithSource:@"cat"];
		XCTAssertEqual([second right], 1); XCTAssertEqual([second wrong], 0);
	}];
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script wait:@"question 4" until:^BOOL { return [self showsQuestionNumber:4]; }];
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ XCTAssertEqualObjects([self resultValues], (@[@3, @1])); PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Esc finishes the test (the words not asked yet are reported as ignored and can be
// repeated); Option-Esc aborts it at once.
-(void)scenarioEscapeFinishesAndOptionEscapeAborts
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1" until:^BOOL { return [self showsQuestionNumber:1]; }];
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@1, @0, @3]), @"correct / wrong / ignored");
		XCTAssertFalse([[self retryButton] isHidden]);
		// Return repeats the ignored words
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the three remaining words" until:^BOOL { return [self showsQuestionNumber:1] && [[[self tester] valueForKey:@"progressMax"] intValue] == 3; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be aborted without result panel" until:^BOOL { return [self testIsOver]; }];

	// the same with the button: it reads Finish, and Abort while Option is down
	NSButton *(^finishButton)(void) = ^{ return [self buttonWithAction:@selector(cancelTestPanel:) inView:[[self testPanel] contentView]]; };
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"a new test" until:^BOOL { return [self showsQuestionNumber:1] && [self answerFieldHasFocus]; }];
	[script then:^{
		XCTAssertEqualObjects([finishButton() title], NSLocalizedString(@"Finish Button Title", @""));
		PVClickView(finishButton(), 1, 0);
	}];
	[script wait:@"a click on Finish to show the results" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"Esc (Done) to close the results" until:^BOOL { return [self testIsOver]; }];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"a new test" until:^BOOL { return [self showsQuestionNumber:1] && [self answerFieldHasFocus]; }];
	[script then:^{ PVPostFlagsChanged(NSEventModifierFlagOption); }];
	[script wait:@"the button to read Abort while Option is down" until:^BOOL { return [[finishButton() title] isEqualToString:NSLocalizedString(@"Abort Button Title", @"")]; }];
	[script then:^{ PVClickView(finishButton(), 1, NSEventModifierFlagOption); }];
	[script wait:@"Option-click on Abort to end the test without result panel" until:^BOOL { return [self testIsOver] && ![[self resultPanel] isVisible]; }];
	[script then:^{ PVPostFlagsChanged(0); }];
	[self runScript:script];
}

// Command-P pauses (it must not print), Command-R resumes with the same word.
-(void)scenarioPauseAndResume
{
	PVScript *script = [PVScript script];
	__block NSString *pausedQuestion = nil;
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1" until:^BOOL { return [self showsQuestionNumber:1]; }];
	[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{ pausedQuestion = [[self question] copy]; PVTypeCommand(@"p", 0); }];
	[script wait:@"the test panel to close, the test staying resumable" until:^BOOL {
		return ![[self testPanel] isVisible] && [mDocument valueForKey:@"mTester"] && [[mDocument valueForKey:@"canResumeTest"] boolValue] && [[mDocument window] isKeyWindow] && [[mDocument window] attachedSheet] == nil && ![NSApp modalWindow];
	}];
	[script then:^{ XCTAssertNil([[mDocument window] attachedSheet], @"a print panel?"); PVTypeCommand(@"r", 0); }];
	[script wait:@"the test to resume on the same question" until:^BOOL { return [self showsQuestionNumber:2] && [[self question] isEqualToString:pausedQuestion]; }];
	for (int number = 2; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[self answerCorrectlyIn:script withReturnKeyCode:PVKeyReturn];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ XCTAssertEqualObjects([self resultValues], (@[@4, @0])); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Holding Option turns "Give Answer" into "Give Hint": each click reveals one more
// letter in the answer field, which keeps the focus.
-(void)scenarioHintWithOptionClick
{
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	PVScript *script = [PVScript script];
	NSButton *(^giveButton)(void) = ^{ return [self buttonWithAction:@selector(giveAnswerTestPanel:) inView:[[self testPanel] contentView]]; };
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1 (house)" until:^BOOL { return [self showsQuestionNumber:1] && [[self question] isEqualToString:@"house"]; }];
	[script then:^{
		XCTAssertEqualObjects([giveButton() title], NSLocalizedString(@"Give Answer Button Title", @""));
		PVPostFlagsChanged(NSEventModifierFlagOption);
	}];
	[script wait:@"the button to read Give Hint while Option is down" until:^BOOL { return [[giveButton() title] isEqualToString:NSLocalizedString(@"Give Hint Button Title", @"")]; }];
	[script then:^{ PVClickView(giveButton(), 1, NSEventModifierFlagOption); }];
	[script wait:@"the first letter" until:^BOOL { return [[self typedAnswer] isEqualToString:@"m"] && [self answerFieldHasFocus]; }];
	[script then:^{ PVClickView(giveButton(), 1, NSEventModifierFlagOption); }];
	[script wait:@"the second letter" until:^BOOL { return [[self typedAnswer] isEqualToString:@"ma"] && [self answerFieldHasFocus]; }];
	[script then:^{ PVPostFlagsChanged(0); }];
	[script wait:@"the button to read Give Answer again" until:^BOOL { return [[giveButton() title] isEqualToString:NSLocalizedString(@"Give Answer Button Title", @"")]; }];
	// the cursor is after the hint: the rest of the word is typed
	[script then:^{ XCTAssertFalse([self showsSolution]); PVTypeText(@"ison"); }];
	[script wait:@"the completed answer" until:^BOOL { return [[self typedAnswer] isEqualToString:@"maison"]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{
		XCTAssertEqual([[self wordWithSource:@"house"] right], 1);
		PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Holding Option turns "Pause" into "Edit": the test is paused and the current word
// is selected in the list, ready to be edited; the test can be resumed.
-(void)scenarioEditCurrentWordWithOptionClick
{
	PVScript *script = [PVScript script];
	__block NSString *question = nil;
	NSButton *(^pauseButton)(void) = ^{ return [self buttonWithAction:@selector(pauseTestPanel:) inView:[[self testPanel] contentView]]; };
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"question 1" until:^BOOL { return [self showsQuestionNumber:1]; }];
	[self answerCorrectlyIn:script];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[script then:^{ question = [[self question] copy]; PVPostFlagsChanged(NSEventModifierFlagOption); }];
	[script wait:@"the button to read Edit while Option is down" until:^BOOL { return [[pauseButton() title] isEqualToString:NSLocalizedString(@"Edit Button Title", @"")]; }];
	[script then:^{ PVClickView(pauseButton(), 1, NSEventModifierFlagOption); }];
	[script wait:@"the test to pause and the word to be selected in the Editing view" until:^BOOL {
		NSArray *selected = [mDocument selectedWords];
		return ![[self testPanel] isVisible] && [[mDocument valueForKey:@"canResumeTest"] boolValue] && [[mDocument valueForKey:@"mainTab"] intValue] == 1
			&& [selected count] == 1 && [[(ProVocWord *)selected[0] sourceWord] isEqualToString:question];
	}];
	[script then:^{ PVPostFlagsChanged(0); PVTypeCommand(@"r", 0); }];
	[script wait:@"the test to resume on the same question" until:^BOOL { return [self showsQuestionNumber:2] && [[self question] isEqualToString:question]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Direction target -> source: the questions are the translations.
-(void)scenarioDirectionTargetToSource
{
	[mDocument setValue:@1 forKey:@"testDirection"];
	NSDictionary *reversed = [NSDictionary dictionaryWithObjects:[mAnswers allKeys] forKeys:[mAnswers allValues]];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{
			XCTAssertNotNil(reversed[[self question]], @"the question should be a translation, not %@", [self question]);
			PVTypeText(reversed[[self question]]);
			PVPostKey(PVKeyReturn, nil, 0);
		}];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ XCTAssertEqualObjects([self resultValues], (@[@4, @0])); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Direction "both": every word is asked once in each direction.
-(void)scenarioDirectionBoth
{
	[mDocument setValue:@3 forKey:@"testDirection"];
	NSDictionary *reversed = [NSDictionary dictionaryWithObjects:[mAnswers allKeys] forKeys:[mAnswers allValues]];
	NSMutableSet *asked = [NSMutableSet set];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 8; number++) {
		[script wait:[NSString stringWithFormat:@"question %i of 8", number] until:^BOOL { return [self showsQuestionNumber:number] && [self progressMax] == 8; }];
		[script then:^{
			NSString *question = [self question];
			XCTAssertFalse([asked containsObject:question], @"%@ asked twice", question);
			[asked addObject:question];
			NSString *answer = mAnswers[question] ? mAnswers[question] : reversed[question];
			XCTAssertNotNil(answer, @"unexpected question %@", question);
			PVTypeText(answer);
			PVPostKey(PVKeyReturn, nil, 0);
		}];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqual([asked count], 8u);
		XCTAssertEqualObjects([self resultValues], (@[@8, @0]));
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Direction "random": with the slider at one end all questions are in one language.
-(void)scenarioDirectionRandom
{
	[mDocument setValue:@2 forKey:@"testDirection"];
	[mDocument setValue:@1.0f forKey:@"testDirectionProbability"];
	NSDictionary *reversed = [NSDictionary dictionaryWithObjects:[mAnswers allKeys] forKeys:[mAnswers allValues]];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{
			XCTAssertNotNil(reversed[[self question]], @"with a probability of 100%% the question should be a translation, not %@", [self question]);
			PVTypeText(reversed[[self question]]);
			PVPostKey(PVKeyReturn, nil, 0);
		}];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// "Train words in random order" off: the words come in the order of the list.
-(void)scenarioWordsInListOrder
{
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	NSArray *order = @[@"house", @"cat", @"dog", @"summer"];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{ XCTAssertEqualObjects([self question], order[number - 1]); }];
		[self answerCorrectlyIn:script];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// "Train only": flagged words, words with given labels, a limited number of words.
-(void)scenarioTrainOnlyFilters
{
	[[self wordWithSource:@"cat"] setMark:1];
	[[self wordWithSource:@"dog"] setLabel:3];
	[[self wordWithSource:@"summer"] setLabel:5];
	[mDocument setValue:@YES forKey:@"testMarked"];
	// row 0 of the label list is "Marked", row n + 1 is label n
	NSMutableIndexSet *labels = [NSMutableIndexSet indexSetWithIndex:0];
	[labels addIndex:3 + 1];
	[mDocument setValue:labels forKey:@"labelsToTest"];
	NSMutableSet *asked = [NSMutableSet set];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"question %i of 2", number] until:^BOOL { return [self showsQuestionNumber:number] && [self progressMax] == 2; }];
		[script then:^{ [asked addObject:[self question]]; }];
		[self answerCorrectlyIn:script];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects(asked, ([NSSet setWithArray:@[@"cat", @"dog"]]), @"only the flagged word and the word with label 3");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	// a limited number of words
	[script then:^{
		[mDocument setValue:@NO forKey:@"testMarked"];
		[mDocument setValue:@YES forKey:@"testLimit"];
		[mDocument setValue:@3 forKey:@"testLimitNumber"];
		[mDocument setValue:@0 forKey:@"testLimitWhat"];
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"a test of 3 words" until:^BOOL { return [self showsQuestionNumber:1] && [self progressMax] == 3; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	// the most difficult words first
	[script then:^{
		[[self wordWithSource:@"summer"] increaseDifficulty];
		[[self wordWithSource:@"summer"] increaseDifficulty];
		[mDocument setValue:@1 forKey:@"testLimitNumber"];
		[mDocument setValue:@1 forKey:@"testLimitWhat"];
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"a test of the most difficult word" until:^BOOL { return [self showsQuestionNumber:1] && [self progressMax] == 1 && [[self question] isEqualToString:@"summer"]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// Dead keys and accented keys in the answer field, typed as key codes that go through
// the text input system: ^ then e gives ê, ¨ then i gives ï, ~ then n gives ñ, and the
// accented letters that have their own key. With the French (AZERTY) layout, and with
// the U.S. layout (Option-E then e gives é...) when it is enabled on this Mac; the
// layout of the user is put back at the end.
-(void)scenarioDeadKeysAndAccentedLetters
{
	NSString *userLayout = [PVCurrentKeyboardLayout() copy];
	NSMutableArray *layouts = [NSMutableArray array];
	for (NSString *layout in @[@"com.apple.keylayout.French", @"com.apple.keylayout.US", @"com.apple.keylayout.ABC"])
		if ([PVEnabledKeyboardLayouts() containsObject:layout])
			[layouts addObject:layout];
	XCTAssertTrue([layouts containsObject:@"com.apple.keylayout.French"], @"the French (AZERTY) layout is not enabled on this Mac: %@", PVEnabledKeyboardLayouts());
	NSLog(@"PVTestSupport: dead keys tested with %@ (enabled layouts: %@)", [layouts componentsJoinedByString:@", "], [PVEnabledKeyboardLayouts() componentsJoinedByString:@", "]);
	// what is typed: plain text, or an accent (a dead key) followed by its letter
	NSArray *answers = @[
		@[@"forest", @"forêt", @[@"for", @[@"^", @"e"], @"t"]],
		@[@"naive", @"naïve", @[@"na", @[@"¨", @"i"], @"ve"]],
		@[@"child", @"niño", @[@"ni", @[@"~", @"n"], @"o"]],
		@[@"pupil", @"élève", @[@"élève"]],
		@[@"boy", @"garçon", @[@"garçon"]],
		@[@"where", @"où", @[@"où"]],
		@[@"coffee", @"café", @[@"caf", @[@"´", @"e"]]],
		@[@"there", @"là", @[@"l", @[@"`", @"a"]]],
	];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	PVScript *script = [PVScript script];
	for (NSString *layout in layouts) {
		[script then:^{
			XCTAssertTrue(PVSelectKeyboardLayout(layout), @"cannot select %@", layout);
		}];
		[script wait:[NSString stringWithFormat:@"the keyboard layout %@", layout] until:^BOOL { return [PVCurrentKeyboardLayout() isEqualToString:layout]; }];
		[script then:^{ PVTypeCommand(@"r", 0); }];
		for (NSUInteger index = 0; index < [answers count]; index++) {
			NSArray *answer = answers[index];
			[script wait:[NSString stringWithFormat:@"the question %@ (%@)", answer[0], layout] until:^BOOL { return [self showsQuestionNumber:(int)index + 1] && [[self question] isEqualToString:answer[0]]; }];
			__block BOOL typed = YES;
			for (id part in answer[2]) {
				if ([part isKindOfClass:[NSString class]])
					[script then:^{ PVTypeText(part); }];
				else {
					// the dead key: nothing is typed yet, the accent waits (marked text) in the field, which keeps the focus
					[script then:^{ typed = typed && PVTypeDeadKey(part[0]); }];
					[script wait:@"the accent to wait for its letter" until:^BOOL {
						return !typed || ([(NSTextView *)[[self answerField] currentEditor] hasMarkedText] && [self answerFieldHasFocus]);
					}];
					[script then:^{ if (typed) PVTypeText(part[1]); }];
					[script wait:@"the accented letter" until:^BOOL { return !typed || ![(NSTextView *)[[self answerField] currentEditor] hasMarkedText]; }];
				}
			}
			[script wait:[NSString stringWithFormat:@"%@ in the answer field (%@)", answer[1], layout] until:^BOOL {
				// (a layout without one of the dead keys cannot type that word: it is given up, and said)
				return !typed || [[self typedAnswer] isEqualToString:answer[1]];
			}];
			[script then:^{
				if (typed) {
					XCTAssertEqualObjects([[self typedAnswer] precomposedStringWithCanonicalMapping], answer[1]);
					PVPostKey(PVKeyReturn, nil, 0);
				} else {
					NSLog(@"PVTestSupport: %@ has no dead key to type %@", layout, answer[1]);
					NSArray *typedWithFrenchDeadKeys = @[@"forêt", @"naïve", @"niño"];
					XCTAssertFalse([layout isEqualToString:@"com.apple.keylayout.French"] && [typedWithFrenchDeadKeys containsObject:answer[1]], @"the French layout should type %@", answer[1]);
					PVTypeCommand(@"a", 0);
					PVPostKey(PVKeyDelete, nil, 0);
					PVTypeCommand(@"g", 0);
				}
			}];
			if (index + 1 < [answers count])
				[script wait:@"the next question (or the solution of a word that cannot be typed)" until:^BOOL { return typed ? [self showsQuestionNumber:(int)index + 2] : [self showsSolution]; }];
			else
				[script wait:@"the result panel (or the solution of a word that cannot be typed)" until:^BOOL { return typed ? [[self resultPanel] isVisible] : [self showsSolution]; }];
			[script then:^{ if (!typed) PVPostKey(PVKeyReturn, nil, 0); }];
		}
		[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
		[script then:^{
			// every word was typed, with the French layout as with the U.S. one
			XCTAssertEqualObjects([self resultValues], (@[@8, @0]), @"correct answers with %@", layout);
			PVPostKey(PVKeyEscape, nil, 0);
		}];
		[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
		[script then:^{ for (ProVocWord *word in [mDocument allWords]) [word reset]; }];
	}
	[self runScript:script];
	XCTAssertTrue(PVSelectKeyboardLayout(userLayout), @"cannot put the keyboard layout %@ back", userLayout);
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [PVCurrentKeyboardLayout() isEqualToString:userLayout]; }), @"the keyboard layout %@ was not put back", userLayout);
}

@end
