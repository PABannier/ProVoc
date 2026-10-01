//
//  PVTestSupport.m
//

#import "PVTestSupport.h"
#import <Carbon/Carbon.h>
#import <objc/message.h>

#define PV_STRINGIFY2(x) #x
#define PV_STRINGIFY(x) PV_STRINGIFY2(x)

NSString *PVTestSourceRoot(void)
{
	return @PV_STRINGIFY(PV_SRCROOT);
}

static int sSavedStderr = -1;
static NSString *sCapturePath = nil;

void PVBeginCapturingStderr(void)
{
	[sCapturePath release];
	sCapturePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]] retain];
	fflush(stderr);
	sSavedStderr = dup(STDERR_FILENO);
	freopen([sCapturePath fileSystemRepresentation], "w", stderr);
}

NSString *PVEndCapturingStderr(void)
{
	fflush(stderr);
	dup2(sSavedStderr, STDERR_FILENO);
	close(sSavedStderr);
	NSString *log = [NSString stringWithContentsOfFile:sCapturePath encoding:NSUTF8StringEncoding error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:sCapturePath error:NULL];
	if ([log length] > 0)
		fputs([log UTF8String], stderr);
	return log ? log : @"";
}

static void PVSaveSnapshot(NSWindow *inWindow, NSString *inName)
{
	NSView *view = [[inWindow contentView] superview];
	if (!view)
		view = [inWindow contentView];
	[view layoutSubtreeIfNeeded];
	[view display];
	NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:[view bounds]];
	if (!rep)
		return;
	[view cacheDisplayInRect:[view bounds] toBitmapImageRep:rep];
	NSString *path = [[[PVTestSourceRoot() stringByAppendingPathComponent:@"verification/screenshots"] stringByAppendingPathComponent:inName] stringByAppendingPathExtension:@"png"];
	[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
	[[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

void PVSaveWindowSnapshot(NSWindow *inWindow, NSString *inName)
{
	NSAppearance *appearance = [[inWindow appearance] retain];
	[inWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
	PVSaveSnapshot(inWindow, inName);
	[inWindow setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];
	PVSaveSnapshot(inWindow, [inName stringByAppendingString:@"-dark"]);
	[inWindow setAppearance:appearance];
	[appearance release];
}

BOOL PVWaitUntil(NSTimeInterval inTimeout, BOOL (^inCondition)(void))
{
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:inTimeout];
	while (!inCondition()) {
		if ([limit timeIntervalSinceNow] < 0)
			return NO;
		// handle events too: activation, window ordering... arrive as events
		NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate dateWithTimeIntervalSinceNow:0.02] inMode:NSDefaultRunLoopMode dequeue:YES];
		if (event)
			[NSApp sendEvent:event];
	}
	return YES;
}

NSString *PVTemporaryCopyOfDeck(NSString *inPath)
{
	NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"ProVocTests-" stringByAppendingString:[[NSUUID UUID] UUIDString]]];
	[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
	NSString *copy = [directory stringByAppendingPathComponent:[inPath lastPathComponent]];
	NSError *error = nil;
	if (![[NSFileManager defaultManager] copyItemAtPath:inPath toPath:copy error:&error]) {
		NSLog(@"PVTemporaryCopyOfDeck: %@", error);
		return nil;
	}
	return copy;
}

ProVocDocument *PVOpenCopyOfDeck(NSString *inPath)
{
	NSString *copy = PVTemporaryCopyOfDeck(inPath);
	if (!copy)
		return nil;
	__block id document = nil;
	__block BOOL done = NO;
	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:copy] display:YES
		completionHandler:^(NSDocument *inDocument, BOOL inAlreadyOpen, NSError *inError) {
			if (inError)
				NSLog(@"PVOpenCopyOfDeck: %@", inError);
			document = [inDocument retain];
			done = YES;
		}];
	PVWaitUntil(20, ^BOOL { return done; });
	return [document autorelease];
}

void PVCloseDocument(NSDocument *inDocument)
{
	[inDocument updateChangeCount:NSChangeCleared];
	[inDocument close];
}

#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocData.h"
#import "ProVocChapter.h"
#import "ProVocPage.h"
#import "ProVocWord.h"

