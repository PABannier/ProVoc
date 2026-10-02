//
//  ProVocAutomatorTests.m
//
//  The three Automator actions in the application (Contents/Library/Automator): their
//  bundles, the view of their settings in each language, and what their scripts do to
//  the front document when Automator runs them.
//
//  Automator only loads actions "provided by a third party" once its user has enabled
//  them (Automator > Third Party Automator Actions...). The scripts are therefore run
//  here the way Automator runs them - their run handler gets {input, parameters} - and
//  the actions are also loaded with the classes of Automator when that setting is on.
//

#import "PVScenarioTestCase.h"
#import <Automator/Automator.h>
#import <Carbon/Carbon.h>

// The owner of the settings nib of an action (AMBundleAction for Automator): the view
// and the settings that the check boxes are bound to.
@interface PVActionOwner : NSObject {
@public
	NSView *view;
	NSMutableDictionary *parameters;
}
@end

@implementation PVActionOwner
// (the view belongs to the top-level objects of the nib: an outlet without accessor is not retained)
-(void)dealloc { [parameters release]; [super dealloc]; }
@end

@interface ProVocAutomatorTests : PVScenarioTestCase
@end

@implementation ProVocAutomatorTests

-(NSURL *)urlOfAction:(NSString *)inName
{
	return [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"Contents/Library/Automator/%@.action", inName]];
}

-(NSBundle *)bundleOfAction:(NSString *)inName
{
	return [NSBundle bundleWithURL:[self urlOfAction:inName]];
}

// Runs the script of an action as Automator does: its run handler with {input, parameters}
-(NSAppleEventDescriptor *)run:(NSString *)inName input:(NSAppleEventDescriptor *)inInput parameters:(NSDictionary *)inParameters
{
	NSDictionary *error = nil;
	NSAppleScript *script = [[[NSAppleScript alloc] initWithContentsOfURL:[[self bundleOfAction:inName] URLForResource:@"main" withExtension:@"scpt"] error:&error] autorelease];
	XCTAssertNotNil(script, @"the script of %@: %@", inName, error);
	// the settings: a record with the names of AMDefaultParameters
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:[[self bundleOfAction:inName] objectForInfoDictionaryKey:@"AMDefaultParameters"]];
	[settings addEntriesFromDictionary:inParameters];
	NSAppleEventDescriptor *fields = [NSAppleEventDescriptor listDescriptor];
	for (NSString *key in settings) {
		[fields insertDescriptor:[NSAppleEventDescriptor descriptorWithString:key] atIndex:0];
		[fields insertDescriptor:[NSAppleEventDescriptor descriptorWithBoolean:[settings[key] boolValue]] atIndex:0];
	}
	NSAppleEventDescriptor *record = [NSAppleEventDescriptor recordDescriptor];
	[record setDescriptor:fields forKeyword:keyASUserRecordFields];
	NSAppleEventDescriptor *arguments = [NSAppleEventDescriptor listDescriptor];
	[arguments insertDescriptor:inInput ?: [NSAppleEventDescriptor listDescriptor] atIndex:0];
	[arguments insertDescriptor:record atIndex:0];
	NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kCoreEventClass eventID:kAEOpenApplication targetDescriptor:nil returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
	[event setParamDescriptor:arguments forKeyword:keyDirectObject];
	NSAppleEventDescriptor *result = [script executeAppleEvent:event error:&error];
	XCTAssertNil(error, @"%@ failed: %@", inName, error);
	return result;
}

-(NSAppleEventDescriptor *)listOf:(NSArray *)inItems
{
	NSAppleEventDescriptor *list = [NSAppleEventDescriptor listDescriptor];
	for (id item in inItems)
		[list insertDescriptor:[item isKindOfClass:[NSURL class]] ? [NSAppleEventDescriptor descriptorWithFileURL:item] : [NSAppleEventDescriptor descriptorWithString:item] atIndex:0];
	return list;
}

// The action loaded by Automator itself; nil when its user has not enabled the actions of third parties
-(AMBundleAction *)actionLoadedByAutomator:(NSString *)inName
{
	NSError *error = nil;
	AMBundleAction *action = [[[AMAppleScriptAction alloc] initWithContentsOfURL:[self urlOfAction:inName] error:&error] autorelease];
	if (!action) {
		XCTAssertTrue([[error domain] isEqualToString:@"com.apple.Automator"] && [error code] == -222, @"%@ cannot be loaded by Automator: %@", inName, error);
		NSLog(@"ProVocAutomatorTests: Automator does not load %@ (the actions of third parties are not enabled in Automator on this Mac)", inName);
	}
	return action;
}

