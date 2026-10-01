//
//  ProVocTrainingTests.m
//
//  The Training view of the document: training modes (presets) and their controls,
//  and the tests they start: continuous, until learned, words to review...
//

#import "PVScenarioTestCase.h"
#import "ProVocPreset.h"
#import "ProVocHistory.h"

@interface ProVocTrainingTests : PVScenarioTestCase
@end

@implementation ProVocTrainingTests

-(void)setUp
{
	[super setUp];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:PVLearnedConsecutiveRepetitions];
	[defaults removeObjectForKey:PVLearnedDistractInterval];
	[defaults removeObjectForKey:PVReviewLearningFactor];
	[defaults removeObjectForKey:PVReviewTrainingFactor];
}

-(NSTableView *)presetTable
{
	return [mDocument valueForKey:@"mPresetTableView"];
}

-(NSArray *)presetNames
{
	return [[mDocument presets] valueForKey:@"name"];
}

-(void)clickRow:(NSInteger)inRow ofTable:(NSTableView *)inTable clickCount:(NSInteger)inCount
{
	NSRect rect = [inTable rectOfRow:inRow];
	PVClickAtPoint(inTable, NSMakePoint(NSMidX(rect), NSMidY(rect)), inCount, 0);
}

// A control of the preset editor, scrolled into view
-(id)parameterControlWithBinding:(NSString *)inBinding to:(NSString *)inKey
{
	NSView *control = [self controlWithBinding:inBinding to:inKey];
	XCTAssertNotNil(control, @"no control for %@", inKey);
	[control scrollRectToVisible:[control bounds]];
	return control;
}

-(void)showTrainingViewIn:(PVScript *)inScript editing:(BOOL)inEditing
{
	[inScript then:^{ PVTypeCommand(@"2", NSEventModifierFlagOption); }];
	[inScript wait:@"the Training view (Option-Command-2)" until:^BOOL { return [[mDocument valueForKey:@"mainTab"] intValue] == 0 && [[self presetTable] window] == [mDocument window] && ![[self presetTable] isHiddenOrHasHiddenAncestor]; }];
	if (inEditing) {
		// a double click on a training mode opens its settings
		[inScript then:^{ if (![[mDocument valueForKey:@"editingPreset"] boolValue]) [self clickRow:[[self presetTable] selectedRow] ofTable:[self presetTable] clickCount:2]; }];
		[inScript wait:@"the settings of the training mode" until:^BOOL { return [[mDocument valueForKey:@"editingPreset"] boolValue]; }];
	}
}

#pragma mark Training modes (presets)

