//
//  ProVocBoxesSheet.m
//  ProVoc
//

#import "ProVocBoxesSheet.h"

#import <Vision/Vision.h>

#import "ProVocDocument+Lists.h"
#import "ProVocInspector.h"
#import "ProVocPage.h"

enum { kNoDrag, kDragNew, kDragMove, kDragResize };

static const float kHandleSize = 10;
static const float kMinBoxSize = 12;

@implementation ProVocBoxesView

-(id)initWithFrame:(NSRect)inFrame
{
	if (self = [super initWithFrame:inFrame]) {
		mBoxes = [[NSMutableArray alloc] init];
		mSelection = NSNotFound;
		[self setImageScaling:NSImageScaleAxesIndependently];
		[self setEditable:NO];
		[self unregisterDraggedTypes];
	}
	return self;
}

-(void)dealloc
{
	[mBoxes release];
	[super dealloc];
}

-(BOOL)acceptsFirstResponder
{
	return YES;
}

-(ProVocBoxesSheet *)sheet
{
	return (ProVocBoxesSheet *)mDelegate;
}

-(void)setSheet:(ProVocBoxesSheet *)inSheet
{
	mDelegate = inSheet;
}

-(NSMutableArray *)boxes
{
	return mBoxes;
}

-(NSUInteger)selection
{
	return mSelection;
}

-(void)selectBoxAtIndex:(NSUInteger)inIndex
{
	mSelection = inIndex;
	[self setNeedsDisplay:YES];
}

-(NSRect)viewRectOfFraction:(NSRect)inRect
{
	NSSize size = [self bounds].size;
	return NSMakeRect(NSMinX(inRect) * size.width, (1 - NSMaxY(inRect)) * size.height, NSWidth(inRect) * size.width, NSHeight(inRect) * size.height);
}

-(NSRect)fractionOfViewRect:(NSRect)inRect
{
	NSSize size = [self bounds].size;
	return NSMakeRect(NSMinX(inRect) / size.width, 1 - NSMaxY(inRect) / size.height, NSWidth(inRect) / size.width, NSHeight(inRect) / size.height);
}

-(NSRect)viewRectOfBoxAtIndex:(NSUInteger)inIndex
{
	return [self viewRectOfFraction:[mBoxes[inIndex][@"rect"] rectValue]];
}

-(NSRect)handleOfRect:(NSRect)inRect
{
	return NSMakeRect(NSMaxX(inRect) - kHandleSize / 2, NSMinY(inRect) - kHandleSize / 2, kHandleSize, kHandleSize);
}

-(void)addBoxWithRect:(NSRect)inRect answer:(NSString *)inAnswer
{
	[mBoxes addObject:[NSMutableDictionary dictionaryWithDictionary:@{@"rect": [NSValue valueWithRect:inRect], @"answer": inAnswer}]];
	[self selectBoxAtIndex:[mBoxes count] - 1];
	[[self sheet] boxesDidChange];
}