ProVocPage *PVAddPage(ProVocDocument *inDocument, NSString *inTitle, NSArray *inWords)
{
	ProVocData *data = [inDocument valueForKey:@"mProVocData"];
	ProVocPage *page = [[[ProVocPage alloc] init] autorelease];
	[page setTitle:inTitle];
	for (NSArray *texts in inWords) {
		ProVocWord *word = [[[ProVocWord alloc] init] autorelease];
		[word setSourceWord:texts[0]];
		[word setTargetWord:texts[1]];
		if ([texts count] > 2)
			[word setComment:texts[2]];
		[page addWord:word];
	}
	[[data rootChapter] addChild:page];
	[inDocument pagesDidChange];
	return page;
}

ProVocDocument *PVNewDocumentWithWords(NSArray *inWords)
{
	NSError *error = nil;
	ProVocDocument *document = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:&error];
	if (!document) {
		NSLog(@"PVNewDocumentWithWords: %@", error);
		return nil;
	}
	ProVocPage *page = PVAddPage(document, @"Lesson 1", inWords);
	NSOutlineView *outlineView = [document valueForKey:@"mPageOutlineView"];
	[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[outlineView rowForItem:page]] byExtendingSelection:NO];
	[document selectedPagesDidChange];
	return document;
}

void PVPostKeyRepeat(unsigned short inKeyCode, NSString *inCharacters, NSEventModifierFlags inModifiers, BOOL inIsRepeat)
{
	// Built from Quartz events, like the events the window server delivers: AppKit matches
	// key equivalents and feeds the text input system from the underlying CGEvent.
	for (int down = 1; down >= 0; down--) {
		CGEventRef cgEvent = CGEventCreateKeyboardEvent(NULL, inKeyCode, down);
		CGEventSetFlags(cgEvent, (CGEventFlags)inModifiers);
		if (inIsRepeat)
			CGEventSetIntegerValueField(cgEvent, kCGKeyboardEventAutorepeat, 1);
		if ([inCharacters length] > 0) {
			unichar characters[8];
			NSUInteger length = MIN([inCharacters length], 8u);
			[inCharacters getCharacters:characters range:NSMakeRange(0, length)];
			CGEventKeyboardSetUnicodeString(cgEvent, length, characters);
		}
		NSEvent *event = [NSEvent eventWithCGEvent:cgEvent];
		CFRelease(cgEvent);
		[NSApp postEvent:event atStart:NO];
	}
}

void PVPostKey(unsigned short inKeyCode, NSString *inCharacters, NSEventModifierFlags inModifiers)
{
	PVPostKeyRepeat(inKeyCode, inCharacters, inModifiers, NO);
}

void PVClickAtPoint(NSView *inView, NSPoint inPoint, NSInteger inClickCount, NSEventModifierFlags inModifiers)
{
	NSPoint location = [inView convertPoint:inPoint toView:nil];
	for (NSInteger click = 1; click <= inClickCount; click++)
		for (NSNumber *type in @[@(NSEventTypeLeftMouseDown), @(NSEventTypeLeftMouseUp)]) {
			NSEvent *event = [NSEvent mouseEventWithType:[type unsignedIntegerValue] location:location modifierFlags:inModifiers
											   timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[[inView window] windowNumber]
												 context:nil eventNumber:0 clickCount:click pressure:[type unsignedIntegerValue] == NSEventTypeLeftMouseDown ? 1.0 : 0.0];
			[NSApp postEvent:event atStart:NO];
		}
}

void PVClickView(NSView *inView, NSInteger inClickCount, NSEventModifierFlags inModifiers)
{
	NSRect bounds = [inView bounds];
	PVClickAtPoint(inView, NSMakePoint(NSMidX(bounds), NSMidY(bounds)), inClickCount, inModifiers);
}

void PVPressAlertButton(NSButton *inButton)
{
	[inButton performClick:nil];
	// the modal loop of the alert only notices that it was stopped when an event comes
	[NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0] atStart:NO];
}

void PVPostFlagsChanged(NSEventModifierFlags inModifiers)
{
	CGEventRef cgEvent = CGEventCreateKeyboardEvent(NULL, 58 /* left Option */, inModifiers != 0);
	CGEventSetType(cgEvent, kCGEventFlagsChanged);
	CGEventSetFlags(cgEvent, (CGEventFlags)inModifiers);
	[NSApp postEvent:[NSEvent eventWithCGEvent:cgEvent] atStart:NO];
	CFRelease(cgEvent);
}

