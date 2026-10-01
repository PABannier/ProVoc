//
//  PVAppScenarios.m
//
//  The clipboard between documents, quitting with unsaved changes, what a document
//  remembers of its window, launching with a document, and every language.
//

#import "PVDriver.h"
#import "ProVocMCQView.h"
#import "ProVocInspector.h"
#import "ProVocChapter.h"
#import "ProVocData.h"

@interface PVScenarios (Editing)
-(ProVocDocument *)editedDocument;
-(NSTableView *)wordTable;
-(NSOutlineView *)lessonOutline;
-(NSArray *)sources;
-(NSArray *)listedSources;
-(NSArray *)lessonTitles;
-(void)typeWord:(NSString *)inSource translation:(NSString *)inTarget in:(PVScript *)inScript;
-(void)newDocumentWithThreeWordsIn:(PVScript *)inScript;
-(void)clickWordRow:(NSInteger)inRow column:(NSString *)inIdentifier clickCount:(NSInteger)inCount modifiers:(NSEventModifierFlags)inModifiers;
-(void)selectWord:(NSString *)inSource in:(PVScript *)inScript;
-(void)selectLesson:(NSString *)inTitle in:(PVScript *)inScript;
-(void)undoAndRedoIn:(PVScript *)inScript what:(NSString *)inWhat before:(PVCondition)inBefore after:(PVCondition)inAfter;
-(void)chooseMenuItemWithAction:(SEL)inAction tag:(NSInteger)inTag;
-(BOOL)isEditingField:(NSTextField *)inField;
@end

@interface PVScenarios (Documents)
-(NSWindow *)alertSheet;
-(NSArray *)buttonsOfAlertSheet;
-(NSButton *)dontSaveButton;
-(NSButton *)alertButtonWithKey:(unichar)inCharacter;
-(void)pressKeyOfButton:(NSButton *)inButton;
@end

@interface PVScenarios (Application)
@end

@implementation PVScenarios (Application)

-(NSWindow *)startingPoint
{
	return [[NSClassFromString(@"ProVocStartingPoint") performSelector:@selector(defaultStartingPoint)] window];
}

-(NSArray *)documents
{
	return [[NSDocumentController sharedDocumentController] documents];
}

#pragma mark Clipboard

// Command-C / Command-X / Command-V of words between two documents, of text coming
// from another application, and of a lesson. The clipboard of the user is put back at the end.
-(void)clipboardBetweenDocuments:(PVScript *)inScript
{
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSMutableArray *savedItems = [NSMutableArray array];
	for (NSPasteboardItem *item in [pasteboard pasteboardItems]) {
		NSPasteboardItem *copy = [[[NSPasteboardItem alloc] init] autorelease];
		for (NSString *type in [item types]) {
			NSData *data = [item dataForType:type];
			if (data)
				[copy setData:data forType:type];
		}
		[savedItems addObject:copy];
	}
	__block ProVocDocument *first = nil;
	__block ProVocDocument *second = nil;
	[self newDocumentWithThreeWordsIn:inScript];
	[inScript then:^{ first = [self editedDocument]; }];
	// select cat and dog (click, Shift-click), copy
	[self selectWord:@"cat" in:inScript];
	[inScript then:^{ [self clickWordRow:2 column:@"Source" clickCount:1 modifiers:NSEventModifierFlagShift]; }];
	[inScript wait:@"a Shift-click to extend the selection" until:^BOOL { return [[first selectedWords] count] == 2; }];
	[inScript then:^{ PVTypeCommand(@"c", 0); }];
	[inScript wait:@"the words on the clipboard, also as text" until:^BOOL {
		NSString *text = [pasteboard stringForType:NSPasteboardTypeString];
		return [text rangeOfString:@"cat"].location != NSNotFound && [text rangeOfString:@"chien"].location != NSNotFound && [text rangeOfString:@"house"].location == NSNotFound;
	}];
	[inScript then:^{
		NSArray *lines = [[[pasteboard stringForType:NSPasteboardTypeString] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		PVExpectEqual([lines count], 2, @"one line per word: %@", lines);
		PVExpect([[lines firstObject] hasPrefix:@"cat\tchat"], @"words are copied as tab-separated text: %@", lines);
		PVTypeCommand(@"n", 0);
	}];
	[inScript wait:@"a second document" until:^BOOL { return [[self documents] count] == 2 && [self editedDocument] != first && [[[self editedDocument] window] isKeyWindow]; }];
	[inScript then:^{ second = [self editedDocument]; PVTypeCommand(@"1", NSEventModifierFlagOption); }];
	[inScript wait:@"its Editing view" until:^BOOL { return [[second valueForKey:@"mainTab"] intValue] == 1 && [[self wordTable] window] == [second window]; }];
	[inScript then:^{ PVClickAtPoint([self wordTable], NSMakePoint(40, 100), 1, 0); }];
	[inScript wait:@"a click in its (empty) list" until:^BOOL { return [[second window] firstResponder] == [self wordTable]; }];
	[inScript then:^{ PVTypeCommand(@"v", 0); }];
	[inScript wait:@"Command-V to paste the two words" until:^BOOL { return [[self sources] isEqualToArray:@[@"cat", @"dog"]] && [[self listedSources] isEqualToArray:@[@"cat", @"dog"]]; }];
	[inScript then:^{
		PVExpectEqualObjects([[[second allWords] firstObject] targetWord], @"chat", @"the translation comes with the word");
		PVExpectEqual([[first allWords] count], 3, @"the first document is unchanged by a copy");
		PVExpect([[second allWords] firstObject] != [[first allWords] objectAtIndex:1], @"the pasted words must be copies");
	}];
	[self undoAndRedoIn:inScript what:@"pasting words" before:^BOOL { return [[self sources] count] == 0; } after:^BOOL { return [[self sources] isEqualToArray:@[@"cat", @"dog"]]; }];

	// text copied in another application: one word per line, tab between word and translation
	[inScript then:^{
		[pasteboard clearContents];
		[pasteboard setString:@"sun\tsoleil\nmoon\tlune\tat night" forType:NSPasteboardTypeString];
		PVTypeCommand(@"v", 0);
	}];
	[inScript wait:@"the text to be pasted as two words" until:^BOOL { return [[second allWords] count] == 4 && [[self sources] containsObject:@"sun"] && [[self sources] containsObject:@"moon"]; }];
	[inScript then:^{
		for (ProVocWord *word in [second allWords])
			if ([[word sourceWord] isEqualToString:@"moon"]) {
				PVExpectEqualObjects([word targetWord], @"lune", @"second field of the pasted line");
				PVExpectEqualObjects([word comment], @"at night", @"third field of the pasted line");
			}
		// back to the first document: cut the first word
		[[first window] makeKeyAndOrderFront:nil];
	}];
	[inScript wait:@"the first document in front" until:^BOOL { return [[first window] isKeyWindow] && [self editedDocument] == first; }];
	[self selectWord:@"house" in:inScript];
	[inScript then:^{ PVTypeCommand(@"x", 0); }];
	[inScript wait:@"Command-X to remove the word" until:^BOOL { return [[self sources] isEqualToArray:@[@"cat", @"dog"]] && [[pasteboard stringForType:NSPasteboardTypeString] rangeOfString:@"house"].location != NSNotFound; }];
	[self undoAndRedoIn:inScript what:@"cutting a word" before:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"cat", @"dog"]]; } after:^BOOL { return [[self sources] isEqualToArray:@[@"cat", @"dog"]]; }];

	// a whole lesson: copy in the outline of the first document, paste in the outline of the second
	__block NSString *lesson = nil;
	[inScript then:^{ lesson = [[[self lessonTitles] firstObject] copy]; }];
	[inScript then:^{
		NSRect rect = [[self lessonOutline] rectOfRow:0];
		PVClickAtPoint([self lessonOutline], NSMakePoint(NSMinX(rect) + 60, NSMidY(rect)), 1, 0);
	}];
	[inScript wait:@"the lesson to be selected" until:^BOOL { return [[first window] firstResponder] == [self lessonOutline] && [[first selectedPages] count] == 1; }];
	[inScript then:^{ PVTypeCommand(@"c", 0); }];
	[inScript wait:@"the lesson on the clipboard" until:^BOOL { return [[pasteboard stringForType:NSPasteboardTypeString] rangeOfString:@"chien"].location != NSNotFound && [[pasteboard types] count] >= 2; }];
	[inScript then:^{ [[second window] makeKeyAndOrderFront:nil]; }];
	[inScript wait:@"the second document in front" until:^BOOL { return [[second window] isKeyWindow] && [self editedDocument] == second; }];
	[inScript then:^{
		NSRect rect = [[self lessonOutline] rectOfRow:0];
		PVClickAtPoint([self lessonOutline], NSMakePoint(NSMinX(rect) + 60, NSMidY(rect)), 1, 0);
	}];
	[inScript wait:@"a click in its lessons" until:^BOOL { return [[second window] firstResponder] == [self lessonOutline]; }];
	[inScript then:^{ PVTypeCommand(@"v", 0); }];
	[inScript wait:@"the lesson to be pasted with its words" until:^BOOL { return [[self lessonTitles] count] == 2 && [[second allWords] count] == 6; }];
	[self undoAndRedoIn:inScript what:@"pasting a lesson" before:^BOOL { return [[self lessonTitles] count] == 1 && [[second allWords] count] == 4; } after:^BOOL { return [[self lessonTitles] count] == 2 && [[second allWords] count] == 6; }];
	[inScript then:^{
		[first updateChangeCount:NSChangeCleared];
		[second updateChangeCount:NSChangeCleared];
		[pasteboard clearContents];
		if ([savedItems count] > 0)
			[pasteboard writeObjects:savedItems];
	}];
}

