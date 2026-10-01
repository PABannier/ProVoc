//
//  PVEditingScenarios.m
//
//  Editing a document, with Undo and Redo after each operation: one operation, one
//  step back. (Undo needs the real event loop: see PVDriver.h.)
//

#import "PVDriver.h"
#import "ProVocChapter.h"
#import "ProVocData.h"

@interface PVScenarios (Editing)
@end

@implementation PVScenarios (Editing)

-(ProVocDocument *)editedDocument
{
	return [PVScenarios document];
}

-(NSTableView *)wordTable
{
	return [[self editedDocument] valueForKey:@"mWordTableView"];
}

-(NSOutlineView *)lessonOutline
{
	return [[self editedDocument] valueForKey:@"mPageOutlineView"];
}

-(NSArray *)sources
{
	return [PVScenarios sourceWordsOf:[self editedDocument]];
}

// The words as listed in the window, top to bottom
-(NSArray *)listedSources
{
	return [[[self editedDocument] valueForKey:@"mVisibleWords"] valueForKey:@"sourceWord"];
}

-(NSArray *)lessonTitles
{
	NSMutableArray *titles = [NSMutableArray array];
	NSOutlineView *outline = [self lessonOutline];
	for (NSInteger row = 0; row < [outline numberOfRows]; row++)
		[titles addObject:[[outline itemAtRow:row] title]];
	return titles;
}

-(ProVocWord *)wordWithSource:(NSString *)inSource
{
	for (ProVocWord *word in [[self editedDocument] allWords])
		if ([[word sourceWord] isEqualToString:inSource])
			return word;
	return nil;
}