// The key (and Shift / Option state) that produces a character with the current keyboard
// layout, found by asking the layout what each key produces - whatever the layout is.
// With inCommand, the layout is asked what the keys produce while Command is held (on
// AZERTY, for instance, Command plus the unshifted top-row keys gives the digits).
static BOOL PVKeyForCharacter(NSString *inCharacter, BOOL inCommand, unsigned short *outKeyCode, NSEventModifierFlags *outModifiers)
{
	static NSMutableDictionary *tables[2] = {nil, nil};
	if (!tables[inCommand]) {
		NSMutableDictionary *keys = tables[inCommand] = [[NSMutableDictionary alloc] init];
		TISInputSourceRef source = TISCopyCurrentKeyboardLayoutInputSource();
		CFDataRef layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData);
		NSLog(@"PVTestSupport: keyboard layout %@", TISGetInputSourceProperty(source, kTISPropertyInputSourceID));
		if (layoutData) {
			const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
			NSEventModifierFlags modifiers[4] = {0, NSEventModifierFlagShift, NSEventModifierFlagOption, NSEventModifierFlagShift | NSEventModifierFlagOption};
			for (int m = inCommand ? 1 : 3; m >= 0; m--)	// plainest combination last, so that it wins
				for (int keyCode = 127; keyCode >= 0; keyCode--) {
					if (keyCode >= 65 && keyCode <= 92)
						continue;	// keypad
					UInt32 deadKeyState = 0;
					UniChar characters[4];
					UniCharCount length = 0;
					UInt32 carbonModifiers = ((modifiers[m] & NSEventModifierFlagShift) ? shiftKey : 0) | ((modifiers[m] & NSEventModifierFlagOption) ? optionKey : 0) | (inCommand ? cmdKey : 0);
					if (UCKeyTranslate(layout, keyCode, kUCKeyActionDown, carbonModifiers >> 8, LMGetKbdType(), 0, &deadKeyState, 4, &length, characters) == noErr
							&& length == 1 && deadKeyState == 0 && characters[0] >= 0x20)
						keys[[NSString stringWithCharacters:characters length:1]] = @[@(keyCode), @(modifiers[m])];
				}
		}
		CFRelease(source);
	}
	NSArray *key = tables[inCommand][inCharacter];
	if (!key)
		return NO;
	*outKeyCode = [key[0] unsignedShortValue];
	*outModifiers = [key[1] unsignedIntegerValue];
	return YES;
}

void PVTypeText(NSString *inText)
{
	[inText enumerateSubstringsInRange:NSMakeRange(0, [inText length]) options:NSStringEnumerationByComposedCharacterSequences
		usingBlock:^(NSString *inCharacter, NSRange inRange, NSRange inEnclosingRange, BOOL *outStop) {
			unsigned short keyCode;
			NSEventModifierFlags modifiers;
			if (PVKeyForCharacter(inCharacter, NO, &keyCode, &modifiers))
				PVPostKey(keyCode, nil, modifiers);
			else
				// no single key types it on this layout: deliver the character itself
				PVPostKey(0, inCharacter, 0);
		}];
}

void PVTypeCommand(NSString *inCharacter, NSEventModifierFlags inExtraModifiers)
{
	unsigned short keyCode = 0;
	NSEventModifierFlags modifiers = 0;
	if (!PVKeyForCharacter(inCharacter, YES, &keyCode, &modifiers))
		NSLog(@"*** PVTypeCommand: no key for %@ on this keyboard layout", inCharacter);
	PVPostKey(keyCode, nil, modifiers | NSEventModifierFlagCommand | inExtraModifiers);
}

@implementation PVDragInfo

+(PVDragInfo *)infoWithPasteboard:(NSPasteboard *)inPasteboard source:(id)inSource copy:(BOOL)inCopy
{
	PVDragInfo *info = [[[self alloc] init] autorelease];
	info->mPasteboard = [inPasteboard retain];
	info->mSource = [inSource retain];
	info->mOperationMask = inCopy ? NSDragOperationCopy : NSDragOperationEvery;
	return info;
}