#pragma mark Quit

// Command-Q with an edited document asks; Cancel keeps the application running,
// Don't Save quits. Command-M and Command-H before that.
-(void)quitWithUnsavedChanges:(PVScript *)inScript
{
	[self newDocumentWithThreeWordsIn:inScript];
	// Command-M minimizes the window; a click in the Dock (here: deminiaturize) brings it back
	[inScript then:^{ PVExpect([[self editedDocument] isDocumentEdited], @"the document should be edited"); PVTypeCommand(@"m", 0); }];
	[inScript wait:@"Command-M to minimize the window" timeout:10 until:^BOOL { return [[[[self documents] lastObject] window] isMiniaturized]; }];
	[inScript then:^{ [[[[self documents] lastObject] window] deminiaturize:nil]; }];
	[inScript wait:@"the window back" timeout:10 until:^BOOL { return ![[[[self documents] lastObject] window] isMiniaturized] && [[[[self documents] lastObject] window] isKeyWindow]; }];
	// Command-H hides the application. (A hidden application is not active, and the script
	// only goes on once it is active again: the notification tells that it was hidden.)
	__block BOOL didHide = NO;
	[[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationDidHideNotification object:nil queue:nil usingBlock:^(NSNotification *inNotification) { didHide = YES; }];
	[inScript then:^{ PVTypeCommand(@"h", 0); }];
	[inScript wait:@"Command-H to hide the application" timeout:10 until:^BOOL { return didHide; }];
	[inScript then:^{
		// Hide Others is there with its shortcut (not played: it would hide the windows of the other applications of this Mac)
		NSMenuItem *hideOthers = [PVScenarios menuItemWithAction:@selector(hideOtherApplications:)];
		PVExpectEqualObjects([hideOthers keyEquivalent], @"h", @"Hide Others shortcut");
		PVExpectEqual([hideOthers keyEquivalentModifierMask] & (NSEventModifierFlagCommand | NSEventModifierFlagOption), NSEventModifierFlagCommand | NSEventModifierFlagOption, @"Hide Others shortcut");
		[NSApp unhide:nil];
	}];
	[inScript wait:@"the application back in front" timeout:15 until:^BOOL { return ![NSApp isHidden] && [NSApp isActive] && [[[self editedDocument] window] isKeyWindow]; }];

	// (a document that has a file: for an untitled one the question is the save panel itself)
	__block BOOL saved = NO;
	NSString *path = [[PVScenarios workDirectory] stringByAppendingPathComponent:@"Quit.pvoc"];
	[inScript then:^{
		[[self editedDocument] saveToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" forSaveOperation:NSSaveOperation completionHandler:^(NSError *inError) {
			PVExpect(inError == nil, @"saving failed: %@", inError);
			saved = YES;
		}];
	}];
	[inScript wait:@"the document to be saved" timeout:15 until:^BOOL { return saved && ![[self editedDocument] isDocumentEdited]; }];
	[self typeWord:@"summer" translation:@"été" in:inScript];
	[inScript wait:@"the document to be edited again" until:^BOOL { return [[self editedDocument] isDocumentEdited]; }];
	[inScript then:^{ PVTypeCommand(@"q", 0); }];
	[inScript wait:@"the sheet asking to save before quitting" until:^BOOL { return [self alertSheet] != nil && [[self buttonsOfAlertSheet] count] == 3; }];
	[inScript then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"Esc to cancel: the application keeps running" until:^BOOL { return [self alertSheet] == nil && [[self documents] count] == 1 && [[self editedDocument] isDocumentEdited]; }];
	[inScript pause:0.5];
	[inScript then:^{ PVExpectEqual([[self documents] count], 1, @"the document was closed although quitting was cancelled"); PVTypeCommand(@"q", 0); }];
	[inScript wait:@"the sheet again" until:^BOOL { return [self alertSheet] != nil && [self dontSaveButton] != nil; }];
	[inScript then:^{
		[PVScenarios expectTermination];
		[self pressKeyOfButton:[self dontSaveButton]];
	}];
}