-(void)drawRect:(NSRect)inRect
{
	[super drawRect:inRect];
	NSColor *blue = [NSColor colorWithCalibratedRed:0.20 green:0.47 blue:0.96 alpha:1];
	NSDictionary *numberAttributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:11], NSForegroundColorAttributeName: [NSColor whiteColor]};
	NSDictionary *answerAttributes = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.04 green:0.31 blue:0.77 alpha:1]};
	[mBoxes enumerateObjectsUsingBlock:^(NSDictionary *inBox, NSUInteger inIndex, BOOL *outStop) {
		NSRect rect = [self viewRectOfFraction:[inBox[@"rect"] rectValue]];
		[([inBox[@"answer"] length] > 0 ? [NSColor whiteColor] : [NSColor colorWithCalibratedRed:0.92 green:0.95 blue:1 alpha:1]) set];
		NSRectFill(rect);
		[blue set];
		NSFrameRectWithWidth(rect, inIndex == mSelection ? 2.5 : 1.5);
		[NSGraphicsContext saveGraphicsState];
		[NSBezierPath clipRect:rect];
		[inBox[@"answer"] drawAtPoint:NSMakePoint(NSMinX(rect) + 6, NSMidY(rect) - 9) withAttributes:answerAttributes];
		[NSGraphicsContext restoreGraphicsState];
		NSRect badge = NSMakeRect(NSMinX(rect) - 9, NSMaxY(rect) - 9, 18, 18);
		[blue set];
		[[NSBezierPath bezierPathWithOvalInRect:badge] fill];
		NSString *number = [NSString stringWithFormat:@"%lu", (unsigned long)inIndex + 1];
		NSSize size = [number sizeWithAttributes:numberAttributes];
		[number drawAtPoint:NSMakePoint(NSMidX(badge) - size.width / 2, NSMidY(badge) - size.height / 2) withAttributes:numberAttributes];
		if (inIndex == mSelection) {
			NSRect handle = [self handleOfRect:rect];
			[[NSColor whiteColor] set];
			NSRectFill(handle);
			[blue set];
			NSFrameRect(handle);
		}
	}];
	if (mDragKind == kDragNew) {
		[[blue colorWithAlphaComponent:0.18] set];
		NSRectFillUsingOperation(mDragRect, NSCompositeSourceOver);
		[blue set];
		NSFrameRect(mDragRect);
	} else if ([mBoxes count] == 0) {
		NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:12], NSForegroundColorAttributeName: [NSColor whiteColor]};
		NSString *hint = NSLocalizedString(@"Boxes Hint", @"");
		NSSize size = [hint sizeWithAttributes:attributes];
		NSRect rect = NSMakeRect(NSMidX([self bounds]) - size.width / 2 - 10, NSMaxY([self bounds]) - size.height - 20, size.width + 20, size.height + 10);
		[[NSColor colorWithCalibratedWhite:0.11 alpha:0.82] set];
		[[NSBezierPath bezierPathWithRoundedRect:rect xRadius:6 yRadius:6] fill];
		[hint drawAtPoint:NSMakePoint(NSMinX(rect) + 10, NSMinY(rect) + 5) withAttributes:attributes];
	}
}

-(NSUInteger)indexOfBoxAtPoint:(NSPoint)inPoint
{
	for (NSInteger i = [mBoxes count] - 1; i >= 0; i--)
		if (NSPointInRect(inPoint, [self viewRectOfBoxAtIndex:i]))
			return i;
	return NSNotFound;
}

-(void)mouseDown:(NSEvent *)inEvent
{
	[self commitEditing];
	[[self window] makeFirstResponder:self];
	NSPoint point = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	mDragStart = point;
	if (mSelection != NSNotFound && NSPointInRect(point, [self handleOfRect:[self viewRectOfBoxAtIndex:mSelection]])) {
		mDragKind = kDragResize;
		mDragRect = [self viewRectOfBoxAtIndex:mSelection];
		return;
	}
	NSUInteger index = [self indexOfBoxAtPoint:point];
	if (index != NSNotFound) {
		[self selectBoxAtIndex:index];
		[[self sheet] boxesDidChange];
		if ([inEvent clickCount] == 2)
			[self editSelectedBox];
		else {
			mDragKind = kDragMove;
			mDragRect = [self viewRectOfBoxAtIndex:index];
		}
		return;
	}
	[self selectBoxAtIndex:NSNotFound];
	[[self sheet] boxesDidChange];
	mDragKind = kDragNew;
	mDragRect = NSMakeRect(point.x, point.y, 0, 0);
}

-(void)mouseDragged:(NSEvent *)inEvent
{
	NSPoint point = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	NSRect bounds = [self bounds];
	point.x = MIN(NSMaxX(bounds), MAX(NSMinX(bounds), point.x));
	point.y = MIN(NSMaxY(bounds), MAX(NSMinY(bounds), point.y));
	if (mDragKind == kDragNew) {
		mDragRect = NSMakeRect(MIN(mDragStart.x, point.x), MIN(mDragStart.y, point.y), fabs(point.x - mDragStart.x), fabs(point.y - mDragStart.y));
		[self setNeedsDisplay:YES];
	} else if (mDragKind != kNoDrag) {
		NSRect rect = mDragRect;
		if (mDragKind == kDragMove) {
			rect.origin.x = MIN(NSMaxX(bounds) - NSWidth(rect), MAX(NSMinX(bounds), NSMinX(rect) + point.x - mDragStart.x));
			rect.origin.y = MIN(NSMaxY(bounds) - NSHeight(rect), MAX(NSMinY(bounds), NSMinY(rect) + point.y - mDragStart.y));
		} else {
			rect.size.width = MAX(kMinBoxSize, NSWidth(rect) + point.x - mDragStart.x);
			rect.size.height = MAX(kMinBoxSize, NSHeight(rect) - point.y + mDragStart.y);
			rect.origin.y = NSMaxY(mDragRect) - NSHeight(rect);
		}
		mBoxes[mSelection][@"rect"] = [NSValue valueWithRect:[self fractionOfViewRect:rect]];
		[self setNeedsDisplay:YES];
	}
}