-(NSArray *)sources
{
	return [[mDocument allWords] valueForKey:@"sourceWord"];
}

// The three actions are in the application, for Automator to find, with their script,
// their names and their settings view in English, French and Italian.
-(void)testActionsAreInTheApplication
{
	NSDictionary *settings = @{@"Add Files to Vocabulary": @[@"newDocument"], @"Add Text to Vocabulary": @[@"newDocument"], @"Get Contents of ProVoc Document": @[@"selectionOnly", @"includeNames", @"includeComments"]};
	NSArray *found = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[[self urlOfAction:@"x"] URLByDeletingLastPathComponent] path] error:NULL];
	XCTAssertEqualObjects([[found sortedArrayUsingSelector:@selector(compare:)] valueForKey:@"stringByDeletingPathExtension"], [[settings allKeys] sortedArrayUsingSelector:@selector(compare:)]);
	for (NSString *name in settings) {
		NSBundle *bundle = [self bundleOfAction:name];
		XCTAssertEqualObjects([bundle objectForInfoDictionaryKey:@"NSPrincipalClass"], @"AMAppleScriptAction", @"%@", name);
		XCTAssertEqualObjects([bundle objectForInfoDictionaryKey:@"AMApplication"], @"ProVoc");
		XCTAssertEqualObjects([bundle objectForInfoDictionaryKey:@"AMName"], name);
		XCTAssertNotNil([bundle pathForResource:@"main" ofType:@"scpt"], @"%@ has no compiled script", name);
		XCTAssertEqualObjects([[[bundle objectForInfoDictionaryKey:@"AMDefaultParameters"] allKeys] sortedArrayUsingSelector:@selector(compare:)], [settings[name] sortedArrayUsingSelector:@selector(compare:)], @"settings of %@", name);
		for (NSString *language in @[@"English", @"French", @"Italian"]) {
			NSDictionary *strings = [NSDictionary dictionaryWithContentsOfFile:[bundle pathForResource:@"InfoPlist" ofType:@"strings" inDirectory:nil forLocalization:language]];
			XCTAssertTrue([strings[@"AMName"] length] > 0, @"%@: no name in %@", name, language);
			// the view of the settings: a check box for each, bound to the settings of the action
			NSString *nibPath = [bundle pathForResource:@"main" ofType:@"nib" inDirectory:nil forLocalization:language];
			XCTAssertNotNil(nibPath, @"%@: no settings view in %@", name, language);
			NSData *data = [NSData dataWithContentsOfFile:[nibPath stringByAppendingPathComponent:@"keyedobjects.nib"]] ?: [NSData dataWithContentsOfFile:nibPath];
			PVActionOwner *owner = [[[PVActionOwner alloc] init] autorelease];
			owner->parameters = [[bundle objectForInfoDictionaryKey:@"AMDefaultParameters"] mutableCopy];
			NSArray *objects = nil;
			XCTAssertTrue([[[[NSNib alloc] initWithNibData:data bundle:bundle] autorelease] instantiateWithOwner:owner topLevelObjects:&objects], @"%@: the settings view in %@ did not load", name, language);
			XCTAssertNotNil(owner->view, @"%@ in %@: no view", name, language);
			NSMutableArray *boxes = [NSMutableArray array];
			NSMutableArray *views = [NSMutableArray arrayWithObject:owner->view ?: [[[NSView alloc] init] autorelease]];
			while ([views count] > 0) {
				NSView *each = views[0];
				[views removeObjectAtIndex:0];
				[views addObjectsFromArray:[each subviews]];
				if ([each isKindOfClass:[NSButton class]] && [each infoForBinding:NSValueBinding])
					[boxes addObject:each];
			}
			XCTAssertEqual([boxes count], [settings[name] count], @"check boxes of %@ in %@", name, language);
			for (NSButton *box in boxes) {
				NSString *key = [[[box infoForBinding:NSValueBinding][NSObservedKeyPathKey] componentsSeparatedByString:@"."] lastObject];
				XCTAssertTrue([[box title] length] > 0);
				XCTAssertEqualObjects(owner->parameters[key], @NO, @"%@ of %@", key, name);
				[box performClick:nil];
				XCTAssertEqualObjects(owner->parameters[key], @YES, @"%@ in %@: the check box of %@ does not change the setting", name, language, key);
			}
			// (the controller of the nib observes the owner: undo that before the owner goes away)
			for (id object in objects)
				if ([object isKindOfClass:[NSObjectController class]])
					[object unbind:NSContentObjectBinding];
		}
		// loaded by Automator itself, when it accepts to
		AMBundleAction *action = [self actionLoadedByAutomator:name];
		if (action) {
			XCTAssertEqualObjects([action name], name);
			XCTAssertTrue([action hasView] && [action view] != nil, @"%@ has no settings view in Automator", name);
		}
	}
}