-(BOOL)isEditingField:(NSTextField *)inField
{
	id firstResponder = [[inField window] firstResponder];
	return [[inField window] isKeyWindow] && [firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == (id)inField;
}

-(void)typeWord:(NSString *)inSource translation:(NSString *)inTarget in:(PVScript *)inScript
{
	__block NSUInteger count = 0;
	[inScript then:^{
		count = [[[self editedDocument] allWords] count];
		PVClickView([[self editedDocument] valueForKey:@"mSourceTextField"], 1, 0);
	}];
	[inScript wait:@"the source field to be edited" until:^BOOL { return [self isEditingField:[[self editedDocument] valueForKey:@"mSourceTextField"]]; }];
	[inScript then:^{ PVTypeText(inSource); PVPostKey(PVKeyTab, nil, 0); }];
	[inScript wait:@"the target field to be edited" until:^BOOL { return [self isEditingField:[[self editedDocument] valueForKey:@"mTargetTextField"]]; }];
	[inScript then:^{ PVTypeText(inTarget); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:[NSString stringWithFormat:@"the word %@ to be added", inSource] until:^BOOL { return [[[self editedDocument] allWords] count] == count + 1; }];
}

// Command-N, the Editing view, and the words house, cat, dog typed in
-(void)newDocumentWithThreeWordsIn:(PVScript *)inScript
{
	[inScript then:^{ PVTypeCommand(@"n", 0); }];
	[inScript wait:@"an untitled document" until:^BOOL { return [[[NSDocumentController sharedDocumentController] documents] count] >= 1 && [[[self editedDocument] window] isKeyWindow] && [[self editedDocument] fileURL] == nil && [[[self editedDocument] allWords] count] == 0; }];
	[inScript then:^{ PVTypeCommand(@"1", NSEventModifierFlagOption); }];
	[inScript wait:@"the Editing view" until:^BOOL { return [[[self editedDocument] valueForKey:@"mainTab"] intValue] == 1 && [[[self editedDocument] valueForKey:@"mSourceTextField"] window] != nil; }];
	[self typeWord:@"house" translation:@"maison" in:inScript];
	[self typeWord:@"cat" translation:@"chat" in:inScript];
	[self typeWord:@"dog" translation:@"chien" in:inScript];
}

-(void)clickWordRow:(NSInteger)inRow column:(NSString *)inIdentifier clickCount:(NSInteger)inCount modifiers:(NSEventModifierFlags)inModifiers
{
	NSTableView *table = [self wordTable];
	NSRect frame = [table frameOfCellAtColumn:[table columnWithIdentifier:inIdentifier] row:inRow];
	PVClickAtPoint(table, NSMakePoint(NSMinX(frame) + 12, NSMidY(frame)), inCount, inModifiers);
}

-(void)selectWord:(NSString *)inSource in:(PVScript *)inScript
{
	[inScript then:^{ [self clickWordRow:[[self listedSources] indexOfObject:inSource] column:@"Source" clickCount:1 modifiers:0]; }];
	[inScript wait:[NSString stringWithFormat:@"a click to select %@", inSource] until:^BOOL {
		NSArray *selected = [[self editedDocument] selectedWords];
		return [selected count] == 1 && [[(ProVocWord *)selected[0] sourceWord] isEqualToString:inSource] && [[[self editedDocument] window] firstResponder] == [self wordTable];
	}];
}

// Command-Z brings back the state before the last operation, Shift-Command-Z the state after
-(void)undoAndRedoIn:(PVScript *)inScript what:(NSString *)inWhat before:(PVCondition)inBefore after:(PVCondition)inAfter
{
	[inScript then:^{
		PVExpect(inAfter(), @"%@: not done", inWhat);
		PVExpect([[[self editedDocument] undoManager] canUndo], @"%@ cannot be undone", inWhat);
		PVTypeCommand(@"z", 0);
	}];
	[inScript wait:[NSString stringWithFormat:@"Undo of: %@", inWhat] until:inBefore];
	[inScript then:^{ PVTypeCommand(@"z", NSEventModifierFlagShift); }];
	[inScript wait:[NSString stringWithFormat:@"Redo of: %@", inWhat] until:inAfter];
}

-(void)chooseMenuItemWithAction:(SEL)inAction tag:(NSInteger)inTag
{
	NSMenuItem *item = [PVScenarios menuItemWithAction:inAction tag:inTag];
	PVExpect(item != nil, @"no menu item for %@", NSStringFromSelector(inAction));
	PVPrepareMenu([item menu]);
	PVExpect([item isEnabled], @"the menu item %@ is disabled", [item title]);
	[[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]];
}

#pragma mark Words

// Add, delete, edit in place, flag, label, difficulty, swap, sort: each can be undone and redone, one at a time.
-(void)editingWordsWithUndo:(PVScript *)inScript
{
	[self newDocumentWithThreeWordsIn:inScript];
	// typing a word: one undo step per word
	[self undoAndRedoIn:inScript what:@"adding the word dog" before:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"cat"]]; } after:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"cat", @"dog"]]; }];

	// Delete key
	[self selectWord:@"cat" in:inScript];
	[inScript then:^{ PVPostKey(PVKeyDelete, nil, 0); }];
	[inScript wait:@"the Delete key to remove the word" until:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"dog"]]; }];
	[self undoAndRedoIn:inScript what:@"deleting the word cat" before:^BOOL { return [[self listedSources] isEqualToArray:@[@"house", @"cat", @"dog"]]; } after:^BOOL { return [[self listedSources] isEqualToArray:@[@"house", @"dog"]]; }];
	// two operations, two steps: one more Undo brings the word back, nothing else
	[inScript then:^{ PVTypeCommand(@"z", 0); }];
	[inScript wait:@"Undo to bring the word back" until:^BOOL { return [[self listedSources] isEqualToArray:@[@"house", @"cat", @"dog"]]; }];

	// editing in place: double click, type, Return
	[inScript then:^{ [self clickWordRow:1 column:@"Source" clickCount:2 modifiers:0]; }];
	[inScript wait:@"a double click to edit the word" until:^BOOL { return [[self wordTable] editedRow] == 1 && [[[[self editedDocument] window] firstResponder] isKindOfClass:[NSText class]]; }];
	[inScript then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"kitten"); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the word to be changed" until:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"kitten", @"dog"]]; }];
	[inScript then:^{ if ([[self wordTable] editedRow] >= 0) PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"the end of the editing" until:^BOOL { return [[self wordTable] editedRow] < 0; }];
	[self undoAndRedoIn:inScript what:@"editing a word in the list" before:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"cat", @"dog"]]; } after:^BOOL { return [[self sources] isEqualToArray:@[@"house", @"kitten", @"dog"]]; }];
	// the translation too, with Tab from the first column
	[inScript then:^{ [self clickWordRow:0 column:@"Target" clickCount:2 modifiers:0]; }];
	[inScript wait:@"a double click to edit the translation" until:^BOOL { return [[self wordTable] editedRow] == 0 && [[self wordTable] editedColumn] == [[self wordTable] columnWithIdentifier:@"Target"]; }];
	[inScript then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"la maison"); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the translation to be changed" until:^BOOL { return [[[self wordWithSource:@"house"] targetWord] isEqualToString:@"la maison"]; }];
	[inScript then:^{ if ([[self wordTable] editedRow] >= 0) PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"the end of the editing" until:^BOOL { return [[self wordTable] editedRow] < 0; }];
	[self undoAndRedoIn:inScript what:@"editing a translation" before:^BOOL { return [[[self wordWithSource:@"house"] targetWord] isEqualToString:@"maison"]; } after:^BOOL { return [[[self wordWithSource:@"house"] targetWord] isEqualToString:@"la maison"]; }];

	// flag, label, difficulty
	[self selectWord:@"dog" in:inScript];
	[inScript then:^{ PVTypeCommand(@"f", NSEventModifierFlagShift); }];
	[inScript wait:@"the word to be flagged" until:^BOOL { return [[self wordWithSource:@"dog"] mark] != 0; }];
	[self undoAndRedoIn:inScript what:@"flagging a word" before:^BOOL { return [[self wordWithSource:@"dog"] mark] == 0; } after:^BOOL { return [[self wordWithSource:@"dog"] mark] != 0; }];
	[inScript then:^{ PVTypeCommand(@"3", 0); }];
	[inScript wait:@"the word to be labelled" until:^BOOL { return [[self wordWithSource:@"dog"] label] == 3; }];
	[self undoAndRedoIn:inScript what:@"labelling a word" before:^BOOL { return [[self wordWithSource:@"dog"] label] == 0 && [[self wordWithSource:@"dog"] mark] != 0; } after:^BOOL { return [[self wordWithSource:@"dog"] label] == 3; }];
	[inScript then:^{ PVPostKey(PVKeyRight, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction | NSEventModifierFlagNumericPad); }];
	[inScript wait:@"the word to be more difficult" until:^BOOL { return [[self wordWithSource:@"dog"] difficulty] > 0; }];
	[self undoAndRedoIn:inScript what:@"increasing the difficulty" before:^BOOL { return [[self wordWithSource:@"dog"] difficulty] == 0 && [[self wordWithSource:@"dog"] label] == 3; } after:^BOOL { return [[self wordWithSource:@"dog"] difficulty] > 0; }];

	// Vocabulary > Swap Source and Target
	[inScript then:^{ [self chooseMenuItemWithAction:@selector(swapSourceAndTarget:) tag:0]; }];
	[inScript wait:@"source and target to be swapped for the selected word" until:^BOOL { return [self wordWithSource:@"chien"] != nil && [self wordWithSource:@"house"] != nil; }];
	[self undoAndRedoIn:inScript what:@"swapping source and target" before:^BOOL { return [self wordWithSource:@"dog"] != nil; } after:^BOOL { return [[[self wordWithSource:@"chien"] targetWord] isEqualToString:@"dog"]; }];
	[inScript then:^{ PVTypeCommand(@"z", 0); }];
	[inScript wait:@"the swap to be undone" until:^BOOL { return [self wordWithSource:@"dog"] != nil; }];

	// a click on a column header sorts the list (not the document), another click reverses
	[inScript then:^{
		NSTableHeaderView *header = [[self wordTable] headerView];
		NSRect rect = [header headerRectOfColumn:[[self wordTable] columnWithIdentifier:@"Source"]];
		PVClickAtPoint(header, NSMakePoint(NSMidX(rect), NSMidY(rect)), 1, 0);
	}];
	[inScript wait:@"the list sorted by source word" until:^BOOL { return [[self listedSources] isEqualToArray:@[@"dog", @"house", @"kitten"]] || [[self listedSources] isEqualToArray:@[@"kitten", @"house", @"dog"]]; }];
	__block NSArray *firstOrder = nil;
	[inScript then:^{
		firstOrder = [[self listedSources] copy];
		NSTableHeaderView *header = [[self wordTable] headerView];
		NSRect rect = [header headerRectOfColumn:[[self wordTable] columnWithIdentifier:@"Source"]];
		PVClickAtPoint(header, NSMakePoint(NSMidX(rect), NSMidY(rect)), 1, 0);
	}];
	[inScript wait:@"the list sorted the other way" until:^BOOL { return [[self listedSources] isEqualToArray:[[firstOrder reverseObjectEnumerator] allObjects]]; }];
	[inScript then:^{
		PVExpectEqualObjects([self sources], (@[@"house", @"kitten", @"dog"]), @"sorting the list should not reorder the lesson");
		PVSaveWindowScreenshot([[self editedDocument] window], @"windows/document-editing-sorted");
		[[self editedDocument] updateChangeCount:NSChangeCleared];
	}];
}

