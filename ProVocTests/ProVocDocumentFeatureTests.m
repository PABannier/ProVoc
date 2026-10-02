//
//  ProVocDocumentFeatureTests.m
//
//  Find Double Entries, spelling, import and export, printing, reveal in lessons,
//  swaps, resetting the difficulty, the history, languages and columns.
//

#import "PVScenarioTestCase.h"
#import "ProVocDocument+Export.h"
#import "ProVocDocument+Columns.h"
#import "ProVocHistory.h"
#import "ProVocPrintView.h"
#import "ProVocCardsView.h"
#import <Quartz/Quartz.h>

// What the export code asks the save panel once it is confirmed
@interface PVChosenFile : NSObject {
	NSString *mPath;
}
+(PVChosenFile *)fileWithPath:(NSString *)inPath;
-(NSString *)filename;
-(NSURL *)URL;
@end

@implementation PVChosenFile
+(PVChosenFile *)fileWithPath:(NSString *)inPath { PVChosenFile *file = [[[self alloc] init] autorelease]; file->mPath = [inPath copy]; return file; }
-(void)dealloc { [mPath release]; [super dealloc]; }
-(NSString *)filename { return mPath; }
-(NSURL *)URL { return [NSURL fileURLWithPath:mPath]; }
@end

@interface ProVocDocumentFeatureTests : PVScenarioTestCase
@end

@implementation ProVocDocumentFeatureTests

-(NSArray *)words
{
	return @[@[@"house", @"maison", @"a building"], @[@"cat", @"chat"], @[@"dog", @"chien", @"an animal"], @[@"summer", @"été"]];
}

-(NSTableView *)wordTable
{
	return [mDocument valueForKey:@"mWordTableView"];
}

-(NSArray *)listedSources
{
	return [[mDocument valueForKey:@"mVisibleWords"] valueForKey:@"sourceWord"];
}