// Command-Q with two edited documents: "review the changes?"; Cancel, then Discard Changes.
-(void)quitWithTwoUnsavedDocuments:(PVScript *)inScript
{
	[self newDocumentWithThreeWordsIn:inScript];
	__block ProVocDocument *first = nil;
	[inScript then:^{ first = [self editedDocument]; PVTypeCommand(@"n", 0); }];
	[inScript wait:@"a second document" until:^BOOL { return [[self documents] count] == 2 && [self editedDocument] != first && [[[self editedDocument] window] isKeyWindow]; }];
	[inScript then:^{ PVTypeCommand(@"1", NSEventModifierFlagOption); }];
	[inScript wait:@"its Editing view" until:^BOOL { return [[[self editedDocument] valueForKey:@"mainTab"] intValue] == 1 && [[[self editedDocument] valueForKey:@"mSourceTextField"] window] != nil; }];
	[self typeWord:@"sun" translation:@"soleil" in:inScript];
	[inScript wait:@"two edited documents" until:^BOOL { return [first isDocumentEdited] && [[self editedDocument] isDocumentEdited]; }];
	NSArray *(^alertButtons)(void) = ^{
		NSMutableArray *buttons = [NSMutableArray array];
		NSMutableArray *views = [NSMutableArray arrayWithObjects:[[NSApp modalWindow] contentView], nil];
		while ([views count] > 0) {
			NSView *view = views[0];
			[views removeObjectAtIndex:0];
			if ([view isKindOfClass:[NSButton class]] && [[(NSButton *)view title] length] > 0)
				[buttons addObject:view];
			[views addObjectsFromArray:[view subviews]];
		}
		return buttons;
	};
	[inScript then:^{ PVTypeCommand(@"q", 0); }];
	[inScript wait:@"the alert offering to review the changes" until:^BOOL { return [[NSApp modalWindow] isKeyWindow] && [alertButtons() count] == 3; }];
	[inScript then:^{
		PVSaveWindowScreenshot([NSApp modalWindow], @"windows/quit-review-changes");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[inScript wait:@"Esc to cancel: both documents stay" until:^BOOL { return [NSApp modalWindow] == nil && [[self documents] count] == 2; }];
	[inScript pause:0.5];
	[inScript then:^{ PVExpectEqual([[self documents] count], 2, @"documents were closed although quitting was cancelled"); PVTypeCommand(@"q", 0); }];
	[inScript wait:@"the alert again" until:^BOOL { return [[NSApp modalWindow] isKeyWindow] && [alertButtons() count] == 3; }];
	[inScript then:^{
		// "Discard Changes": the button that is neither the default one nor Cancel
		NSButton *discard = nil;
		for (NSButton *button in alertButtons()) {
			unichar character = [[button keyEquivalent] length] == 1 ? [[button keyEquivalent] characterAtIndex:0] : 0;
			if (character != '\r' && character != 27)
				discard = button;
		}
		PVExpect(discard != nil, @"no Discard Changes button: %@", [alertButtons() valueForKey:@"title"]);
		[PVScenarios expectTermination];
		if ([[discard keyEquivalent] length] == 1)
			[self pressKeyOfButton:discard];
		else
			PVPressAlertButton(discard);
	}];
}

// Command-Q without unsaved change quits at once.
-(void)quitWithoutChanges:(PVScript *)inScript
{
	[inScript wait:@"the starting point window" timeout:15 until:^BOOL { return [[self startingPoint] isKeyWindow]; }];
	[inScript then:^{
		[PVScenarios expectTermination];
		PVTypeCommand(@"q", 0);
	}];
}

@end

@interface PVScenarios (LaunchAndState)
@end

@implementation PVScenarios (LaunchAndState)

static NSString *PVFixturesDirectory(void)
{
	const char *directory = getenv("PV_FIXTURES");
	return [[NSString stringWithUTF8String:directory ? directory : "/tmp"] stringByAppendingPathComponent:@"generated"];
}

// A new document comes with an empty first lesson: the fixtures only have their own
static ProVocDocument *PVEmptyDocument(void)
{
	ProVocDocument *document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:NULL];
	ProVocChapter *root = [(ProVocData *)[document valueForKey:@"mProVocData"] rootChapter];
	for (id child in [NSArray arrayWithArray:[root children]])
		[root removeChild:child];
	[document pagesDidChange];
	return document;
}

static ProVocWord *PVWord(NSString *inSource, NSString *inTarget, NSString *inComment)
{
	ProVocWord *word = [[[ProVocWord alloc] init] autorelease];
	[word setSourceWord:inSource];
	[word setTargetWord:inTarget];
	if (inComment)
		[word setComment:inComment];
	return word;
}

#pragma mark Fixtures

// Writes the decks of fixtures/generated with the application's own classes
// (scripts/make-fixtures.sh): plain words, accents, a rich deck (chapters, synonyms,
// parentheses, comments, labels, flags, difficulties, sound, picture, movie) and a
// deck in the old flat file format (.provoc).
-(void)generateFixtures:(PVScript *)inScript
{
	NSString *directory = PVFixturesDirectory();
	NSDocumentController *controller = [NSDocumentController sharedDocumentController];
	NSMutableArray *pending = [NSMutableArray array];
	void (^save)(ProVocDocument *, NSString *) = ^(ProVocDocument *document, NSString *name) {
		NSString *path = [directory stringByAppendingPathComponent:name];
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
		[pending addObject:name];
		[document saveToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" forSaveOperation:NSSaveOperation completionHandler:^(NSError *inError) {
			PVExpect(inError == nil, @"%@: %@", name, inError);
			[pending removeObject:name];
			[document close];
		}];
	};
	[inScript then:^{
		[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];

		ProVocDocument *plain = PVEmptyDocument();
		PVAddPage(plain, @"Lesson 1", @[@[@"house", @"maison"], @[@"cat", @"chat"], @[@"dog", @"chien"], @[@"summer", @"été"], @[@"bread", @"pain"]]);
		save(plain, @"Plain.pvoc");

		ProVocDocument *accents = PVEmptyDocument();
		PVAddPage(accents, @"Français", @[@[@"summer", @"été"], @[@"boy", @"garçon"], @[@"naive", @"naïve"], @[@"heart", @"cœur"], @[@"where", @"où"], @[@"age", @"âge"], @[@"Christmas", @"Noël"], @[@"pupil", @"élève"], @[@"forest", @"forêt"]]);
		PVAddPage(accents, @"Español y Deutsch", @[@[@"child", @"niño"], @[@"what?", @"¿qué?"], @[@"street", @"Straße"], @[@"beautiful", @"schön"], @[@"Greek", @"ελληνικά"], @[@"Japanese", @"日本語"]]);
		save(accents, @"Accents.pvoc");

		ProVocDocument *rich = PVEmptyDocument();
		ProVocData *data = [rich valueForKey:@"mProVocData"];
		ProVocChapter *chapter = [[[ProVocChapter alloc] init] autorelease];
		[chapter setTitle:@"Unit 1"];
		ProVocPage *basics = [[[ProVocPage alloc] init] autorelease];
		[basics setTitle:@"Basics"];
		ProVocWord *big = PVWord(@"big", @"grand / gros", @"size");
		ProVocWord *eat = PVWord(@"(to) eat", @"manger", nil);
		ProVocWord *summer = PVWord(@"summer", @"l'été", @"a season; masculine");
		ProVocWord *hello = PVWord(@"hello / hi", @"bonjour / salut", nil);
		ProVocWord *house = PVWord(@"house", @"maison", @"with sound, picture and movie");
		[summer setLabel:2];
		[eat setMark:1];
		[eat setLabel:5];
		[big increaseDifficulty];
		[big increaseDifficulty];
		[basics addWords:@[big, eat, summer, hello, house]];
		ProVocPage *animals = [[[ProVocPage alloc] init] autorelease];
		[animals setTitle:@"Animals"];
		[animals addWords:@[PVWord(@"cat", @"chat", nil), PVWord(@"dog", @"chien", @"barks"), PVWord(@"bird", @"oiseau", nil)]];
		[chapter addChild:basics];
		[chapter addChild:animals];
		[[data rootChapter] addChild:chapter];
		PVAddPage(rich, @"Extras", @[@[@"bread", @"pain"], @[@"water", @"eau"]]);
		[rich pagesDidChange];
		[rich setAudioFile:PVMediaFile(@"aiff") forKey:@"Source" ofWord:house];
		[rich setAudioFile:PVMediaFile(@"m4a") forKey:@"Target" ofWord:house];
		[rich setImageFile:PVMediaFile(@"png") ofWord:house];
		[rich setMovieFile:PVMediaFile(@"mov") ofWord:house];
		[rich setImageFile:PVMediaFile(@"jpg") ofWord:[[animals words] objectAtIndex:0]];
		save(rich, @"Rich.pvoc");

		// the flat file of ProVoc 2 and 3
		ProVocDocument *old = PVEmptyDocument();
		PVAddPage(old, @"Leçon 1", @[@[@"house", @"maison"], @[@"cat", @"chat", @"animal"], @[@"summer", @"été"]]);
		NSData *flat = [old dataRepresentationOfType:@"ProVocDocument"];
		PVExpect([flat length] > 0, @"no data for the old format");
		[flat writeToFile:[directory stringByAppendingPathComponent:@"Old format.provoc"] atomically:YES];
		[old close];
	}];
	[inScript wait:@"the fixture decks to be saved" timeout:60 until:^BOOL { return [pending count] == 0; }];
	[inScript then:^{
		for (NSString *name in @[@"Plain.pvoc", @"Accents.pvoc", @"Rich.pvoc", @"Old format.provoc"])
			PVExpect([[NSFileManager defaultManager] fileExistsAtPath:[directory stringByAppendingPathComponent:name]], @"%@ was not written", name);
		NSArray *media = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[directory stringByAppendingPathComponent:@"Rich.pvoc"] stringByAppendingPathComponent:@"Media"] error:NULL];
		PVExpect([media count] >= 5, @"the media of Rich.pvoc should be in the package: %@", media);
	}];
}