#pragma mark Lessons

-(id)lessonTitled:(NSString *)inTitle
{
	NSOutlineView *outline = [self lessonOutline];
	for (NSInteger row = 0; row < [outline numberOfRows]; row++)
		if ([[[outline itemAtRow:row] title] isEqualToString:inTitle])
			return [outline itemAtRow:row];
	return nil;
}

-(NSArray *)wordsOfLesson:(NSString *)inTitle
{
	return [[(ProVocPage *)[self lessonTitled:inTitle] words] valueForKey:@"sourceWord"];
}

-(void)clickLesson:(NSString *)inTitle clickCount:(NSInteger)inCount modifiers:(NSEventModifierFlags)inModifiers
{
	NSOutlineView *outline = [self lessonOutline];
	NSRect rect = [outline rectOfRow:[outline rowForItem:[self lessonTitled:inTitle]]];
	PVClickAtPoint(outline, NSMakePoint(NSMinX(rect) + 60, NSMidY(rect)), inCount, inModifiers);
}

-(void)selectLesson:(NSString *)inTitle in:(PVScript *)inScript
{
	[inScript then:^{ [self clickLesson:inTitle clickCount:1 modifiers:0]; }];
	[inScript wait:@"a click to select the lesson" until:^BOOL {
		NSArray *selected = [[self editedDocument] selectedPages];
		return [selected count] == 1 && [[(ProVocPage *)selected[0] title] isEqualToString:inTitle] && [[[self editedDocument] window] firstResponder] == [self lessonOutline];
	}];
}