// The four training modes of DefaultPresets.xml are offered. A click applies one.
// + creates one, which can be renamed and changed; the action menu duplicates and
// removes; the modes are saved with the document.
-(void)testTrainingModes
{
	NSArray *defaultPresets = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DefaultPresets" ofType:@"xml"]];
	XCTAssertEqual([defaultPresets count], 4u);
	NSArray *defaultNames = [defaultPresets valueForKey:@"Name"];
	NSButton *(^newButton)(void) = ^{ return [self buttonWithAction:@selector(newPreset:) inView:[[mDocument window] contentView]]; };
	__block NSPopUpButton *actionPopUp = nil;
	NSTextField *(^nameField)(void) = ^{ return (NSTextField *)[self controlWithBinding:NSValueBinding to:@"presetName"]; };
	PVScript *script = [PVScript script];
	[self showTrainingViewIn:script editing:NO];
	[script then:^{
		XCTAssertEqualObjects([self presetNames], defaultNames);
		XCTAssertEqual([[self presetTable] numberOfRows], 4);
		[self clickRow:2 ofTable:[self presetTable] clickCount:1];
	}];
	[script wait:@"a click to apply the third training mode" until:^BOOL { return [[self presetTable] selectedRow] == 2 && [[mDocument valueForKey:@"testKind"] intValue] == 1; }];
	[script then:^{
		NSDictionary *expected = defaultPresets[2][@"Parameters"];
		NSDictionary *parameters = [mDocument parameters];
		for (NSString *key in expected)
			XCTAssertEqualObjects(parameters[key], expected[key], @"%@ of %@", key, defaultNames[2]);
		[self clickRow:1 ofTable:[self presetTable] clickCount:1];
	}];
	[script wait:@"a click to apply the second training mode" until:^BOOL { return [[self presetTable] selectedRow] == 1 && [[mDocument valueForKey:@"testKind"] intValue] == 0; }];
	[script then:^{
		NSDictionary *expected = defaultPresets[1][@"Parameters"];
		NSDictionary *parameters = [mDocument parameters];
		for (NSString *key in expected)
			XCTAssertEqualObjects(parameters[key], expected[key], @"%@ of %@", key, defaultNames[1]);
		XCTAssertNotNil(newButton(), @"no + button");
		PVClickView(newButton(), 1, 0);
	}];
	[script wait:@"a new training mode, selected, its settings displayed" until:^BOOL {
		return [[mDocument presets] count] == 5 && [[self presetTable] selectedRow] == 4 && [[mDocument valueForKey:@"editingPreset"] boolValue] && ![nameField() isHiddenOrHasHiddenAncestor];
	}];
	// rename it
	[script then:^{
		XCTAssertEqualObjects([nameField() stringValue], [[self presetNames] lastObject]);
		XCTAssertEqual([[mDocument valueForKey:@"numberOfRetries"] intValue], 2, @"the new mode starts as a copy of the current settings");
		PVClickView(nameField(), 1, 0);
	}];
	[script wait:@"the name field to be edited" until:^BOOL { return [nameField() currentEditor] != nil; }];
	[script then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"Dictation"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the new name in the list" until:^BOOL { return [[[self presetNames] lastObject] isEqualToString:@"Dictation"]; }];
	// change one of its settings: the other modes keep theirs
	[script then:^{ PVClickView([self parameterControlWithBinding:NSValueBinding to:@"dontShuffleWords"], 1, 0); }];
	[script wait:@"the setting to change" until:^BOOL { return [[mDocument valueForKey:@"dontShuffleWords"] boolValue]; }];
	[script then:^{ [self clickRow:1 ofTable:[self presetTable] clickCount:1]; }];
	[script wait:@"the second mode with its own setting" until:^BOOL { return [[self presetTable] selectedRow] == 1 && ![[mDocument valueForKey:@"dontShuffleWords"] boolValue]; }];
	[script then:^{ [self clickRow:4 ofTable:[self presetTable] clickCount:1]; }];
	[script wait:@"the new mode with its setting" until:^BOOL { return [[self presetTable] selectedRow] == 4 && [[mDocument valueForKey:@"dontShuffleWords"] boolValue]; }];
	[script then:^{
		PVSaveWindowScreenshot([mDocument window], @"windows/document-training-new-mode");
		// the action menu: Duplicate
		actionPopUp = [self popUpWithItemAction:@selector(duplicatePreset:)];
		XCTAssertNotNil(actionPopUp, @"no action menu for the training modes");
		[[actionPopUp menu] performActionForItemAtIndex:[self indexOfItemWithAction:@selector(duplicatePreset:) inMenu:[actionPopUp menu]]];
	}];
	[script wait:@"a copy of the mode" until:^BOOL { return [[mDocument presets] count] == 6 && [[self presetTable] selectedRow] == 5; }];
	[script then:^{
		XCTAssertTrue([[[self presetNames] lastObject] hasPrefix:@"Dictation"] && ![[[self presetNames] lastObject] isEqualToString:@"Dictation"], @"name of the copy: %@", [[self presetNames] lastObject]);
		XCTAssertTrue([[mDocument valueForKey:@"dontShuffleWords"] boolValue]);
	}];
	[self runScript:script];

	// saved with the document
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVTrainingModes-%i.pvoc", [[NSProcessInfo processInfo] processIdentifier]]];
	NSError *error = nil;
	XCTAssertTrue([mDocument writeToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" error:&error], @"%@", error);
	ProVocDocument *reopened = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path] display:YES error:&error];
	XCTAssertNotNil(reopened, @"%@", error);
	XCTAssertEqualObjects([[reopened presets] valueForKey:@"name"], [self presetNames]);
	XCTAssertEqualObjects([[reopened presets] valueForKey:@"parameters"], [[mDocument presets] valueForKey:@"parameters"]);
	XCTAssertEqual([[reopened valueForKey:@"mPresetTableView"] selectedRow], 5);
	PVCloseDocument(reopened);
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];

	// Remove, down to the last one, which cannot be removed
	script = [PVScript script];
	[script wait:@"the document window to be key again" until:^BOOL { return [[mDocument window] isKeyWindow]; }];
	for (int count = 5; count >= 1; count--) {
		[script then:^{
			NSInteger index = [self indexOfItemWithAction:@selector(removePreset:) inMenu:[actionPopUp menu]];
			[[actionPopUp menu] update];
			XCTAssertTrue([[[actionPopUp menu] itemAtIndex:index] isEnabled], @"Remove is disabled with %i modes", count + 1);
			XCTAssertEqual([[self presetTable] selectedRow], count, @"after a removal the mode before is selected");
			[[actionPopUp menu] performActionForItemAtIndex:index];
		}];
		[script wait:[NSString stringWithFormat:@"%i training modes left", count] until:^BOOL { return [[mDocument presets] count] == count && [[self presetTable] numberOfRows] == count; }];
	}
	[script then:^{
		NSInteger index = [self indexOfItemWithAction:@selector(removePreset:) inMenu:[actionPopUp menu]];
		[[actionPopUp menu] update];
		XCTAssertFalse([[[actionPopUp menu] itemAtIndex:index] isEnabled], @"the last training mode can be removed");
		XCTAssertEqualObjects([self presetNames], @[defaultNames[0]]);
	}];
	[self runScript:script];
}