-(NSString *)temporaryPath:(NSString *)inName
{
	NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ProVocFeatureTests-%i", [[NSProcessInfo processInfo] processIdentifier]]];
	[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
	return [directory stringByAppendingPathComponent:inName];
}

-(void)selectRows:(NSIndexSet *)inRows
{
	[[mDocument window] makeFirstResponder:[self wordTable]];
	[[self wordTable] selectRowIndexes:inRows byExtendingSelection:NO];
}

#pragma mark Find Double Entries

// Option-Command-F lists the words that are there twice (same word or same translation);
// when there is none, an alert says so.
-(void)testFindDoubleEntries
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"f", NSEventModifierFlagOption); }];
	[script wait:@"the alert saying that there are no double entries" timeout:10 until:^BOOL { return [[NSApp modalWindow] isKeyWindow]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"Return to close the alert" until:^BOOL { return [NSApp modalWindow] == nil && [[mDocument window] isKeyWindow]; }];
	[script then:^{
		XCTAssertEqual([[self listedSources] count], 4u);
		// the same word again, with another translation; and another word with a translation already used
		PVAddPage(mDocument, @"Lesson 2", @[@[@"House", @"domicile"], @[@"kitty", @"chat"], @[@"bird", @"oiseau"]]);
		[[mDocument valueForKey:@"mPageOutlineView"] selectAll:nil];
		[mDocument selectedPagesDidChange];
	}];
	[script wait:@"the words of all lessons" until:^BOOL { return [[self listedSources] count] == 7; }];
	[script then:^{ PVTypeCommand(@"f", NSEventModifierFlagOption); }];
	[script wait:@"the double entries only" timeout:10 until:^BOOL { return [[NSSet setWithArray:[self listedSources]] isEqualToSet:[NSSet setWithArray:@[@"house", @"House", @"cat", @"kitty"]]] && [[mDocument window] attachedSheet] == nil; }];
	[script then:^{
		PVSaveWindowScreenshot([mDocument window], @"windows/document-double-entries");
		XCTAssertFalse([[mDocument valueForKey:@"showingAllWords"] boolValue]);
		// a search (here an empty one: Command-F, Return) shows all the words again
		PVTypeCommand(@"f", 0);
	}];
	[script wait:@"the search field" until:^BOOL { return [[mDocument valueForKey:@"mSearchField"] currentEditor] != nil; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"all the words again" until:^BOOL { return [[self listedSources] count] == 7; }];
	[self runScript:script];
}

#pragma mark Spelling

// Command-; selects the next misspelled word of the field being edited; Command-: opens the Spelling panel.
-(void)testCheckSpelling
{
	NSTextField *field = [mDocument valueForKey:@"mCommentTextField"];
	NSText *(^editor)(void) = ^{ return [field currentEditor]; };
	NSPanel *spellingPanel = [[NSSpellChecker sharedSpellChecker] spellingPanel];
	XCTAssertEqual([self menuItemWithAction:@selector(checkSpelling:) tag:0] != nil, YES, @"no Check Spelling menu item");
	XCTAssertEqualObjects([[self menuItemWithAction:@selector(checkSpelling:) tag:0] keyEquivalent], @";");
	XCTAssertEqualObjects([[self menuItemWithAction:@selector(showGuessPanel:) tag:0] keyEquivalent], @":");
	PVScript *script = [PVScript script];
	[script then:^{ PVClickView(field, 1, 0); }];
	[script wait:@"the comment field to be edited" until:^BOOL { return editor() != nil && [[mDocument window] firstResponder] == editor(); }];
	[script then:^{ PVTypeText(@"a nice xqzvw word"); }];
	[script wait:@"the text" until:^BOOL { return [[field stringValue] isEqualToString:@"a nice xqzvw word"]; }];
	[script then:^{ [editor() setSelectedRange:NSMakeRange(0, 0)]; PVTypeCommand(@";", 0); }];
	[script wait:@"Command-; to select the misspelled word" until:^BOOL { return NSEqualRanges([editor() selectedRange], [[field stringValue] rangeOfString:@"xqzvw"]); }];
	[script then:^{ PVTypeCommand(@":", 0); }];
	[script wait:@"Command-: to open the Spelling panel" timeout:10 until:^BOOL { return [spellingPanel isVisible]; }];
	[script then:^{
		[spellingPanel orderOut:nil];
		[field setStringValue:@""];
		[[mDocument window] makeFirstResponder:[self wordTable]];
	}];
	[self runScript:script];
}

#pragma mark Import and export

-(NSArray *)wordTextsOf:(ProVocDocument *)inDocument
{
	NSMutableArray *texts = [NSMutableArray array];
	for (ProVocWord *word in [inDocument allWords])
		[texts addObject:@[[word sourceWord], [word targetWord], [word comment] ? [word comment] : @""]];
	return texts;
}

// Shift-Command-E and Shift-Command-I open the panels with their options. Each format
// offered (text separated by tabs, with or without lesson names and comments; values
// separated by commas; each with the automatic encoding or UTF-8) is exported and
// imported again into a new document: the words come back as they were.
-(void)testImportAndExportEveryFormat
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	// accents, non-Latin scripts, quotes, commas and tabs' worth of trouble
	PVAddPage(mDocument, @"Leçon d'été", @[@[@"boy", @"garçon"], @[@"heart", @"cœur", @"say \"keur\", not coeur"], @[@"Greek", @"ελληνικά"], @[@"Japanese", @"日本語", @"nihongo, 3 kanji"], @[@"street", @"Straße"]]);
	[[mDocument valueForKey:@"mPageOutlineView"] selectAll:nil];
	[mDocument selectedPagesDidChange];
	NSArray *expected = [self wordTextsOf:mDocument];
	XCTAssertEqual([expected count], 9u);

	// the panels
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"e", NSEventModifierFlagShift); }];
	[script wait:@"the export panel (Shift-Command-E)" timeout:15 until:^BOOL { return [[[mDocument window] attachedSheet] isKindOfClass:[NSSavePanel class]]; }];
	[script then:^{
		NSSavePanel *panel = (NSSavePanel *)[[mDocument window] attachedSheet];
		XCTAssertEqual([panel accessoryView], [mDocument valueForKey:@"mExportAccessoryView"], @"the export options are not in the panel");
		XCTAssertTrue([[panel allowedFileTypes] containsObject:@"txt"], @"%@", [panel allowedFileTypes]);
		[panel cancel:nil];
	}];
	[script wait:@"the export panel to close" timeout:15 until:^BOOL { return [[mDocument window] attachedSheet] == nil; }];
	[script then:^{ PVTypeCommand(@"i", NSEventModifierFlagShift); }];
	[script wait:@"the import panel (Shift-Command-I)" timeout:15 until:^BOOL { return [[[mDocument window] attachedSheet] isKindOfClass:[NSOpenPanel class]]; }];
	[script then:^{
		NSOpenPanel *panel = (NSOpenPanel *)[[mDocument window] attachedSheet];
		XCTAssertEqual([panel accessoryView], [mDocument valueForKey:@"mImportAccessoryView"], @"the import options are not in the panel");
		XCTAssertTrue([panel allowsMultipleSelection]);
		[panel cancel:nil];
	}];
	[script wait:@"the import panel to close" timeout:15 until:^BOOL { return [[mDocument window] attachedSheet] == nil; }];
	[self runScript:script];

	// the formats of the pop-up of the export panel, the two check boxes, and two encodings
	NSPopUpButton *formats = [self viewIn:[mDocument valueForKey:@"mExportAccessoryView"] withBinding:NSSelectedIndexBinding to:@"values.exportFormat"];
	XCTAssertEqual([formats numberOfItems], 2, @"formats offered: %@", [formats itemTitles]);
	NSArray *encodings = [mDocument valueForKey:@"localizedNamesOfStringEncodings"];
	NSUInteger utf8 = NSNotFound;
	for (NSUInteger index = 0; index < [encodings count]; index++)
		if ([encodings[index] rangeOfString:@"UTF-8"].location != NSNotFound)
			utf8 = index;
	XCTAssertTrue(utf8 != NSNotFound, @"UTF-8 is not among the encodings: %@", encodings);
	for (int format = 0; format < 2; format++)
		for (int names = 0; names < 2; names++)
			for (int comments = 0; comments < 2; comments++)
				for (int encoding = 0; encoding < 2; encoding++) {
					NSString *what = [NSString stringWithFormat:@"format %@, lesson names %i, comments %i, encoding %@", [formats itemTitleAtIndex:format], names, comments, encodings[encoding ? utf8 : 0]];
					[defaults setInteger:format forKey:PVExportFormat];
					[defaults setBool:names forKey:PVExportPageNames];
					[defaults setBool:comments forKey:PVExportComments];
					[mDocument setValue:@(encoding ? utf8 : 0) forKey:@"stringEncodingIndex"];
					NSString *path = [self temporaryPath:[NSString stringWithFormat:@"export-%i%i%i%i.%@", format, names, comments, encoding, format == 1 ? @"csv" : @"txt"]];
					[mDocument exportPanelDidEnd:(NSSavePanel *)[PVChosenFile fileWithPath:path] returnCode:NSModalResponseOK contextInfo:NULL];
					XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:path], @"nothing exported (%@)", what);
					if (encoding == 1) {
						NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
						XCTAssertTrue([text rangeOfString:@"日本語"].location != NSNotFound && [text rangeOfString:@"garçon"].location != NSNotFound, @"the file is not UTF-8 (%@)", what);
						if (format == 0)
							XCTAssertEqual([text rangeOfString:@"# Leçon d'été"].location != NSNotFound, (BOOL)names, @"lesson names (%@)", what);
					}

					ProVocDocument *imported = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
					NSUInteger lessons = [[imported allPages] count];
					[imported importWordsFromFiles:@[path]];
					// (values separated by commas with the lesson names but without the comments have
					// three columns, which are read back as word, translation and comment)
					BOOL namesAsComments = format == 1 && names && !comments;
					NSMutableArray *expectedTexts = [NSMutableArray array];
					for (NSUInteger index = 0; index < [expected count]; index++) {
						NSArray *texts = expected[index];
						[expectedTexts addObject:@[texts[0], texts[1], comments ? texts[2] : namesAsComments ? (index < 4 ? @"Lesson 1" : @"Leçon d'été") : @""]];
					}
					XCTAssertEqualObjects([self wordTextsOf:imported], expectedTexts, @"words exported and imported again (%@)", what);
					// with their names, the two lessons come back as two lessons
					XCTAssertEqual([[imported allPages] count] - lessons, names && !namesAsComments ? 2u : 1u, @"lessons imported (%@)", what);
					if (names && !namesAsComments)
						XCTAssertEqualObjects([[[imported allPages] lastObject] title], @"Leçon d'été", @"name of the imported lesson (%@)", what);
					PVCloseDocument(imported);
				}

	// a text file made elsewhere, in UTF-8 as text files are today, with the automatic encoding
	[mDocument setValue:@0 forKey:@"stringEncodingIndex"];
	NSString *path = [self temporaryPath:@"elsewhere.txt"];
	[@"# Vêtements\nshirt\tchemise\nhat\tchapeau\tsur la tête\n\n# Été\nsea\tmer\n" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	ProVocDocument *imported = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
	[imported importWordsFromFiles:@[path]];
	XCTAssertEqualObjects([self wordTextsOf:imported], (@[@[@"shirt", @"chemise", @""], @[@"hat", @"chapeau", @"sur la tête"], @[@"sea", @"mer", @""]]));
	XCTAssertEqualObjects([[[imported allPages] valueForKey:@"title"] subarrayWithRange:NSMakeRange([[imported allPages] count] - 2, 2)], (@[@"Vêtements", @"Été"]));
	PVCloseDocument(imported);

	// another ProVoc document: its lessons and words (with their comments) are added
	imported = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
	NSString *deck = PVTemporaryCopyOfDeck([PVTestSourceRoot() stringByAppendingPathComponent:@"fixtures/generated/Rich.pvoc"]);
	[imported importWordsFromFiles:@[deck]];
	XCTAssertEqual([[imported allWords] count], 10u, @"words imported from a ProVoc document");
	XCTAssertTrue([[[imported allWords] valueForKey:@"comment"] containsObject:@"a season; masculine"]);
	PVCloseDocument(imported);
}

