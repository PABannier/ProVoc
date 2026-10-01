//
//  PVDriver.m
//

#import "PVDriver.h"

static NSMutableArray *sFailures = nil;
static BOOL sScriptEnded = NO;
static BOOL sExpectsTermination = NO;

void PVFail(const char *inFile, int inLine, NSString *inFormat, ...)
{
	va_list arguments;
	va_start(arguments, inFormat);
	NSString *message = [[[NSString alloc] initWithFormat:inFormat arguments:arguments] autorelease];
	va_end(arguments);
	NSString *failure = [NSString stringWithFormat:@"%@:%i: %@", [[NSString stringWithUTF8String:inFile] lastPathComponent], inLine, message];
	NSLog(@"PVDriver: FAILED %@", failure);
	[sFailures addObject:failure];
}

static void PVWriteVerdict(BOOL inTerminated)
{
	const char *path = getenv("PV_RESULT_FILE");
	if (!path)
		return;
	NSMutableString *verdict = [NSMutableString string];
	if (!sScriptEnded)
		[sFailures addObject:@"the application quit before the end of the scenario"];
	if (sExpectsTermination && !inTerminated)
		[verdict appendString:@"WAITING FOR THE APPLICATION TO QUIT\n"];
	else
		[verdict appendString:[sFailures count] == 0 ? @"PASS\n" : @"FAIL\n"];
	for (NSString *failure in sFailures)
		[verdict appendFormat:@"%@\n", failure];
	[verdict writeToFile:[NSString stringWithUTF8String:path] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@interface PVDriver : NSObject
@end

@implementation PVDriver

+(void)applicationDidFinishLaunching:(NSNotification *)inNotification
{
	// once the application is back in its event loop
	[self performSelector:@selector(start) withObject:nil afterDelay:0.0];
}

+(void)applicationWillTerminate:(NSNotification *)inNotification
{
	PVWriteVerdict(YES);
}

+(void)start
{
	NSString *name = [NSString stringWithUTF8String:getenv("PV_SCENARIO")];
	SEL selector = NSSelectorFromString([name stringByAppendingString:@":"]);
	PVScenarios *scenarios = [[PVScenarios alloc] init];
	PVScript *script = [PVScript script];
	if (![scenarios respondsToSelector:selector]) {
		PVFail(__FILE__, __LINE__, @"no scenario named %@", name);
		sScriptEnded = YES;
		PVWriteVerdict(NO);
		exit(2);
	}
	NSLog(@"PVDriver: scenario %@", name);
	[script wait:@"the application to be active" timeout:20 until:^BOOL { return [NSApp isActive]; }];
	[scenarios performSelector:selector withObject:script];
	[script startWithCompletion:^(NSString *inFailure) {
		if (inFailure) {
			for (ProVocDocument *document in [[NSDocumentController sharedDocumentController] documents])
				NSLog(@"PVDriver: document %@ edited %i window visible %i key %i main %i words %@", [[document fileURL] lastPathComponent], [document isDocumentEdited], [[document window] isVisible],
					  [[document window] isKeyWindow], [[document window] isMainWindow], [[PVScenarios sourceWordsOf:document] componentsJoinedByString:@", "]);
			for (NSWindow *window in [NSApp orderedWindows])
				NSLog(@"PVDriver: window %@ \"%@\" visible %i key %i main %i canBecomeKey %i canBecomeMain %i level %ld occlusion %lx sheet %@", [window className], [window title], [window isVisible], [window isKeyWindow], [window isMainWindow],
					  [window canBecomeKeyWindow], [window canBecomeMainWindow], (long)[window level], (unsigned long)[window occlusionState], [[window attachedSheet] className]);
			PVFail(__FILE__, __LINE__, @"%@ (application active %i, frontmost %@; key window: %@ \"%@\", first responder %@, sheet %@; windows: %@)", inFailure,
				   [NSApp isActive], [[[NSWorkspace sharedWorkspace] frontmostApplication] bundleIdentifier], [[NSApp keyWindow] className], [[NSApp keyWindow] title],
				   [[[NSApp keyWindow] firstResponder] className], [[[NSApp mainWindow] attachedSheet] className],
				   [[[[NSApp windows] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isVisible == YES"]] valueForKey:@"className"] componentsJoinedByString:@", "]);
		}
		sScriptEnded = YES;
		PVWriteVerdict(NO);
		NSLog(@"PVDriver: scenario %@ ended with %lu failure(s)", name, (unsigned long)[sFailures count]);
		if (!sExpectsTermination || [sFailures count] > 0) {
			[[NSUserDefaults standardUserDefaults] synchronize];
			exit([sFailures count] == 0 ? 0 : 1);
		}
	}];
}

@end

__attribute__((constructor)) static void PVDriverLoad(void)
{
	if (!getenv("PV_SCENARIO"))
		return;
	@autoreleasepool {
		sFailures = [[NSMutableArray alloc] init];
		NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
		[center addObserver:[PVDriver class] selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
		[center addObserver:[PVDriver class] selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
		// a trace of what happens to the windows, for the logs
		for (NSString *name in @[NSWindowDidBecomeKeyNotification, NSWindowDidBecomeMainNotification, NSWindowWillCloseNotification, NSWindowDidResignKeyNotification])
			[center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *inNotification) {
				NSWindow *window = [inNotification object];
				NSLog(@"PVDriver: %@ %@ \"%@\" (%lu documents)", [name substringFromIndex:2], [window className], [window title], (unsigned long)[[[NSDocumentController sharedDocumentController] documents] count]);
			}];
	}
}

@implementation PVScenarios

+(NSString *)workDirectory
{
	const char *directory = getenv("PV_WORKDIR");
	return directory ? [NSString stringWithUTF8String:directory] : NSTemporaryDirectory();
}

+(void)expectTermination
{
	sExpectsTermination = YES;
}

+(ProVocDocument *)document
{
	NSDocument *document = [[NSDocumentController sharedDocumentController] documentForWindow:[NSApp mainWindow]];
	if (!document)
		document = [[[NSDocumentController sharedDocumentController] documents] lastObject];
	return (ProVocDocument *)document;
}

+(ProVocTester *)tester
{
	return [[ProVocTester currentTesters] lastObject];
}

+(NSTextField *)answerField
{
	return [[self tester] valueForKey:@"mAnswerTextField"];
}

+(BOOL)answerFieldHasFocus
{
	NSTextField *field = [self answerField];
	NSWindow *window = [field window];
	id firstResponder = [window firstResponder];
	return field && [window isKeyWindow] && [firstResponder isKindOfClass:[NSText class]] && [(NSText *)firstResponder delegate] == (id)field;
}

+(NSMenuItem *)itemWithAction:(SEL)inAction inMenu:(NSMenu *)inMenu
{
	for (NSMenuItem *item in [inMenu itemArray]) {
		if ([item action] == inAction)
			return item;
		NSMenuItem *found = [item submenu] ? [self itemWithAction:inAction inMenu:[item submenu]] : nil;
		if (found)
			return found;
	}
	return nil;
}

+(NSMenuItem *)menuItemWithAction:(SEL)inAction
{
	return [self itemWithAction:inAction inMenu:[NSApp mainMenu]];
}

+(NSButton *)buttonWithTitle:(NSString *)inTitle inView:(NSView *)inView
{
	if ([inView isKindOfClass:[NSButton class]] && [[(NSButton *)inView title] isEqualToString:inTitle])
		return (NSButton *)inView;
	for (NSView *subview in [inView subviews]) {
		NSButton *button = [self buttonWithTitle:inTitle inView:subview];
		if (button)
			return button;
	}
	return nil;
}

+(NSButton *)buttonWithTitle:(NSString *)inTitle inWindow:(NSWindow *)inWindow
{
	return [self buttonWithTitle:inTitle inView:[[inWindow contentView] superview] ? [[inWindow contentView] superview] : [inWindow contentView]];
}

+(NSArray *)sourceWordsOf:(ProVocDocument *)inDocument
{
	return [[inDocument allWords] valueForKey:@"sourceWord"];
}

@end