-(void)mouseUp:(NSEvent *)inEvent
{
	int kind = mDragKind;
	mDragKind = kNoDrag;
	if (kind == kDragNew) {
		if (NSWidth(mDragRect) >= kMinBoxSize && NSHeight(mDragRect) >= kMinBoxSize) {
			[self addBoxWithRect:[self fractionOfViewRect:mDragRect] answer:@""];
			[self editSelectedBox];
		}
		[self setNeedsDisplay:YES];
	}
}

-(void)editSelectedBox
{
	if (mSelection == NSNotFound)
		return;
	NSRect frame = [self viewRectOfBoxAtIndex:mSelection];
	frame.size.width = MAX(NSWidth(frame), 100);
	frame.origin.y = NSMidY(frame) - 11;
	frame.size.height = 22;
	frame = NSIntersectionRect(frame, [self bounds]);
	mEditor = [[NSTextField alloc] initWithFrame:frame];
	[mEditor setFont:[NSFont systemFontOfSize:13]];
	[mEditor setStringValue:mBoxes[mSelection][@"answer"]];
	[mEditor setDelegate:(id)[self sheet]];
	[self addSubview:mEditor];
	[mEditor release];
	[[self window] makeFirstResponder:mEditor];
}

-(NSTextField *)editor
{
	return mEditor;
}

-(void)commitEditing
{
	if (!mEditor)
		return;
	NSTextField *editor = mEditor;
	mEditor = nil;
	if (mSelection != NSNotFound)
		mBoxes[mSelection][@"answer"] = [editor stringValue];
	[editor removeFromSuperview];
	[[self window] makeFirstResponder:self];
	[self setNeedsDisplay:YES];
	[[self sheet] boxesDidChange];
}

-(void)delete:(id)inSender
{
	if (mSelection == NSNotFound)
		return;
	[mBoxes removeObjectAtIndex:mSelection];
	[self selectBoxAtIndex:NSNotFound];
	[[self sheet] boxesDidChange];
}

-(void)insertNewline:(id)inSender
{
	if (mSelection != NSNotFound)
		[self editSelectedBox];
	else
		[[self window] performKeyEquivalent:[NSApp currentEvent]];
}

-(void)insertText:(NSString *)inString
{
}

-(IBAction)displayFullImage:(id)inSender
{
}

@end

@implementation ProVocBoxesSheet

-(NSTextField *)labelWithString:(NSString *)inString frame:(NSRect)inFrame font:(NSFont *)inFont
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:inFrame] autorelease];
	[label setStringValue:inString];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setFont:inFont];
	return label;
}

-(NSButton *)buttonWithTitle:(NSString *)inTitle frame:(NSRect)inFrame action:(SEL)inAction
{
	NSButton *button = [[[NSButton alloc] initWithFrame:inFrame] autorelease];
	[button setBezelStyle:NSBezelStyleRounded];
	[button setTitle:inTitle];
	[button setTarget:self];
	[button setAction:inAction];
	return button;
}

-(NSButton *)radioWithTitle:(NSString *)inTitle frame:(NSRect)inFrame
{
	NSButton *radio = [[[NSButton alloc] initWithFrame:inFrame] autorelease];
	[radio setButtonType:NSButtonTypeRadio];
	[radio setTitle:inTitle];
	[radio setTarget:self];
	[radio setAction:@selector(chooseOthers:)];
	return radio;
}