+(PVDragInfo *)infoWithFiles:(NSArray *)inPaths
{
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
	[pasteboard declareTypes:@[NSFilenamesPboardType] owner:nil];
	[pasteboard setPropertyList:inPaths forType:NSFilenamesPboardType];
	PVDragInfo *info = [self infoWithPasteboard:pasteboard source:nil copy:NO];
	info->mOperationMask = NSDragOperationCopy | NSDragOperationLink | NSDragOperationGeneric;
	return info;
}

-(void)dealloc
{
	[mPasteboard releaseGlobally];
	[mPasteboard release];
	[mSource release];
	[mWindow release];
	[super dealloc];
}

-(void)setLocation:(NSPoint)inPoint inView:(NSView *)inView
{
	mLocation = [inView convertPoint:inPoint toView:nil];
	[mWindow autorelease];
	mWindow = [[inView window] retain];
}

-(NSWindow *)draggingDestinationWindow { return mWindow; }
-(NSDragOperation)draggingSourceOperationMask { return mOperationMask; }
-(NSPoint)draggingLocation { return mLocation; }
-(NSPoint)draggedImageLocation { return mLocation; }
-(NSImage *)draggedImage { return nil; }
-(NSPasteboard *)draggingPasteboard { return mPasteboard; }
-(id)draggingSource { return mSource; }
-(NSInteger)draggingSequenceNumber { return 1; }
-(void)slideDraggedImageTo:(NSPoint)inPoint { }
-(NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)inDestination { return nil; }
-(NSDraggingFormation)draggingFormation { return NSDraggingFormationDefault; }
-(void)setDraggingFormation:(NSDraggingFormation)inFormation { }
-(BOOL)animatesToDestination { return NO; }
-(void)setAnimatesToDestination:(BOOL)inAnimates { }
-(NSInteger)numberOfValidItemsForDrop { return 1; }
-(void)setNumberOfValidItemsForDrop:(NSInteger)inNumber { }
-(void)enumerateDraggingItemsWithOptions:(NSDraggingItemEnumerationOptions)inOptions forView:(NSView *)inView classes:(NSArray *)inClasses searchOptions:(NSDictionary *)inSearchOptions usingBlock:(void (^)(NSDraggingItem *, NSInteger, BOOL *))inBlock { }
-(NSSpringLoadingHighlight)springLoadingHighlight { return NSSpringLoadingHighlightNone; }
-(void)resetSpringLoading { }

@end

void PVPrepareMenu(NSMenu *inMenu)
{
	id <NSMenuDelegate> delegate = [inMenu delegate];
	SEL updateWithEvent = NSSelectorFromString(@"updateMenu:withEvent:withFlags:");
	if ([delegate respondsToSelector:@selector(menuNeedsUpdate:)])
		[delegate menuNeedsUpdate:inMenu];
	else if ([delegate respondsToSelector:updateWithEvent])
		// AppKit's own delegate of the Open Recent menu only has this (private) variant
		((void (*)(id, SEL, id, id, NSUInteger))objc_msgSend)(delegate, updateWithEvent, inMenu, nil, 0);
	else if ([delegate respondsToSelector:@selector(numberOfItemsInMenu:)] && [delegate respondsToSelector:@selector(menu:updateItem:atIndex:shouldCancel:)]) {
		NSInteger count = [delegate numberOfItemsInMenu:inMenu];
		if (count >= 0) {
			while ([inMenu numberOfItems] < count)
				[inMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""] autorelease]];
			while ([inMenu numberOfItems] > count)
				[inMenu removeItemAtIndex:[inMenu numberOfItems] - 1];
			for (NSInteger index = 0; index < count; index++)
				if (![delegate menu:inMenu updateItem:[inMenu itemAtIndex:index] atIndex:index shouldCancel:NO])
					break;
		}
	}
	[inMenu update];
}

@interface PVScript () {
	NSMutableArray *mSteps;
	NSUInteger mIndex;
	NSDate *mStepStart;
	NSString *mFailure;
	BOOL mFinished;
	void (^mCompletion)(NSString *);
}
@end

@implementation PVScript

+(PVScript *)script
{
	return [[[self alloc] init] autorelease];
}

-(id)init
{
	if (self = [super init])
		mSteps = [[NSMutableArray alloc] init];
	return self;
}

