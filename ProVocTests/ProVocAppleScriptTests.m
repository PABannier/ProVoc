//
//  ProVocAppleScriptTests.m
//
//  The AppleScript dictionary of ProVoc (ProVoc.scriptSuite), with scripts run inside
//  the application and addressed to itself. scripts/applescript-check.sh does the
//  same from outside with osascript (which macOS has to be allowed to do).
//

#import "PVScenarioTestCase.h"

@interface ProVocAppleScriptTests : PVScenarioTestCase
@end

@implementation ProVocAppleScriptTests

-(id)run:(NSString *)inCommands
{
	NSString *source = [NSString stringWithFormat:@"tell application id \"%@\"\n%@\nend tell", [[NSBundle mainBundle] bundleIdentifier], inCommands];
	NSDictionary *error = nil;
	NSAppleEventDescriptor *result = [[[[NSAppleScript alloc] initWithSource:source] autorelease] executeAndReturnError:&error];
	XCTAssertNil(error, @"%@ failed: %@", inCommands, error);
	return [result stringValue] ? (id)[result stringValue] : (id)result;
}

// the documents, export (to read the words), import text, import a file, start test
-(void)testReadWordsImportAndStartTest
{
	// (The "open" command is not sent here: a document opens asynchronously, and a script
	// that runs inside the application cannot wait for it - "AppleEvent timed out".
	// scripts/applescript-check.sh opens a deck with osascript.)
	NSUInteger documents = [[[NSDocumentController sharedDocumentController] documents] count];
	ProVocDocument *opened = PVOpenCopyOfDeck([PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated/Plain.pvoc"]);
	XCTAssertNotNil(opened);
	XCTAssertTrue(PVWaitUntil(10, ^BOOL { return [[opened window] isMainWindow]; }), @"the deck is not in front");
	XCTAssertEqualObjects([self run:@"name of front document"], [opened displayName]);
	XCTAssertEqual([[self run:@"count documents"] intValue], (int)documents + 1);

	// the words, as text
	NSString *text = [self run:@"export \"\""];
	XCTAssertEqualObjects(text, @"house\tmaison\ncat\tchat\ndog\tchien\nsummer\tété\nbread\tpain\n");
	text = [self run:@"export \"\" with include names"];
	XCTAssertTrue([text hasPrefix:@"# Lesson 1\nhouse\tmaison\n"], @"%@", text);
	NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVScripted-%i.txt", [[NSProcessInfo processInfo] processIdentifier]]];
	[self run:[NSString stringWithFormat:@"export \"%@\"", file]];
	XCTAssertTrue([[NSString stringWithContentsOfFile:file usedEncoding:NULL error:NULL] hasPrefix:@"house\tmaison\n"], @"export to a file: %@", [NSString stringWithContentsOfFile:file usedEncoding:NULL error:NULL]);

	// import text and a file
	[self run:@"import text \"sun\\tsoleil\\tin the sky\\nmoon\\tlune\""];
	XCTAssertEqual([[opened allWords] count], 7u, @"import text");
	XCTAssertEqualObjects([[[opened allWords] objectAtIndex:5] comment], @"in the sky");
	[self run:[NSString stringWithFormat:@"import \"%@\" with new document", file]];
	XCTAssertTrue(PVWaitUntil(10, ^BOOL { return [[[NSDocumentController sharedDocumentController] documents] count] == documents + 2; }), @"import with new document made no document");
	ProVocDocument *imported = [[[NSDocumentController sharedDocumentController] documents] lastObject];
	XCTAssertEqual([[imported allWords] count], 5u, @"words imported in the new document");
	PVCloseDocument(imported);

	// start test: what Command-R does, for the front document
	PVScript *script = [PVScript script];
	[script then:^{
		[[opened window] makeKeyAndOrderFront:nil];
		for (NSArray *setting in @[@[@"testMCQ", @NO], @[@"initialSlideshow", @NO], @[@"timer", @0]])
			[opened setValue:setting[1] forKey:setting[0]];
	}];
	[script wait:@"the opened document in front" until:^BOOL { return [[opened window] isMainWindow] && [ProVocDocument currentDocument] == opened; }];
	[script then:^{ [self run:@"start test"]; }];
	[script wait:@"the test started by the script, its answer field focused" until:^BOOL { return [self tester] != nil && [self answerFieldHasFocus] && [self progress] == 1; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to end" until:^BOOL { return [self tester] == nil && [[opened window] attachedSheet] == nil && [NSApp modalWindow] == nil; }];
	[self runScript:script];
	PVCloseDocument(opened);
}

@end
