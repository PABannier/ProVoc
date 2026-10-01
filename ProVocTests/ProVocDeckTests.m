//
//  ProVocDeckTests.m
//
//  Opens real decks through NSDocumentController, saves them and checks that
//  they reopen identically.
//

#import <XCTest/XCTest.h>
#import "PVTestSupport.h"
#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocWord.h"
#import "ProVocInspector.h"

@interface ProVocDeckTests : XCTestCase
@end

@implementation ProVocDeckTests

-(NSArray *)userDecks
{
	NSString *directory = [PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/user-decks"];
	NSMutableArray *decks = [NSMutableArray array];
	for (NSString *name in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL] sortedArrayUsingSelector:@selector(compare:)])
		if ([@[@"pvoc", @"provoc"] containsObject:[[name pathExtension] lowercaseString]])
			[decks addObject:[directory stringByAppendingPathComponent:name]];
	return decks;
}

// What must survive a save: every word with its texts, statistics, labels and media.
-(NSArray *)signatureOfDocument:(ProVocDocument *)inDocument
{
	NSMutableArray *signature = [NSMutableArray array];
	for (ProVocWord *word in [inDocument allWords])
		[signature addObject:@[[word sourceWord], [word targetWord], [word comment], @([word right]), @([word wrong]), @([word mark]), @([word label]),
							   [[word mediaDictionary] count] ? [word mediaDictionary] : @{}, [word lastAnswered] ? [word lastAnswered] : [NSNull null]]];
	return signature;
}

// The decks written by scripts/make-fixtures.sh, among them one in the old flat format
-(NSArray *)generatedDecks
{
	NSString *directory = [PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated"];
	NSMutableArray *decks = [NSMutableArray array];
	for (NSString *name in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL] sortedArrayUsingSelector:@selector(compare:)])
		if ([@[@"pvoc", @"provoc"] containsObject:[[name pathExtension] lowercaseString]])
			[decks addObject:[directory stringByAppendingPathComponent:name]];
	return decks;
}

-(void)testGeneratedDecksOpenWithEverything
{
	NSArray *decks = [self generatedDecks];
	XCTAssertEqualObjects([decks valueForKey:@"lastPathComponent"], (@[@"Accents.pvoc", @"Old format.provoc", @"Plain.pvoc", @"Rich.pvoc"]));
	NSDictionary *counts = @{@"Accents.pvoc": @15, @"Old format.provoc": @3, @"Plain.pvoc": @5, @"Rich.pvoc": @10};
	for (NSString *deck in decks) {
		ProVocDocument *document = PVOpenCopyOfDeck(deck);
		XCTAssertNotNil(document, @"%@ did not open", [deck lastPathComponent]);
		XCTAssertEqualObjects(@([[document allWords] count]), counts[[deck lastPathComponent]], @"words of %@", [deck lastPathComponent]);
		if ([[deck lastPathComponent] isEqualToString:@"Accents.pvoc"]) {
			NSArray *targets = [[document allWords] valueForKey:@"targetWord"];
			for (NSString *word in @[@"été", @"garçon", @"naïve", @"cœur", @"où", @"niño", @"¿qué?", @"Straße", @"ελληνικά", @"日本語"])
				XCTAssertTrue([targets containsObject:word], @"%@ is not in Accents.pvoc: %@", word, targets);
		}
		PVCloseDocument(document);
	}
}

-(void)testUserDecksOpenSaveAndReopenIdentically
{
	XCTAssertTrue([[self userDecks] count] > 0, @"no deck in fixtures/user-decks");
	for (NSString *deck in [[self userDecks] arrayByAddingObjectsFromArray:[[self generatedDecks] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'pvoc'"]]]) {
		NSString *name = [deck lastPathComponent];
		ProVocDocument *document = PVOpenCopyOfDeck(deck);
		XCTAssertNotNil(document, @"%@ did not open", name);
		if (!document)
			continue;
		NSArray *signature = [self signatureOfDocument:document];
		XCTAssertTrue([signature count] > 0, @"%@ has no word", name);
		PVSaveWindowSnapshot([document window], [@"decks/" stringByAppendingString:[name stringByDeletingPathExtension]]);

		__block BOOL saved = NO;
		__block NSError *saveError = nil;
		NSURL *url = [document fileURL];
		[document saveToURL:url ofType:[document fileType] forSaveOperation:NSSaveOperation completionHandler:^(NSError *inError) {
			saveError = [inError retain];
			saved = YES;
		}];
		XCTAssertTrue(PVWaitUntil(20, ^BOOL { return saved; }), @"%@: save did not finish", name);
		XCTAssertNil(saveError, @"%@: %@", name, saveError);
		PVCloseDocument(document);

		ProVocDocument *reopened = PVOpenCopyOfDeck([url path]);
		XCTAssertNotNil(reopened, @"%@ did not reopen after saving", name);
		XCTAssertEqualObjects([self signatureOfDocument:reopened], signature, @"%@ changed when saved", name);
		NSLog(@"deck %@: %lu words, type %@", name, (unsigned long)[signature count], [reopened fileType]);
		PVCloseDocument(reopened);
	}
}

@end
