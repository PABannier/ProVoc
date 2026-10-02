//
//  ProVocEditingTests.m
//
//  Editing a document with the keyboard: adding words, Tab chaining, deleting,
//  undo, find, selection, flags, labels, modes.
//

#import "PVScenarioTestCase.h"
#import "ProVocTextField.h"

@interface ProVocEditingTests : PVScenarioTestCase
@end

@implementation ProVocEditingTests

-(void)setUp
{
	[super setUp];
	[mDocument setMainTab:1];
	PVWaitUntil(1, ^BOOL { return [[self sourceField] window] == [mDocument window]; });
}

-(NSTextField *)sourceField { return [mDocument valueForKey:@"mSourceTextField"]; }
-(NSTextField *)targetField { return [mDocument valueForKey:@"mTargetTextField"]; }
-(NSTextField *)commentField { return [mDocument valueForKey:@"mCommentTextField"]; }
-(NSTableView *)wordTable { return [mDocument valueForKey:@"mWordTableView"]; }
-(NSOutlineView *)pageOutline { return [mDocument valueForKey:@"mPageOutlineView"]; }
-(NSSearchField *)searchField { return [mDocument valueForKey:@"mSearchField"]; }
-(NSArray *)visibleWords { return [mDocument valueForKey:@"mVisibleWords"]; }

-(NSArray *)visibleSources
{
	return [[self visibleWords] valueForKey:@"sourceWord"];
}