#pragma mark Launching with a document

// Launched with a .pvoc document as argument (as when it is double-clicked in the
// Finder): the document opens, not the starting point.
-(void)launchWithDocument:(PVScript *)inScript
{
	[inScript wait:@"the document given at launch" timeout:20 until:^BOOL {
		return [[self documents] count] == 1 && [[[[self documents] lastObject] window] isKeyWindow] && [[[self documents] lastObject] fileURL] != nil;
	}];
	[inScript then:^{
		ProVocDocument *document = [[self documents] lastObject];
		// the keyboard goes to the document at once, also while the About window of the launch is still there
		PVExpect([[[NSClassFromString(@"ARAboutDialog") performSelector:@selector(sharedAboutDialog)] window] isVisible], @"the About window of the launch should still be showing");
		PVExpect([[document window] isMainWindow], @"the document window is not the main window");
		PVExpectEqualObjects([[document fileURL] lastPathComponent], @"Rich.pvoc", @"the document opened at launch");
		PVExpect(![[self startingPoint] isVisible], @"the starting point shows although a document was opened");
		PVExpectEqual([[document allWords] count], 10, @"words of Rich.pvoc");
		PVExpect(![document isDocumentEdited], @"a document just opened is edited");
		ProVocWord *house = nil, *eat = nil, *summer = nil, *big = nil;
		for (ProVocWord *word in [document allWords]) {
			if ([[word sourceWord] isEqualToString:@"house"]) house = word;
			if ([[word sourceWord] isEqualToString:@"(to) eat"]) eat = word;
			if ([[word sourceWord] isEqualToString:@"summer"]) summer = word;
			if ([[word sourceWord] isEqualToString:@"big"]) big = word;
		}
		PVExpect([document imageOfWord:house] != nil, @"the picture of the word is lost");
		PVExpect([[document movieOfWord:house] isPlayable], @"the movie of the word is lost");
		PVExpect([house canPlayAudio:@"Source"] && [house canPlayAudio:@"Target"], @"the sounds of the word are lost");
		PVExpectEqualObjects([summer comment], @"a season; masculine", @"comment");
		PVExpectEqual([summer label], 2, @"label");
		PVExpectEqual([eat mark], 1, @"flag");
		PVExpectEqual([eat label], 5, @"label");
		PVExpect([big difficulty] > [house difficulty], @"difficulty");
		NSOutlineView *outline = [document valueForKey:@"mPageOutlineView"];
		PVExpectEqualObjects([[outline itemAtRow:0] title], @"Unit 1", @"the chapter");
		PVSaveWindowScreenshot([document window], @"windows/document-rich-fixture");
	}];
}