-(void)dealloc
{
	[mSteps release];
	[mStepStart release];
	[mFailure release];
	[super dealloc];
}

-(void)then:(void (^)(void))inBlock
{
	[mSteps addObject:@{@"do": [[inBlock copy] autorelease]}];
}

-(void)wait:(NSString *)inDescription timeout:(NSTimeInterval)inTimeout until:(PVCondition)inCondition
{
	[mSteps addObject:@{@"until": [[inCondition copy] autorelease], @"what": inDescription, @"timeout": @(inTimeout)}];
}

-(void)wait:(NSString *)inDescription until:(PVCondition)inCondition
{
	[self wait:inDescription timeout:5 until:inCondition];
}

-(void)pause:(NSTimeInterval)inDuration
{
	[mSteps addObject:@{@"pause": @(inDuration)}];
}

// Called by a timer scheduled in the common run loop modes, so that the script goes
// on inside modal sessions (the dimmed test panel) as well as in sheets.
-(void)step:(NSTimer *)inTimer
{
	// An exception raised by a step (or by what it calls in the application) must not
	// unwind through the timer: the timer would never fire again, and the script would
	// hang instead of failing.
	@try {
		[self runSteps:inTimer];
	} @catch (NSException *exception) {
		NSLog(@"*** PVScript: exception in step %lu: %@", (unsigned long)mIndex, exception);
		[self fail:[NSString stringWithFormat:@"exception in step %lu: %@", (unsigned long)mIndex, exception]];
		mFinished = YES;
		[self runSteps:inTimer];
	}
}

-(void)runSteps:(NSTimer *)inTimer
{
	while (!mFinished) {
		if (mIndex >= [mSteps count]) {
			mFinished = YES;
			break;
		}
		NSDictionary *step = mSteps[mIndex];
		if (!mStepStart)
			mStepStart = [[NSDate alloc] init];
		NSTimeInterval elapsed = -[mStepStart timeIntervalSinceNow];
		if (step[@"do"]) {
			// only one action per timer tick: the events it posts must be handled before the next step
			((void (^)(void))step[@"do"])();
			mIndex++;
			[mStepStart release];
			mStepStart = nil;
			return;
		} else if (step[@"pause"]) {
			if (elapsed < [step[@"pause"] doubleValue])
				return;
		} else if (((PVCondition)step[@"until"])()) {
			if (mCompletion)	// the driver of the stand-alone application keeps a trace
				NSLog(@"PVScript: %@ (%.2f s)", step[@"what"], elapsed);
		} else {
			if (elapsed < [step[@"timeout"] doubleValue])
				return;
			mFailure = [[NSString alloc] initWithFormat:@"timed out waiting for: %@ (step %lu; modal window: %@ \"%@\")", step[@"what"], (unsigned long)mIndex, [[NSApp modalWindow] className], [[NSApp modalWindow] title]];
			if ([NSApp modalWindow])
				PVSaveWindowScreenshot([NSApp modalWindow], @"failures/modal-window-at-timeout");
			mFinished = YES;
			break;
		}
		mIndex++;
		[mStepStart release];
		mStepStart = nil;
	}
	if (mFinished) {
		[inTimer invalidate];
		// A script may leave the modal test panel up: -run could never return.
		if ([NSApp modalWindow]) {
			if (!mFailure)
				mFailure = [[NSString alloc] initWithFormat:@"the script ended with a modal window still open: %@", [[NSApp modalWindow] title]];
			[NSApp abortModal];
		}
		// The slideshow runs its own event loop until Esc: -run could never return either.
		for (NSWindow *window in [NSApp windows])
			if ([window isVisible] && [[window contentView] isKindOfClass:NSClassFromString(@"SlideView")]) {
				if (!mFailure)
					mFailure = [[NSString alloc] initWithString:@"the script ended with the slideshow still running"];
				PVPostKey(PVKeyEscape, nil, 0);
				break;
			}
		if (mCompletion) {
			mCompletion(mFailure);
			return;
		}
		// wake the event loop of -run up
		[NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0] atStart:NO];
	}
}

