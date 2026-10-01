//
//  PVTestSupport.m
//

#import "PVTestSupport.h"
#import <Carbon/Carbon.h>

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

// The key (and Shift / Option state) that types a character with the current keyboard
// layout, found by asking the layout what each key produces - whatever the layout is.
static BOOL PVKeyForCharacter(NSString *inCharacter, unsigned short *outKeyCode, NSEventModifierFlags *outModifiers)
{
	static NSMutableDictionary *keys = nil;
	if (!keys) {
		keys = [[NSMutableDictionary alloc] init];
		TISInputSourceRef source = TISCopyCurrentKeyboardLayoutInputSource();
		CFDataRef layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData);
		NSLog(@"PVTestSupport: keyboard layout %@", TISGetInputSourceProperty(source, kTISPropertyInputSourceID));
		if (layoutData) {
			const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
			NSEventModifierFlags modifiers[4] = {0, NSEventModifierFlagShift, NSEventModifierFlagOption, NSEventModifierFlagShift | NSEventModifierFlagOption};
			for (int m = 3; m >= 0; m--)	// plainest combination last, so that it wins
				for (int keyCode = 127; keyCode >= 0; keyCode--) {
					if (keyCode >= 65 && keyCode <= 92)
						continue;	// keypad
					UInt32 deadKeyState = 0;
					UniChar characters[4];
					UniCharCount length = 0;
					UInt32 carbonModifiers = ((modifiers[m] & NSEventModifierFlagShift) ? shiftKey : 0) | ((modifiers[m] & NSEventModifierFlagOption) ? optionKey : 0);
					if (UCKeyTranslate(layout, keyCode, kUCKeyActionDown, carbonModifiers >> 8, LMGetKbdType(), 0, &deadKeyState, 4, &length, characters) == noErr
							&& length == 1 && deadKeyState == 0 && characters[0] >= 0x20)
						keys[[NSString stringWithCharacters:characters length:1]] = @[@(keyCode), @(modifiers[m])];
				}
		}
		CFRelease(source);
	}
	NSArray *key = keys[inCharacter];
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
			if (PVKeyForCharacter(inCharacter, &keyCode, &modifiers))
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
	if (!PVKeyForCharacter(inCharacter, &keyCode, &modifiers))
		NSLog(@"*** PVTypeCommand: no key for %@ on this keyboard layout", inCharacter);
	PVPostKey(keyCode, nil, modifiers | NSEventModifierFlagCommand | inExtraModifiers);
}

@interface PVScript () {
	NSMutableArray *mSteps;
	NSUInteger mIndex;
	NSDate *mStepStart;
	NSString *mFailure;
	BOOL mFinished;
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
		} else if (!((PVCondition)step[@"until"])()) {
			if (elapsed < [step[@"timeout"] doubleValue])
				return;
			mFailure = [[NSString alloc] initWithFormat:@"timed out waiting for: %@ (step %lu)", step[@"what"], (unsigned long)mIndex];
			mFinished = YES;
			break;
		}
		mIndex++;
		[mStepStart release];
		mStepStart = nil;
	}
	if (mFinished) {
		[inTimer invalidate];
		// A failed script may leave the modal test panel up: -run could never return.
		if (mFailure && [NSApp modalWindow])
			[NSApp abortModal];
		// wake the event loop of -run up
		[NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0] atStart:NO];
	}
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
