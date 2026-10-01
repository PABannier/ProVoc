//
//  ProVocInterrogationTests.m
//
//  Drives a whole test with key events posted to the application's event queue
//  (they travel through -[ProVocApplication sendEvent:] like real keystrokes) and
//  checks what the user would see. Every scenario runs twice: with the test panel
//  as a sheet and as the modal panel used when "Dim test background" is on.
//

#import <XCTest/XCTest.h>
#import "PVTestSupport.h"
#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocTester.h"
#import "ProVocWord.h"
#import "ProVocPreferences.h"

@interface ProVocInterrogationTests : XCTestCase {
	ProVocDocument *mDocument;
	NSDictionary *mAnswers;
}
@end

@implementation ProVocInterrogationTests

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

// Type the answer, Return, type the answer, Return... never touching the mouse.
-(void)allCorrectWithReturnKeyCode:(unsigned short)inReturnKeyCode
{
	PVScript *script = [PVScript script];
	NSMutableArray *asked = [NSMutableArray array];
	[script then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 4; number++) {
		[script wait:[NSString stringWithFormat:@"question %i with the answer field empty and focused", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
		[script then:^{
			NSString *question = [self question];
			XCTAssertNotNil(mAnswers[question], @"unexpected question %@", question);
			XCTAssertFalse([asked containsObject:question], @"%@ asked twice", question);
			[asked addObject:question];
			PVTypeText(mAnswers[question]);
		}];
		[script wait:@"the typed answer in the field" until:^BOOL { return [[self typedAnswer] isEqualToString:mAnswers[[self question]]]; }];
		[script then:^{ PVPostKey(inReturnKeyCode, nil, 0); }];
	}
	[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible] && ![[self testPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqual([asked count], 4u);
		XCTAssertEqual([[self wordWithSource:@"house"] right], 1);
		XCTAssertEqual([[self wordWithSource:@"house"] wrong], 0);
		// nothing to repeat: Return means Done
		PVPostKey(inReturnKeyCode, nil, 0);
	}];
	[script wait:@"the result panel to close and the test to be over" until:^BOOL { return ![[self resultPanel] isVisible] && ![mDocument testIsRunning] && ![mDocument valueForKey:@"mTester"]; }];
	[self runScript:script];
}

-(void)testAllCorrectInSheet
{
	[self allCorrectWithReturnKeyCode:PVKeyReturn];
}

-(void)testAllCorrectInDimmedModalPanel
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PVDimTestBackground];
	[self allCorrectWithReturnKeyCode:PVKeyReturn];
}

-(void)testKeypadEnterBehavesLikeReturnInSheet
{
	[self allCorrectWithReturnKeyCode:PVKeyKeypadEnter];
}

-(void)testKeypadEnterBehavesLikeReturnInDimmedModalPanel
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PVDimTestBackground];
	[self allCorrectWithReturnKeyCode:PVKeyKeypadEnter];
}

@end
