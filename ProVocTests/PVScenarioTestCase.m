//
//  PVScenarioTestCase.m
//

#import "PVScenarioTestCase.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation PVScenarioTestCase


// Every -scenarioXxx method becomes two tests: -testXxxInSheet (the test panel is a
// sheet of the document window) and -testXxxInDimmedModalPanel ("Dim test background"
// is on: the panel is run as a floating application-modal window).
+(void)initialize
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
			IMP implementation = imp_implementationWithBlock(^(PVScenarioTestCase *inSelf) {
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
	XCTAssertFalse(PVScreenIsLocked(), @"THE SCREEN OF THIS MAC IS LOCKED: the tests that send keys cannot run (unlock it, see verification/NEEDS_HUMAN.md)");
	XCTAssertTrue(PVScreenIsLocked() || PVWaitUntil(10, ^BOOL { return [NSApp isActive]; }), @"ProVoc is not the active application (frontmost: %@)", [[[NSWorkspace sharedWorkspace] frontmostApplication] bundleIdentifier]);
	// Factory settings for each test: a document that becomes current puts its own settings
	// (separators, fonts, labels...) in the preferences, and one of the decks of
	// fixtures/user-decks uses the letter m as separator of synonyms.
	PVResetPreferences();
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:NO forKey:PVDimTestBackground];
	[defaults setBool:NO forKey:PVSlideShowWithWrongWords];
	NSArray *words = [self words];
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
	XCTAssertTrue(PVScreenIsLocked() || PVWaitUntil(5, ^BOOL { return [[mDocument window] isKeyWindow]; }), @"the document window did not become key");
}

-(void)tearDown
{
	// a test still registered here would get the key events of the next tests
	XCTAssertEqual([[ProVocTester currentTesters] count], 0u, @"a test (of words) is still running at the end of %@", [self name]);
	PVCloseDocument(mDocument);
	[mDocument release];
	mDocument = nil;
	// ... and so would a document left open: the window that gets the keys would not be the one of the next test
	NSArray *left = [NSArray arrayWithArray:[[NSDocumentController sharedDocumentController] documents]];
	XCTAssertEqual([left count], 0u, @"%@ left documents open: %@", [self name], [left valueForKey:@"displayName"]);
	for (NSDocument *document in left)
		PVCloseDocument(document);
	[mAnswers release];
	mAnswers = nil;
}

-(NSArray *)words
{
	return @[@[@"house", @"maison"], @[@"cat", @"chat"], @[@"dog", @"chien"], @[@"summer", @"été"]];
}

#pragma mark What the user sees

-(ProVocTester *)tester
{
	return [[ProVocTester currentTesters] lastObject];
}