-(NSPanel *)nameSheet
{
	NSWindow *sheet = [[[self editedDocument] window] attachedSheet];
	return sheet == [[self editedDocument] valueForKey:@"mInputPanel"] ? (NSPanel *)sheet : nil;
}

// A plain button (inPopUp NO) or a pop-up button with a menu item (inPopUp YES) for an action
-(id)controlWithAction:(SEL)inAction popUp:(BOOL)inPopUp inView:(NSView *)inView
{
	if (![inView isHiddenOrHasHiddenAncestor]) {
		if (!inPopUp && [inView isKindOfClass:[NSButton class]] && ![inView isKindOfClass:[NSPopUpButton class]] && [(NSButton *)inView action] == inAction)
			return inView;
		if (inPopUp && [inView isKindOfClass:[NSPopUpButton class]])
			for (NSMenuItem *item in [[(NSPopUpButton *)inView menu] itemArray])
				if ([item action] == inAction)
					return inView;
	}
	for (NSView *subview in [inView subviews]) {
		id found = [self controlWithAction:inAction popUp:inPopUp inView:subview];
		if (found)
			return found;
	}
	return nil;
}

-(NSButton *)newLessonButton
{
	return [self controlWithAction:@selector(newPage:) popUp:NO inView:[[[self editedDocument] window] contentView]];
}

