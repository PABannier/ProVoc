//
//  ProVocLongQuestionTests.m
//
//  A question longer than its field is shown entirely: the field wraps it and the panel
//  grows to make room; a question too long for the screen scrolls, from its first line.
//  In a written test and in a multiple-choice test, in a sheet and in the dimmed modal
//  panel.
//

#import "PVScenarioTestCase.h"

@interface ProVocLongQuestionTests : PVScenarioTestCase
@end

@implementation ProVocLongQuestionTests

static NSString *sSentence = @"La cellule cancéreuse est une cellule génétiquement instable, capable d'explorer les fonctions de l'ensemble du génome et de mettre à profit tout avantage prolifératif ou migratoire pour le sélectionner et le transmettre à sa descendance.";
static NSString *sComment = @"a comment under the question, kept apart from it";

-(NSArray *)words
{
	NSString *huge = [[NSArray arrayWithObjects:sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, sSentence, nil] componentsJoinedByString:@" "];
	return @[@[sSentence, @"instabilité", sComment], @[huge, @"douze fois"]];
}

#pragma mark What the user sees

-(NSTextField *)questionField
{
	return [self viewIn:[[self testPanel] contentView] withBinding:NSValueBinding to:@"question"];
}

-(NSTextField *)commentField
{
	return [self viewIn:[[self testPanel] contentView] withBinding:NSValueBinding to:@"comment"];
}

-(CGFloat)heightNeededBy:(NSTextField *)inField
{
	return ceil([[inField cell] cellSizeForBounds:NSMakeRect(0, 0, NSWidth([inField bounds]), 100000)].height);
}

// The panel has made its room for the question: all of it is visible, or the panel is as
// tall as the screen (it grows after the question is set)
-(BOOL)questionIsLaidOut
{
	NSTextField *field = [self questionField];
	return NSHeight([field visibleRect]) >= [self heightNeededBy:field] || NSHeight([[self testPanel] frame]) > 0.9 * NSHeight([[[self testPanel] screen] visibleFrame]);
}

// The question is wrapped at the width of its field and shown from its first line; the
// panel stays on the screen. Returns the height the whole question needs.
-(CGFloat)checkQuestion:(NSString *)inQuestion
{
	NSTextField *field = [self questionField];
	XCTAssertEqualObjects([field stringValue], inQuestion);
	XCTAssertFalse([field isHiddenOrHasHiddenAncestor]);
	XCTAssertTrue([[field cell] wraps]);
	NSRect visible = [field visibleRect];
	CGFloat needed = [self heightNeededBy:field];
	XCTAssertGreaterThanOrEqual(NSHeight([field frame]), needed, @"the field is shorter than its text: the middle lines show, cut above and below");
	XCTAssertEqual([field isFlipped] ? NSMinY(visible) : NSMaxY(visible), [field isFlipped] ? 0 : NSMaxY([field bounds]), @"the first line of the question is not visible");
	XCTAssertGreaterThan(NSWidth(visible), 400, @"the question is wrapped in a narrow column");
	NSRect panel = [[self testPanel] frame], screen = [[[self testPanel] screen] visibleFrame];
	XCTAssertTrue(NSContainsRect(screen, panel), @"the panel %@ left the screen %@", NSStringFromRect(panel), NSStringFromRect(screen));
	return needed;
}

// The sentence of five lines: the panel grew and the whole question is visible, with its
// comment under it. The sixty lines: the panel took the height of the screen, the rest scrolls.
-(void)checkLaidOutQuestionWithInitialPanel:(NSRect)inInitialPanel
{
	NSString *question = [self question];
	CGFloat needed = [self checkQuestion:question];
	NSTextField *field = [self questionField];
	NSRect panel = [[self testPanel] frame], screen = [[[self testPanel] screen] visibleFrame];
	if ([question isEqualToString:sSentence]) {
		XCTAssertEqual(NSHeight([field visibleRect]), NSHeight([field frame]), @"part of a question that fits on the screen is scrolled away");
		XCTAssertGreaterThan(NSHeight(panel), NSHeight(inInitialPanel), @"the panel did not grow");
		NSTextField *comment = [self commentField];
		if (comment && ![comment isHiddenOrHasHiddenAncestor]) {
			XCTAssertEqualObjects([comment stringValue], sComment);
			XCTAssertLessThanOrEqual(NSMaxY([comment frame]), NSMinY([[field enclosingScrollView] frame]) + 1, @"the comment overlaps the question");
			XCTAssertGreaterThanOrEqual(NSHeight([comment frame]), [self heightNeededBy:comment] - 1, @"the comment is cut");
			XCTAssertTrue(NSContainsRect([[comment superview] bounds], [comment frame]), @"the comment left its view");
		}
	} else {
		XCTAssertGreaterThan(needed, NSHeight(screen));
		XCTAssertGreaterThan(NSHeight(panel), 0.9 * NSHeight(screen), @"the panel did not grow to the height of the screen");
		NSScrollView *scrollView = [field enclosingScrollView];
		XCTAssertNotNil(scrollView);
		XCTAssertGreaterThan(NSHeight([field frame]), NSHeight([scrollView frame]), @"nothing to scroll");
		XCTAssertGreaterThan(NSHeight([scrollView frame]), 150, @"the question got a sliver of the panel");
		XCTAssertFalse([[scrollView verticalScroller] isHidden], @"no scroller for the rest of the question");
	}
}