-(id)initWithDocument:(ProVocDocument *)inDocument image:(NSImage *)inImage title:(NSString *)inTitle
{
	if (self = [super init]) {
		mDocument = inDocument;
		const float width = 800, height = 560, margin = 16;
		mPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:YES];
		NSView *content = [mPanel contentView];

		NSFont *font = [NSFont systemFontOfSize:13];
		float y = height - margin - 24;
		[content addSubview:[self labelWithString:NSLocalizedString(@"Boxes Title Label", @"") frame:NSMakeRect(margin, y + 2, 44, 18) font:font]];
		mTitleField = [[NSTextField alloc] initWithFrame:NSMakeRect(margin + 48, y, width - 2 * margin - 48 - 130, 24)];
		[mTitleField setFont:[NSFont systemFontOfSize:14]];
		[mTitleField setStringValue:inTitle];
		[content addSubview:mTitleField];
		[mTitleField release];
		mFindLabels = [self buttonWithTitle:NSLocalizedString(@"Boxes Find Labels Button", @"") frame:NSMakeRect(width - margin - 122, y - 3, 122, 30) action:@selector(findLabels:)];
		[content addSubview:mFindLabels];

		// the picture, at the size of the room it has
		NSSize imageSize = [inImage size];
		const float maxWidth = 576, maxHeight = 420;
		float k = MIN(maxWidth / imageSize.width, maxHeight / imageSize.height);
		NSSize size = NSMakeSize(round(imageSize.width * k), round(imageSize.height * k));
		float top = y - 12;
		NSRect stage = NSMakeRect(margin + round((maxWidth - size.width) / 2), top - maxHeight + round((maxHeight - size.height) / 2), size.width, size.height);
		mBoxesView = [[ProVocBoxesView alloc] initWithFrame:stage];
		[mBoxesView setImage:inImage];
		[mBoxesView setSheet:self];
		[content addSubview:mBoxesView];
		[mBoxesView release];

		NSRect listFrame = NSMakeRect(margin + maxWidth + 12, top - maxHeight, width - 2 * margin - maxWidth - 12, maxHeight);
		NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:listFrame] autorelease];
		[scrollView setBorderType:NSBezelBorder];
		[scrollView setHasVerticalScroller:YES];
		mAnswerTable = [[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]];
		NSTableColumn *numberColumn = [[[NSTableColumn alloc] initWithIdentifier:@"Number"] autorelease];
		[numberColumn setTitle:@""];
		[numberColumn setWidth:22];
		[numberColumn setEditable:NO];
		[mAnswerTable addTableColumn:numberColumn];
		NSTableColumn *answerColumn = [[[NSTableColumn alloc] initWithIdentifier:@"Answer"] autorelease];
		[answerColumn setTitle:NSLocalizedString(@"Boxes Answers Column", @"")];
		[answerColumn setWidth:NSWidth(listFrame) - 22 - 30 - 24];
		[mAnswerTable addTableColumn:answerColumn];
		NSTableColumn *removeColumn = [[[NSTableColumn alloc] initWithIdentifier:@"Remove"] autorelease];
		NSButtonCell *removeCell = [[[NSButtonCell alloc] initTextCell:@"×"] autorelease];
		[removeCell setBordered:NO];
		[removeCell setAlignment:NSCenterTextAlignment];
		[removeCell setTarget:self];
		[removeCell setAction:@selector(removeBox:)];
		[removeColumn setDataCell:removeCell];
		[removeColumn setTitle:@""];
		[removeColumn setWidth:24];
		[mAnswerTable addTableColumn:removeColumn];
		[mAnswerTable setStyle:NSTableViewStylePlain];
		[mAnswerTable setDataSource:self];
		[mAnswerTable setDelegate:self];
		[scrollView setDocumentView:mAnswerTable];
		[mAnswerTable release];
		[content addSubview:scrollView];

		y = top - maxHeight - 32;
		[content addSubview:[self labelWithString:NSLocalizedString(@"Boxes While Asking Label", @"") frame:NSMakeRect(margin, y + 2, 150, 18) font:font]];
		mHideOthers = [self radioWithTitle:NSLocalizedString(@"Boxes Hide Others", @"") frame:NSMakeRect(margin + 154, y, 170, 22)];
		[mHideOthers setState:NSOnState];
		[content addSubview:mHideOthers];
		mShowOthers = [self radioWithTitle:NSLocalizedString(@"Boxes Show Others", @"") frame:NSMakeRect(margin + 330, y, 170, 22)];
		[content addSubview:mShowOthers];

		[content addSubview:[self labelWithString:NSLocalizedString(@"Boxes Note", @"") frame:NSMakeRect(margin, 16, 500, 16) font:[NSFont systemFontOfSize:11]]];
		[content addSubview:[self buttonWithTitle:NSLocalizedString(@"Boxes Cancel Button", @"") frame:NSMakeRect(width - margin - 240, 10, 100, 30) action:@selector(cancel:)]];
		[[[content subviews] lastObject] setKeyEquivalent:@"\e"];
		mAddButton = [self buttonWithTitle:@"" frame:NSMakeRect(width - margin - 130, 10, 130, 30) action:@selector(add:)];
		[mAddButton setKeyEquivalent:@"\r"];
		[content addSubview:mAddButton];
		[mPanel setInitialFirstResponder:mBoxesView];
	}
	return self;
}