// Get Contents of ProVoc Document: the words of the front document, as text for the next action
-(void)testGetContentsOfDocument
{
	NSString *name = @"Get Contents of ProVoc Document";
	[[self wordWithSource:@"cat"] setComment:@"animal"];
	XCTAssertEqualObjects([[self run:name input:nil parameters:nil] stringValue], @"house\tmaison\ncat\tchat\ndog\tchien\nsummer\tété\n");
	NSString *text = [[self run:name input:nil parameters:@{@"includeComments": @YES, @"includeNames": @YES}] stringValue];
	XCTAssertTrue([text rangeOfString:@"cat\tchat\tanimal\n"].location != NSNotFound && [text hasPrefix:@"# "], @"with names and comments: %@", text);
	// only the selected lessons
	PVAddPage(mDocument, @"Lesson 2", @[@[@"bird", @"oiseau"]]);
	NSOutlineView *lessons = [mDocument valueForKey:@"mPageOutlineView"];
	[lessons selectRowIndexes:[NSIndexSet indexSetWithIndex:[lessons numberOfRows] - 1] byExtendingSelection:NO];
	XCTAssertEqualObjects([[self run:name input:nil parameters:@{@"selectionOnly": @YES}] stringValue], @"bird\toiseau\n");
	AMBundleAction *action = [self actionLoadedByAutomator:name];
	if (action) {
		NSError *error = nil;
		id output = [action runWithInput:nil error:&error];
		XCTAssertNil(error);
		XCTAssertTrue([[output description] rangeOfString:@"house"].location != NSNotFound, @"run by Automator: %@", output);
	}
}

// Add Text to Vocabulary: the text that comes from the previous action becomes words
// of the front document - or of a new one.
-(void)testAddTextToVocabulary
{
	NSString *name = @"Add Text to Vocabulary";
	NSAppleEventDescriptor *output = [self run:name input:[self listOf:@[@"sun\tsoleil\nmoon\tlune\tat night\n"]] parameters:nil];
	XCTAssertEqualObjects([self sources], (@[@"house", @"cat", @"dog", @"summer", @"sun", @"moon"]));
	XCTAssertEqualObjects([[[mDocument allWords] lastObject] comment], @"at night");
	XCTAssertEqualObjects([[output descriptorAtIndex:1] stringValue], @"sun\tsoleil\nmoon\tlune\tat night\n", @"the action passes its input on");

	NSArray *before = [[[[NSDocumentController sharedDocumentController] documents] copy] autorelease];
	[self run:name input:[self listOf:@[@"bread\tpain\n"]] parameters:@{@"newDocument": @YES}];
	ProVocDocument *(^newDocument)(void) = ^{
		for (ProVocDocument *document in [[NSDocumentController sharedDocumentController] documents])
			if (![before containsObject:document])
				return document;
		return (ProVocDocument *)nil;
	};
	XCTAssertTrue(PVWaitUntil(10, ^BOOL { return newDocument() != nil; }), @"no new document");
	XCTAssertEqualObjects([[newDocument() allWords] valueForKey:@"sourceWord"], @[@"bread"]);
	XCTAssertEqual([[self sources] count], 6u, @"the words went to the front document too");
	PVCloseDocument(newDocument());
}

// Add Files to Vocabulary: the text files that come from the previous action are imported
-(void)testAddFilesToVocabulary
{
	NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"PVAutomator-%i.txt", [[NSProcessInfo processInfo] processIdentifier]]];
	XCTAssertTrue([@"sea\tmer\nsky\tciel\n" writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
	[self run:@"Add Files to Vocabulary" input:[self listOf:@[[NSURL fileURLWithPath:file]]] parameters:nil];
	XCTAssertTrue(PVWaitUntil(10, ^BOOL { return [[self sources] count] == 6; }), @"the words of the file were not added: %@", [self sources]);
	XCTAssertEqualObjects([self sources], (@[@"house", @"cat", @"dog", @"summer", @"sea", @"sky"]));
	[[NSFileManager defaultManager] removeItemAtPath:file error:NULL];
}

@end
