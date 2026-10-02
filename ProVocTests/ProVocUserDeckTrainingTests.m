//
//  ProVocUserDeckTrainingTests.m
//
//  Every deck of fixtures/user-decks (copies of real decks) and of fixtures/generated:
//  opened, trained on a few words with the keyboard only (type the answer, Return),
//  saved, and opened again to check that it is as it was saved.
//

#import "PVScenarioTestCase.h"
#import "ProVocInspector.h"

@interface ProVocUserDeckTrainingTests : PVScenarioTestCase
@end

@implementation ProVocUserDeckTrainingTests

-(NSArray *)decks
{
	NSMutableArray *decks = [NSMutableArray array];
	for (NSString *folder in @[@"fixtures/user-decks", @"fixtures/generated"]) {
		NSString *directory = [PVTestSourceRoot() stringByAppendingPathComponent:folder];
		for (NSString *name in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL] sortedArrayUsingSelector:@selector(compare:)])
			if ([[[name pathExtension] lowercaseString] isEqualToString:@"pvoc"])
				[decks addObject:[directory stringByAppendingPathComponent:name]];
	}
	return decks;
}

-(NSArray *)signatureOfDocument:(ProVocDocument *)inDocument
{
	NSMutableArray *signature = [NSMutableArray array];
	for (ProVocWord *word in [inDocument allWords])
		[signature addObject:@[[word sourceWord], [word targetWord], [word comment], @([word right]), @([word wrong]), @([word mark]), @([word label]),
							   [[word mediaDictionary] count] ? [word mediaDictionary] : @{}, [word lastAnswered] ? [word lastAnswered] : [NSNull null]]];
	return signature;
}