-(NSPanel *)testPanel
{
	// the written test panel or the multiple-choice one
	return [[self tester] performSelector:@selector(testPanel)];
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
-(int)progressMax
{
	return [[[self tester] valueForKey:@"progressMax"] intValue];
}

-(NSButton *)buttonWithAction:(SEL)inAction inView:(NSView *)inView
{
	if ([inView isKindOfClass:[NSButton class]] && [(NSButton *)inView action] == inAction && ![inView isHiddenOrHasHiddenAncestor])
		return (NSButton *)inView;
	for (NSView *subview in [inView subviews]) {
		NSButton *button = [self buttonWithAction:inAction inView:subview];
		if (button)
			return button;
	}
	return nil;
}

-(id)viewIn:(NSView *)inView withBinding:(NSString *)inBinding to:(NSString *)inKeyPath
{
	if ([[[inView infoForBinding:inBinding] objectForKey:NSObservedKeyPathKey] isEqualToString:inKeyPath])
		return inView;
	for (NSView *subview in [inView subviews]) {
		NSView *found = [self viewIn:subview withBinding:inBinding to:inKeyPath];
		if (found)
			return found;
	}
	if ([inView isKindOfClass:[NSTabView class]])
		for (NSTabViewItem *item in [(NSTabView *)inView tabViewItems])
			if ([item view] && [[item view] superview] != inView) {
				NSView *found = [self viewIn:[item view] withBinding:inBinding to:inKeyPath];
				if (found)
					return found;
			}
	return nil;
}

-(id)controlWithBinding:(NSString *)inBinding to:(NSString *)inKeyPath
{
	return [self viewIn:[[mDocument window] contentView] withBinding:inBinding to:inKeyPath];
}

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

-(NSMenuItem *)itemWithAction:(SEL)inAction tag:(NSInteger)inTag inMenu:(NSMenu *)inMenu
{
	for (NSMenuItem *item in [inMenu itemArray]) {
		if ([item action] == inAction && [item tag] == inTag)
			return item;
		NSMenuItem *found = [item submenu] ? [self itemWithAction:inAction tag:inTag inMenu:[item submenu]] : nil;
		if (found)
			return found;
	}
	return nil;
}

-(NSMenuItem *)menuItemWithAction:(SEL)inAction tag:(NSInteger)inTag
{
	return [self itemWithAction:inAction tag:inTag inMenu:[NSApp mainMenu]];
}

-(void)chooseMenuItemWithAction:(SEL)inAction tag:(NSInteger)inTag
{
	NSMenuItem *item = [self menuItemWithAction:inAction tag:inTag];
	XCTAssertNotNil(item, @"no menu item for %@", NSStringFromSelector(inAction));
	PVPrepareMenu([item menu]);
	XCTAssertTrue([item isEnabled], @"the menu item %@ is disabled", [item title]);
	[[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]];
}

-(void)runScript:(PVScript *)inScript
{
	NSString *failure = [inScript run];
	if (failure)	// what the document window looked like
		PVSaveWindowScreenshot([mDocument window], [@"failures/" stringByAppendingString:[[[self name] componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"-"]]);
	XCTAssertNil(failure, @"%@ — question \"%@\", typed \"%@\", progress %i, test panel visible %i, focus %i, result panel visible %i; app active %i, key window %@ (first responder %@), main window %@, modal window %@; default button %@ enabled %i hidden %i, typed %@", failure,
				 [self question], [self typedAnswer], [self progress], [[self testPanel] isVisible], [self answerFieldHasFocus], [[self resultPanel] isVisible],
				 [NSApp isActive], [[NSApp keyWindow] title], [[[NSApp keyWindow] firstResponder] className], [[NSApp mainWindow] title], [[NSApp modalWindow] title],
				 [[[self testPanel] defaultButtonCell] title], [[[self testPanel] defaultButtonCell] isEnabled], [[[[self testPanel] defaultButtonCell] controlView] isHiddenOrHasHiddenAncestor],
				 [[[self typedAnswer] dataUsingEncoding:NSUTF8StringEncoding] description]);
	// never leave a modal session, a sheet or a running test behind for the next test
	if ([self tester])
		[[self tester] performSelector:@selector(closePanelWithCode:) withObject:nil];
	if ([NSApp modalWindow])
		[NSApp abortModal];
	// (a modal test panel that was aborted has not ended its test)
	for (ProVocTester *tester in [NSArray arrayWithArray:[ProVocTester currentTesters]]) {
		[[tester performSelector:@selector(testPanel)] orderOut:nil];
		((void (*)(id, SEL, BOOL))objc_msgSend)(tester, NSSelectorFromString(@"terminateTest:"), YES);
	}
}

-(void)answerCorrectlyIn:(PVScript *)inScript withReturnKeyCode:(unsigned short)inReturnKeyCode
{
	[inScript then:^{
		XCTAssertNotNil(mAnswers[[self question]], @"unexpected question %@", [self question]);
		PVTypeText(mAnswers[[self question]]);
	}];
	[inScript wait:@"the typed answer in the field" until:^BOOL { return [[self typedAnswer] isEqualToString:mAnswers[[self question]]]; }];
	[inScript then:^{ PVPostKey(inReturnKeyCode, nil, 0); }];
}

-(void)answerCorrectlyIn:(PVScript *)inScript
{
	[self answerCorrectlyIn:inScript withReturnKeyCode:PVKeyReturn];
}

@end