-(void)dealloc
{
	[mAnswerTable setDataSource:nil];
	[mAnswerTable setDelegate:nil];
	[mPanel release];
	[mImageFile release];
	[mWords release];
	[super dealloc];
}

-(void)begin
{
	[self boxesDidChange];
	[self retain];	// until the sheet ends
	[NSApp beginSheet:mPanel modalForWindow:[mDocument window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	[mPanel makeFirstResponder:mBoxesView];
}

-(void)sheetDidEnd:(NSWindow *)inSheet returnCode:(NSInteger)inReturnCode contextInfo:(void *)inContextInfo
{
	[self release];
}

-(void)close
{
	[mPanel orderOut:nil];
	[NSApp endSheet:mPanel];
}

-(void)setImageFile:(NSString *)inFile row:(int)inRow
{
	mImageFile = [inFile retain];
	mRow = inRow;
}

-(void)setWords:(NSArray *)inWords
{
	mWords = [inWords retain];
	for (ProVocWord *word in mWords) {
		NSDictionary *box = [word occlusion][@"box"];
		[mBoxesView addBoxWithRect:NSMakeRect([box[@"x"] floatValue], [box[@"y"] floatValue], [box[@"w"] floatValue], [box[@"h"] floatValue]) answer:[word targetWord]];
		[[mBoxesView boxes] lastObject][@"word"] = word;
	}
	[mBoxesView selectBoxAtIndex:NSNotFound];
	BOOL showOthers = [[[mWords lastObject] occlusion][@"showOthers"] boolValue];
	[mHideOthers setState:showOthers ? NSOffState : NSOnState];
	[mShowOthers setState:showOthers ? NSOnState : NSOffState];
}

-(int)numberOfAnswers
{
	int n = 0;
	for (NSDictionary *box in [mBoxesView boxes])
		if ([[box[@"answer"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] > 0)
			n++;
	return n;
}

-(void)boxesDidChange
{
	int n = [self numberOfAnswers];
	if (mWords)
		[mAddButton setTitle:NSLocalizedString(@"Boxes Save Button", @"")];
	else
		[mAddButton setTitle:n == 1 ? NSLocalizedString(@"Boxes Add One Word Button", @"") : n > 1 ? [NSString stringWithFormat:NSLocalizedString(@"Boxes Add Words Button", @""), n] : NSLocalizedString(@"Boxes Add No Word Button", @"")];
	[mAddButton setEnabled:n > 0 || mWords];
	[mAnswerTable reloadData];
	NSUInteger selection = [mBoxesView selection];
	if (selection == NSNotFound)
		[mAnswerTable deselectAll:nil];
	else
		[mAnswerTable selectRowIndexes:[NSIndexSet indexSetWithIndex:selection] byExtendingSelection:NO];
}

-(IBAction)chooseOthers:(id)inSender
{
	[mHideOthers setState:inSender == mHideOthers ? NSOnState : NSOffState];
	[mShowOthers setState:inSender == mShowOthers ? NSOnState : NSOffState];
}

-(NSArray *)recognitionLanguages
{
	// The languages of a document are names, as the user wrote them
	NSArray *names = [[@[[mDocument sourceLanguage], [mDocument targetLanguage]] valueForKey:@"lowercaseString"] copy];
	NSLocale *english = [NSLocale localeWithLocaleIdentifier:@"en"];
	NSMutableArray *languages = [NSMutableArray array];
	VNRecognizeTextRequest *request = [[[VNRecognizeTextRequest alloc] init] autorelease];
	[request setRecognitionLevel:VNRequestTextRecognitionLevelAccurate];
	for (NSString *language in [request supportedRecognitionLanguagesAndReturnError:nil]) {
		NSString *code = [[NSLocale localeWithLocaleIdentifier:language] languageCode];
		if ([names containsObject:[[english localizedStringForLanguageCode:code] lowercaseString]] ||
			[names containsObject:[[[NSLocale localeWithLocaleIdentifier:code] localizedStringForLanguageCode:code] lowercaseString]])
			[languages addObject:language];
	}
	[names release];
	return languages;
}

// One box per line of text found in the picture. Everything about Vision is here.
-(IBAction)findLabels:(id)inSender
{
	CGImageRef image = [[mBoxesView image] CGImageForProposedRect:NULL context:nil hints:nil];
	if (!image)
		return;
	[mFindLabels setEnabled:NO];
	NSArray *languages = [self recognitionLanguages];
	CFRetain(image);
	[self retain];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		VNRecognizeTextRequest *request = [[[VNRecognizeTextRequest alloc] init] autorelease];
		[request setRecognitionLevel:VNRequestTextRecognitionLevelAccurate];
		if ([languages count] > 0)
			[request setRecognitionLanguages:languages];
		VNImageRequestHandler *handler = [[[VNImageRequestHandler alloc] initWithCGImage:image options:@{}] autorelease];
		[handler performRequests:@[request] error:nil];
		NSArray *results = [[request results] retain];
		CFRelease(image);
		dispatch_async(dispatch_get_main_queue(), ^{
			[self addLabels:results];
			[results release];
			[self release];
		});
	});
}

-(void)addLabels:(NSArray *)inObservations
{
	for (VNRecognizedTextObservation *observation in inObservations) {
		NSString *text = [[[observation topCandidates:1] firstObject] string];
		NSRect found = NSRectFromCGRect([observation boundingBox]);
		NSRect rect = NSMakeRect(NSMinX(found), 1 - NSMaxY(found), NSWidth(found), NSHeight(found));	// Vision has its origin at the bottom left
		BOOL boxed = [text length] == 0;
		for (NSDictionary *box in [mBoxesView boxes])
			if (NSIntersectsRect(rect, [box[@"rect"] rectValue]))
				boxed = YES;
		if (!boxed)
			[mBoxesView addBoxWithRect:rect answer:text];
	}
	[mBoxesView selectBoxAtIndex:NSNotFound];
	[mFindLabels setEnabled:YES];
	[self boxesDidChange];
}

-(IBAction)removeBox:(id)inSender
{
	NSInteger row = [mAnswerTable clickedRow];
	if (row >= 0) {
		[mBoxesView selectBoxAtIndex:row];
		[mBoxesView delete:nil];
	}
}

-(IBAction)cancel:(id)inSender
{
	[self close];
}

-(IBAction)add:(id)inSender
{
	[mBoxesView commitEditing];
	[mPanel makeFirstResponder:mBoxesView];	// an answer being typed in the list
	[mDocument applyBoxes:[mBoxesView boxes] title:[mTitleField stringValue] showOthers:[mShowOthers state] == NSOnState imageFile:mImageFile row:mRow oldWords:mWords];
	[self close];
}

#pragma mark The answers

-(NSInteger)numberOfRowsInTableView:(NSTableView *)inTableView
{
	return [[mBoxesView boxes] count];
}

-(id)tableView:(NSTableView *)inTableView objectValueForTableColumn:(NSTableColumn *)inColumn row:(NSInteger)inRow
{
	if ([[inColumn identifier] isEqual:@"Number"])
		return @(inRow + 1);
	if ([[inColumn identifier] isEqual:@"Answer"])
		return [mBoxesView boxes][inRow][@"answer"];
	return nil;
}

-(void)tableView:(NSTableView *)inTableView setObjectValue:(id)inValue forTableColumn:(NSTableColumn *)inColumn row:(NSInteger)inRow
{
	if ([[inColumn identifier] isEqual:@"Answer"]) {
		[mBoxesView boxes][inRow][@"answer"] = inValue;
		[mBoxesView setNeedsDisplay:YES];
		[self performSelector:@selector(boxesDidChange) withObject:nil afterDelay:0.0 inModes:@[NSModalPanelRunLoopMode, NSDefaultRunLoopMode]];
	}
}

-(void)tableViewSelectionDidChange:(NSNotification *)inNotification
{
	NSInteger row = [mAnswerTable selectedRow];
	if ((NSUInteger)row != [mBoxesView selection])
		[mBoxesView selectBoxAtIndex:row >= 0 ? row : NSNotFound];
}

#pragma mark The answer being typed on the picture

-(void)controlTextDidChange:(NSNotification *)inNotification
{
	NSTextField *editor = [mBoxesView editor];
	if ([inNotification object] == editor && [mBoxesView selection] != NSNotFound) {
		[mBoxesView boxes][[mBoxesView selection]][@"answer"] = [editor stringValue];
		[self boxesDidChange];
	}
}

-(BOOL)control:(NSControl *)inControl textView:(NSTextView *)inTextView doCommandBySelector:(SEL)inSelector
{
	if (inControl == [mBoxesView editor] && (inSelector == @selector(insertNewline:) || inSelector == @selector(cancelOperation:) || inSelector == @selector(insertTab:))) {
		[mBoxesView commitEditing];
		return YES;
	}
	return NO;
}

@end

@implementation ProVocDocument (Boxes)

-(void)addBoxesOnImageFile:(NSString *)inFile row:(int)inRow
{
	NSImage *image = [[[NSImage alloc] initWithContentsOfFile:inFile] autorelease];
	if (!image)
		return;
	ProVocBoxesSheet *sheet = [[[ProVocBoxesSheet alloc] initWithDocument:self image:image title:[[inFile lastPathComponent] stringByDeletingPathExtension]] autorelease];
	[sheet setImageFile:inFile row:inRow];
	[sheet begin];
}

-(void)applyBoxes:(NSArray *)inBoxes title:(NSString *)inTitle showOthers:(BOOL)inShowOthers imageFile:(NSString *)inFile row:(int)inRow oldWords:(NSArray *)inOldWords
{
	NSString *group = inOldWords ? [inOldWords[0] occlusion][@"group"] : [[NSUUID UUID] UUIDString];
	NSString *media = inFile ? [self addImageFile:inFile] : [inOldWords[0] imageMedia];
	NSMutableArray *kept = [NSMutableArray array];
	NSMutableArray *added = [NSMutableArray array];

	[self willChangeData];
	for (NSDictionary *box in inBoxes) {
		NSString *answer = [box[@"answer"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if ([answer length] == 0)
			continue;
		ProVocWord *word = box[@"word"];
		if (word)
			[kept addObject:word];
		else {
			word = [[[ProVocWord alloc] init] autorelease];
			[word setImageMedia:media];
			[added addObject:word];
		}
		NSRect rect = [box[@"rect"] rectValue];
		[word setSourceWord:inTitle];
		[word setTargetWord:answer];
		[word setOcclusion:@{@"group": group, @"box": @{@"x": @(NSMinX(rect)), @"y": @(NSMinY(rect)), @"w": @(NSWidth(rect)), @"h": @(NSHeight(rect))}, @"showOthers": @(inShowOthers)}];
	}
	for (ProVocWord *word in inOldWords)
		if (![kept containsObject:word])
			[word removeFromParent];
	[self selectedPagesDidChange];
	if ([added count] > 0) {
		NSUInteger last = inOldWords ? [mVisibleWords indexOfObjectIdenticalTo:[kept lastObject]] : NSNotFound;
		[self insertWords:added row:!inOldWords ? inRow : last == NSNotFound ? (int)[mVisibleWords count] : (int)last + 1];
	}
	[self didChangeData];
}

-(void)editBoxesOfWord:(ProVocWord *)inWord
{
	if (![inWord occlusion] || [[self window] attachedSheet])
		return;
	ProVocBoxesSheet *sheet = [[[ProVocBoxesSheet alloc] initWithDocument:self image:[self imageOfWord:inWord] title:[inWord sourceWord]] autorelease];
	[sheet setWords:[inWord occlusionSiblings]];
	[sheet begin];
}

@end
