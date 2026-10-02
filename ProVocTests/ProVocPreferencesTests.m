//
//  ProVocPreferencesTests.m
//
//  The Preferences window (Command-,): every control of its five panes changes the
//  setting it shows, the settings are saved, and they take effect.
//

#import "PVScenarioTestCase.h"
#import "ProVocFontNameField.h"
#import "ProVocStartingPoint.h"

// What the Font panel is for -changeFont: when a font is chosen in it
@interface PVChosenFont : NSObject {
	NSString *mFamily;
	CGFloat mSize;
}
+(PVChosenFont *)fontWithFamily:(NSString *)inFamily size:(CGFloat)inSize;
-(NSFont *)convertFont:(NSFont *)inFont;
@end

@implementation PVChosenFont
+(PVChosenFont *)fontWithFamily:(NSString *)inFamily size:(CGFloat)inSize { PVChosenFont *font = [[[self alloc] init] autorelease]; font->mFamily = [inFamily copy]; font->mSize = inSize; return font; }
-(void)dealloc { [mFamily release]; [super dealloc]; }
-(NSFont *)convertFont:(NSFont *)inFont { return [[NSFontManager sharedFontManager] convertFont:[[NSFontManager sharedFontManager] convertFont:inFont toFamily:mFamily] toSize:mSize]; }
@end

@interface ProVocPreferencesTests : PVScenarioTestCase
@end

@implementation ProVocPreferencesTests

-(NSWindow *)preferencesWindow
{
	return [[ProVocPreferences sharedPreferences] window];
}

-(NSUserDefaults *)defaults
{
	return [NSUserDefaults standardUserDefaults];
}

-(void)tearDown
{
	[[self preferencesWindow] orderOut:nil];
	[[NSFontPanel sharedFontPanel] orderOut:nil];
	[[NSColorPanel sharedColorPanel] orderOut:nil];
	[super tearDown];
}

-(void)openPreferencesIn:(PVScript *)inScript
{
	[inScript then:^{ PVTypeCommand(@",", 0); }];
	[inScript wait:@"the Preferences window (Command-,)" timeout:10 until:^BOOL { return [[self preferencesWindow] isKeyWindow]; }];
}

// A click on an item of the toolbar of the Preferences window
-(void)selectPane:(NSUInteger)inIndex in:(PVScript *)inScript
{
	[inScript then:^{
		NSToolbarItem *item = [[[self preferencesWindow] toolbar] items][inIndex];
		[NSApp sendAction:[item action] to:[item target] from:item];
	}];
	[inScript wait:[NSString stringWithFormat:@"the pane %lu", (unsigned long)inIndex] until:^BOOL {
		NSArray *panes = [[ProVocPreferences sharedPreferences] valueForKey:@"mPaneViews"];
		return [panes[inIndex] window] == [self preferencesWindow] && [[[[self preferencesWindow] toolbar] selectedItemIdentifier] isEqual:[[[[self preferencesWindow] toolbar] items][inIndex] itemIdentifier]];
	}];
}

-(NSArray *)controlsIn:(NSView *)inView boundTo:(NSString *)inBinding
{
	NSMutableArray *controls = [NSMutableArray array];
	NSMutableArray *views = [NSMutableArray arrayWithObject:inView];
	while ([views count] > 0) {
		NSView *view = views[0];
		[views removeObjectAtIndex:0];
		if ([[[view infoForBinding:inBinding] objectForKey:NSObservedKeyPathKey] hasPrefix:@"values."])
			[controls addObject:view];
		[views addObjectsFromArray:[view subviews]];
	}
	return controls;
}

-(NSString *)defaultsKeyOf:(NSView *)inControl binding:(NSString *)inBinding
{
	return [[[inControl infoForBinding:inBinding] objectForKey:NSObservedKeyPathKey] substringFromIndex:[@"values." length]];
}