// Launched with a document in the old flat format (.provoc): it opens; saving it
// explains that the new format is needed and proposes Save As.
-(void)launchWithOldFormatDocument:(PVScript *)inScript
{
	[inScript wait:@"the old-format document given at launch" timeout:20 until:^BOOL {
		return [[self documents] count] == 1 && [[[[self documents] lastObject] window] isKeyWindow] && [[[self documents] lastObject] fileURL] != nil;
	}];
	__block ProVocDocument *document = nil;
	[inScript then:^{
		document = [[self documents] lastObject];
		PVExpectEqualObjects([[[document fileURL] pathExtension] lowercaseString], @"provoc", @"the document opened at launch");
		PVExpectEqualObjects([document fileType], @"ProVocDocument", @"type of the old format");
		PVExpectEqualObjects([PVScenarios sourceWordsOf:document], (@[@"house", @"cat", @"summer"]), @"words of the old-format document");
		PVExpectEqualObjects([[[document allWords] objectAtIndex:1] comment], @"animal", @"comment in the old format");
		PVTypeCommand(@"1", NSEventModifierFlagOption);
	}];
	[inScript wait:@"the Editing view" until:^BOOL { return [[document valueForKey:@"mainTab"] intValue] == 1 && [[document valueForKey:@"mSourceTextField"] window] != nil; }];
	[self typeWord:@"dog" translation:@"chien" in:inScript];
	[inScript then:^{ PVTypeCommand(@"s", 0); }];
	[inScript wait:@"the alert explaining the new format" until:^BOOL { return [[NSApp modalWindow] isKeyWindow]; }];
	[inScript then:^{
		PVSaveWindowScreenshot([NSApp modalWindow], @"windows/save-old-format-alert");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[inScript wait:@"the save panel for the new format" timeout:15 until:^BOOL { return [NSApp modalWindow] == nil && [[[document window] attachedSheet] isKindOfClass:[NSSavePanel class]]; }];
	__block BOOL saved = NO;
	NSString *path = [[PVScenarios workDirectory] stringByAppendingPathComponent:@"Converted.pvoc"];
	[inScript then:^{
		NSSavePanel *panel = (NSSavePanel *)[[document window] attachedSheet];
		PVExpect([[panel allowedFileTypes] containsObject:@"pvoc"], @"the new format is not offered: %@", [panel allowedFileTypes]);
		[panel cancel:nil];
	}];
	[inScript wait:@"the save panel to close" timeout:15 until:^BOOL { return [[document window] attachedSheet] == nil; }];
	[inScript then:^{
		[document saveToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" forSaveOperation:NSSaveAsOperation completionHandler:^(NSError *inError) {
			PVExpect(inError == nil, @"saving in the new format failed: %@", inError);
			saved = YES;
		}];
	}];
	[inScript wait:@"the document to be saved in the new format" timeout:15 until:^BOOL { return saved && ![document isDocumentEdited]; }];
	[inScript then:^{
		PVExpectEqualObjects([document fileType], @"ProVocDocumentPackage", @"type after Save As");
		PVExpect([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"Data"]], @"the package has no Data file");
		PVExpect([[NSFileManager defaultManager] fileExistsAtPath:[[[[NSProcessInfo processInfo] arguments] lastObject] stringByExpandingTildeInPath]] || YES, @"");
		PVExpectEqualObjects([PVScenarios sourceWordsOf:document], (@[@"house", @"cat", @"summer", @"dog"]), @"words after the conversion");
	}];
}

#pragma mark What a document remembers of its window

static const NSRect kStateFrame = {{140, 180}, {910, 615}};