-(void)startWithCompletion:(void (^)(NSString *))inCompletion
{
	mCompletion = [inCompletion copy];
	[self retain];	// until the application ends
	NSTimer *timer = [NSTimer timerWithTimeInterval:0.01 target:self selector:@selector(step:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

-(void)fail:(NSString *)inFailure
{
	if (!mFailure)
		mFailure = [inFailure copy];
}

-(NSString *)run
{
	NSTimer *timer = [NSTimer timerWithTimeInterval:0.01 target:self selector:@selector(step:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:120];
	while (!mFinished && [limit timeIntervalSinceNow] > 0) {
		NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate dateWithTimeIntervalSinceNow:0.05] inMode:NSDefaultRunLoopMode dequeue:YES];
		if (event)
			[NSApp sendEvent:event];
	}
	[timer invalidate];
	if (!mFinished)
		return @"the script did not finish in 120 s";
	return mFailure;
}

@end

#import <dlfcn.h>

NSBitmapImageRep *PVSaveWindowScreenshot(NSWindow *inWindow, NSString *inName)
{
	// CGWindowListCreateImage is no longer declared in the SDK but still captures the
	// windows of the calling process without any permission.
	CGImageRef (*createImage)(CGRect, uint32_t, uint32_t, uint32_t) = dlsym(RTLD_DEFAULT, "CGWindowListCreateImage");
	if (!createImage)
		return nil;
	CGImageRef image = createImage(CGRectNull, 1 << 3 /* including window */, (uint32_t)[inWindow windowNumber], 1 << 0 /* ignore framing */);
	if (!image)
		return nil;
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
	CGImageRelease(image);
	NSString *path = [[[PVTestSourceRoot() stringByAppendingPathComponent:@"verification/screenshots"] stringByAppendingPathComponent:inName] stringByAppendingPathExtension:@"png"];
	[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
	[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
	return bitmap;
}

NSUInteger PVNumberOfDistinctColors(NSBitmapImageRep *inBitmap)
{
	NSMutableSet *colors = [NSMutableSet set];
	NSInteger width = [inBitmap pixelsWide], height = [inBitmap pixelsHigh];
	for (NSInteger y = 0; y < height; y += MAX(1, height / 40))
		for (NSInteger x = 0; x < width; x += MAX(1, width / 40)) {
			NSColor *color = [[inBitmap colorAtX:x y:y] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
			[colors addObject:@((int)([color redComponent] * 15) << 8 | (int)([color greenComponent] * 15) << 4 | (int)([color blueComponent] * 15))];
		}
	return [colors count];
}

#import <AVFoundation/AVFoundation.h>

static void PVWriteWAV(NSString *inPath)
{
	// 0.4 s of a very faint 440 Hz tone, 16 bit mono at 22050 Hz
	const int rate = 22050, count = rate * 4 / 10;
	NSMutableData *data = [NSMutableData data];
	uint32_t dataSize = count * 2, riffSize = 36 + dataSize, fmtSize = 16, byteRate = rate * 2, sampleRate = rate;
	uint16_t pcm = 1, channels = 1, blockAlign = 2, bits = 16;
	[data appendBytes:"RIFF" length:4]; [data appendBytes:&riffSize length:4]; [data appendBytes:"WAVEfmt " length:8];
	[data appendBytes:&fmtSize length:4]; [data appendBytes:&pcm length:2]; [data appendBytes:&channels length:2];
	[data appendBytes:&sampleRate length:4]; [data appendBytes:&byteRate length:4]; [data appendBytes:&blockAlign length:2]; [data appendBytes:&bits length:2];
	[data appendBytes:"data" length:4]; [data appendBytes:&dataSize length:4];
	for (int i = 0; i < count; i++) {
		int16_t sample = (int16_t)(200 * sin(2 * M_PI * 440 * i / rate));
		[data appendBytes:&sample length:2];
	}
	[data writeToFile:inPath atomically:YES];
}

static void PVWriteMP3(NSString *inPath)
{
	// 40 silent MPEG-1 Layer III frames (128 kbit/s, 44.1 kHz, mono): about one second
	NSMutableData *data = [NSMutableData data];
	const unsigned char header[4] = {0xFF, 0xFB, 0x90, 0xC4};
	for (int frame = 0; frame < 40; frame++) {
		[data appendBytes:header length:4];
		[data increaseLengthBy:413];
	}
	[data writeToFile:inPath atomically:YES];
}

static void PVWritePicture(NSString *inPath, NSBitmapImageFileType inType)
{
	NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:320 pixelsHigh:240 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
																  colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
	[[NSColor colorWithCalibratedRed:0.2 green:0.5 blue:0.8 alpha:1.0] set];
	NSRectFill(NSMakeRect(0, 0, 320, 240));
	[[NSColor yellowColor] set];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(100, 60, 120, 120)] fill];
	[NSGraphicsContext restoreGraphicsState];
	[[rep representationUsingType:inType properties:@{}] writeToFile:inPath atomically:YES];
}

static void PVWriteMovie(NSString *inPath, AVFileType inFileType)
{
	// one second of H.264 video, 320 x 240, 10 frames, each of another gray
	[[NSFileManager defaultManager] removeItemAtPath:inPath error:NULL];
	AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:inPath] fileType:inFileType error:NULL];
	AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:@{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @320, AVVideoHeightKey: @240}];
	AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:input
		sourcePixelBufferAttributes:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB), (id)kCVPixelBufferWidthKey: @320, (id)kCVPixelBufferHeightKey: @240}];
	[writer addInput:input];
	[writer startWriting];
	[writer startSessionAtSourceTime:kCMTimeZero];
	for (int frame = 0; frame < 10; frame++) {
		CVPixelBufferRef buffer = NULL;
		CVPixelBufferCreate(NULL, 320, 240, kCVPixelFormatType_32ARGB, NULL, &buffer);
		CVPixelBufferLockBaseAddress(buffer, 0);
		memset(CVPixelBufferGetBaseAddress(buffer), 40 + frame * 20, CVPixelBufferGetBytesPerRow(buffer) * 240);
		CVPixelBufferUnlockBaseAddress(buffer, 0);
		while (![input isReadyForMoreMediaData])
			[NSThread sleepForTimeInterval:0.01];
		[adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 10)];
		CVPixelBufferRelease(buffer);
	}
	[input markAsFinished];
	[writer endSessionAtSourceTime:CMTimeMake(10, 10)];
	__block BOOL finished = NO;
	[writer finishWritingWithCompletionHandler:^{ finished = YES; }];
	while (!finished)
		[NSThread sleepForTimeInterval:0.01];
}