#pragma mark Printing

-(NSString *)textOfPDFPrintedFromView:(NSView *)inView name:(NSString *)inName pages:(NSUInteger *)outPages
{
	NSString *path = [self temporaryPath:inName];
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	NSPrintInfo *info = [[[mDocument printInfo] copy] autorelease];
	[info setJobDisposition:NSPrintSaveJob];
	[[info dictionary] setObject:[NSURL fileURLWithPath:path] forKey:NSPrintJobSavingURL];
	NSPrintOperation *operation = [NSPrintOperation printOperationWithView:inView printInfo:info];
	[operation setShowsPrintPanel:NO];
	[operation setShowsProgressPanel:NO];
	XCTAssertTrue([operation runOperation], @"printing %@ failed", inName);
	PDFDocument *pdf = [[[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]] autorelease];
	if (outPages)
		*outPages = [pdf pageCount];
	[[NSFileManager defaultManager] copyItemAtPath:path toPath:[[PVTestSourceRoot() stringByAppendingPathComponent:@"verification/screenshots"] stringByAppendingPathComponent:[@"printed-" stringByAppendingString:inName]] error:NULL];
	return [pdf string];
}

// Command-P shows the print panel (Esc cancels), Shift-Command-P the page setup,
// Option-Command-P the card options (Return = Print, Esc = Cancel). What gets printed
// is checked in PDF files made with the same views: the words are in them.
-(void)testPrintPageSetupAndCards
{
	NSWindow *(^sheet)(void) = ^{ return [[mDocument window] attachedSheet]; };
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"p", 0); }];
	// (the options of ProVoc - comments, page numbers, size of the text - come with the panel)
	[script wait:@"the print panel (Command-P) with the options of ProVoc" timeout:20 until:^BOOL { return sheet() != nil && [[mDocument valueForKey:@"mPrintAccessoryView"] window] != nil; }];
	[script then:^{
		XCTAssertEqual([[mDocument valueForKey:@"mPrintAccessoryView"] window], sheet(), @"the options of ProVoc are not in the print panel");
		XCTAssertNotNil([self viewIn:[mDocument valueForKey:@"mPrintAccessoryView"] withBinding:NSValueBinding to:@"values.printComments"]);
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"Esc to cancel the printing" timeout:15 until:^BOOL { return sheet() == nil; }];
	[script then:^{ PVTypeCommand(@"p", NSEventModifierFlagShift); }];
	[script wait:@"the page setup (Shift-Command-P)" timeout:15 until:^BOOL { return sheet() != nil; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"Esc to cancel the page setup" timeout:15 until:^BOOL { return sheet() == nil; }];
	// the cards
	[script then:^{ PVTypeCommand(@"p", NSEventModifierFlagOption); }];
	[script wait:@"the card options (Option-Command-P)" timeout:15 until:^BOOL { return [[NSApp modalWindow] isKeyWindow]; }];
	[script then:^{
		PVSaveWindowScreenshot([NSApp modalWindow], @"windows/print-cards-options");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[script wait:@"Esc to cancel the cards" until:^BOOL { return [NSApp modalWindow] == nil && sheet() == nil; }];
	[script pause:0.3];
	[script then:^{ XCTAssertNil(sheet(), @"Esc in the card options printed all the same"); PVTypeCommand(@"p", NSEventModifierFlagOption); }];
	[script wait:@"the card options again" timeout:15 until:^BOOL { return [[NSApp modalWindow] isKeyWindow]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"Return to go on to the print panel" timeout:20 until:^BOOL { return [NSApp modalWindow] == nil && sheet() != nil; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[script wait:@"Esc to cancel the printing" timeout:15 until:^BOOL { return sheet() == nil; }];
	[self runScript:script];

	NSUInteger pages = 0;
	// without and with the comments (an option of the print panel)
	NSString *text = [self textOfPDFPrintedFromView:[[[ProVocPrintView alloc] initWithDocument:mDocument] autorelease] name:@"list.pdf" pages:&pages];
	XCTAssertTrue(pages >= 1, @"the printed list is empty");
	for (NSString *word in @[@"Lesson 1", @"house", @"maison", @"été", @"chien"])
		XCTAssertTrue([text rangeOfString:word].location != NSNotFound, @"%@ is not in the printed list: %@", word, text);
	XCTAssertTrue([text rangeOfString:@"a building"].location == NSNotFound, @"the comments are printed although the option is off");
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:ProVocPrintComments];
	text = [self textOfPDFPrintedFromView:[[[ProVocPrintView alloc] initWithDocument:mDocument] autorelease] name:@"list-with-comments.pdf" pages:&pages];
	for (NSString *word in @[@"house", @"maison", @"a building", @"an animal"])
		XCTAssertTrue([text rangeOfString:word].location != NSNotFound, @"%@ is not in the list printed with comments: %@", word, text);
	text = [self textOfPDFPrintedFromView:[[[ProVocCardsView alloc] initWithDocument:mDocument words:[mDocument valueForKey:@"mSortedWords"]] autorelease] name:@"cards.pdf" pages:&pages];
	XCTAssertTrue(pages >= 1, @"the printed cards are empty");
	for (NSString *word in @[@"house", @"maison", @"été", @"chien"])
		XCTAssertTrue([text rangeOfString:word].location != NSNotFound, @"%@ is not on the printed cards: %@", word, text);
}

#pragma mark Edit menu

// Reveal Selected Words in Lessons, the three swaps, Reset Difficulty and Last Answered.
-(void)testRevealSwapAndReset
{
	PVAddPage(mDocument, @"Lesson 2", @[@[@"bird", @"oiseau", @"flies"]]);
	NSOutlineView *outline = [mDocument valueForKey:@"mPageOutlineView"];
	ProVocWord *(^word)(NSString *) = ^(NSString *source) { return [self wordWithSource:source]; };
	PVScript *script = [PVScript script];
	// all lessons, a search that finds one word of the second lesson
	[script then:^{
		[outline selectAll:nil];
		[mDocument selectedPagesDidChange];
		PVTypeCommand(@"f", 0);
	}];
	[script wait:@"the search field" until:^BOOL { return [[mDocument valueForKey:@"mSearchField"] currentEditor] != nil; }];
	[script then:^{ PVTypeText(@"bird"); }];
	[script wait:@"the word found" until:^BOOL { return [[self listedSources] isEqualToArray:@[@"bird"]]; }];
	[script then:^{
		[self selectRows:[NSIndexSet indexSetWithIndex:0]];
		[self chooseMenuItemWithAction:@selector(revealSelectedWordsInPages:) tag:0];
	}];
	[script wait:@"the lesson of the word to be the only one selected, the word selected in it" until:^BOOL {
		NSArray *pages = [mDocument selectedPages];
		NSArray *selected = [mDocument selectedWords];
		return [pages count] == 1 && [[(ProVocPage *)pages[0] title] isEqualToString:@"Lesson 2"] && [[self listedSources] isEqualToArray:@[@"bird"]]
			&& [[[mDocument valueForKey:@"mSearchField"] stringValue] length] == 0 && [selected count] == 1 && [[selected[0] sourceWord] isEqualToString:@"bird"];
	}];
	// swaps of the selected word
	[script then:^{ [self chooseMenuItemWithAction:@selector(swapSourceAndTarget:) tag:0]; }];
	[script wait:@"source and target swapped" until:^BOOL { return [[word(@"oiseau") targetWord] isEqualToString:@"bird"]; }];
	[script then:^{ [self chooseMenuItemWithAction:@selector(swapSourceAndTarget:) tag:1]; }];
	[script wait:@"source and comment swapped" until:^BOOL { return [[word(@"flies") comment] isEqualToString:@"oiseau"] && [[word(@"flies") targetWord] isEqualToString:@"bird"]; }];
	[script then:^{ [self chooseMenuItemWithAction:@selector(swapSourceAndTarget:) tag:2]; }];
	[script wait:@"target and comment swapped" until:^BOOL { return [[word(@"flies") comment] isEqualToString:@"bird"] && [[word(@"flies") targetWord] isEqualToString:@"oiseau"]; }];
	// difficulty and date of the last answer, then reset
	[script then:^{
		ProVocWord *flies = word(@"flies");
		[flies incrementRight];
		[flies incrementWrong];
		[flies increaseDifficulty];
		XCTAssertNotNil([flies lastAnswered]);
		[self chooseMenuItemWithAction:@selector(resetDifficulty:) tag:0];
	}];
	[script wait:@"the statistics of the word to be reset" until:^BOOL {
		ProVocWord *flies = word(@"flies");
		return [flies right] == 0 && [flies wrong] == 0 && [flies difficulty] == 0 && [flies lastAnswered] == nil;
	}];
	[self runScript:script];
}

#pragma mark History

// Each training adds a bar to the History view; Clear History empties it.
-(void)testHistoryViewAndClearHistory
{
	NSView *historyView = [mDocument valueForKey:@"mHistoryView"];
	NSButton *(^clearButton)(void) = ^{ return [self buttonWithAction:@selector(clearHistory:) inView:[[mDocument window] contentView]]; };
	PVScript *script = [PVScript script];
	// two trainings: all right, then one wrong
	for (int training = 0; training < 2; training++) {
		[script then:^{ [mDocument setValue:@1 forKey:@"numberOfRetries"]; PVTypeCommand(@"r", 0); }];
		for (int number = 1; number <= 4; number++) {
			[script wait:[NSString stringWithFormat:@"question %i", number] until:^BOOL { return [self showsQuestionNumber:number]; }];
			if (training == 1 && number == 2) {
				[script then:^{ PVTypeText(@"xyz"); PVPostKey(PVKeyReturn, nil, 0); }];
				[script wait:@"the solution" until:^BOOL { return [self showsSolution]; }];
				[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
			} else
				[self answerCorrectlyIn:script];
		}
		[script wait:@"the result panel" until:^BOOL { return [[self resultPanel] isVisible]; }];
		[script then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
		[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	}
	[script then:^{ PVTypeCommand(@"3", NSEventModifierFlagOption); }];
	[script wait:@"the History view (Option-Command-3)" until:^BOOL { return [[mDocument valueForKey:@"mainTab"] intValue] == 2 && [historyView window] == [mDocument window] && ![historyView isHiddenOrHasHiddenAncestor]; }];
	[script then:^{
		XCTAssertEqual([mDocument numberOfHistories], 2);
		ProVocHistory *first = [mDocument historyAtIndex:0], *second = [mDocument historyAtIndex:1];
		XCTAssertEqual([first total], 4);
		XCTAssertEqual([first numberOfRepetition:0], 4, @"first training: 4 right at once");
		XCTAssertEqual([second numberOfRepetition:0], 3, @"second training: 3 right at once");
		XCTAssertEqual([second numberOfRepetition:1], 1, @"second training: 1 wrong once");
		// the chart is drawn: its colored bars
		NSBitmapImageRep *shot = PVSaveWindowScreenshot([mDocument window], @"windows/document-history-with-trainings");
		XCTAssertTrue(PVNumberOfDistinctColors(shot) >= 4, @"the history chart looks empty");
		XCTAssertNotNil(clearButton(), @"no Clear History button");
		XCTAssertTrue([clearButton() isEnabled]);
		PVClickView(clearButton(), 1, 0);
	}];
	[script wait:@"Clear History to empty the history" until:^BOOL { return [mDocument numberOfHistories] == 0; }];
	[script then:^{ XCTAssertFalse([clearButton() isEnabled], @"Clear History stays enabled without history"); }];
	[self runScript:script];
}

#pragma mark Languages and columns

// The language pop-ups of the document name its two languages everywhere; the columns
// for the difficulty, the flag and the dates show what the words have.
-(void)testLanguagePopUpsAndColumns
{
	NSTableView *table = [self wordTable];
	NSPopUpButton *sourcePopUp = [mDocument valueForKey:@"mSourceLanguagePopUp"], *targetPopUp = [mDocument valueForKey:@"mTargetLanguagePopUp"];
	NSString *(^item)(NSString *) = ^(NSString *language) { return [NSString stringWithFormat:NSLocalizedString(@"Language PopUp Item Format (%@)", @""), language]; };
	XCTAssertTrue([sourcePopUp numberOfItems] >= 4, @"languages offered: %@", [sourcePopUp itemTitles]);
	NSArray *languages = [[mDocument class] performSelector:@selector(languageNames)];
	XCTAssertTrue([languages count] >= 2, @"%@", languages);
	NSString *first = languages[0], *second = languages[1];
	[[sourcePopUp menu] performActionForItemAtIndex:[sourcePopUp indexOfItemWithTitle:item(second)]];
	[[targetPopUp menu] performActionForItemAtIndex:[targetPopUp indexOfItemWithTitle:item(first)]];
	XCTAssertEqualObjects([mDocument sourceLanguage], second);
	XCTAssertEqualObjects([mDocument targetLanguage], first);
	XCTAssertEqualObjects([[[table tableColumnWithIdentifier:@"Source"] headerCell] stringValue], second, @"header of the source column");
	XCTAssertEqualObjects([[[table tableColumnWithIdentifier:@"Target"] headerCell] stringValue], first, @"header of the target column");
	XCTAssertEqualObjects([sourcePopUp titleOfSelectedItem], item(second));
	// "Other..." opens the Languages preferences
	[[sourcePopUp menu] performActionForItemAtIndex:[sourcePopUp numberOfItems] - 1];
	NSWindow *preferences = [[ProVocPreferences sharedPreferences] window];
	XCTAssertTrue(PVWaitUntil(5, ^BOOL { return [preferences isVisible]; }), @"the last item of the language pop-up should open the Languages preferences");
	[preferences orderOut:nil];
	XCTAssertEqualObjects([mDocument sourceLanguage], second, @"choosing Other changed the language");

	// columns: difficulty (a level), flag (an image), last answered and next review (dates)
	ProVocWord *house = [self wordWithSource:@"house"], *cat = [self wordWithSource:@"cat"];
	[house setMark:1];
	[house incrementRight];
	for (int i = 0; i < 3; i++)
		[cat increaseDifficulty];
	[mDocument performSelector:@selector(updateDifficultyLimits)];
	[table reloadData];
	id <NSTableViewDataSource> source = (id <NSTableViewDataSource>)mDocument;
	NSUInteger houseRow = [[self listedSources] indexOfObject:@"house"], catRow = [[self listedSources] indexOfObject:@"cat"];
	for (NSString *identifier in @[@"Difficulty", @"Mark", @"LastAnswered", @"NextReview"]) {
		[mDocument makeColumnWithIdentifier:identifier visible:YES];
		XCTAssertNotNil([table tableColumnWithIdentifier:identifier], @"no %@ column", identifier);
	}
	XCTAssertTrue([[source tableView:table objectValueForTableColumn:[table tableColumnWithIdentifier:@"Difficulty"] row:catRow] floatValue] > [[source tableView:table objectValueForTableColumn:[table tableColumnWithIdentifier:@"Difficulty"] row:houseRow] floatValue], @"the difficulty column");
	XCTAssertTrue([[source tableView:table objectValueForTableColumn:[table tableColumnWithIdentifier:@"Mark"] row:houseRow] isKindOfClass:[NSImage class]], @"the flag column shows no flag");
	XCTAssertFalse([[source tableView:table objectValueForTableColumn:[table tableColumnWithIdentifier:@"Mark"] row:catRow] isKindOfClass:[NSImage class]], @"the flag column shows a flag for a word without");
	XCTAssertTrue([[[source tableView:table objectValueForTableColumn:[table tableColumnWithIdentifier:@"LastAnswered"] row:houseRow] description] length] > 0, @"the last answered column is empty for a word just answered");
	XCTAssertEqual([[[source tableView:table objectValueForTableColumn:[table tableColumnWithIdentifier:@"LastAnswered"] row:catRow] description] length], 0u, @"the last answered column should be empty for a word never answered");
	PVSaveWindowScreenshot([mDocument window], @"windows/document-all-columns");
}

@end