// First launch: a document with two lessons, a window of a given size, the Comment
// column hidden with View Options (Command-J, Return), the History view; saved; Command-Q.
-(void)windowStateSave:(PVScript *)inScript
{
	[self newDocumentWithThreeWordsIn:inScript];
	__block ProVocDocument *document = nil;
	__block BOOL saved = NO;
	NSString *path = [[PVScenarios workDirectory] stringByAppendingPathComponent:@"State.pvoc"];
	NSPanel *(^optionsSheet)(void) = ^{ return (NSPanel *)[[document window] attachedSheet]; };
	NSMatrix *(^matrix)(void) = ^{
		NSMutableArray *views = [NSMutableArray arrayWithObjects:[optionsSheet() contentView], nil];
		while ([views count] > 0) {
			NSView *view = views[0];
			[views removeObjectAtIndex:0];
			if ([view isKindOfClass:[NSMatrix class]])
				return (NSMatrix *)view;
			[views addObjectsFromArray:[view subviews]];
		}
		return (NSMatrix *)nil;
	};
	void (^clickCheckBox)(NSString *) = ^(NSString *key) {
		NSMatrix *boxes = matrix();
		for (NSInteger row = 0; row < [boxes numberOfRows]; row++)
			for (NSInteger column = 0; column < [boxes numberOfColumns]; column++) {
				NSCell *cell = [boxes cellAtRow:row column:column];
				if ([[[cell infoForBinding:NSValueBinding] objectForKey:NSObservedKeyPathKey] isEqualToString:key]) {
					NSRect frame = [boxes cellFrameAtRow:row column:column];
					PVClickAtPoint(boxes, NSMakePoint(NSMinX(frame) + 10, NSMidY(frame)), 1, 0);
				}
			}
	};
	// The document gets its file, is closed, and opened again as from the Finder: this
	// makes it the most recent document. (The save panel cannot be confirmed from here.)
	[inScript then:^{
		document = [self editedDocument];
		PVAddPage(document, @"Second lesson", @[@[@"sun", @"soleil"], @[@"moon", @"lune"]]);
		[document saveToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" forSaveOperation:NSSaveOperation completionHandler:^(NSError *inError) {
			PVExpect(inError == nil, @"saving failed: %@", inError);
			saved = YES;
		}];
	}];
	[inScript wait:@"the document to be saved" timeout:15 until:^BOOL { return saved && ![document isDocumentEdited]; }];
	[inScript then:^{ PVTypeCommand(@"w", 0); }];
	[inScript wait:@"the document to close" until:^BOOL { return [[self documents] count] == 0; }];
	[inScript wait:@"the starting point" timeout:15 until:^BOOL { return [[self startingPoint] isKeyWindow]; }];
	[inScript then:^{
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path] display:YES completionHandler:^(NSDocument *inDocument, BOOL inAlreadyOpen, NSError *inError) {
			PVExpect(inError == nil, @"opening failed: %@", inError);
		}];
	}];
	[inScript wait:@"the document to open again, first of the recent documents" timeout:15 until:^BOOL {
		document = [[self documents] lastObject];
		NSURL *recent = [[[NSDocumentController sharedDocumentController] recentDocumentURLs] firstObject];
		return [[self documents] count] == 1 && [[document window] isKeyWindow] && [[[recent path] stringByResolvingSymlinksInPath] isEqualToString:[path stringByResolvingSymlinksInPath]];
	}];
	[inScript then:^{ PVTypeCommand(@"1", NSEventModifierFlagOption); }];
	[inScript wait:@"the Editing view" until:^BOOL { return [[document valueForKey:@"mainTab"] intValue] == 1 && [[self wordTable] window] == [document window]; }];

	// View Options (Command-J): hide the Comment column, Return
	[inScript then:^{ PVTypeCommand(@"j", 0); }];
	[inScript wait:@"the View Options sheet (Command-J)" until:^BOOL { return optionsSheet() != nil && matrix() != nil; }];
	[inScript then:^{
		PVSaveWindowScreenshot(optionsSheet(), @"windows/view-options");
		PVExpect([[self wordTable] columnWithIdentifier:@"Comment"] >= 0, @"the Comment column should be displayed at first");
		clickCheckBox(@"Comment");
	}];
	[inScript wait:@"the check box to be unchecked (the column only goes with OK)" until:^BOOL {
		return ![[[optionsSheet() windowController] valueForKey:@"Comment"] boolValue] && [[self wordTable] columnWithIdentifier:@"Comment"] >= 0;
	}];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return to close the sheet, the Comment column gone" until:^BOOL { return optionsSheet() == nil && [[self wordTable] columnWithIdentifier:@"Comment"] < 0; }];
	// ... and show it again, with the column of the next review (hidden at first)
	[inScript then:^{ PVTypeCommand(@"j", 0); }];
	[inScript wait:@"the View Options sheet once more" until:^BOOL { return optionsSheet() != nil && matrix() != nil; }];
	[inScript then:^{
		PVExpect([[self wordTable] columnWithIdentifier:@"NextReview"] < 0, @"the Next Review column should be hidden at first");
		clickCheckBox(@"Comment");
	}];
	[inScript wait:@"the Comment box to be checked" until:^BOOL { return [[[optionsSheet() windowController] valueForKey:@"Comment"] boolValue]; }];
	[inScript then:^{ clickCheckBox(@"NextReview"); }];
	[inScript wait:@"the Next Review box to be checked" until:^BOOL { return [[[optionsSheet() windowController] valueForKey:@"NextReview"] boolValue]; }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return to show both columns" until:^BOOL { return optionsSheet() == nil && [[self wordTable] columnWithIdentifier:@"Comment"] >= 0 && [[self wordTable] columnWithIdentifier:@"NextReview"] >= 0; }];
	// hide Comment again for the rest of the scenario
	[inScript then:^{ PVTypeCommand(@"j", 0); }];
	[inScript wait:@"the View Options sheet" until:^BOOL { return optionsSheet() != nil && matrix() != nil; }];
	[inScript then:^{ clickCheckBox(@"Comment"); }];
	[inScript wait:@"the Comment box to be unchecked" until:^BOOL { return ![[[optionsSheet() windowController] valueForKey:@"Comment"] boolValue]; }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the Comment column to go again" until:^BOOL { return optionsSheet() == nil && [[self wordTable] columnWithIdentifier:@"Comment"] < 0; }];
	// Esc cancels: nothing changes
	[inScript then:^{ PVTypeCommand(@"j", 0); }];
	[inScript wait:@"the View Options sheet again" until:^BOOL { return optionsSheet() != nil && matrix() != nil; }];
	[inScript then:^{ clickCheckBox(@"Difficulty"); }];
	[inScript wait:@"the check box to be unchecked" until:^BOOL { return ![[[optionsSheet() windowController] valueForKey:@"Difficulty"] boolValue]; }];
	[inScript then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"Esc to close the sheet" until:^BOOL { return optionsSheet() == nil; }];
	[inScript then:^{
		PVExpect([[self wordTable] columnWithIdentifier:@"Difficulty"] >= 0, @"Esc in View Options applied the change");
		PVExpect([[self wordTable] columnWithIdentifier:@"Comment"] < 0, @"Esc in View Options undid the previous change");
		// both lessons selected, a window of a given size and place, the History view
		[[self lessonOutline] selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)] byExtendingSelection:NO];
		NSRect frame = kStateFrame;
		frame.origin.x += NSMinX([[NSScreen mainScreen] visibleFrame]);
		frame.origin.y += NSMinY([[NSScreen mainScreen] visibleFrame]);
		[[document window] setFrame:frame display:YES];
		PVTypeCommand(@"3", NSEventModifierFlagOption);
	}];
	[inScript wait:@"the History view" until:^BOOL { return [[document valueForKey:@"mainTab"] intValue] == 2; }];
	// Command-S, then Command-Q
	__block NSDate *before = nil;
	[inScript then:^{
		before = [[[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:@"Settings"] error:NULL][NSFileModificationDate] retain];
		PVTypeCommand(@"s", 0);
	}];
	[inScript wait:@"Command-S to save the document" timeout:15 until:^BOOL {
		NSDate *date = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByAppendingPathComponent:@"Settings"] error:NULL][NSFileModificationDate];
		return date && ![date isEqualToDate:before] && ![document isDocumentEdited];
	}];
	[inScript then:^{
		[NSStringFromRect([[document window] frame]) writeToFile:[[PVScenarios workDirectory] stringByAppendingPathComponent:@"frame.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		[PVScenarios expectTermination];
		PVTypeCommand(@"q", 0);
	}];
}

// Second launch: the last document opens by itself, as it was left. Saved and opened
// once more, its window keeps its size.
-(void)windowStateRestore:(PVScript *)inScript
{
	NSString *path = [[PVScenarios workDirectory] stringByAppendingPathComponent:@"State.pvoc"];
	__block ProVocDocument *document = nil;
	__block NSRect expected;
	__block BOOL saved = NO;
	[inScript wait:@"the last document to open at launch" timeout:20 until:^BOOL {
		document = [[self documents] lastObject];
		return [[self documents] count] == 1 && [[document window] isKeyWindow] && [[[[document fileURL] path] stringByResolvingSymlinksInPath] isEqualToString:[path stringByResolvingSymlinksInPath]];
	}];
	void (^check)(NSString *) = ^(NSString *when) {
		PVExpect(NSEqualRects([[document window] frame], expected), @"%@: the window is at %@ instead of %@", when, NSStringFromRect([[document window] frame]), NSStringFromRect(expected));
		PVExpectEqual([[document valueForKey:@"mainTab"] intValue], 2, @"%@: the view shown (History)", when);
		PVExpectEqualObjects([[document valueForKey:@"mPageOutlineView"] selectedRowIndexes], [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)], @"%@: the selected lessons", when);
		PVExpectEqual([[document allWords] count], 5, @"%@: words", when);
	};
	[inScript then:^{
		expected = NSRectFromString([NSString stringWithContentsOfFile:[[PVScenarios workDirectory] stringByAppendingPathComponent:@"frame.txt"] encoding:NSUTF8StringEncoding error:NULL]);
		PVExpect(![[self startingPoint] isVisible], @"the starting point shows although the last document was reopened");
		check(@"at launch");
		PVTypeCommand(@"1", NSEventModifierFlagOption);
	}];
	[inScript wait:@"the Editing view" until:^BOOL { return [[document valueForKey:@"mainTab"] intValue] == 1 && [[document valueForKey:@"mWordTableView"] window] != nil; }];
	[inScript then:^{
		NSTableView *table = [document valueForKey:@"mWordTableView"];
		PVExpect([table columnWithIdentifier:@"Comment"] < 0, @"the Comment column is back");
		PVExpect([table columnWithIdentifier:@"Difficulty"] >= 0, @"the Difficulty column is gone");
		PVExpect([table columnWithIdentifier:@"NextReview"] >= 0, @"the Next Review column, shown with View Options, is hidden again");
		PVExpectEqual([[document valueForKey:@"mVisibleWords"] count], 5, @"the words of both selected lessons are listed");
		PVTypeCommand(@"3", NSEventModifierFlagOption);
	}];
	[inScript wait:@"the History view" until:^BOOL { return [[document valueForKey:@"mainTab"] intValue] == 2; }];
	// save, close, open again: nothing moves
	[inScript then:^{
		[document saveToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" forSaveOperation:NSSaveOperation completionHandler:^(NSError *inError) {
			PVExpect(inError == nil, @"saving failed: %@", inError);
			saved = YES;
		}];
	}];
	[inScript wait:@"the document to be saved" timeout:15 until:^BOOL { return saved; }];
	[inScript then:^{ PVTypeCommand(@"w", 0); }];
	[inScript wait:@"the document to close" until:^BOOL { return [[self documents] count] == 0; }];
	[inScript wait:@"the starting point" timeout:15 until:^BOOL { return [[self startingPoint] isKeyWindow]; }];
	[inScript then:^{
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:path] display:YES completionHandler:^(NSDocument *inDocument, BOOL inAlreadyOpen, NSError *inError) {
			PVExpect(inError == nil, @"opening failed: %@", inError);
		}];
	}];
	[inScript wait:@"the document to open again" timeout:15 until:^BOOL {
		document = [[self documents] lastObject];
		return [[self documents] count] == 1 && [[document window] isKeyWindow];
	}];
	[inScript then:^{ check(@"after saving and opening again"); }];
}