static void PVConvertSound(NSString *inSource, NSString *inDestination, NSArray *inFormat)
{
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/afconvert"];
	[task setArguments:[inFormat arrayByAddingObjectsFromArray:@[inSource, inDestination]]];
	[task launch];
	[task waitUntilExit];
}

NSString *PVMediaFile(NSString *inKind)
{
	static NSString *directory = nil;
	if (!directory) {
		directory = [[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"ProVocTestMedia-%i", [[NSProcessInfo processInfo] processIdentifier]]] retain];
		[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
		NSString *(^file)(NSString *) = ^(NSString *name) { return [directory stringByAppendingPathComponent:name]; };
		PVWriteWAV(file(@"sound.wav"));
		PVConvertSound(file(@"sound.wav"), file(@"sound.aiff"), @[@"-f", @"AIFF", @"-d", @"BEI16"]);
		PVConvertSound(file(@"sound.wav"), file(@"sound.m4a"), @[@"-f", @"m4af", @"-d", @"aac"]);
		PVWriteMP3(file(@"sound.mp3"));
		PVWritePicture(file(@"picture.png"), NSBitmapImageFileTypePNG);
		PVWritePicture(file(@"picture.jpg"), NSBitmapImageFileTypeJPEG);
		PVWriteMovie(file(@"movie.mov"), AVFileTypeQuickTimeMovie);
		PVWriteMovie(file(@"movie.mp4"), AVFileTypeMPEG4);
		[[@"this is not a movie" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:file(@"bad.mov") atomically:YES];
	}
	NSDictionary *names = @{@"wav": @"sound.wav", @"aiff": @"sound.aiff", @"m4a": @"sound.m4a", @"mp3": @"sound.mp3", @"png": @"picture.png", @"jpg": @"picture.jpg",
							@"mov": @"movie.mov", @"mp4": @"movie.mp4", @"bad.mov": @"bad.mov"};
	return [directory stringByAppendingPathComponent:names[inKind]];
}