// The drag of words (rows of the list) onto a lesson, or between two rows of the list (inLesson nil)
-(BOOL)dragWords:(NSArray *)inSources toLesson:(NSString *)inLesson orRow:(NSInteger)inRow copy:(BOOL)inCopy
{
	ProVocDocument *document = [self editedDocument];
	NSMutableIndexSet *rows = [NSMutableIndexSet indexSet];
	for (NSString *source in inSources)
		[rows addIndex:[[self listedSources] indexOfObject:source]];
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
	if (![(id <NSTableViewDataSource>)document tableView:[self wordTable] writeRowsWithIndexes:rows toPasteboard:pasteboard])
		return NO;
	PVDragInfo *info = [PVDragInfo infoWithPasteboard:pasteboard source:[self wordTable] copy:inCopy];
	if (inLesson) {
		id item = [self lessonTitled:inLesson];
		if ([(id <NSOutlineViewDataSource>)document outlineView:[self lessonOutline] validateDrop:info proposedItem:item proposedChildIndex:NSOutlineViewDropOnItemIndex] == NSDragOperationNone)
			return NO;
		return [(id <NSOutlineViewDataSource>)document outlineView:[self lessonOutline] acceptDrop:info item:item childIndex:NSOutlineViewDropOnItemIndex];
	}
	if ([(id <NSTableViewDataSource>)document tableView:[self wordTable] validateDrop:info proposedRow:inRow proposedDropOperation:NSTableViewDropAbove] == NSDragOperationNone)
		return NO;
	return [(id <NSTableViewDataSource>)document tableView:[self wordTable] acceptDrop:info row:inRow dropOperation:NSTableViewDropAbove];
}

// The drag of lessons to another place of the outline (inParent nil: the top level)
-(BOOL)dragLessons:(NSArray *)inTitles intoChapter:(NSString *)inParent atIndex:(NSInteger)inIndex copy:(BOOL)inCopy
{
	ProVocDocument *document = [self editedDocument];
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *title in inTitles)
		[items addObject:[self lessonTitled:title]];
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
	if (![(id <NSOutlineViewDataSource>)document outlineView:[self lessonOutline] writeItems:items toPasteboard:pasteboard])
		return NO;
	PVDragInfo *info = [PVDragInfo infoWithPasteboard:pasteboard source:[self lessonOutline] copy:inCopy];
	id parent = inParent ? [self lessonTitled:inParent] : nil;
	if ([(id <NSOutlineViewDataSource>)document outlineView:[self lessonOutline] validateDrop:info proposedItem:parent proposedChildIndex:inIndex] == NSDragOperationNone)
		return NO;
	return [(id <NSOutlineViewDataSource>)document outlineView:[self lessonOutline] acceptDrop:info item:parent childIndex:inIndex];
}