-(NSInteger)indexOfItemWithAction:(SEL)inAction inMenu:(NSMenu *)inMenu
{
	for (NSMenuItem *item in [inMenu itemArray])
		if ([item action] == inAction)
			return [inMenu indexOfItem:item];
	return -1;
}

-(NSPopUpButton *)popUpWithItemAction:(SEL)inAction in:(NSView *)inView
{
	if ([inView isKindOfClass:[NSPopUpButton class]] && [self indexOfItemWithAction:inAction inMenu:[(NSPopUpButton *)inView menu]] >= 0)
		return (NSPopUpButton *)inView;
	for (NSView *subview in [inView subviews]) {
		NSPopUpButton *popUp = [self popUpWithItemAction:inAction in:subview];
		if (popUp)
			return popUp;
	}
	return nil;
}

-(NSPopUpButton *)popUpWithItemAction:(SEL)inAction
{
	return [self popUpWithItemAction:inAction in:[[mDocument window] contentView]];
}

// Every control of the settings of a training mode changes the corresponding setting.
-(void)testTrainingModeControls
{
	PVScript *script = [PVScript script];
	[self showTrainingViewIn:script editing:YES];
	// check boxes (some are only enabled when another one is checked)
	[script then:^{ [mDocument setValue:@YES forKey:@"testMCQ"]; }];
	for (NSString *key in @[@"delayedMCQ", @"imageMCQ", @"dontShuffleWords", @"initialSlideshow", @"showBacktranslation", @"testWordsToReview", @"testMarked", @"testLimit", @"testOldWords",
							@"autoPlayMedia", @"useSpeechSynthesizer", @"colorWindowWithLabel", @"displayLabelText", @"testMCQ"]) {
		for (int pass = 0; pass < 2; pass++) {
			__block BOOL before;
			[script then:^{
				NSButton *button = [self parameterControlWithBinding:NSValueBinding to:key];
				before = [[mDocument valueForKey:key] boolValue];
				XCTAssertTrue([button isEnabled] && ![button isHiddenOrHasHiddenAncestor], @"the check box of %@ cannot be clicked", key);
				// "Train words in random order" shows the opposite of dontShuffleWords
				BOOL negated = [[[button infoForBinding:NSValueBinding][NSOptionsKey][NSValueTransformerNameBindingOption] description] isEqualToString:NSNegateBooleanTransformerName];
				XCTAssertEqual(negated, [key isEqualToString:@"dontShuffleWords"], @"%@", key);
				XCTAssertEqual([button state] == NSControlStateValueOn, before != negated, @"the check box of %@ does not show its value", key);
				PVClickView(button, 1, 0);
			}];
			[script wait:[NSString stringWithFormat:@"a click on the check box of %@", key] until:^BOOL { return [[mDocument valueForKey:key] boolValue] != before; }];
		}
	}
	// pop-up menus whose items carry the value as tag
	for (NSString *key in @[@"testDirection", @"testKind", @"timer", @"lateComments", @"displayLabels", @"mediaHideQuestion"])
		[script then:^{
			NSPopUpButton *popUp = [self parameterControlWithBinding:NSSelectedTagBinding to:key];
			XCTAssertTrue([popUp isEnabled] && ![popUp isHiddenOrHasHiddenAncestor], @"the pop-up of %@ cannot be used", key);
			NSMutableSet *tags = [NSMutableSet set];
			for (NSMenuItem *item in [[popUp menu] itemArray]) {
				if ([item isSeparatorItem])
					continue;
				[[popUp menu] performActionForItemAtIndex:[[popUp menu] indexOfItem:item]];
				XCTAssertEqual([[mDocument valueForKey:key] integerValue], [item tag], @"%@ after choosing %@", key, [item title]);
				[tags addObject:@([item tag])];
			}
			XCTAssertTrue([tags count] >= 3 && [tags count] == [[[popUp menu] itemArray] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isSeparatorItem == NO"]].count, @"%@: tags %@", key, tags);
			[[popUp menu] performActionForItemAtIndex:0];
		}];
	// pop-up menus bound by index
	[script then:^{ [mDocument setValue:@YES forKey:@"testLimit"]; [mDocument setValue:@YES forKey:@"testOldWords"]; }];
	for (NSString *key in @[@"testLimitWhat", @"testOldUnit"])
		[script then:^{
			NSPopUpButton *popUp = [self parameterControlWithBinding:NSSelectedIndexBinding to:key];
			XCTAssertTrue([popUp isEnabled] && ![popUp isHiddenOrHasHiddenAncestor], @"the pop-up of %@ cannot be used", key);
			for (NSInteger index = [popUp numberOfItems] - 1; index >= 0; index--) {
				[[popUp menu] performActionForItemAtIndex:index];
				XCTAssertEqual([[mDocument valueForKey:key] integerValue], index, @"%@", key);
			}
		}];
	// steppers and their fields
	[script then:^{ [mDocument setValue:@2 forKey:@"timer"]; [mDocument setValue:@YES forKey:@"testMCQ"]; }];
	for (NSString *key in @[@"numberOfRetries", @"testMCQNumber", @"testLimitNumber", @"testOldNumber", @"timerDuration"]) {
		__block double before;
		[script then:^{
			NSStepper *stepper = nil;
			for (NSView *view in [self viewsIn:[[mDocument window] contentView] withBinding:NSValueBinding to:key])
				if ([view isKindOfClass:[NSStepper class]])
					stepper = (NSStepper *)view;
			XCTAssertNotNil(stepper, @"no stepper for %@", key);
			[stepper scrollRectToVisible:[stepper bounds]];
			XCTAssertTrue([stepper isEnabled] && ![stepper isHiddenOrHasHiddenAncestor], @"the stepper of %@ cannot be clicked", key);
			before = [[mDocument valueForKey:key] doubleValue];
			// the upper arrow
			NSRect bounds = [stepper bounds];
			PVClickAtPoint(stepper, NSMakePoint(NSMidX(bounds), [stepper isFlipped] ? NSMinY(bounds) + NSHeight(bounds) / 4 : NSMaxY(bounds) - NSHeight(bounds) / 4), 1, 0);
		}];
		[script wait:[NSString stringWithFormat:@"the stepper to increase %@", key] until:^BOOL { return [[mDocument valueForKey:key] doubleValue] > before; }];
		[script then:^{
			for (NSView *view in [self viewsIn:[[mDocument window] contentView] withBinding:NSValueBinding to:key])
				if ([view isKindOfClass:[NSTextField class]] && ![key isEqualToString:@"timerDuration"])
					XCTAssertEqual([(NSTextField *)view doubleValue], [[mDocument valueForKey:key] doubleValue], @"the field of %@ does not follow", key);
		}];
	}
	// the labels to train: a click in the list
	[script then:^{ [mDocument setValue:@YES forKey:@"testMarked"]; }];
	[script then:^{
		NSTableView *labels = [mDocument valueForKey:@"mLabelTableView"];
		[labels scrollRectToVisible:[labels bounds]];
		XCTAssertTrue([labels isEnabled]);
		[self clickRow:2 ofTable:labels clickCount:1];
	}];
	[script wait:@"the label clicked to be the one to train" until:^BOOL { return [[mDocument valueForKey:@"labelsToTest"] isEqual:[NSIndexSet indexSetWithIndex:2]]; }];
	// the slider of the random direction
	[script then:^{
		[mDocument setValue:@2 forKey:@"testDirection"];
		NSSlider *slider = [self parameterControlWithBinding:NSValueBinding to:@"testDirectionProbability"];
		XCTAssertFalse([slider isHiddenOrHasHiddenAncestor], @"no slider for the random direction");
		NSRect bounds = [slider bounds];
		PVClickAtPoint(slider, NSMakePoint(NSMaxX(bounds) - 4, NSMidY(bounds)), 1, 0);
	}];
	[script wait:@"a click at the end of the slider" until:^BOOL { return [[mDocument valueForKey:@"testDirectionProbability"] floatValue] > 0.9; }];
	[script then:^{
		[mDocument setValue:@0 forKey:@"testDirection"];
		XCTAssertTrue([[self controlWithBinding:NSValueBinding to:@"testDirectionProbability"] isHiddenOrHasHiddenAncestor], @"the slider shows although the direction is not random");
		PVSaveWindowScreenshot([mDocument window], @"windows/document-training-all-settings");
	}];
	[self runScript:script];
}

-(NSArray *)viewsIn:(NSView *)inView withBinding:(NSString *)inBinding to:(NSString *)inKeyPath
{
	NSMutableArray *views = [NSMutableArray array];
	if ([[[inView infoForBinding:inBinding] objectForKey:NSObservedKeyPathKey] isEqualToString:inKeyPath])
		[views addObject:inView];
	for (NSView *subview in [inView subviews])
		[views addObjectsFromArray:[self viewsIn:subview withBinding:inBinding to:inKeyPath]];
	return views;
}

#pragma mark Training methods

// "Continuous": the questions never end; never the same word twice in a row; a
// difficult word comes more often; Esc shows the results, kept in the history.
-(void)scenarioContinuousTrainingWeightedByDifficulty
{
	[mDocument setValue:@1 forKey:@"testKind"];
	[mDocument setValue:@1 forKey:@"numberOfRetries"];
	[mDocument setValue:@1.0f forKey:@"testDifficulty"];
	ProVocWord *summer = [self wordWithSource:@"summer"];
	for (int i = 0; i < 6; i++)
		[summer increaseDifficulty];
	srand(42);	// what -PVRandomSeed 42 does at launch
	NSMutableArray *asked = [NSMutableArray array];
	NSUInteger historyCount = [[mDocument valueForKey:@"mHistories"] count];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	const int questions = 24;
	for (int number = 1; number <= questions; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{
			XCTAssertNotEqualObjects([asked lastObject], [self question], @"the same word twice in a row");
			[asked addObject:[self question]];
		}];
		if (number == 3) {
			// a wrong answer makes the word more difficult
			__block float difficulty;
			[script then:^{ difficulty = [[self currentWord] difficulty]; PVTypeText(@"xyz"); PVPostKey(PVKeyReturn, nil, 0); }];
			[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
			[script then:^{
				XCTAssertTrue([[self currentWord] difficulty] > difficulty, @"a wrong answer did not make the word more difficult");
				PVPostKey(PVKeyReturn, nil, 0);
			}];
		} else
			[self answerCorrectlyIn:script];
	}
	[script wait:@"one more question: the training goes on" until:^BOOL { return [self showsQuestionNumber:questions + 1]; }];
	[script then:^{
		NSCountedSet *counts = [NSCountedSet setWithArray:asked];
		XCTAssertEqual([counts count], 4u, @"some words were never asked: %@", counts);
		for (NSString *word in @[@"house", @"cat", @"dog"])
			XCTAssertTrue([counts countForObject:@"summer"] > [counts countForObject:word], @"the difficult word should come more often than %@: %@", word, counts);
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the result panel (Esc)" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		// correct, wrong once, twice, three times and more, not answered
		NSArray *results = [self resultValues];
		XCTAssertEqual([results[1] intValue], 1, @"one word was answered wrong once: %@", results);
		XCTAssertEqual([results[0] intValue] + [results[1] intValue], 4, @"%@", results);
		PVSaveWindowScreenshot([self resultPanel], [@"tester/result-continuous" stringByAppendingString:[self variant]]);
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[script then:^{
		NSArray *histories = [mDocument valueForKey:@"mHistories"];
		XCTAssertEqual([histories count], historyCount + 1, @"the training is not in the history");
		XCTAssertEqual([[[histories lastObject] valueForKey:@"mMode"] intValue], 1);
	}];
	[self runScript:script];
}

// "Until learned": every word comes back until it has been answered right twice in a
// row, with other words in between; a wrong answer starts the count again.
-(void)scenarioUntilLearned
{
	[mDocument setValue:@2 forKey:@"testKind"];
	[mDocument setValue:@1 forKey:@"numberOfRetries"];
	NSMutableArray *asked = [NSMutableArray array];
	__block NSString *wrongWord = nil;
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	// at most: 4 words twice, plus the wrong one once more with its two right answers
	__block ProVocWord *word = nil;
	__block int rightBefore = 0;
	__block BOOL answeringWrong = NO;
	for (int number = 1; number <= 12; number++) {
		[script wait:@"the next question or the results" until:^BOOL {
			return [[self resultPanel] isVisible] || ([self testPanelIsReady] && [[self typedAnswer] length] == 0);
		}];
		[script then:^{
			word = nil;
			if ([[self resultPanel] isVisible])
				return;
			[asked addObject:[self question]];
			word = [self currentWord];
			rightBefore = [word right];
			answeringWrong = [asked count] == 2;
			if (answeringWrong)
				wrongWord = [[self question] copy];
			PVTypeText(answeringWrong ? @"xyz" : mAnswers[[self question]]);
			PVPostKey(PVKeyReturn, nil, 0);
		}];
		[script wait:@"the answer to be taken" until:^BOOL { return !word || (answeringWrong ? [self showsSolution] : [word right] > rightBefore); }];
		[script then:^{ if (word && answeringWrong) PVPostKey(PVKeyReturn, nil, 0); }];
		[script wait:@"the solution to go away" until:^BOOL { return ![self showsSolution]; }];
	}
	[script wait:@"the result panel: everything is learned" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		NSCountedSet *counts = [NSCountedSet setWithArray:asked];
		XCTAssertEqual([counts count], 4u, @"%@", asked);
		// right twice in a row (once for the very last word, when no other word is left to come in between)
		for (NSString *word in counts)
			if (![word isEqualToString:wrongWord])
				XCTAssertTrue([counts countForObject:word] == 2 || ([counts countForObject:word] == 1 && [[asked lastObject] isEqualToString:word]), @"%@ asked %lu times: %@", word, (unsigned long)[counts countForObject:word], asked);
		XCTAssertTrue([counts countForObject:wrongWord] >= 2, @"the word answered wrong did not come back: %@", asked);
		// the wrong word came back after other words, not at once
		XCTAssertNotEqualObjects(asked[2], wrongWord, @"%@", asked);
		NSUInteger again = [asked indexOfObject:wrongWord inRange:NSMakeRange(2, [asked count] - 2)];
		XCTAssertTrue(again != NSNotFound && again <= 5, @"the wrong word should come back after a few other words: %@", asked);
		for (NSUInteger i = 1; i < [asked count]; i++)
			XCTAssertNotEqualObjects(asked[i], asked[i - 1], @"the same word twice in a row: %@", asked);
		NSArray *results = [self resultValues];
		XCTAssertEqualObjects(([results subarrayWithRange:NSMakeRange(0, 2)]), (@[@3, @1]), @"3 words right at once, 1 wrong once: %@", results);
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// "Words needed to be reviewed" and "Words not answered during the last ..."
-(void)scenarioWordsToReviewAndNotAnsweredSince
{
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	NSTextField *caption = [self controlWithBinding:NSValueBinding to:@"pageSelectionTitle"];
	XCTAssertNotNil(caption, @"no caption telling the number of words to train");
	PVScript *script = [PVScript script];
	[script then:^{
		XCTAssertTrue([[caption stringValue] rangeOfString:@"4"].location != NSNotFound, @"caption: %@", [caption stringValue]);
		PVTypeCommand(@"r", 0);
	}];
	// house and cat answered now
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[self answerCorrectlyIn:script];
	}
	[script wait:@"question 3" until:^BOOL { return [self showsQuestionNumber:3]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	// to review: the words never answered (dog, summer); the others come back later
	[script then:^{
		XCTAssertTrue([[[self wordWithSource:@"house"] nextReview] timeIntervalSinceNow] > 60, @"a word just answered is to be reviewed at once");
		[mDocument setValue:@YES forKey:@"testWordsToReview"];
		XCTAssertTrue([[caption stringValue] rangeOfString:@"2"].location != NSNotFound, @"caption: %@", [caption stringValue]);
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"a test of the 2 words to review" until:^BOOL { return [self showsQuestionNumber:1] && [self progressMax] == 2 && [[self question] isEqualToString:@"dog"]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	// a word answered long ago is to be reviewed again
	[script then:^{
		[[self wordWithSource:@"house"] setValue:[NSDate dateWithTimeIntervalSinceNow:-90 * 24 * 3600.0] forKey:@"mLastAnswered"];
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"a test of 3 words, with the one answered long ago" until:^BOOL { return [self showsQuestionNumber:1] && [self progressMax] == 3 && [[self question] isEqualToString:@"house"]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	// not answered during the last 2 days: not cat (answered today), but house (90 days ago) and the two never answered
	[script then:^{
		[mDocument setValue:@NO forKey:@"testWordsToReview"];
		[mDocument setValue:@YES forKey:@"testOldWords"];
		[mDocument setValue:@2 forKey:@"testOldNumber"];
		[mDocument setValue:@0 forKey:@"testOldUnit"];
		PVTypeCommand(@"r", 0);
	}];
	NSMutableArray *asked = [NSMutableArray array];
	for (int number = 1; number <= 3; number++) {
		[script wait:[NSString stringWithFormat:@"question %i of 3", number] until:^BOOL { return [self showsQuestionNumber:number] && [self progressMax] == 3; }];
		[script then:^{ [asked addObject:[self question]]; }];
		[self answerCorrectlyIn:script];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ XCTAssertEqualObjects(asked, (@[@"house", @"dog", @"summer"])); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	// weeks and months
	[script then:^{
		[[self wordWithSource:@"house"] setValue:[NSDate dateWithTimeIntervalSinceNow:-90 * 24 * 3600.0] forKey:@"mLastAnswered"];
		[[self wordWithSource:@"dog"] setValue:[NSDate dateWithTimeIntervalSinceNow:-10 * 24 * 3600.0] forKey:@"mLastAnswered"];
		[mDocument setValue:@1 forKey:@"testOldUnit"];	// 2 weeks: house (90 days) only, not dog (10 days)
		XCTAssertEqualObjects([[mDocument wordsToBeTested] valueForKey:@"sourceWord"], (@[@"house"]));
		[mDocument setValue:@2 forKey:@"testOldUnit"];	// 2 months: house
		XCTAssertEqualObjects([[mDocument wordsToBeTested] valueForKey:@"sourceWord"], (@[@"house"]));
		[mDocument setValue:@1 forKey:@"testOldNumber"];
		[mDocument setValue:@1 forKey:@"testOldUnit"];	// 1 week: house and dog
		XCTAssertEqualObjects([[mDocument wordsToBeTested] valueForKey:@"sourceWord"], (@[@"house", @"dog"]));
	}];
	[self runScript:script];
}

@end
