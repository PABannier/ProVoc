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
	XCTAssertEqualObjects([decks valueForKey:@"lastPathComponent"], (@[@"Accents.pvoc", @"Dead keys.pvoc", @"Old format.provoc", @"Plain.pvoc", @"Rich.pvoc"]));
	NSDictionary *counts = @{@"Accents.pvoc": @15, @"Dead keys.pvoc": @3, @"Old format.provoc": @3, @"Plain.pvoc": @5, @"Rich.pvoc": @10};
	for (NSString *deck in decks) {
		ProVocDocument *document = PVOpenCopyOfDeck(deck);
		XCTAssertNotNil(document, @"%@ did not open", [deck lastPathComponent]);
		XCTAssertEqualObjects(@([[document allWords] count]), counts[[deck lastPathComponent]], @"words of %@", [deck lastPathComponent]);
		if ([[deck lastPathComponent] isEqualToString:@"Dead keys.pvoc"]) {
			// the deck keeps its training settings: a written test, in the order of the list
			XCTAssertFalse([[document valueForKey:@"testMCQ"] boolValue]);
			XCTAssertFalse([[document valueForKey:@"initialSlideshow"] boolValue]);
			XCTAssertTrue([[document valueForKey:@"dontShuffleWords"] boolValue]);
			XCTAssertEqualObjects([[document allWords] valueForKey:@"targetWord"], (@[@"être", @"naïf", @"été"]));
		}
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

// A deck whose vocabulary cannot be read: the exception raised by the unarchiver is not
// swallowed. It is logged ("*** Exception raised during ..."), and the document does not
// open - with an error, not with an empty window. The same when such a file is imported.
-(void)testCorruptDeckIsRefusedAndTheExceptionIsLogged
{
	NSString *deck = PVTemporaryCopyOfDeck([PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated/Plain.pvoc"]);
	XCTAssertTrue([[@"this is not an archive" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[deck stringByAppendingPathComponent:@"Data"] atomically:YES]);
	NSUInteger documents = [[[NSDocumentController sharedDocumentController] documents] count];
	__block BOOL done = NO;
	__block NSDocument *opened = nil;
	__block NSError *error = nil;
	PVBeginCapturingStderr();
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:deck] display:YES completionHandler:^(NSDocument *inDocument, BOOL inWasOpen, NSError *inError) {
		opened = [inDocument retain];
		error = [inError retain];
		done = YES;
	}];
	XCTAssertTrue(PVWaitUntil(20, ^BOOL { return done; }), @"no answer from the document controller");
	NSString *log = PVEndCapturingStderr();
	XCTAssertNil(opened, @"a deck that cannot be read was opened");
	XCTAssertNotNil(error, @"no error for a deck that cannot be read");
	XCTAssertEqual([[[NSDocumentController sharedDocumentController] documents] count], documents);
	XCTAssertTrue([log rangeOfString:@"*** Exception raised during loadFileWrapperRepresentation:ofType:"].location != NSNotFound, @"the exception was not logged: %@", log);
	[opened close];
	[opened release];
	[error release];

	// the old flat file: the same
	NSString *flat = [[deck stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Corrupt.provoc"];
	XCTAssertTrue([[@"this is not an archive either" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:flat atomically:YES]);
	done = NO;
	opened = nil;
	error = nil;
	PVBeginCapturingStderr();
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:flat] display:YES completionHandler:^(NSDocument *inDocument, BOOL inWasOpen, NSError *inError) {
		opened = [inDocument retain];
		error = [inError retain];
		done = YES;
	}];
	XCTAssertTrue(PVWaitUntil(20, ^BOOL { return done; }), @"no answer from the document controller");
	log = PVEndCapturingStderr();
	XCTAssertNil(opened, @"a flat file that cannot be read was opened");
	XCTAssertNotNil(error, @"no error for a flat file that cannot be read");
	XCTAssertTrue([log rangeOfString:@"*** Exception raised during loadFileWrapperRepresentation:ofType:"].location != NSNotFound, @"the exception was not logged: %@", log);
	XCTAssertEqual([[[NSDocumentController sharedDocumentController] documents] count], documents);
	[opened close];
	[opened release];
	[error release];

	// A file given to Import is tried as a ProVoc document first; one that is not is
	// then read as text (there the exception of the unarchiver is expected, and silent).
	ProVocDocument *document = PVNewDocumentWithWords(@[@[@"house", @"maison"]]);
	XCTAssertNil([document pagesFromProVocFile:flat]);
	PVCloseDocument(document);
}

@end