// The growth is not remembered as the layout the user chose
-(void)checkSavedLayout:(NSString *)inKey
{
	float before = [[[self tester] valueForKey:@"mPaneHeightBeforeGrowth"] floatValue];
	XCTAssertGreaterThan(before, 50);
	XCTAssertLessThan(before, 300);
	XCTAssertEqualWithAccuracy([[NSUserDefaults standardUserDefaults] floatForKey:inKey], before, 1);
}

#pragma mark Scenarios

-(void)scenarioLongQuestionsAreShownEntirely
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	NSRect initialPanel = [[self testPanel] frame];
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"question %i, laid out", number] until:^BOOL { return [self showsQuestionNumber:number] && [self questionIsLaidOut]; }];
		[script then:^{
			[self checkLaidOutQuestionWithInitialPanel:initialPanel];
			XCTAssertTrue([self answerFieldHasFocus]);
			PVSaveWindowScreenshot([self testPanel], [NSString stringWithFormat:@"long-question-%i%@", number, [self variant]]);
		}];
		// and it stays so once the sheet has finished growing
		[script pause:0.5];
		[script then:^{ [self checkQuestion:[self question]]; }];
		[self answerCorrectlyIn:script];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		[self checkSavedLayout:@"Split Subview 0"];
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

-(id)mcqView
{
	return [[self tester] valueForKey:@"mMCQView"];
}

-(int)solutionIndex
{
	return [[[self mcqView] valueForKey:@"mSolutionIndex"] intValue];
}

-(BOOL)showsMCQQuestionNumber:(int)inNumber
{
	id view = [self mcqView];
	return [self tester] && [[self testPanel] isVisible] && [[self testPanel] isKeyWindow] && [[self testPanel] firstResponder] == view
		&& [self progress] == inNumber && [[view valueForKey:@"mSelectedIndex"] intValue] < 0 && [[view valueForKey:@"mAnswers"] count] > 0;
}

-(void)scenarioLongQuestionsAreShownEntirelyInMultipleChoice
{
	[mDocument setValue:@YES forKey:@"testMCQ"];
	[mDocument setValue:@2 forKey:@"testMCQNumber"];
	[mDocument setValue:@NO forKey:@"delayedMCQ"];
	[mDocument setValue:@NO forKey:@"imageMCQ"];
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	NSRect initialPanel = [[self testPanel] frame];
	static const unsigned short digitKeyCodes[3] = {29, 18, 19};	// the top row, without Shift
	for (int number = 1; number <= 2; number++) {
		[script wait:[NSString stringWithFormat:@"multiple-choice question %i, laid out", number] until:^BOOL { return [self showsMCQQuestionNumber:number] && [self questionIsLaidOut]; }];
		[script then:^{
			[self checkLaidOutQuestionWithInitialPanel:initialPanel];
			PVSaveWindowScreenshot([self testPanel], [NSString stringWithFormat:@"long-question-mcq-%i%@", number, [self variant]]);
			PVPostKey(digitKeyCodes[[self solutionIndex] + 1], nil, 0);
		}];
		[script wait:@"the right choice to be selected" until:^BOOL { return [[[self mcqView] valueForKey:@"mSelectedIndex"] intValue] == [self solutionIndex]; }];
		[script then:^{
			[self checkQuestion:[self question]];
			PVPostKey(PVKeyReturn, nil, 0);
		}];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		[self checkSavedLayout:@"MCQ Other View Height"];
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

@end