-(BOOL)isEditing:(NSTextField *)inField
{
	id firstResponder = [[mDocument window] firstResponder];
	return [[mDocument window] isKeyWindow] && [firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == (id)inField;
}

-(void)selectWordRows:(NSIndexSet *)inRows
{
	[[mDocument window] makeFirstResponder:[self wordTable]];
	[[self wordTable] selectRowIndexes:inRows byExtendingSelection:NO];
}

// Typing a word: Tab and Shift-Tab go from field to field, Return adds the word and
// puts the cursor back in the first field.
-(void)testAddWordWithTabChainingAndReturn
{
	PVScript *script = [PVScript script];
	[script then:^{ [[mDocument window] makeFirstResponder:[self sourceField]]; }];
	[script wait:@"the source field to be edited" until:^BOOL { return [self isEditing:[self sourceField]]; }];
	[script then:^{ PVTypeText(@"tree"); PVPostKey(PVKeyTab, nil, 0); }];
	[script wait:@"Tab to go to the target field" until:^BOOL { return [self isEditing:[self targetField]] && [[[self sourceField] stringValue] isEqualToString:@"tree"]; }];
	[script then:^{ PVTypeText(@"arbre"); PVPostKey(PVKeyTab, nil, 0); }];
	[script wait:@"Tab to go to the comment field" until:^BOOL { return [self isEditing:[self commentField]] && [[[self targetField] stringValue] isEqualToString:@"arbre"]; }];
	[script then:^{ PVTypeText(@"a plant"); PVPostKey(PVKeyTab, nil, NSEventModifierFlagShift); }];
	[script wait:@"Shift-Tab to go back to the target field" until:^BOOL { return [self isEditing:[self targetField]] && [[[self commentField] stringValue] isEqualToString:@"a plant"]; }];
	[script then:^{ PVPostKey(PVKeyTab, nil, NSEventModifierFlagShift); }];
	[script wait:@"Shift-Tab to go back to the source field" until:^BOOL { return [self isEditing:[self sourceField]]; }];
	[script then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"Return to add the word, clear the fields and focus the source field" until:^BOOL {
		return [[mDocument allWords] count] == 5 && [self isEditing:[self sourceField]] && [[[self sourceField] stringValue] length] == 0
			&& [[[self targetField] stringValue] length] == 0 && [[[self commentField] stringValue] length] == 0;
	}];
	[script then:^{
		ProVocWord *word = [self wordWithSource:@"tree"];
		XCTAssertEqualObjects([word targetWord], @"arbre");
		XCTAssertEqualObjects([word comment], @"a plant");
		XCTAssertTrue([[self visibleSources] containsObject:@"tree"]);
		// a second word straight away, accents included
		PVTypeText(@"été"); PVPostKey(PVKeyTab, nil, 0);
	}];
	[script wait:@"the target field" until:^BOOL { return [self isEditing:[self targetField]]; }];
	[script then:^{ PVTypeText(@"summer"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the second word to be added" until:^BOOL { return [[mDocument allWords] count] == 6 && [self isEditing:[self sourceField]]; }];
	[script then:^{ XCTAssertEqualObjects([[self wordWithSource:@"été"] targetWord], @"summer"); }];
	// Return with no translation yet: nothing is added, the cursor goes to the translation
	[script then:^{ PVTypeText(@"alone"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the cursor in the empty target field" until:^BOOL { return [self isEditing:[self targetField]]; }];
	[script then:^{ XCTAssertEqual([[mDocument allWords] count], 6u); }];
	[self runScript:script];
}

// Delete key removes the selected words; Command-Z and Shift-Command-Z undo and redo.
-(void)testDeleteKeyUndoRedo
{
	PVScript *script = [PVScript script];
	[script then:^{ [self selectWordRows:[NSIndexSet indexSetWithIndex:1]]; }];
	[script wait:@"the row to be selected" until:^BOOL { return [[self wordTable] selectedRow] == 1 && [[mDocument window] firstResponder] == [self wordTable]; }];
	[script then:^{ PVPostKey(PVKeyDelete, nil, 0); }];
	[script wait:@"the word to be deleted" until:^BOOL { return [[mDocument allWords] count] == 3 && ![self wordWithSource:@"cat"]; }];
	[script then:^{ PVTypeCommand(@"z", 0); }];
	[script wait:@"Command-Z to bring it back" until:^BOOL { return [[mDocument allWords] count] == 4 && [self wordWithSource:@"cat"] && [[self visibleSources] containsObject:@"cat"]; }];
	[script then:^{ PVTypeCommand(@"z", NSEventModifierFlagShift); }];
	[script wait:@"Shift-Command-Z to delete it again" until:^BOOL { return [[mDocument allWords] count] == 3 && ![self wordWithSource:@"cat"]; }];
	[script then:^{ PVTypeCommand(@"z", 0); }];
	[script wait:@"undo again" until:^BOOL { return [[mDocument allWords] count] == 4; }];
	// several words at once
	[script then:^{ [self selectWordRows:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)]]; PVPostKey(PVKeyDelete, nil, 0); }];
	[script wait:@"three words to be deleted" until:^BOOL { return [[mDocument allWords] count] == 1; }];
	[script then:^{ PVTypeCommand(@"z", 0); }];
	[script wait:@"undo" until:^BOOL { return [[mDocument allWords] count] == 4; }];
	[self runScript:script];
}

// Command-F puts the cursor in the search field; typing filters the list.
-(void)testFindFiltersTheList
{
	PVScript *script = [PVScript script];
	[script then:^{ [self selectWordRows:[NSIndexSet indexSetWithIndex:0]]; PVTypeCommand(@"f", 0); }];
	[script wait:@"the search field to be edited" until:^BOOL { return [self isEditing:[self searchField]]; }];
	[script then:^{ PVTypeText(@"ch"); }];
	[script wait:@"the list to show the words containing 'ch'" until:^BOOL { return [[NSSet setWithArray:[self visibleSources]] isEqualToSet:[NSSet setWithArray:@[@"cat", @"dog"]]]; }];
	[script then:^{ PVTypeText(@"i"); }];
	[script wait:@"only 'chien'" until:^BOOL { return [[self visibleSources] isEqualToArray:@[@"dog"]]; }];
	[script then:^{ PVPostKey(PVKeyDelete, nil, 0); PVPostKey(PVKeyDelete, nil, 0); PVPostKey(PVKeyDelete, nil, 0); }];
	[script wait:@"all the words again" until:^BOOL { return [[self visibleWords] count] == 4; }];
	[self runScript:script];
}

// Command-A / Shift-Command-A, Shift-Command-F (flag), Command-digit (label) on the selection.
-(void)testSelectionFlagAndLabelShortcuts
{
	PVScript *script = [PVScript script];
	[script then:^{ [self selectWordRows:[NSIndexSet indexSetWithIndex:0]]; PVTypeCommand(@"a", 0); }];
	[script wait:@"Command-A to select all the words" until:^BOOL { return [[mDocument selectedWords] count] == 4; }];
	[script then:^{ PVTypeCommand(@"f", NSEventModifierFlagShift); }];
	[script wait:@"Shift-Command-F to flag them" until:^BOOL { return [[[mDocument allWords] valueForKeyPath:@"@sum.mark"] intValue] == 4; }];
	[script then:^{ PVTypeCommand(@"f", NSEventModifierFlagShift); }];
	[script wait:@"Shift-Command-F to unflag them" until:^BOOL { return [[[mDocument allWords] valueForKeyPath:@"@sum.mark"] intValue] == 0; }];
	[script then:^{ PVTypeCommand(@"a", NSEventModifierFlagShift); }];
	[script wait:@"Shift-Command-A to select none" until:^BOOL { return [[mDocument selectedWords] count] == 0 && [[self wordTable] numberOfSelectedRows] == 0; }];
	[script then:^{ [self selectWordRows:[NSIndexSet indexSetWithIndex:2]]; PVTypeCommand(@"5", 0); }];
	[script wait:@"Command-5 to label the selected word" until:^BOOL { return [(ProVocWord *)[self visibleWords][2] label] == 5; }];
	[script then:^{ PVTypeCommand(@"9", 0); }];
	[script wait:@"Command-9" until:^BOOL { return [(ProVocWord *)[self visibleWords][2] label] == 9; }];
	[script then:^{ PVTypeCommand(@"0", 0); }];
	[script wait:@"Command-0 to remove the label" until:^BOOL { return [(ProVocWord *)[self visibleWords][2] label] == 0; }];
	[script then:^{
		XCTAssertEqual([[[mDocument allWords] valueForKeyPath:@"@sum.label"] intValue], 0, @"only the selected word must be labeled");
	}];
	[self runScript:script];
}

// Option-Command-1/2/3 switch between Editing, Training and History;
// Command-Right / Left / = change the difficulty of the selected words.
-(void)testModeAndDifficultyShortcuts
{
	PVScript *script = [PVScript script];
	[script then:^{ PVTypeCommand(@"2", NSEventModifierFlagOption); }];
	[script wait:@"Training" until:^BOOL { return [[mDocument valueForKey:@"mainTab"] intValue] == 0; }];
	[script then:^{ PVTypeCommand(@"3", NSEventModifierFlagOption); }];
	[script wait:@"History" until:^BOOL { return [[mDocument valueForKey:@"mainTab"] intValue] == 2; }];
	[script then:^{ PVTypeCommand(@"1", NSEventModifierFlagOption); }];
	[script wait:@"Editing" until:^BOOL { return [[mDocument valueForKey:@"mainTab"] intValue] == 1 && [[self wordTable] window] == [mDocument window]; }];
	[script then:^{ [self selectWordRows:[NSIndexSet indexSetWithIndex:0]]; PVPostKey(PVKeyRight, nil, NSEventModifierFlagCommand); }];
	[script wait:@"Command-Right to increase the difficulty" until:^BOOL { return [(ProVocWord *)[self visibleWords][0] difficulty] == 1; }];
	[script then:^{ PVPostKey(PVKeyRight, nil, NSEventModifierFlagCommand); }];
	[script wait:@"again" until:^BOOL { return [(ProVocWord *)[self visibleWords][0] difficulty] == 2; }];
	[script then:^{ PVPostKey(PVKeyLeft, nil, NSEventModifierFlagCommand); }];
	[script wait:@"Command-Left to decrease it" until:^BOOL { return [(ProVocWord *)[self visibleWords][0] difficulty] == 1; }];
	[script then:^{ PVTypeCommand(@"=", 0); }];
	[script wait:@"Command-= to reset it" until:^BOOL { return [(ProVocWord *)[self visibleWords][0] difficulty] == 0; }];
	[self runScript:script];
}

@end