// New lesson and chapter (name sheet: Return = OK, Esc = Cancel), rename, delete,
// drag words onto a lesson, Option-drag to copy, drag lessons, reorder words: with Undo / Redo.
-(void)editingLessonsWithUndo:(PVScript *)inScript
{
	[self newDocumentWithThreeWordsIn:inScript];
	// (the name of the first lesson is only known once the script runs)
	NSMutableString *firstLesson = [NSMutableString string];
	[inScript then:^{
		PVExpectEqual([[self lessonTitles] count], 1, @"a new document has one lesson: %@", [self lessonTitles]);
		[firstLesson setString:[[self lessonTitles] firstObject]];
		// the + button under the lessons
		PVExpect([self newLessonButton] != nil, @"no + button for a new lesson");
		PVClickView([self newLessonButton], 1, 0);
	}];
	[inScript wait:@"the sheet asking the name of the lesson, its field being edited" until:^BOOL {
		return [self nameSheet] != nil && [self isEditingField:[[self editedDocument] valueForKey:@"mInputTextField"]];
	}];
	[inScript then:^{
		PVExpect([[[[self editedDocument] valueForKey:@"mInputTextField"] stringValue] length] > 0, @"a name should be proposed");
		PVSaveWindowScreenshot([self nameSheet], @"windows/new-lesson-sheet");
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[inScript wait:@"Esc to cancel: no new lesson" until:^BOOL { return [self nameSheet] == nil && [[self lessonTitles] count] == 1; }];
	[inScript then:^{ PVClickView([self newLessonButton], 1, 0); }];
	[inScript wait:@"the name sheet again" until:^BOOL { return [self nameSheet] != nil && [self isEditingField:[[self editedDocument] valueForKey:@"mInputTextField"]]; }];
	[inScript then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"Animals"); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return to create the lesson, selected and empty" until:^BOOL {
		return [self nameSheet] == nil && [[self lessonTitles] isEqualToArray:@[firstLesson, @"Animals"]] && [[[[[self editedDocument] selectedPages] lastObject] title] isEqualToString:@"Animals"] && [[self listedSources] count] == 0;
	}];
	[self undoAndRedoIn:inScript what:@"creating a lesson" before:^BOOL { return [[self lessonTitles] isEqualToArray:@[firstLesson]]; } after:^BOOL { return [[self lessonTitles] isEqualToArray:@[firstLesson, @"Animals"]]; }];

	// drag two words onto the new lesson: they move
	[self selectLesson:firstLesson in:inScript];
	[inScript then:^{ PVExpect(([self dragWords:@[@"cat", @"dog"] toLesson:@"Animals" orRow:0 copy:NO]), @"the drag of words onto a lesson was refused"); }];
	[inScript wait:@"the words to move to the lesson" until:^BOOL { return [[self wordsOfLesson:firstLesson] isEqualToArray:@[@"house"]] && [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"cat", @"dog"]]; }];
	[self undoAndRedoIn:inScript what:@"dragging words onto a lesson" before:^BOOL { return [[self wordsOfLesson:firstLesson] isEqualToArray:@[@"house", @"cat", @"dog"]] && [[self wordsOfLesson:@"Animals"] count] == 0; }
				  after:^BOOL { return [[self wordsOfLesson:firstLesson] isEqualToArray:@[@"house"]] && [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"cat", @"dog"]]; }];
	// with Option: a copy
	[self selectLesson:firstLesson in:inScript];
	[inScript then:^{ PVExpect([self dragWords:@[@"house"] toLesson:@"Animals" orRow:0 copy:YES], @"the Option-drag of a word onto a lesson was refused"); }];
	[inScript wait:@"a copy of the word in the lesson" until:^BOOL { return [[self wordsOfLesson:firstLesson] isEqualToArray:@[@"house"]] && [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"cat", @"dog", @"house"]]; }];
	[self undoAndRedoIn:inScript what:@"copying a word to a lesson" before:^BOOL { return [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"cat", @"dog"]]; } after:^BOOL { return [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"cat", @"dog", @"house"]]; }];

	// reorder the words of a lesson by dragging in the list
	[self selectLesson:@"Animals" in:inScript];
	[inScript then:^{ PVExpect([self dragWords:@[@"house"] toLesson:nil orRow:0 copy:NO], @"the drag of a word in the list was refused"); }];
	[inScript wait:@"the word to move to the top" until:^BOOL { return [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"house", @"cat", @"dog"]] && [[self listedSources] isEqualToArray:@[@"house", @"cat", @"dog"]]; }];
	[self undoAndRedoIn:inScript what:@"reordering the words" before:^BOOL { return [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"cat", @"dog", @"house"]]; } after:^BOOL { return [[self wordsOfLesson:@"Animals"] isEqualToArray:@[@"house", @"cat", @"dog"]]; }];

	// rename: double click, type, Return
	[inScript then:^{ [self clickLesson:@"Animals" clickCount:2 modifiers:0]; }];
	[inScript wait:@"a double click to edit the name of the lesson" until:^BOOL { return [[self lessonOutline] editedRow] >= 0 && [[[[self editedDocument] window] firstResponder] isKindOfClass:[NSText class]]; }];
	[inScript then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"Pets"); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the lesson to be renamed" until:^BOOL { return [[self lessonTitles] isEqualToArray:@[firstLesson, @"Pets"]] && [[self lessonOutline] editedRow] < 0; }];
	[self undoAndRedoIn:inScript what:@"renaming a lesson" before:^BOOL { return [[self lessonTitles] isEqualToArray:@[firstLesson, @"Animals"]]; } after:^BOOL { return [[self lessonTitles] isEqualToArray:@[firstLesson, @"Pets"]]; }];

	// drag the lesson before the first one; Option-drag copies it
	[inScript then:^{ PVExpect([self dragLessons:@[@"Pets"] intoChapter:nil atIndex:0 copy:NO], @"the drag of a lesson was refused"); }];
	[inScript wait:@"the lesson to come first" until:^BOOL { return [[self lessonTitles] isEqualToArray:@[@"Pets", firstLesson]]; }];
	[self undoAndRedoIn:inScript what:@"moving a lesson" before:^BOOL { return [[self lessonTitles] isEqualToArray:@[firstLesson, @"Pets"]]; } after:^BOOL { return [[self lessonTitles] isEqualToArray:@[@"Pets", firstLesson]]; }];
	[inScript then:^{ PVExpect([self dragLessons:@[@"Pets"] intoChapter:nil atIndex:2 copy:YES], @"the Option-drag of a lesson was refused"); }];
	[inScript wait:@"a copy of the lesson at the end, with its words" until:^BOOL {
		NSArray *titles = [self lessonTitles];
		return [titles count] == 3 && [titles[0] isEqualToString:@"Pets"] && [titles[1] isEqualToString:firstLesson] && [[(ProVocPage *)[[self lessonOutline] itemAtRow:2] words] count] == 3;
	}];
	[self undoAndRedoIn:inScript what:@"copying a lesson" before:^BOOL { return [[self lessonTitles] count] == 2; } after:^BOOL { return [[self lessonTitles] count] == 3; }];

	// a chapter, from the action menu under the lessons; a lesson dragged into it
	[inScript then:^{
		NSPopUpButton *popUp = [self controlWithAction:@selector(newChapter:) popUp:YES inView:[[[self editedDocument] window] contentView]];
		PVExpect(popUp != nil, @"no action menu with New Chapter");
		for (NSMenuItem *item in [[popUp menu] itemArray])
			if ([item action] == @selector(newChapter:))
				[[popUp menu] performActionForItemAtIndex:[[popUp menu] indexOfItem:item]];
	}];
	[inScript wait:@"the sheet asking the name of the chapter" until:^BOOL { return [self nameSheet] != nil && [self isEditingField:[[self editedDocument] valueForKey:@"mInputTextField"]]; }];
	[inScript then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"Unit 1"); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the chapter" until:^BOOL { return [self nameSheet] == nil && [[self lessonTitled:@"Unit 1"] isKindOfClass:[ProVocChapter class]]; }];
	[self undoAndRedoIn:inScript what:@"creating a chapter" before:^BOOL { return [self lessonTitled:@"Unit 1"] == nil; } after:^BOOL { return [[self lessonTitled:@"Unit 1"] isKindOfClass:[ProVocChapter class]]; }];
	[inScript then:^{ PVExpect([self dragLessons:@[firstLesson] intoChapter:@"Unit 1" atIndex:NSOutlineViewDropOnItemIndex copy:NO], @"the drag of a lesson into a chapter was refused"); }];
	[inScript wait:@"the lesson to be in the chapter" until:^BOOL { return [(ProVocPage *)[self lessonTitled:firstLesson] parent] == [self lessonTitled:@"Unit 1"] || ([self lessonTitled:firstLesson] == nil && [[[(ProVocChapter *)[self lessonTitled:@"Unit 1"] children] valueForKey:@"title"] containsObject:firstLesson]); }];
	[inScript then:^{ PVSaveWindowScreenshot([[self editedDocument] window], @"windows/document-lessons-and-chapter"); }];

	// delete: select + the Delete key; the words go with the lesson (its copy stays)
	[self selectLesson:@"Pets" in:inScript];
	__block NSUInteger wordCount = 0;
	NSUInteger (^numberOfPets)(void) = ^{ return [[[self lessonTitles] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'Pets'"]] count]; };
	[inScript then:^{
		PVExpectEqual(numberOfPets(), 2, @"the lesson and its copy: %@", [self lessonTitles]);
		wordCount = [[[self editedDocument] allWords] count];
		PVPostKey(PVKeyDelete, nil, 0);
	}];
	[inScript wait:@"the Delete key to remove the lesson and its words" until:^BOOL { return numberOfPets() == 1 && [[[self editedDocument] allWords] count] == wordCount - 3; }];
	[self undoAndRedoIn:inScript what:@"deleting a lesson" before:^BOOL { return numberOfPets() == 2 && [[[self editedDocument] allWords] count] == wordCount; } after:^BOOL { return numberOfPets() == 1 && [[[self editedDocument] allWords] count] == wordCount - 3; }];
	[inScript then:^{ [[self editedDocument] updateChangeCount:NSChangeCleared]; }];
}

@end