-(void)trainWithKeyboardOnDeck:(NSString *)inDeck variant:(NSString *)inVariant
{
	NSString *name = [inDeck lastPathComponent];
	// the deck takes the place of the document of the test
	PVCloseDocument(mDocument);
	[mDocument release];
	mDocument = [PVOpenCopyOfDeck(inDeck) retain];
	XCTAssertNotNil(mDocument, @"%@ did not open", name);
	if (!mDocument)
		return;
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [[mDocument window] isKeyWindow]; }), @"%@: its window is not key", name);
	// a written test of six words, whatever the training modes of the deck
	for (NSArray *setting in @[@[@"testMCQ", @NO], @[@"timer", @0], @[@"lateComments", @0], @[@"useSpeechSynthesizer", @NO], @[@"initialSlideshow", @NO], @[@"testDirection", @0], @[@"testKind", @0],
							   @[@"numberOfRetries", @3], @[@"testMarked", @NO], @[@"testWordsToReview", @NO], @[@"testOldWords", @NO], @[@"autoPlayMedia", @NO], @[@"mediaHideQuestion", @0],
							   @[@"dontShuffleWords", @YES], @[@"testLimit", @YES], @[@"testLimitNumber", @6], @[@"testLimitWhat", @0]])
		[mDocument setValue:setting[1] forKey:setting[0]];
	// all the lessons
	NSOutlineView *outline = [mDocument valueForKey:@"mPageOutlineView"];
	[outline selectAll:nil];
	[mDocument selectedPagesDidChange];
	int count = (int)MIN(6u, [[mDocument wordsToBeTested] count]);
	XCTAssertTrue(count > 0, @"%@ has no word to train", name);

	// (a word whose question has synonyms is asked once for each of them: there may be more questions than words)
	PVScript *script = [PVScript script];
	__block NSString *answer = nil;
	__block int answered = 0;
	__block int questions = 0;
	[script then:^{ PVTypeCommand(@"r", 0); }];
	[script wait:[NSString stringWithFormat:@"%@: question 1, the answer field focused", name] timeout:10 until:^BOOL { return [self showsQuestionNumber:1]; }];
	[script then:^{
		questions = [self progressMax];
		XCTAssertTrue(questions >= count && questions <= 4 * count, @"%@: %i questions for %i words", name, questions, count);
		PVSaveWindowScreenshot([self testPanel], [NSString stringWithFormat:@"decks/%@-question%@", [name stringByDeletingPathExtension], inVariant]);
	}];
	for (int number = 1; number <= 4 * count; number++) {
		[script wait:[NSString stringWithFormat:@"%@: the next question, the answer field focused (or the results)", name] timeout:10 until:^BOOL {
			return [[self resultPanel] isVisible] || ([self showsQuestionNumber:number] && [self answerFieldHasFocus]);
		}];
		[script then:^{
			answer = nil;
			if ([[self resultPanel] isVisible])
				return;
			// the full answer, as the deck has it
			answer = [[[self tester] valueForKey:@"answer"] copy];
			PVTypeText(answer);
		}];
		[script wait:[NSString stringWithFormat:@"%@: the answer typed in the field", name] until:^BOOL {
			return !answer || ([[[self typedAnswer] precomposedStringWithCanonicalMapping] isEqualToString:[answer precomposedStringWithCanonicalMapping]] && [self answerFieldHasFocus]);
		}];
		[script then:^{
			if (answer) {
				answered = [self progress];
				PVPostKey(PVKeyReturn, nil, 0);
			}
		}];
		[script wait:[NSString stringWithFormat:@"%@: Return to take the answer and go on", name] until:^BOOL {
			return !answer || [[self resultPanel] isVisible] || ([self testPanelIsReady] && [self progress] == answered + 1 && [[self typedAnswer] length] == 0);
		}];
		[script then:^{ XCTAssertFalse(answer && [self showsSolution], @"%@: the answer \"%@\" typed as it is in the deck was refused", name, answer); }];
	}
	[script wait:[NSString stringWithFormat:@"%@: the result panel", name] until:^BOOL { return [[self resultPanel] isVisible]; }];
	[script then:^{
		XCTAssertEqualObjects([self resultValues], (@[@(questions), @0]), @"%@: results", name);
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[script wait:[NSString stringWithFormat:@"%@: the test to be over", name] until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];

	// saved, and opened again
	NSArray *signature = [self signatureOfDocument:mDocument];
	NSUInteger answeredWords = [[[mDocument allWords] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ProVocWord *word, NSDictionary *bindings) {
		return [word lastAnswered] && [[word lastAnswered] timeIntervalSinceNow] > -120;
	}]] count];
	XCTAssertEqual(answeredWords, (NSUInteger)count, @"%@: the words answered are not recorded", name);
	__block BOOL saved = NO;
	NSURL *url = [mDocument fileURL];
	[mDocument saveToURL:url ofType:[mDocument fileType] forSaveOperation:NSSaveOperation completionHandler:^(NSError *inError) {
		XCTAssertNil(inError, @"%@: %@", name, inError);
		saved = YES;
	}];
	XCTAssertTrue(PVWaitUntil(20, ^BOOL { return saved; }), @"%@: save did not finish", name);
	PVCloseDocument(mDocument);
	[mDocument release];
	mDocument = [PVOpenCopyOfDeck([url path]) retain];
	XCTAssertNotNil(mDocument, @"%@ did not reopen after the training", name);
	XCTAssertEqualObjects([self signatureOfDocument:mDocument], signature, @"%@ is not as it was saved", name);
	XCTAssertEqual([[mDocument valueForKey:@"mHistories"] count] > 0, YES, @"%@: the training is not in its history", name);
}

-(void)scenarioEveryDeckIsTrainedWithTheKeyboardSavedAndReopened
{
	NSArray *decks = [self decks];
	XCTAssertTrue([decks count] >= 4, @"decks: %@", decks);
	NSString *variant = [self variant];
	for (NSString *deck in decks)
		@autoreleasepool {	// (the documents of a deck go away before the next one: some twenty decks are opened twice each)
			// each deck starts from the factory settings (a deck brings its own separators, fonts and labels)
			PVResetPreferences();
			[[NSUserDefaults standardUserDefaults] setBool:[variant isEqualToString:@"-dimmed"] forKey:PVDimTestBackground];
			[self trainWithKeyboardOnDeck:deck variant:variant];
		}
}

@end
