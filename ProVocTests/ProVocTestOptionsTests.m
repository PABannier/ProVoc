//
//  ProVocTestOptionsTests.m
//
//  The options of the Training view, as they show during a test driven by the keyboard:
//  timer, comments, back translation, media first, auto-play, speech, labels,
//  the three training modes, words to review, and what the result panel offers.
//

#import "PVScenarioTestCase.h"
#import "ProVocInspector.h"
#import "ProVocTimer.h"
#import "QTKitCompat.h"

@interface ProVocTestOptionsTests : PVScenarioTestCase
@end

@implementation ProVocTestOptionsTests

-(NSArray *)words
{
	return @[@[@"house", @"maison", @"a building"], @[@"cat", @"chat"], @[@"dog", @"chien", @"an animal"], @[@"big", @"grand / gros"]];
}

-(void)setUp
{
	[super setUp];
	[mDocument setValue:@YES forKey:@"dontShuffleWords"];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObjectForKey:PVMarkWrongWords];
	[defaults removeObjectForKey:PVLabelForWrongWords];
	[defaults removeObjectForKey:PVLearnedConsecutiveRepetitions];
	[defaults removeObjectForKey:PVLearnedDistractInterval];
}

-(void)tearDown
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PVSlideShowWithWrongWords];
	[[ProVocInspector sharedInspector] stopPlayingSound];
	[super tearDown];
}

#pragma mark What the user sees

-(NSWindow *)timerWindow
{
	return [[[self tester] valueForKey:@"mTimer"] valueForKey:@"mWindow"];
}

// The time shown by the timer window, in seconds
-(double)shownTime
{
	return [[[[[self tester] valueForKey:@"mTimer"] valueForKey:@"mTimerView"] valueForKey:@"mTime"] doubleValue];
}

-(NSButton *)buttonWithTitle:(NSString *)inTitle inView:(NSView *)inView
{
	if ([inView isKindOfClass:[NSButton class]] && [[(NSButton *)inView title] isEqualToString:inTitle])
		return (NSButton *)inView;
	for (NSView *subview in [inView subviews]) {
		NSButton *button = [self buttonWithTitle:inTitle inView:subview];
		if (button)
			return button;
	}
	return nil;
}

// A button of the "Time is over!" alert
-(NSButton *)timeIsOverButton:(NSString *)inTitleKey
{
	// once the alert is the key window: before that it is still being presented
	if (![[NSApp modalWindow] isKeyWindow])
		return nil;
	return [self buttonWithTitle:NSLocalizedString(inTitleKey, @"") inView:[[NSApp modalWindow] contentView]];
}

-(NSString *)visibleComment
{
	return [self visibleStringBoundTo:@"comment" inView:[[self testPanel] contentView]];
}

-(NSPanel *)notePanel
{
	return [[self tester] valueForKey:@"mNotePanel"];
}

-(NSString *)playingAudioKey
{
	return [[ProVocInspector sharedInspector] valueForKey:@"mPlayingSoundKey"];
}

-(NSView *)view:(NSView *)inView ofClass:(Class)inClass
{
	if ([inView isKindOfClass:inClass] && ![inView isHiddenOrHasHiddenAncestor])
		return inView;
	for (NSView *subview in [inView subviews]) {
		NSView *found = [self view:subview ofClass:inClass];
		if (found)
			return found;
	}
	return nil;
}

