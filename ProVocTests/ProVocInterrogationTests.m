//
//  ProVocInterrogationTests.m
//
//  Drives a whole test with key events posted to the application's event queue
//  (they travel through -[ProVocApplication sendEvent:] like real keystrokes) and
//  checks what the user would see. Every scenario runs twice: with the test panel
//  as a sheet and as the modal panel used when "Dim test background" is on.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "PVTestSupport.h"
#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocTester.h"
#import "ProVocWord.h"
#import "ProVocPreferences.h"
#import "ProVocBackground.h"

@interface ProVocInterrogationTests : XCTestCase {
	ProVocDocument *mDocument;
	NSDictionary *mAnswers;
}
@end

@implementation ProVocInterrogationTests

// Every -scenarioXxx method becomes two tests: -testXxxInSheet (the test panel is a
// sheet of the document window) and -testXxxInDimmedModalPanel ("Dim test background"
// is on: the panel is run as a floating application-modal window).
+(void)load
{
	unsigned int count = 0;
	Method *methods = class_copyMethodList(self, &count);
	for (unsigned int i = 0; i < count; i++) {
		SEL scenario = method_getName(methods[i]);
		NSString *name = NSStringFromSelector(scenario);
		if (![name hasPrefix:@"scenario"])
			continue;
		name = [name substringFromIndex:[@"scenario" length]];
		for (int dimmed = 0; dimmed <= 1; dimmed++) {
			IMP implementation = imp_implementationWithBlock(^(ProVocInterrogationTests *inSelf) {
				[[NSUserDefaults standardUserDefaults] setBool:dimmed forKey:PVDimTestBackground];
				((void (*)(id, SEL))objc_msgSend)(inSelf, scenario);
			});
			class_addMethod(self, NSSelectorFromString([NSString stringWithFormat:@"test%@%@", name, dimmed ? @"InDimmedModalPanel" : @"InSheet"]), implementation, "v@:");
		}
	}
	free(methods);
}

-(void)setUp
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp activate];
	XCTAssertTrue(PVWaitUntil(10, ^BOOL { return [NSApp isActive]; }), @"ProVoc is not the active application (frontmost: %@)", [[[NSWorkspace sharedWorkspace] frontmostApplication] bundleIdentifier]);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:NO forKey:PVDimTestBackground];
	[defaults setBool:NO forKey:PVSlideShowWithWrongWords];
	NSArray *words = @[@[@"house", @"maison"], @[@"cat", @"chat"], @[@"dog", @"chien"], @[@"summer", @"été"]];
	mDocument = [PVNewDocumentWithWords(words) retain];
	NSMutableDictionary *answers = [NSMutableDictionary dictionary];
	for (NSArray *word in words)
		answers[word[0]] = word[1];
	mAnswers = [answers copy];
	// a plain written test, whatever the default preset says
	[mDocument setValue:@NO forKey:@"testMCQ"];
	[mDocument setValue:@0 forKey:@"timer"];
	[mDocument setValue:@0 forKey:@"lateComments"];
	[mDocument setValue:@NO forKey:@"useSpeechSynthesizer"];
	[mDocument setValue:@NO forKey:@"initialSlideshow"];
	[mDocument setValue:@0 forKey:@"testDirection"];
	[mDocument setValue:@0 forKey:@"testKind"];
	[mDocument setValue:@3 forKey:@"numberOfRetries"];
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [[mDocument window] isKeyWindow]; }), @"the document window did not become key");
}

-(void)tearDown
{
	PVCloseDocument(mDocument);
	[mDocument release];
	mDocument = nil;
	[mAnswers release];
	mAnswers = nil;
}

#pragma mark What the user sees

-(ProVocTester *)tester
{
	return [[ProVocTester currentTesters] lastObject];
}

-(NSPanel *)testPanel
{
	return [[self tester] valueForKey:@"mTestPanel"];
}

-(NSPanel *)resultPanel
{
	return [[mDocument valueForKey:@"mTester"] valueForKey:@"mResultPanel"];
}

-(NSTextField *)answerField
{
	return [[self tester] valueForKey:@"mAnswerTextField"];
}

-(NSString *)question
{
	return [[self tester] question];
}

-(NSString *)typedAnswer
{
	return [[self answerField] stringValue];
}

-(int)progress
{
	return [[[self tester] valueForKey:@"progressValue"] intValue];
}

