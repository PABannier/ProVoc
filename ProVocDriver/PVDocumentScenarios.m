//
//  PVDocumentScenarios.m
//
//  New, Save, Save As, Close and its prompt, Open Recent, Revert, Quit and its prompt:
//  what depends on the document knowing that it was edited.
//
//  The Open and Save panels of macOS run in another process (their window only hosts a
//  remote view): key events posted to ProVoc's event queue do not reach them. They are
//  answered through the NSSavePanel object instead (-setNameFieldStringValue:, -ok:, -cancel:).
//

#import "PVDriver.h"

@interface PVScenarios (Documents)
@end

@implementation PVScenarios (Documents)

-(ProVocDocument *)document
{
	return [PVScenarios document];
}

-(BOOL)isEditing:(NSTextField *)inField
{
	id firstResponder = [[inField window] firstResponder];
	return [[inField window] isKeyWindow] && [firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == (id)inField;
}

// Types a word in the fields under the list, as a user does: click, source, Tab, target, Return
-(void)addWord:(NSString *)inSource translation:(NSString *)inTarget in:(PVScript *)inScript
{
	__block NSUInteger count = 0;
	[inScript then:^{
		count = [[[self document] allWords] count];
		PVClickView([[self document] valueForKey:@"mSourceTextField"], 1, 0);
	}];
	[inScript wait:@"the source field to be edited" until:^BOOL { return [self isEditing:[[self document] valueForKey:@"mSourceTextField"]]; }];
	[inScript then:^{ PVTypeText(inSource); PVPostKey(PVKeyTab, nil, 0); }];
	[inScript wait:@"the target field to be edited" until:^BOOL { return [self isEditing:[[self document] valueForKey:@"mTargetTextField"]]; }];
	[inScript then:^{ PVTypeText(inTarget); PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:[NSString stringWithFormat:@"the word %@ to be added", inSource] until:^BOOL { return [[[self document] allWords] count] == count + 1; }];
	[inScript wait:@"the document to be marked as edited" until:^BOOL { return [[self document] isDocumentEdited] && [[[self document] window] isDocumentEdited]; }];
}

-(NSSavePanel *)savePanel
{
	NSWindow *sheet = [[[self document] window] attachedSheet];
	return [sheet isKindOfClass:[NSSavePanel class]] ? (NSSavePanel *)sheet : nil;
}

// The sheet asking what to do with the changes (or to confirm), which is not a save panel
-(NSWindow *)alertSheet
{
	NSWindow *sheet = [[[self document] window] attachedSheet];
	return sheet && ![sheet isKindOfClass:[NSSavePanel class]] ? sheet : nil;
}

// The save panel comes as a sheet. It cannot be filled in and confirmed from here (it
// lives in another process, and -[NSSavePanel ok:] is "not implemented" for it): the
// panel is checked and cancelled, then the document is saved where the panel would
// have said, with the method that NSDocument calls when the panel is confirmed.
-(void)answerSavePanelWithName:(NSString *)inName operation:(NSSaveOperationType)inOperation in:(PVScript *)inScript
{
	NSString *path = [[[PVScenarios workDirectory] stringByAppendingPathComponent:inName] stringByAppendingPathExtension:@"pvoc"];
	__block BOOL saved = NO;
	[inScript wait:@"the save panel" timeout:15 until:^BOOL { return [self savePanel] != nil; }];
	[inScript then:^{
		NSSavePanel *panel = [self savePanel];
		PVExpect([[panel allowedFileTypes] containsObject:@"pvoc"], @"the save panel does not save .pvoc files: %@", [panel allowedFileTypes]);
		[panel cancel:nil];
	}];
	[inScript wait:@"the save panel to close" timeout:15 until:^BOOL { return [self savePanel] == nil; }];
	[inScript then:^{
		if (inOperation == NSSaveOperation)
			PVExpect([[self document] isDocumentEdited], @"cancelling the save panel should leave the document edited");
		[[self document] saveToURL:[NSURL fileURLWithPath:path] ofType:@"ProVocDocumentPackage" forSaveOperation:inOperation completionHandler:^(NSError *inError) {
			PVExpect(inError == nil, @"saving failed: %@", inError);
			saved = YES;
		}];
	}];
	[inScript wait:[NSString stringWithFormat:@"the document to be saved as %@", inName] timeout:20 until:^BOOL {
		return saved && [[NSFileManager defaultManager] fileExistsAtPath:path] && ![[self document] isDocumentEdited]
			&& [[[[[self document] fileURL] path] stringByResolvingSymlinksInPath] isEqualToString:[path stringByResolvingSymlinksInPath]];
	}];
}

// Presses the key equivalent that a button of an alert declares (Return, Esc, Command-D...)
-(void)pressKeyOfButton:(NSButton *)inButton
{
	NSString *key = [inButton keyEquivalent];
	NSEventModifierFlags modifiers = [inButton keyEquivalentModifierMask] & (NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl);
	PVExpect([key length] == 1, @"the button %@ has no key equivalent", [inButton title]);
	if ([key length] != 1)
		return;
	unichar character = [key characterAtIndex:0];
	if (character == '\r')
		PVPostKey(PVKeyReturn, nil, modifiers);
	else if (character == 27)
		PVPostKey(PVKeyEscape, nil, modifiers);
	else if (character == NSBackspaceCharacter || character == NSDeleteCharacter)
		PVPostKey(PVKeyDelete, nil, modifiers);
	else if (modifiers & NSEventModifierFlagCommand)
		PVTypeCommand(key, modifiers & ~NSEventModifierFlagCommand);
	else
		PVTypeText(key);
}

// The buttons of the "save the changes?" sheet, in the order Save, Cancel, Don't Save
-(NSArray *)buttonsOfAlertSheet
{
	NSMutableArray *buttons = [NSMutableArray array];
	NSMutableArray *views = [NSMutableArray arrayWithObject:[[self alertSheet] contentView]];
	while ([views count] > 0) {
		NSView *view = views[0];
		[views removeObjectAtIndex:0];
		if ([view isKindOfClass:[NSButton class]] && [[(NSButton *)view title] length] > 0 && ![view isHidden])
			[buttons addObject:view];
		[views addObjectsFromArray:[view subviews]];
	}
	return buttons;
}

-(NSButton *)alertButtonWithKey:(unichar)inCharacter
{
	for (NSButton *button in [self buttonsOfAlertSheet])
		if ([[button keyEquivalent] length] == 1 && [[button keyEquivalent] characterAtIndex:0] == inCharacter)
			return button;
	return nil;
}

// The button that is neither the default one (Return) nor Cancel (Esc): "Don't Save"
-(NSButton *)dontSaveButton
{
	for (NSButton *button in [self buttonsOfAlertSheet]) {
		unichar character = [[button keyEquivalent] length] == 1 ? [[button keyEquivalent] characterAtIndex:0] : 0;
		if (character != '\r' && character != 27)
			return button;
	}
	return nil;
}

-(NSMenu *)openRecentMenu
{
	return [[PVScenarios menuItemWithAction:@selector(clearRecentDocuments:)] menu];
}

// File > Open Recent > first item
-(void)openMostRecentDocumentIn:(PVScript *)inScript expectingWords:(NSArray *)inWords
{
	// without document, the starting point window comes back (after the About window of a first launch)
	[inScript wait:@"the starting point window" timeout:15 until:^BOOL {
		return [[[NSClassFromString(@"ProVocStartingPoint") performSelector:@selector(defaultStartingPoint)] window] isKeyWindow];
	}];
	[inScript wait:@"the document in the Open Recent menu" timeout:10 until:^BOOL {
		NSMenu *menu = [self openRecentMenu];
		PVPrepareMenu(menu);
		return [menu numberOfItems] >= 3 && [[menu itemAtIndex:0] action] != @selector(clearRecentDocuments:);
	}];
	[inScript then:^{
		[[self openRecentMenu] performActionForItemAtIndex:0];
	}];
	[inScript wait:@"the recent document to open" timeout:15 until:^BOOL {
		return [[self document] fileURL] != nil && [[[self document] window] isKeyWindow] && [[PVScenarios sourceWordsOf:[self document]] isEqualToArray:inWords];
	}];
	[inScript then:^{
		PVExpect(![[self document] isDocumentEdited], @"a document just opened is marked as edited");
		PVExpect(![[[NSClassFromString(@"ProVocStartingPoint") performSelector:@selector(defaultStartingPoint)] window] isVisible], @"the starting point window stays with a document open");
	}];
}

-(void)closeWindowIn:(PVScript *)inScript
{
	[inScript then:^{ PVTypeCommand(@"w", 0); }];
}

// Command-N, a word, Command-S (save panel), another word, Command-S (no panel),
// Command-W (no prompt), Open Recent; then the three answers to "save the changes?".
-(void)documentNewSaveCloseReopen:(PVScript *)inScript
{
	NSDocumentController *controller = [NSDocumentController sharedDocumentController];
	NSString *path = [[PVScenarios workDirectory] stringByAppendingPathComponent:@"Deck.pvoc"];
	[inScript then:^{ PVTypeCommand(@"n", 0); }];
	[inScript wait:@"an untitled document (Command-N)" until:^BOOL { return [[controller documents] count] == 1 && [[[self document] window] isKeyWindow] && [[self document] fileURL] == nil; }];
	[inScript then:^{
		PVExpect(![[self document] isDocumentEdited], @"a new document is marked as edited");
		PVTypeCommand(@"1", NSEventModifierFlagOption);
	}];
	[inScript wait:@"the Editing view" until:^BOOL { return [[[self document] valueForKey:@"mainTab"] intValue] == 1 && [[[self document] valueForKey:@"mSourceTextField"] window] != nil; }];
	[self addWord:@"house" translation:@"maison" in:inScript];
	[inScript then:^{ PVTypeCommand(@"s", 0); }];
	[self answerSavePanelWithName:@"Deck" operation:NSSaveOperation in:inScript];
	[inScript then:^{
		PVExpectEqualObjects([[[self document] window] title], @"Deck", @"window title after saving");
		PVExpect([[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL][NSFileType] isEqual:NSFileTypeDirectory], @"a .pvoc document is a package");
	}];
	// a second word; Command-S saves without asking
	[self addWord:@"cat" translation:@"chat" in:inScript];
	[inScript then:^{ PVTypeCommand(@"s", 0); }];
	[inScript wait:@"Command-S to save at once" timeout:15 until:^BOOL { return ![[self document] isDocumentEdited] && [self savePanel] == nil; }];
	// Command-W closes without question
	[self closeWindowIn:inScript];
	[inScript wait:@"the document to close (Command-W)" until:^BOOL { return [[controller documents] count] == 0; }];
	[self openMostRecentDocumentIn:inScript expectingWords:@[@"house", @"cat"]];

	// edited + Command-W: Cancel (Esc)
	[self addWord:@"dog" translation:@"chien" in:inScript];
	[self closeWindowIn:inScript];
	[inScript wait:@"the sheet asking to save the changes" until:^BOOL { return [self alertSheet] != nil && [[self buttonsOfAlertSheet] count] == 3; }];
	[inScript then:^{
		PVSaveWindowScreenshot([self alertSheet], @"windows/save-changes-sheet");
		PVExpect([self alertButtonWithKey:'\r'] != nil, @"no default button: %@", [[self buttonsOfAlertSheet] valueForKey:@"title"]);
		PVExpect([self alertButtonWithKey:27] != nil, @"no Cancel button with Esc: %@", [[self buttonsOfAlertSheet] valueForKey:@"title"]);
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[inScript wait:@"Esc to cancel: the document stays open, still edited" until:^BOOL { return [self alertSheet] == nil && [[controller documents] count] == 1 && [[self document] isDocumentEdited]; }];
	// Don't Save (its key equivalent)
	[self closeWindowIn:inScript];
	[inScript wait:@"the sheet asking to save the changes" until:^BOOL { return [self alertSheet] != nil && [self dontSaveButton] != nil; }];
	[inScript then:^{
		for (NSButton *button in [self buttonsOfAlertSheet])
			NSLog(@"PVDriver: button \"%@\" key %@ modifiers %lx", [button title], [[[button keyEquivalent] dataUsingEncoding:NSUTF16BigEndianStringEncoding] description], (unsigned long)[button keyEquivalentModifierMask]);
		[self pressKeyOfButton:[self dontSaveButton]];
	}];
	[inScript wait:@"the document to close without saving" until:^BOOL { return [[controller documents] count] == 0; }];
	[self openMostRecentDocumentIn:inScript expectingWords:@[@"house", @"cat"]];
	// Save (Return)
	[self addWord:@"dog" translation:@"chien" in:inScript];
	[self closeWindowIn:inScript];
	[inScript wait:@"the sheet asking to save the changes" until:^BOOL { return [self alertSheet] != nil && [self alertButtonWithKey:'\r'] != nil; }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the document to be saved and closed (Return)" timeout:15 until:^BOOL { return [[controller documents] count] == 0; }];
	[self openMostRecentDocumentIn:inScript expectingWords:@[@"house", @"cat", @"dog"]];

	// Save As (Shift-Command-S): another file, the first one stays
	[inScript then:^{
		NSMenuItem *item = [PVScenarios menuItemWithAction:@selector(saveDocumentAs:)];
		PVExpectEqualObjects([item keyEquivalent], @"S", @"Save As shortcut");
		PVTypeCommand(@"s", NSEventModifierFlagShift);
	}];
	[self answerSavePanelWithName:@"Deck copy" operation:NSSaveAsOperation in:inScript];
	[inScript then:^{
		PVExpect([[NSFileManager defaultManager] fileExistsAtPath:path], @"Save As removed the original");
		PVExpectEqualObjects([[[self document] window] title], @"Deck copy", @"window title after Save As");
	}];

	// Revert: the changes go away after a confirmation
	[self addWord:@"summer" translation:@"été" in:inScript];
	[inScript then:^{
		NSMenuItem *item = [PVScenarios menuItemWithAction:@selector(revertDocumentToSaved:)];
		PVExpect(item != nil, @"no Revert menu item");
		[[item menu] update];
		PVExpect([item isEnabled], @"Revert is disabled although the document is edited");
		[[item menu] performActionForItemAtIndex:[[item menu] indexOfItem:item]];
	}];
	[inScript wait:@"the sheet asking to confirm" until:^BOOL { return [self alertSheet] != nil && [self alertButtonWithKey:'\r'] != nil; }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"the document to be as saved" timeout:15 until:^BOOL {
		return [self alertSheet] == nil && [[PVScenarios sourceWordsOf:[self document]] isEqualToArray:@[@"house", @"cat", @"dog"]] && ![[self document] isDocumentEdited];
	}];
	[inScript then:^{
		NSArray *visible = [[[self document] valueForKey:@"mVisibleWords"] valueForKey:@"sourceWord"];
		PVExpectEqualObjects(visible, (@[@"house", @"cat", @"dog"]), @"the list after reverting");
	}];
	[self closeWindowIn:inScript];
	[inScript wait:@"the document to close" until:^BOOL { return [[controller documents] count] == 0; }];
}

@end