-(void)chooseLanguage:(NSString *)inLanguage inPopUp:(NSPopUpButton *)inPopUp
{
	NSInteger index = [inPopUp indexOfItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Language PopUp Item Format (%@)", @""), inLanguage]];
	XCTAssertTrue(index >= 0, @"%@ is not in the language pop-up: %@", inLanguage, [inPopUp itemTitles]);
	[[inPopUp menu] performActionForItemAtIndex:index];
}

-(BOOL)slideshowIsRunning
{
	for (NSWindow *window in [NSApp windows])
		if ([window isVisible] && [[window contentView] isKindOfClass:NSClassFromString(@"SlideView")])
			return YES;
	return NO;
}

-(void)start:(PVScript *)inScript
{
	[inScript then:^{ PVTypeCommand(@"r", 0); }];
	[inScript wait:@"question 1" until:^BOOL { return [self showsQuestionNumber:1]; }];
}

-(void)abort:(PVScript *)inScript
{
	[inScript then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[inScript wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
}

#pragma mark Timer

// Countdown: the timer window shows the remaining time. When it is over the current
// question can still be answered, then "Time is over!" offers Finish (Return),
// one more minute, or Discard.
-(void)scenarioCountdownOneMoreMinuteThenFinish
{
	[mDocument setValue:@2 forKey:@"timer"];
	[mDocument setValue:@2.0f forKey:@"timerDuration"];
	PVScript *script = [PVScript script];
	[self start:script];
	[script then:^{
		XCTAssertTrue([[self timerWindow] isVisible], @"no timer window");
		XCTAssertTrue([self shownTime] > 0 && [self shownTime] < 3, @"the timer shows %g s", [self shownTime]);
		PVSaveWindowScreenshot([self timerWindow], @"tester/timer-countdown");
	}];
	[script wait:@"the time to be over (the question stays)" timeout:8 until:^BOOL { return [[[self tester] valueForKey:@"mTimerDidElapse"] boolValue]; }];
	[script then:^{ XCTAssertTrue([self showsQuestionNumber:1], @"the question went away when the time was over"); }];
	[self answerCorrectlyIn:script];
	[script wait:@"the Time is over alert" until:^BOOL { return [self timeIsOverButton:@"Timer Did Elapse 1' Button"] != nil; }];
	[script then:^{
		PVSaveWindowScreenshot([NSApp modalWindow], [@"tester/time-is-over" stringByAppendingString:[self variant]]);
		PVPressAlertButton([self timeIsOverButton:@"Timer Did Elapse 1' Button"]);
	}];
	[script wait:@"the test to go on with one more minute" until:^BOOL { return [self showsQuestionNumber:2] && [self shownTime] > 50 && [self shownTime] <= 61; }];
	[self abort:script];
	[script then:^{ XCTAssertFalse([[self timerWindow] isVisible], @"the timer window stayed after the test"); }];

	// again, and this time Return = Finish: the result panel
	[self start:script];
	[script wait:@"the time to be over" timeout:8 until:^BOOL { return [[[self tester] valueForKey:@"mTimerDidElapse"] boolValue]; }];
	[self answerCorrectlyIn:script];
	[script wait:@"the Time is over alert" until:^BOOL { return [self timeIsOverButton:@"Timer Did Elapse Finish Button"] != nil; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@1, @0, @3]), @"1 correct, 3 not asked");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

// When the time is over while the solution is displayed, the alert comes at once.
// Discard: the test goes on without limit.
-(void)scenarioCountdownDiscard
{
	[mDocument setValue:@2 forKey:@"timer"];
	[mDocument setValue:@1.0f forKey:@"timerDuration"];
	PVScript *script = [PVScript script];
	[self start:script];
	[script then:^{ PVTypeCommand(@"g", 0); }];
	[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
	[script wait:@"the Time is over alert, by itself" timeout:8 until:^BOOL { return [self timeIsOverButton:@"Timer Did Elapse Discard Button"] != nil; }];
	[script then:^{ PVPressAlertButton([self timeIsOverButton:@"Timer Did Elapse Discard Button"]); }];
	[script wait:@"the test panel again, the solution still displayed" until:^BOOL { return [self showsSolution] && [NSApp modalWindow] != nil == [[NSUserDefaults standardUserDefaults] boolForKey:PVDimTestBackground]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[self answerCorrectlyIn:script];
	[script wait:@"question 3, with no other alert" until:^BOOL { return [self showsQuestionNumber:3]; }];
	[self abort:script];
	[self runScript:script];
}

// Stopwatch: the timer window counts up; it goes away during a pause and comes back.
-(void)scenarioStopwatch
{
	[mDocument setValue:@1 forKey:@"timer"];
	PVScript *script = [PVScript script];
	[self start:script];
	[script then:^{
		XCTAssertTrue([[self timerWindow] isVisible], @"no timer window");
		XCTAssertTrue([self shownTime] < 1, @"the stopwatch starts at %g s", [self shownTime]);
	}];
	[script wait:@"the stopwatch to count up" timeout:6 until:^BOOL { return [self shownTime] >= 1; }];
	[script then:^{
		PVSaveWindowScreenshot([self timerWindow], @"tester/timer-stopwatch");
		PVTypeCommand(@"p", 0);
	}];
	[script wait:@"the pause, without timer window" until:^BOOL {
		return ![[self testPanel] isVisible] && [[mDocument valueForKey:@"canResumeTest"] boolValue] && ![[[[mDocument valueForKey:@"mTester"] valueForKey:@"mTimer"] valueForKey:@"mWindow"] isVisible];
	}];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"the test and its stopwatch again" until:^BOOL { return [self showsQuestionNumber:1] && [[self timerWindow] isVisible] && [self shownTime] >= 1; }];
	[self abort:script];
	[script then:^{ XCTAssertFalse([[self timerWindow] isVisible]); }];
	[self runScript:script];
}

#pragma mark Comments, full answer, back translation

// Comments shown after the answer: a correct answer displays the comment and waits
// for another Return. A word without comment goes straight on. A correct answer
// that is one of several synonyms displays the full answer, then Return goes on.
-(void)scenarioLateCommentAndFullAnswer
{
	[mDocument setValue:@1 forKey:@"lateComments"];
	PVScript *script = [PVScript script];
	[self start:script];
	[script then:^{
		XCTAssertEqualObjects([self question], @"house");
		XCTAssertNil([self visibleComment], @"the comment shows before the answer");
		PVTypeText(@"maison");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the comment, on the same question" until:^BOOL { return [[self visibleComment] isEqualToString:@"a building"] && [self progress] == 1 && [[self testPanel] isKeyWindow]; }];
	[script then:^{
		XCTAssertEqual([[self wordWithSource:@"house"] right], 1);
		PVSaveWindowScreenshot([self testPanel], [@"tester/late-comment" stringByAppendingString:[self variant]]);
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"question 2 (cat, no comment)" until:^BOOL { return [self showsQuestionNumber:2] && [[self question] isEqualToString:@"cat"]; }];
	[script then:^{ PVTypeText(@"chat"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 3 at once (dog)" until:^BOOL { return [self showsQuestionNumber:3] && [[self question] isEqualToString:@"dog"]; }];
	[script then:^{ PVTypeText(@"chien"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the comment of dog" until:^BOOL { return [[self visibleComment] isEqualToString:@"an animal"] && [self progress] == 3; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 4 (big)" until:^BOOL { return [self showsQuestionNumber:4] && [[self question] isEqualToString:@"big"]; }];
	[script then:^{ PVTypeText(@"gros"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the full answer in the field" until:^BOOL { return [[self typedAnswer] isEqualToString:@"grand / gros"] && [self progress] == 4 && [[self testPanel] isVisible]; }];
	[script then:^{ XCTAssertEqual([[self wordWithSource:@"big"] right], 1); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ XCTAssertEqualObjects([self resultValues], (@[@4, @0])); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];

	// comments always displayed / never displayed
	[script then:^{ [mDocument setValue:@0 forKey:@"lateComments"]; }];
	[self start:script];
	[script then:^{ XCTAssertEqualObjects([self visibleComment], @"a building"); }];
	[self abort:script];
	[script then:^{ [mDocument setValue:@2 forKey:@"lateComments"]; }];
	[self start:script];
	[script then:^{ PVTypeCommand(@"g", 0); }];
	[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
	[script then:^{ XCTAssertNil([self visibleComment], @"the comment shows although comments are off"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 2" until:^BOOL { return [self showsQuestionNumber:2]; }];
	[self abort:script];
	[self runScript:script];
}

// "Translate back wrong answers": answering with the translation of another word
// shows which word that was, in a panel that does not take the focus.
-(void)scenarioBackTranslationNote
{
	[mDocument setValue:@YES forKey:@"showBacktranslation"];
	[mDocument setValue:@1 forKey:@"numberOfRetries"];
	PVScript *script = [PVScript script];
	[self start:script];
	[script then:^{ PVTypeText(@"chat"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the solution, and the note panel telling that chat is cat" until:^BOOL {
		NSArray *notes = [[self tester] valueForKey:@"noteWords"];
		return [self showsSolution] && [[self notePanel] isVisible] && [notes count] == 1 && [[(ProVocWord *)notes[0] sourceWord] isEqualToString:@"cat"];
	}];
	[script then:^{
		XCTAssertTrue([[self testPanel] isKeyWindow], @"the note panel took the keyboard");
		PVSaveWindowScreenshot([self notePanel], @"tester/back-translation-note");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"question 2, the note gone" until:^BOOL { return [self showsQuestionNumber:2] && ![[self notePanel] isVisible]; }];
	// a wrong answer that is no other word: no note
	[script then:^{ PVTypeText(@"xyz"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
	[script then:^{ XCTAssertFalse([[self notePanel] isVisible]); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 3" until:^BOOL { return [self showsQuestionNumber:3]; }];
	// Option-Esc first closes the note, then aborts
	[script then:^{ PVTypeText(@"chat"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the note panel again" until:^BOOL { return [self showsSolution] && [[self notePanel] isVisible]; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"Option-Esc to close the note only" until:^BOOL { return ![[self notePanel] isVisible] && [self showsSolution]; }];
	[self abort:script];
	[self runScript:script];
}

#pragma mark Media

-(void)addMedia
{
	ProVocWord *house = [self wordWithSource:@"house"];
	[mDocument setAudioFile:PVMediaFile(@"aiff") forKey:@"Source" ofWord:house];
	[mDocument setAudioFile:PVMediaFile(@"m4a") forKey:@"Target" ofWord:house];
	[mDocument setImageFile:PVMediaFile(@"png") ofWord:house];
	[mDocument setMovieFile:PVMediaFile(@"mov") ofWord:[self wordWithSource:@"cat"]];
}

// "Play automatically": the sound of the question plays when the question comes, the
// sound of the answer when the answer is displayed, and the movie starts by itself.
-(void)scenarioAutoPlayMedia
{
	[self addMedia];
	[mDocument setValue:@YES forKey:@"autoPlayMedia"];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:@"the sound of the question to play by itself" until:^BOOL { return [self testPanelIsReady] && [[self playingAudioKey] isEqualToString:@"Source"]; }];
	[script wait:@"the sound to end" until:^BOOL { return [self playingAudioKey] == nil; }];
	[script then:^{ PVTypeText(@"maison"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the sound of the answer to play by itself, the question staying" until:^BOOL { return [[self playingAudioKey] isEqualToString:@"Target"] && [self progress] == 1; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"question 2 (cat), its movie playing by itself" until:^BOOL {
		return [self testPanelIsReady] && [self progress] == 2 && [(QTMovieView *)[self view:[[self testPanel] contentView] ofClass:[QTMovieView class]] isPlaying];
	}];
	[self abort:script];
	[self runScript:script];
}

// Media of the question: text hidden until Return; media shown after Return; no media.
-(void)scenarioQuestionTextOrMediaFirst
{
	[self addMedia];
	[mDocument setValue:@NO forKey:@"autoPlayMedia"];
	NSImageView *(^imageView)(void) = ^{ return (NSImageView *)[self view:[[self testPanel] contentView] ofClass:[NSImageView class]]; };
	NSString *(^visibleQuestion)(void) = ^{ return [self visibleStringBoundTo:@"question" inView:[[self testPanel] contentView]]; };
	PVScript *script = [PVScript script];
	// 1: the media first, the text of the question after Return
	[script then:^{ [mDocument setValue:@1 forKey:@"mediaHideQuestion"]; PVTypeCommand(@"r", 0); }];
	[script wait:@"the test panel with a Display button" until:^BOOL {
		return [[self testPanel] isKeyWindow] && [[[[self testPanel] defaultButtonCell] title] isEqualToString:NSLocalizedString(@"Show Question Button Title", @"")];
	}];
	[script then:^{
		XCTAssertEqual([visibleQuestion() length], 0, @"the text of the question shows before Return");
		XCTAssertNotNil([[self tester] valueForKey:@"image"]);
		PVSaveWindowScreenshot([self testPanel], [@"tester/question-media-first" stringByAppendingString:[self variant]]);
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the text of the question after Return" until:^BOOL { return [visibleQuestion() isEqualToString:@"house"] && [self showsQuestionNumber:1]; }];
	[script then:^{ XCTAssertEqual([[self wordWithSource:@"house"] wrong], 0, @"revealing the question counted as an answer"); }];
	[self answerCorrectlyIn:script];
	[script wait:@"question 2" until:^BOOL { return [self progress] == 2 && [[self testPanel] isKeyWindow]; }];
	[self abort:script];
	// 3: the text first, the media after Return
	[script then:^{ [mDocument setValue:@3 forKey:@"mediaHideQuestion"]; PVTypeCommand(@"r", 0); }];
	[script wait:@"the test panel with a Display button" until:^BOOL {
		return [[self testPanel] isKeyWindow] && [[[[self testPanel] defaultButtonCell] title] isEqualToString:NSLocalizedString(@"Show Question Button Title", @"")];
	}];
	[script then:^{
		XCTAssertEqualObjects(visibleQuestion(), @"house");
		XCTAssertNil([[self tester] valueForKey:@"image"], @"the picture shows before Return");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the picture after Return" until:^BOOL { return [[self tester] valueForKey:@"image"] != nil && [imageView() image] != nil && [self showsQuestionNumber:1]; }];
	[self answerCorrectlyIn:script];
	[script wait:@"question 2" until:^BOOL { return [self progress] == 2 && [[self testPanel] isKeyWindow]; }];
	[self abort:script];
	// 4: no media
	[script then:^{ [mDocument setValue:@4 forKey:@"mediaHideQuestion"]; }];
	[self start:script];
	[script then:^{
		XCTAssertEqualObjects(visibleQuestion(), @"house");
		XCTAssertNil([[self tester] valueForKey:@"image"]);
	}];
	[self answerCorrectlyIn:script];
	[script wait:@"question 2" until:^BOOL { return [self progress] == 2 && [[self testPanel] isKeyWindow]; }];
	[self abort:script];
	[self runScript:script];
}

// Speech synthesizer for English: F1 speaks the question with the chosen voice.
-(void)scenarioSpeechSynthesis
{
	[self chooseLanguage:@"English" inPopUp:[mDocument valueForKey:@"mSourceLanguagePopUp"]];
	[self chooseLanguage:@"Français" inPopUp:[mDocument valueForKey:@"mTargetLanguagePopUp"]];
	XCTAssertEqualObjects([mDocument sourceLanguage], @"English");
	XCTAssertEqualObjects([mDocument targetLanguage], @"Français");
	NSArray *voices = [mDocument valueForKey:@"availableVoiceIdentifiers"];
	XCTAssertTrue([voices count] > 0, @"no voice");
	NSString *voice = [voices containsObject:@"com.apple.voice.compact.en-US.Samantha"] ? @"com.apple.voice.compact.en-US.Samantha" : [NSSpeechSynthesizer defaultVoice];
	[mDocument setValue:@YES forKey:@"useSpeechSynthesizer"];
	// the voice is chosen with the pop-up of the Training view ("Default Voice" comes first)
	NSPopUpButton *voicePopUp = (NSPopUpButton *)[self view:[[mDocument window] contentView] withBinding:@"selectedIndex" to:@"selectedVoice"];
	XCTAssertNotNil(voicePopUp, @"no voice pop-up");
	XCTAssertTrue([voicePopUp isEnabled], @"the voice pop-up is disabled although the speech synthesizer is on");
	XCTAssertEqual([voicePopUp numberOfItems], (NSInteger)[voices count] + 1);
	[[voicePopUp menu] performActionForItemAtIndex:[voices indexOfObject:voice] + 1];
	XCTAssertEqualObjects([mDocument valueForKey:@"voiceIdentifier"], voice, @"choosing a voice in the pop-up did not set the voice");
	XCTAssertEqualObjects([voicePopUp titleOfSelectedItem], [NSSpeechSynthesizer attributesForVoice:voice][NSVoiceName]);
	NSSpeechSynthesizer *(^synthesizer)(void) = ^{ return (NSSpeechSynthesizer *)[[self tester] valueForKey:@"mSpeechSynthesizer"]; };
	PVScript *script = [PVScript script];
	[self start:script];
	[script then:^{
		XCTAssertTrue([[[self tester] valueForKey:@"canPlayQuestionAudio"] boolValue], @"the question (English) cannot be spoken");
		XCTAssertFalse([[[self tester] valueForKey:@"canPlayAnswerAudio"] boolValue], @"only English is spoken");
		PVPostKey(PVKeyF1, nil, NSEventModifierFlagFunction);
	}];
	[script wait:@"the question to be spoken with the chosen voice" until:^BOOL { return [synthesizer() isSpeaking] && [[synthesizer() voice] isEqualToString:voice]; }];
	[script wait:@"the end of the speech" timeout:10 until:^BOOL { return ![synthesizer() isSpeaking] && [[[self tester] valueForKey:@"mSpeechSynthesizerState"] intValue] == 0; }];
	[script then:^{ XCTAssertTrue([self answerFieldHasFocus]); }];
	[self abort:script];
	[self runScript:script];
}

#pragma mark Labels

// The label of the word shows in the test (colored panel, pop-up with or without
// text), or only once the answer is displayed, or never.
-(void)scenarioLabelDisplay
{
	[[self wordWithSource:@"house"] setLabel:2];
	NSPopUpButton *(^labelPopUp)(void) = ^{ return (NSPopUpButton *)[[self tester] valueForKey:@"mLabelPopUp1"]; };
	NSColor *(^panelColor)(void) = ^{ return (NSColor *)[[[self testPanel] contentView] valueForKey:@"mColor"]; };
	PVScript *script = [PVScript script];
	// always, with the color in the window and the text of the label
	[script then:^{
		[mDocument setValue:@0 forKey:@"displayLabels"];
		[mDocument setValue:@YES forKey:@"colorWindowWithLabel"];
		[mDocument setValue:@YES forKey:@"displayLabelText"];
	}];
	[self start:script];
	[script then:^{
		XCTAssertFalse([labelPopUp() isHiddenOrHasHiddenAncestor]);
		XCTAssertEqual([labelPopUp() indexOfSelectedItem], 2);
		XCTAssertTrue(NSWidth([labelPopUp() frame]) >= 150, @"no room for the text of the label");
		XCTAssertEqualObjects(panelColor(), [mDocument colorForLabel:2]);
		PVSaveWindowScreenshot([self testPanel], [@"tester/label-colored-window" stringByAppendingString:[self variant]]);
	}];
	[self answerCorrectlyIn:script];
	[script wait:@"question 2 (no label, no color)" until:^BOOL { return [self showsQuestionNumber:2] && [labelPopUp() indexOfSelectedItem] == 0 && [panelColor() alphaComponent] == 0; }];
	[self abort:script];
	// only with the answer
	[script then:^{
		[mDocument setValue:@1 forKey:@"displayLabels"];
		[mDocument setValue:@NO forKey:@"displayLabelText"];
	}];
	[self start:script];
	[script then:^{
		XCTAssertTrue([labelPopUp() isHiddenOrHasHiddenAncestor], @"the label shows before the answer");
		XCTAssertNil(panelColor(), @"the color of the label shows before the answer");
		PVTypeCommand(@"g", 0);
	}];
	[script wait:@"the label with the solution" until:^BOOL { return [self showsSolution] && ![labelPopUp() isHiddenOrHasHiddenAncestor] && [panelColor() isEqual:[mDocument colorForLabel:2]]; }];
	[script then:^{ XCTAssertTrue(NSWidth([labelPopUp() frame]) < 60); }];
	[self abort:script];
	// never
	[script then:^{ [mDocument setValue:@2 forKey:@"displayLabels"]; }];
	[self start:script];
	[script then:^{ PVTypeCommand(@"g", 0); }];
	[script wait:@"the solution without label" until:^BOOL { return [self showsSolution] && [labelPopUp() isHiddenOrHasHiddenAncestor] && panelColor() == nil; }];
	[self abort:script];
	[self runScript:script];
}

#pragma mark Result panel

// "Label them as": the wrong words get the chosen label (or the flag) when repeating
// them, and a slideshow of the wrong words comes first if asked.
-(void)scenarioResultPanelLabelsWrongWordsAndSlideshow
{
	[mDocument setValue:@1 forKey:@"numberOfRetries"];
	NSButton *(^labelThemButton)(void) = ^{ return (NSButton *)[self view:[[self resultPanel] contentView] boundTo:@"values.markWrongWords"]; };
	NSPopUpButton *(^labelPopUp)(void) = ^{ return (NSPopUpButton *)[[mDocument valueForKey:@"mTester"] valueForKey:@"mLabelPopUp2"]; };
	PVScript *script = [PVScript script];
	[self start:script];
	// house wrong, the three others right
	[script then:^{ PVTypeText(@"xyz"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	for (int number = 2; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{ PVTypeText([[[self question] isEqualToString:@"big"] ? @"grand / gros" : mAnswers[[self question]] copy]); PVPostKey(PVKeyReturn, nil, 0); }];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible] && labelThemButton() != nil; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@3, @1]));
		XCTAssertEqual([labelThemButton() state], NSControlStateValueOff, @"labelling the wrong words is offered unchecked each time");
		PVClickView(labelThemButton(), 1, 0);
	}];
	[script wait:@"the checkbox to be checked" until:^BOOL { return [[NSUserDefaults standardUserDefaults] boolForKey:PVMarkWrongWords]; }];
	// item 0 is the flag, item n + 1 the label n
	[script then:^{ [labelPopUp() selectItemAtIndex:4]; [[labelPopUp() menu] performActionForItemAtIndex:4]; }];
	[script wait:@"the label 3 to be chosen" until:^BOOL { return [[NSUserDefaults standardUserDefaults] integerForKey:PVLabelForWrongWords] == 4; }];
	[script then:^{
		PVSaveWindowScreenshot([self resultPanel], [@"tester/result-label-wrong-words" stringByAppendingString:[self variant]]);
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PVSlideShowWithWrongWords];
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the slideshow of the wrong word" timeout:10 until:^BOOL { return [self slideshowIsRunning]; }];
	[script then:^{
		XCTAssertEqual([[self wordWithSource:@"house"] label], 3, @"the wrong word did not get the label");
		XCTAssertEqual([[self wordWithSource:@"cat"] label], 0);
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"the repetition of the wrong word after the slideshow" until:^BOOL { return [self showsQuestionNumber:1] && [self progressMax] == 1 && [[self question] isEqualToString:@"house"]; }];
	[self answerCorrectlyIn:script];
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{ XCTAssertEqualObjects([self resultValues], (@[@1, @0])); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

-(NSView *)view:(NSView *)inView withBinding:(NSString *)inBinding to:(NSString *)inKeyPath
{
	if ([[[inView infoForBinding:inBinding] objectForKey:NSObservedKeyPathKey] isEqualToString:inKeyPath])
		return inView;
	for (NSView *subview in [inView subviews]) {
		NSView *found = [self view:subview withBinding:inBinding to:inKeyPath];
		if (found)
			return found;
	}
	if ([inView isKindOfClass:[NSTabView class]])
		for (NSTabViewItem *item in [(NSTabView *)inView tabViewItems]) {
			NSView *found = [self view:[item view] withBinding:inBinding to:inKeyPath];
			if (found)
				return found;
		}
	return nil;
}

-(NSView *)view:(NSView *)inView boundTo:(NSString *)inKeyPath
{
	return [self view:inView withBinding:NSValueBinding to:inKeyPath];
}

@end