// Every check box, text field, stepper, slider and pop-up of a pane that shows a
// setting of the application changes it when it is used, and the setting is saved.
-(void)exercisePane:(NSUInteger)inIndex in:(PVScript *)inScript expectedSettings:(NSUInteger)inMinimum
{
	NSView *(^pane)(void) = ^{ return (NSView *)[[ProVocPreferences sharedPreferences] valueForKey:@"mPaneViews"][inIndex]; };
	NSMutableSet *exercised = [NSMutableSet set];
	[self selectPane:inIndex in:inScript];
	[inScript then:^{
		NSString *domain = [[NSBundle mainBundle] bundleIdentifier];
		for (NSControl *control in [self controlsIn:pane() boundTo:NSValueBinding]) {
			NSString *key = [self defaultsKeyOf:control binding:NSValueBinding];
			if (![control isEnabled] || [control isHiddenOrHasHiddenAncestor])
				continue;
			id before = [[self defaults] objectForKey:key];
			if ([control isKindOfClass:[NSButton class]] && ![control isKindOfClass:[NSPopUpButton class]]) {
				[(NSButton *)control performClick:nil];
				XCTAssertEqual([[self defaults] boolForKey:key], ![before boolValue], @"the check box of %@ does not change the setting", key);
				XCTAssertNotNil([[[self defaults] persistentDomainForName:domain] objectForKey:key], @"%@ is not saved", key);
				[(NSButton *)control performClick:nil];
				XCTAssertEqual([[self defaults] boolForKey:key], [before boolValue], @"the check box of %@ does not change the setting back", key);
			} else if ([control isKindOfClass:[NSStepper class]]) {
				NSStepper *stepper = (NSStepper *)control;
				double value = [stepper doubleValue];
				BOOL up = value + [stepper increment] <= [stepper maxValue];
				[stepper setDoubleValue:value + (up ? 1 : -1) * [stepper increment]];
				[stepper sendAction:[stepper action] to:[stepper target]];
				NSDictionary *binding = [stepper infoForBinding:NSValueBinding];
				[[binding objectForKey:NSObservedObjectKey] setValue:@([stepper doubleValue]) forKeyPath:[binding objectForKey:NSObservedKeyPathKey]];
				XCTAssertEqualWithAccuracy([[self defaults] doubleForKey:key], value + (up ? 1 : -1) * [stepper increment], 0.001, @"the stepper of %@", key);
				[[binding objectForKey:NSObservedObjectKey] setValue:before forKeyPath:[binding objectForKey:NSObservedKeyPathKey]];
			} else if ([control isKindOfClass:[NSColorWell class]] || [control isKindOfClass:[NSTextField class]] || [control isKindOfClass:[NSSlider class]])
				continue;	// the sliders: below, with clicks; the fields: with real typing; the wells: in the test of the colors
			else
				XCTFail(@"a %@ shows the setting %@: not exercised", [control className], key);
			[exercised addObject:key];
		}
		for (NSString *binding in @[NSSelectedTagBinding, NSSelectedIndexBinding])
			for (NSPopUpButton *popUp in [self controlsIn:pane() boundTo:binding]) {
				NSString *key = [self defaultsKeyOf:popUp binding:binding];
				if (![popUp isKindOfClass:[NSPopUpButton class]] || ![popUp isEnabled] || [popUp isHiddenOrHasHiddenAncestor])
					continue;
				id before = [[self defaults] objectForKey:key];
				for (NSMenuItem *item in [[popUp menu] itemArray]) {
					if ([item isSeparatorItem])
						continue;
					[[popUp menu] performActionForItemAtIndex:[[popUp menu] indexOfItem:item]];
					XCTAssertEqual([[self defaults] integerForKey:key], binding == NSSelectedTagBinding ? [item tag] : [[popUp menu] indexOfItem:item], @"the pop-up of %@ after choosing %@", key, [item title]);
				}
				[[[popUp infoForBinding:binding] objectForKey:NSObservedObjectKey] setValue:before forKeyPath:[[popUp infoForBinding:binding] objectForKey:NSObservedKeyPathKey]];
				[exercised addObject:key];
			}
		// matrices of radio buttons
		for (NSMatrix *matrix in [self controlsIn:pane() boundTo:NSSelectedTagBinding])
			if ([matrix isKindOfClass:[NSMatrix class]]) {
				NSString *key = [self defaultsKeyOf:matrix binding:NSSelectedTagBinding];
				id before = [[self defaults] objectForKey:key];
				for (NSCell *cell in [matrix cells]) {
					NSInteger row, column;
					[matrix getRow:&row column:&column ofCell:cell];
					[matrix selectCellAtRow:row column:column];
					[matrix sendAction];
					[[[matrix infoForBinding:NSSelectedTagBinding] objectForKey:NSObservedObjectKey] setValue:@([cell tag]) forKeyPath:[[matrix infoForBinding:NSSelectedTagBinding] objectForKey:NSObservedKeyPathKey]];
					XCTAssertEqual([[self defaults] integerForKey:key], [cell tag], @"the radio buttons of %@", key);
				}
				[[[matrix infoForBinding:NSSelectedTagBinding] objectForKey:NSObservedObjectKey] setValue:before forKeyPath:[[matrix infoForBinding:NSSelectedTagBinding] objectForKey:NSObservedKeyPathKey]];
				[exercised addObject:key];
			}
		PVSaveWindowScreenshot([self preferencesWindow], [NSString stringWithFormat:@"windows/preferences-pane-%lu", (unsigned long)inIndex]);
	}];
	// the sliders: a click near one end, then near the other
	for (NSSlider *slider in [self controlsIn:pane() boundTo:NSValueBinding]) {
		if (![slider isKindOfClass:[NSSlider class]])
			continue;
		NSString *key = [self defaultsKeyOf:slider binding:NSValueBinding];
		[exercised addObject:key];
		__block double before = 0;
		for (int end = 1; end >= 0; end--) {
			[inScript then:^{
				before = [[self defaults] doubleForKey:key];
				if (![slider isEnabled])	// (the speed of the slideshow: only when it advances by itself)
					[[self defaults] setBool:YES forKey:@"slideshowAutoAdvance"];
				NSRect bounds = [slider bounds];
				PVClickAtPoint(slider, NSMakePoint(end ? NSMaxX(bounds) - 12 : NSMinX(bounds) + 12, NSMidY(bounds)), 1, 0);
			}];
			[inScript wait:[NSString stringWithFormat:@"a click at the %@ of the slider of %@ to change the setting", end ? @"right" : @"left", key] until:^BOOL {
				double value = [[self defaults] doubleForKey:key];
				return value != before && fabs(value - (end ? [slider maxValue] : [slider minValue])) < ([slider maxValue] - [slider minValue]) / 4;
			}];
		}
	}
	[inScript then:^{ XCTAssertTrue([exercised count] >= inMinimum, @"pane %lu: only %lu settings exercised: %@", (unsigned long)inIndex, (unsigned long)[exercised count], exercised); }];
}