// The answer field is being edited in the key window: typing goes into it.
-(BOOL)answerFieldHasFocus
{
	NSTextField *field = [self answerField];
	NSWindow *window = [field window];
	id firstResponder = [window firstResponder];
	return field && [window isKeyWindow] && [firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == (id)field;
}

-(BOOL)testPanelIsReady
{
	return [self tester] && [[self testPanel] isVisible] && [self answerFieldHasFocus];
}

-(BOOL)showsQuestionNumber:(int)inNumber
{
	return [self testPanelIsReady] && [self progress] == inNumber && [[self typedAnswer] length] == 0;
}

-(NSString *)variant
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:PVDimTestBackground] ? @"-dimmed" : @"-sheet";
}

-(ProVocWord *)currentWord
{
	return [self wordWithSource:[self question]];
}

// Typing replaces what is in the field: it is empty, or everything in it is selected.
-(BOOL)answerTextIsSelectedOrEmpty
{
	NSText *editor = [[self answerField] currentEditor];
	return editor && NSEqualRanges([editor selectedRange], NSMakeRange(0, [[editor string] length]));
}

-(BOOL)showsSolution
{
	return [[[self tester] valueForKey:@"displayCorrectAnswer"] boolValue] && [[self testPanel] isVisible];
}

// The text of the visible field bound to the tester's correctAnswer
-(NSString *)displayedSolution
{
	return [self visibleStringBoundTo:@"correctAnswer" inView:[[self testPanel] contentView]];
}

-(NSString *)visibleStringBoundTo:(NSString *)inKeyPath inView:(NSView *)inView
{
	if ([inView isKindOfClass:[NSTextField class]] && ![inView isHiddenOrHasHiddenAncestor] && [[[inView infoForBinding:NSValueBinding] objectForKey:NSObservedKeyPathKey] isEqualToString:inKeyPath])
		return [(NSTextField *)inView stringValue];
	for (NSView *subview in [inView subviews]) {
		NSString *string = [self visibleStringBoundTo:inKeyPath inView:subview];
		if (string)
			return string;
	}
	return nil;
}

-(NSButton *)retryButton
{
	return [[mDocument valueForKey:@"mTester"] valueForKey:@"mRetryButton"];
}

// The numbers shown in the result panel, in order (correct, wrong, ...)
-(NSArray *)resultValues
{
	return [[[[mDocument valueForKey:@"mTester"] valueForKey:@"mResultView"] valueForKey:@"mResults"] valueForKey:@"Value"];
}

-(BOOL)testIsOver
{
	return ![[self resultPanel] isVisible] && ![mDocument testIsRunning] && ![mDocument valueForKey:@"mTester"] && ![NSApp modalWindow] && [[mDocument window] attachedSheet] == nil;
}

-(ProVocWord *)wordWithSource:(NSString *)inSource
{
	for (ProVocWord *word in [mDocument allWords])
		if ([[word sourceWord] isEqualToString:inSource])
			return word;
	return nil;
}

-(void)runScript:(PVScript *)inScript
{
	NSString *failure = [inScript run];
	XCTAssertNil(failure, @"%@ — question \"%@\", typed \"%@\", progress %i, test panel visible %i, focus %i, result panel visible %i; app active %i, key window %@ (first responder %@), main window %@, modal window %@; default button %@ enabled %i hidden %i, typed %@", failure,
				 [self question], [self typedAnswer], [self progress], [[self testPanel] isVisible], [self answerFieldHasFocus], [[self resultPanel] isVisible],
				 [NSApp isActive], [[NSApp keyWindow] title], [[[NSApp keyWindow] firstResponder] className], [[NSApp mainWindow] title], [[NSApp modalWindow] title],
				 [[[self testPanel] defaultButtonCell] title], [[[self testPanel] defaultButtonCell] isEnabled], [[[[self testPanel] defaultButtonCell] controlView] isHiddenOrHasHiddenAncestor],
				 [[[self typedAnswer] dataUsingEncoding:NSUTF8StringEncoding] description]);
	// never leave a modal session or a sheet behind for the next test
	if ([self tester])
		[[self tester] performSelector:@selector(closePanelWithCode:) withObject:nil];
	if ([NSApp modalWindow])
		[NSApp abortModal];
}

#pragma mark Scenarios

-(void)answerCorrectlyIn:(PVScript *)inScript withReturnKeyCode:(unsigned short)inReturnKeyCode
{
	[inScript then:^{
		XCTAssertNotNil(mAnswers[[self question]], @"unexpected question %@", [self question]);
		PVTypeText(mAnswers[[self question]]);
	}];
	[inScript wait:@"the typed answer in the field" until:^BOOL { return [[self typedAnswer] isEqualToString:mAnswers[[self question]]]; }];
	[inScript then:^{ PVPostKey(inReturnKeyCode, nil, 0); }];
}

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

@end