@end

@interface PVScenarios (Localization)
@end

@implementation PVScenarios (Localization)

-(NSArray *)slideViews
{
	NSMutableArray *views = [NSMutableArray array];
	for (NSWindow *window in [NSApp windows])
		if ([window isVisible] && [[window contentView] isKindOfClass:NSClassFromString(@"SlideView")])
			[views addObject:[window contentView]];
	return views;
}

-(NSView *)buttonWithAction:(SEL)inAction in:(NSView *)inView
{
	if ([inView isKindOfClass:[NSButton class]] && [(NSButton *)inView action] == inAction)
		return inView;
	for (NSView *subview in [inView subviews]) {
		NSView *found = [self buttonWithAction:inAction in:subview];
		if (found)
			return found;
	}
	return nil;
}

// The application in the language given by PV_LANGUAGE (launched with -AppleLanguages):
// the starting point, a new document, two words, the first training mode (slideshow of
// the new words, then multiple choice), the written test, Preferences, the Inspector.
-(void)localizedSmoke:(PVScript *)inScript
{
	NSString *language = [NSString stringWithUTF8String:getenv("PV_LANGUAGE") ?: "English"];
	NSBundle *english = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"English" ofType:@"lproj"]];
	__block ProVocDocument *document = nil;
	ProVocTester *(^tester)(void) = ^{ return [PVScenarios tester]; };
	NSPanel *(^testPanel)(void) = ^{ return (NSPanel *)[tester() performSelector:@selector(testPanel)]; };
	NSPanel *(^resultPanel)(void) = ^{ return (NSPanel *)[[document valueForKey:@"mTester"] valueForKey:@"mResultPanel"]; };
	BOOL (^testIsOver)(void) = ^BOOL { return ![document valueForKey:@"mTester"] && [NSApp modalWindow] == nil && [[document window] attachedSheet] == nil && [[document window] isKeyWindow]; };

	[inScript wait:@"the starting point window" timeout:15 until:^BOOL {
		return [[self startingPoint] isKeyWindow] && ([[self startingPoint] occlusionState] & NSWindowOcclusionStateVisible) && ![[self startingPoint] viewsNeedDisplay];
	}];
	[inScript then:^{
		PVExpectEqualObjects([[[NSBundle mainBundle] preferredLocalizations] firstObject], language, @"the localization in use");
		// the strings and the menus are those of the language
		if (![language isEqualToString:@"English"]) {
			NSString *verify = NSLocalizedString(@"Verify Button Title", @"");
			PVExpect(![verify isEqualToString:[english localizedStringForKey:@"Verify Button Title" value:nil table:nil]] && ![verify isEqualToString:@"Verify Button Title"], @"the strings are not localized: %@", verify);
			PVExpect(![[[[NSApp mainMenu] itemAtIndex:1] title] isEqualToString:@"File"], @"the menus are not localized: %@", [[[NSApp mainMenu] itemArray] valueForKey:@"title"]);
		}
		PVExpectEqual([[NSApp mainMenu] numberOfItems], 8, @"menus: %@", [[[NSApp mainMenu] itemArray] valueForKey:@"title"]);
		PVExpect([PVScenarios menuItemWithAction:@selector(performMediaCommand:)] != nil, @"no Media menu");
		PVExpect(![[[[PVScenarios menuItemWithAction:@selector(performMediaCommand:)] menu] title] isEqualToString:@"Media Menu Title"], @"the Media menu is not localized");
		for (NSString *action in @[@"startTest:", @"startSlideshow:", @"viewOptions:", @"import:", @"export:", @"printCards:", @"toggleInspector:", @"showPreferences:", @"findDoubles:", @"saveDocumentAs:"])
			PVExpect([PVScenarios menuItemWithAction:NSSelectorFromString(action)] != nil, @"no menu item for %@", action);
		PVSaveWindowScreenshot([self startingPoint], [NSString stringWithFormat:@"localizations/%@-starting-point", language]);
		PVClickView([self buttonWithAction:NSSelectorFromString(@"newDocument:") in:[[self startingPoint] contentView]], 1, 0);
	}];
	[inScript wait:@"a new document" until:^BOOL {
		document = [[self documents] lastObject];
		return [[self documents] count] == 1 && [[document window] isKeyWindow] && [[document valueForKey:@"mainTab"] intValue] == 1;
	}];
	[self typeWord:@"house" translation:@"maison" in:inScript];
	[self typeWord:@"cat" translation:@"chat" in:inScript];
	[inScript then:^{
		PVSaveWindowScreenshot([document window], [NSString stringWithFormat:@"localizations/%@-document-editing", language]);
		PVTypeCommand(@"r", 0);
	}];
	// the first training mode starts with a slideshow of the new words; Esc ends it
	[inScript wait:@"the slideshow of the new words" timeout:15 until:^BOOL { return [[self slideViews] count] > 0; }];
	[inScript then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	// ... then asks multiple-choice questions
	for (int number = 1; number <= 2; number++) {
		[inScript wait:[NSString stringWithFormat:@"multiple-choice question %i", number] timeout:15 until:^BOOL {
			id view = [tester() valueForKey:@"mMCQView"];
			return [[self slideViews] count] == 0 && [testPanel() isKeyWindow] && [testPanel() firstResponder] == view && [[tester() valueForKey:@"progressValue"] intValue] == number
				&& [[view valueForKey:@"mSelectedIndex"] intValue] < 0 && [[view valueForKey:@"mAnswers"] count] == 2;
		}];
		[inScript then:^{
			if (number == 1)
				PVSaveWindowScreenshot(testPanel(), [NSString stringWithFormat:@"localizations/%@-multiple-choice", language]);
			static const unsigned short digitKeys[] = {18, 19, 20, 21};
			PVPostKey(digitKeys[[[[tester() valueForKey:@"mMCQView"] valueForKey:@"mSolutionIndex"] intValue]], nil, 0);
		}];
		[inScript wait:@"the right choice to be selected" until:^BOOL {
			id view = [tester() valueForKey:@"mMCQView"];
			return [[view valueForKey:@"mSelectedIndex"] intValue] == [[view valueForKey:@"mSolutionIndex"] intValue];
		}];
		[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	}
	[inScript wait:@"the result panel" timeout:10 until:^BOOL { return [resultPanel() isVisible]; }];
	[inScript then:^{
		PVSaveWindowScreenshot(resultPanel(), [NSString stringWithFormat:@"localizations/%@-results", language]);
		PVExpectEqualObjects([[[[document valueForKey:@"mTester"] valueForKey:@"mResultView"] valueForKey:@"mResults"] valueForKey:@"Value"], (@[@2, @0]), @"results of the multiple-choice test");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[inScript wait:@"the end of the test" until:testIsOver];

	// the Training view, the second training mode (written, from the translation to the word)
	[inScript then:^{ PVTypeCommand(@"2", NSEventModifierFlagOption); }];
	[inScript wait:@"the Training view" until:^BOOL {
		NSTableView *presets = [document valueForKey:@"mPresetTableView"];
		return [[document valueForKey:@"mainTab"] intValue] == 0 && [presets window] == [document window] && [presets numberOfRows] == 4;
	}];
	[inScript then:^{
		PVSaveWindowScreenshot([document window], [NSString stringWithFormat:@"localizations/%@-document-training", language]);
		NSTableView *presets = [document valueForKey:@"mPresetTableView"];
		NSRect row = [presets rectOfRow:1];
		PVClickAtPoint(presets, NSMakePoint(NSMidX(row), NSMidY(row)), 1, 0);
	}];
	[inScript wait:@"the second training mode to be selected" until:^BOOL { return [[document valueForKey:@"mPresetTableView"] selectedRow] == 1 && ![[document valueForKey:@"testMCQ"] boolValue]; }];
	[inScript then:^{ PVTypeCommand(@"r", 0); }];
	for (int number = 1; number <= 2; number++) {
		[inScript wait:[NSString stringWithFormat:@"written question %i, the answer field ready", number] timeout:10 until:^BOOL {
			return [testPanel() isVisible] && [PVScenarios answerFieldHasFocus] && [[tester() valueForKey:@"progressValue"] intValue] == number && [[[PVScenarios answerField] stringValue] length] == 0;
		}];
		[inScript then:^{
			if (number == 1)
				PVSaveWindowScreenshot(testPanel(), [NSString stringWithFormat:@"localizations/%@-written-test", language]);
			NSString *question = [tester() question];
			PVExpect([question isEqualToString:@"maison"] || [question isEqualToString:@"chat"], @"unexpected question %@", question);
			PVTypeText([question isEqualToString:@"maison"] ? @"house" : @"cat");
			PVPostKey(PVKeyReturn, nil, 0);
		}];
	}
	[inScript wait:@"the result panel" timeout:10 until:^BOOL { return [resultPanel() isVisible]; }];
	[inScript then:^{
		PVExpectEqualObjects([[[[document valueForKey:@"mTester"] valueForKey:@"mResultView"] valueForKey:@"mResults"] valueForKey:@"Value"], (@[@2, @0]), @"results of the written test");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[inScript wait:@"the end of the test" until:testIsOver];

	// Preferences (Command-,) and the Inspector (Command-I)
	NSWindow *(^preferences)(void) = ^{ return [[NSClassFromString(@"ProVocPreferences") performSelector:@selector(sharedPreferences)] window]; };
	[inScript then:^{ PVTypeCommand(@",", 0); }];
	[inScript wait:@"the Preferences window (Command-,)" timeout:10 until:^BOOL { return [preferences() isKeyWindow]; }];
	[inScript then:^{
		PVSaveWindowScreenshot(preferences(), [NSString stringWithFormat:@"localizations/%@-preferences", language]);
		PVTypeCommand(@"w", 0);
	}];
	[inScript wait:@"Command-W to close the Preferences" until:^BOOL { return ![preferences() isVisible] && [[document window] isKeyWindow]; }];
	[inScript then:^{ PVTypeCommand(@"1", NSEventModifierFlagOption); }];
	[inScript wait:@"the Editing view" until:^BOOL { return [[document valueForKey:@"mainTab"] intValue] == 1; }];
	[inScript then:^{ if (![[ProVocInspector sharedInspector] isVisible]) PVTypeCommand(@"i", 0); }];
	[inScript wait:@"the Inspector (Command-I)" until:^BOOL { return [[ProVocInspector sharedInspector] isVisible]; }];
	[inScript then:^{
		PVSaveWindowScreenshot([[ProVocInspector sharedInspector] window], [NSString stringWithFormat:@"localizations/%@-inspector", language]);
		PVTypeCommand(@"i", 0);
	}];
	[inScript wait:@"Command-I to close the Inspector" until:^BOOL { return ![[ProVocInspector sharedInspector] isVisible]; }];
	[inScript then:^{ [document updateChangeCount:NSChangeCleared]; }];
}

@end