// Types in a text field of the Preferences window that shows a setting: click, select all, type, Tab
-(void)type:(NSString *)inText inFieldOfSetting:(NSString *)inKey pane:(NSUInteger)inIndex in:(PVScript *)inScript
{
	NSTextField *(^field)(void) = ^{
		for (NSTextField *candidate in [self controlsIn:[[ProVocPreferences sharedPreferences] valueForKey:@"mPaneViews"][inIndex] boundTo:NSValueBinding])
			if ([candidate isKindOfClass:[NSTextField class]] && [candidate isEditable] && [[self defaultsKeyOf:candidate binding:NSValueBinding] isEqualToString:inKey])
				return candidate;
		return (NSTextField *)nil;
	};
	[inScript then:^{
		XCTAssertNotNil(field(), @"no text field for %@", inKey);
		XCTAssertTrue([field() isEnabled], @"the field of %@ is disabled", inKey);
		PVClickView(field(), 1, 0);
	}];
	[inScript wait:[NSString stringWithFormat:@"the field of %@ to be edited", inKey] until:^BOOL { return [field() currentEditor] != nil && [[self preferencesWindow] firstResponder] == [field() currentEditor]; }];
	[inScript then:^{ PVTypeCommand(@"a", 0); PVTypeText(inText); PVPostKey(PVKeyTab, nil, 0); }];
	[inScript wait:[NSString stringWithFormat:@"%@ to be %@", inKey, inText] until:^BOOL { return [[[[self defaults] objectForKey:inKey] description] isEqualToString:inText]; }];
}

#pragma mark General and Training

// The General and Training panes; the separators typed there are those the answers are checked with.
-(void)testGeneralAndTrainingPanes
{
	PVScript *script = [PVScript script];
	[self openPreferencesIn:script];
	[self exercisePane:0 in:script expectedSettings:7];
	[self type:@"|" inFieldOfSetting:PVPrefSynonymSeparator pane:0 in:script];
	[script then:^{
		// the comment separator can only be typed once its check box is checked
		NSButton *box = nil;
		for (NSButton *candidate in [self controlsIn:[[ProVocPreferences sharedPreferences] valueForKey:@"mPaneViews"][0] boundTo:NSValueBinding])
			if ([[self defaultsKeyOf:candidate binding:NSValueBinding] isEqualToString:PVPrefsUseCommentsSeparator] && [candidate isKindOfClass:[NSButton class]])
				box = candidate;
		XCTAssertNotNil(box);
		if (![[self defaults] boolForKey:PVPrefsUseCommentsSeparator])
			PVClickView(box, 1, 0);
	}];
	[script wait:@"the comment separator to be used" until:^BOOL { return [[self defaults] boolForKey:PVPrefsUseCommentsSeparator]; }];
	[self type:@"#" inFieldOfSetting:PVPrefCommentsSeparator pane:0 in:script];
	[self exercisePane:1 in:script expectedSettings:5];
	[script then:^{ PVTypeCommand(@"w", 0); }];
	[script wait:@"Command-W to close the Preferences" until:^BOOL { return ![[self preferencesWindow] isVisible] && [[mDocument window] isKeyWindow]; }];
	// a test with the new separators: "maison | domicile" has two answers; "# ..." is a comment
	[script then:^{
		[[self wordWithSource:@"house"] setTargetWord:@"maison | domicile # a building"];
		[mDocument setValue:@YES forKey:@"dontShuffleWords"];
		PVTypeCommand(@"r", 0);
	}];
	[script wait:@"question 1" until:^BOOL { return [self showsQuestionNumber:1] && [[self question] isEqualToString:@"house"]; }];
	[script then:^{ PVTypeText(@"domicile"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"one of the two answers to be accepted, the full answer displayed" until:^BOOL { return [[self wordWithSource:@"house"] right] == 1 && [[self wordWithSource:@"house"] wrong] == 0; }];
	[script then:^{ PVPostKey(PVKeyEscape, nil, NSEventModifierFlagOption); }];
	[script wait:@"the test to be over" until:^BOOL { return [self testIsOver]; }];
	[self runScript:script];
}

#pragma mark Colors and labels

// The Labels pane: titles and colors of the labels, Restore Defaults; and the two color
// wells of the application (comment text, background of the full-screen test).
-(void)testLabelTitlesAndColors
{
	ProVocPreferences *preferences = [ProVocPreferences sharedPreferences];
	NSView *(^pane)(void) = ^{ return (NSView *)[preferences valueForKey:@"mPaneViews"][4]; };
	id (^controlBoundTo)(NSString *) = ^(NSString *key) { return [self viewIn:pane() withBinding:NSValueBinding to:key]; };
	NSString *originalTitle = [[preferences valueForKey:@"labelTitle1"] copy];
	NSColor *red = [NSColor colorWithCalibratedRed:1 green:0 blue:0 alpha:1], *teal = [NSColor colorWithCalibratedRed:0 green:0.5 blue:0.5 alpha:1];
	PVScript *script = [PVScript script];
	[self openPreferencesIn:script];
	[self selectPane:4 in:script];
	[script then:^{
		NSTextField *field = controlBoundTo(@"labelTitle1");
		XCTAssertNotNil(field, @"no field for the title of the first label");
		PVSaveWindowScreenshot([self preferencesWindow], @"windows/preferences-labels");
		PVClickView(field, 1, 0);
	}];
	[script wait:@"the title of the first label to be edited" until:^BOOL { return [(NSTextField *)controlBoundTo(@"labelTitle1") currentEditor] != nil; }];
	[script then:^{ PVTypeCommand(@"a", 0); PVTypeText(@"Verbs"); PVPostKey(PVKeyTab, nil, 0); }];
	[script wait:@"the new title in the settings and in the Label menu" until:^BOOL {
		NSArray *labels = [[self defaults] objectForKey:PVLabels];
		return [labels[0][PVLabelTitle] isEqualToString:@"Verbs"] && [[mDocument stringForLabel:1] isEqualToString:@"Verbs"];
	}];
	[script then:^{
		NSMenuItem *item = [self menuItemWithAction:@selector(setLabel:) tag:1];
		PVPrepareMenu([item menu]);
		XCTAssertEqualObjects([item title], @"Verbs", @"the Label menu does not follow the title of the label");
		// the color of the first label: a click on its well, a color chosen in the color panel
		NSColorWell *well = controlBoundTo(@"labelColorData1");
		XCTAssertNotNil(well, @"no color well for the first label");
		PVClickView(well, 1, 0);
	}];
	[script wait:@"the color panel, for the well of the first label" timeout:10 until:^BOOL { return [[NSColorPanel sharedColorPanel] isVisible] && [(NSColorWell *)controlBoundTo(@"labelColorData1") isActive]; }];
	[script then:^{
		[[NSColorPanel sharedColorPanel] setColor:teal];
	}];
	[script wait:@"the color of the first label to be the chosen one" until:^BOOL {
		NSColor *color = [[mDocument colorForLabel:1] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
		return fabs([color greenComponent] - 0.5) < 0.05 && [color redComponent] < 0.05;
	}];
	[script then:^{
		[(NSColorWell *)controlBoundTo(@"labelColorData1") deactivate];
		[[NSColorPanel sharedColorPanel] orderOut:nil];
		NSButton *restore = [self buttonWithAction:@selector(restoreDefaultLabels:) inView:pane()];
		XCTAssertNotNil(restore, @"no Restore Defaults button");
		PVClickView(restore, 1, 0);
	}];
	[script wait:@"Restore Defaults to bring the title back" until:^BOOL { return [[preferences valueForKey:@"labelTitle1"] isEqualToString:originalTitle] && [[mDocument stringForLabel:1] isEqualToString:originalTitle]; }];
	// the two other color wells: the text of the comments (Fonts pane) and the background of the test (General pane)
	for (NSArray *well in @[@[@3, @"commentTextColor"], @[@0, @"testBackgroundColor"]]) {
		NSUInteger paneIndex = [well[0] unsignedIntegerValue];
		NSString *key = well[1];
		NSColorWell *(^colorWell)(void) = ^{ return (NSColorWell *)[self viewIn:[preferences valueForKey:@"mPaneViews"][paneIndex] withBinding:NSValueBinding to:[@"values." stringByAppendingString:key]]; };
		[self selectPane:paneIndex in:script];
		[script then:^{ XCTAssertNotNil(colorWell(), @"no color well for %@", key); PVClickView(colorWell(), 1, 0); }];
		[script wait:[NSString stringWithFormat:@"the color panel for %@", key] timeout:10 until:^BOOL { return [[NSColorPanel sharedColorPanel] isVisible] && [colorWell() isActive]; }];
		[script then:^{
			[[NSColorPanel sharedColorPanel] setColor:red];
		}];
		[script wait:[NSString stringWithFormat:@"%@ to be red", key] until:^BOOL {
			NSData *data = [[self defaults] objectForKey:key];
			NSColor *color = [data isKindOfClass:[NSData class]] ? [[NSUnarchiver unarchiveObjectWithData:data] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] : nil;
			return color && [color redComponent] > 0.9 && [color greenComponent] < 0.2;
		}];
		[script then:^{ [colorWell() deactivate]; [[NSColorPanel sharedColorPanel] orderOut:nil]; }];
	}
	[self runScript:script];
}

#pragma mark Fonts

// The Fonts pane: Set... opens the Font panel, whose choice becomes the font of the
// words in the list; Option turns Set... into Reset; sizes and writing directions.
-(void)testFontsPane
{
	ProVocPreferences *preferences = [ProVocPreferences sharedPreferences];
	NSView *(^pane)(void) = ^{ return (NSView *)[preferences valueForKey:@"mPaneViews"][3]; };
	NSArray *(^setButtons)(void) = ^{
		NSMutableArray *buttons = [NSMutableArray array];
		NSMutableArray *views = [NSMutableArray arrayWithObject:pane()];
		while ([views count] > 0) {
			NSView *view = views[0];
			[views removeObjectAtIndex:0];
			if ([view isKindOfClass:[NSButton class]] && [(NSButton *)view action] == @selector(userSetFont:))
				[buttons addObject:view];
			[views addObjectsFromArray:[view subviews]];
		}
		[buttons sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
			CGFloat ya = NSMaxY([a convertRect:[a bounds] toView:nil]), yb = NSMaxY([b convertRect:[b bounds] toView:nil]);
			return ya > yb ? NSOrderedAscending : ya < yb ? NSOrderedDescending : NSOrderedSame;
		}];
		return buttons;
	};
	NSTableView *table = [mDocument valueForKey:@"mWordTableView"];
	__block CGFloat rowHeight = 0;
	PVScript *script = [PVScript script];
	[self openPreferencesIn:script];
	[self exercisePane:3 in:script expectedSettings:9];
	[script then:^{
		rowHeight = [table rowHeight];
		XCTAssertEqual([setButtons() count], 3u, @"one Set... button for each of the three fonts");
		XCTAssertEqualObjects([setButtons()[0] title], NSLocalizedString(@"Font Set Button Title", @""));
		PVClickView(setButtons()[0], 1, 0);
	}];
	[script wait:@"the Font panel" timeout:10 until:^BOOL { return [[NSFontPanel sharedFontPanel] isVisible]; }];
	// a font chosen in the Font panel: it sends -changeFont: through the application
	[script then:^{ [NSApp sendAction:@selector(changeFont:) to:nil from:[PVChosenFont fontWithFamily:@"Courier" size:24]]; }];
	[script wait:@"the first font to be Courier 24" until:^BOOL {
		return [[[self defaults] stringForKey:@"sourceFontFamilyName"] isEqualToString:@"Courier"] && [[self defaults] floatForKey:@"sourceFontSize"] == 24;
	}];
	[script then:^{
		XCTAssertTrue([[preferences valueForKey:@"sourceFontCaption"] rangeOfString:@"Courier"].location != NSNotFound, @"caption: %@", [preferences valueForKey:@"sourceFontCaption"]);
		XCTAssertTrue([table rowHeight] > rowHeight, @"the rows of the list did not grow with the font (%g, was %g)", [table rowHeight], rowHeight);
		XCTAssertEqualObjects([mDocument valueForKey:@"sourceFontFamilyName"], @"Courier", @"the document does not use the font");
		PVSaveWindowScreenshot([mDocument window], @"windows/document-with-courier-24");
		[[NSFontPanel sharedFontPanel] orderOut:nil];
		[[self preferencesWindow] makeKeyAndOrderFront:nil];
	}];
	[script wait:@"the Preferences window in front" until:^BOOL { return [[self preferencesWindow] isKeyWindow]; }];
	// with Option the button resets the font
	[script then:^{ PVPostFlagsChanged(NSEventModifierFlagOption); }];
	[script wait:@"the button to read Reset while Option is down" until:^BOOL { return [[setButtons()[0] title] isEqualToString:NSLocalizedString(@"Font Reset Button Title", @"")]; }];
	[script then:^{ PVClickView(setButtons()[0], 1, NSEventModifierFlagOption); }];
	[script wait:@"the font to be the system font again" until:^BOOL {
		return [[[self defaults] stringForKey:@"sourceFontFamilyName"] isEqualToString:[[NSFont systemFontOfSize:0] familyName]] && [[self defaults] floatForKey:@"sourceFontSize"] == [NSFont systemFontSize];
	}];
	[script then:^{
		PVPostFlagsChanged(0);
		XCTAssertFalse([[NSFontPanel sharedFontPanel] isVisible], @"Reset opened the Font panel");
		XCTAssertTrue(fabs([table rowHeight] - rowHeight) < 0.5, @"the rows of the list did not shrink back (%g, was %g)", [table rowHeight], rowHeight);
	}];
	[self runScript:script];
}

#pragma mark Languages

// The Languages pane: + adds a language (its name is typed at once), which the
// documents then offer; the check boxes say what counts in an answer; Delete removes it.
-(void)testLanguagesPane
{
	ProVocPreferences *preferences = [ProVocPreferences sharedPreferences];
	NSTableView *(^table)(void) = ^{ return (NSTableView *)[preferences valueForKey:@"mLanguageTableView"]; };
	NSPopUpButton *sourcePopUp = [mDocument valueForKey:@"mSourceLanguagePopUp"];
	__block NSInteger rows = 0;
	NSDictionary *(^language)(NSString *) = ^(NSString *name) {
		for (NSDictionary *description in [[self defaults] objectForKey:PVPrefsLanguages][@"Languages"])
			if ([description[@"Name"] isEqualToString:name])
				return description;
		return (NSDictionary *)nil;
	};
	PVScript *script = [PVScript script];
	[self openPreferencesIn:script];
	[self selectPane:2 in:script];
	[script then:^{
		rows = [table() numberOfRows];
		XCTAssertTrue(rows >= 2, @"languages: %ld", (long)rows);
		PVSaveWindowScreenshot([self preferencesWindow], @"windows/preferences-languages");
		NSButton *add = [self buttonWithAction:@selector(newLanguage:) inView:[preferences valueForKey:@"mPaneViews"][2]];
		XCTAssertNotNil(add, @"no + button");
		PVClickView(add, 1, 0);
	}];
	[script wait:@"a new language, its name being edited" until:^BOOL { return [table() numberOfRows] == rows + 1 && [table() editedRow] == rows; }];
	[script then:^{ PVTypeText(@"Klingon"); PVPostKey(PVKeyReturn, nil, 0); }];
	[script wait:@"the language to be saved and offered by the document" until:^BOOL {
		return language(@"Klingon") != nil && [sourcePopUp indexOfItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Language PopUp Item Format (%@)", @""), @"Klingon"]] >= 0;
	}];
	[script then:^{
		if ([table() editedRow] >= 0)
			[[self preferencesWindow] makeFirstResponder:table()];
		XCTAssertTrue([language(@"Klingon")[PVCaseSensitive] boolValue], @"a new language is case sensitive");
		// its "case sensitive" check box
		NSRect cell = [table() frameOfCellAtColumn:[table() columnWithIdentifier:PVCaseSensitive] row:rows];
		PVClickAtPoint(table(), NSMakePoint(NSMidX(cell), NSMidY(cell)), 1, 0);
	}];
	[script wait:@"the check box to make the language case insensitive" until:^BOOL { return ![language(@"Klingon")[PVCaseSensitive] boolValue]; }];
	// Delete removes the selected language
	[script then:^{
		[[self preferencesWindow] makeFirstResponder:table()];
		[table() selectRowIndexes:[NSIndexSet indexSetWithIndex:rows] byExtendingSelection:NO];
		PVPostKey(PVKeyDelete, nil, 0);
	}];
	[script wait:@"the Delete key to remove the language" until:^BOOL {
		return language(@"Klingon") == nil && [table() numberOfRows] == rows && [sourcePopUp indexOfItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Language PopUp Item Format (%@)", @""), @"Klingon"]] < 0;
	}];
	[self runScript:script];
}

#pragma mark Backgrounds

// General pane: animated background on or off, and which one.
-(void)testBackgroundSettings
{
	ProVocPreferences *preferences = [ProVocPreferences sharedPreferences];
	NSView *(^pane)(void) = ^{ return (NSView *)[preferences valueForKey:@"mPaneViews"][0]; };
	PVScript *script = [PVScript script];
	[self openPreferencesIn:script];
	[self selectPane:0 in:script];
	[script then:^{
		NSButton *box = [self viewIn:pane() withBinding:NSValueBinding to:@"enableBackground"];
		NSPopUpButton *popUp = [self viewIn:pane() withBinding:NSSelectedIndexBinding to:@"indexOfSelectedBackgroundStyle"];
		XCTAssertTrue(box && popUp, @"the background controls: %@ %@", box, popUp);
		XCTAssertTrue([box isEnabled], @"animated backgrounds are not available");
		if (![[self defaults] boolForKey:PVEnableBackground])
			[box performClick:nil];
		XCTAssertTrue([[self defaults] boolForKey:PVEnableBackground]);
		XCTAssertTrue([popUp isEnabled]);
		// the four backgrounds that come with ProVoc, then "Choose..."
		XCTAssertEqual([popUp numberOfItems], 5, @"backgrounds: %@", [popUp itemTitles]);
		for (NSInteger index = 3; index >= 0; index--) {
			[[popUp menu] performActionForItemAtIndex:index];
			XCTAssertEqual([[preferences valueForKey:@"indexOfSelectedBackgroundStyle"] integerValue], index, @"background %@", [popUp itemTitleAtIndex:index]);
			XCTAssertEqual([ProVocBackgroundStyle indexOfCurrentBackgroundStyle], (int)index);
		}
		[box performClick:nil];
		XCTAssertFalse([[self defaults] boolForKey:PVEnableBackground]);
		XCTAssertFalse([popUp isEnabled], @"the pop-up stays enabled without animated background");
		[box performClick:nil];
	}];
	[self runScript:script];
}

@end
