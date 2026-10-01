//
//  ProVocNibTests.m
//
//  Loads every nib of every localization and checks that it decodes, that every
//  class it names exists, and that every IBOutlet of its owner gets connected.
//  A nil outlet is a silently broken feature.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "PVTestSupport.h"

// Stands in for File's Owner. AppKit connects an outlet through an ivar of that name
// and checks that the owner responds to every action it is the target of, so a probe
// class is built at runtime with the outlet ivars declared in the sources and it
// answers -respondsToSelector: like the real owner class does. Everything else the
// nib objects send it while awaking is swallowed.
static Class sRealOwnerClass = Nil;

static BOOL PVProbeRespondsToSelector(id self, SEL _cmd, SEL inSelector)
{
	return [sRealOwnerClass instancesRespondToSelector:inSelector];
}

static NSMethodSignature *PVProbeMethodSignature(id self, SEL _cmd, SEL inSelector)
{
	NSMethodSignature *signature = [sRealOwnerClass instanceMethodSignatureForSelector:inSelector];
	if (!signature)
		signature = [NSMethodSignature signatureWithObjCTypes:"@@:"];
	return signature;
}

static void PVProbeForwardInvocation(id self, SEL _cmd, NSInvocation *inInvocation)
{
	NSUInteger length = [[inInvocation methodSignature] methodReturnLength];
	if (length > 0) {
		void *zero = calloc(1, length);
		[inInvocation setReturnValue:zero];
		free(zero);
	}
}

static id PVProbeValueForUndefinedKey(id self, SEL _cmd, NSString *inKey)
{
	// Like the real owner: nil for object properties, a number for scalar ones.
	NSMethodSignature *signature = [sRealOwnerClass instanceMethodSignatureForSelector:NSSelectorFromString(inKey)];
	if (signature && strchr("@#:v", [signature methodReturnType][0]) == NULL)
		return @0;
	return nil;
}

static void PVProbeSetValueForUndefinedKey(id self, SEL _cmd, id inValue, NSString *inKey)
{
}

static Class PVProbeClass(NSString *inOwnerClassName, NSSet *inOutlets)
{
	static int serial = 0;
	Class probe = objc_allocateClassPair([NSObject class], [[NSString stringWithFormat:@"PVNibProbe%i_%@", serial++, inOwnerClassName] UTF8String], 0);
	for (NSString *outlet in inOutlets)
		class_addIvar(probe, [outlet UTF8String], sizeof(id), log2(sizeof(id)), @encode(id));
	class_addMethod(probe, @selector(respondsToSelector:), (IMP)PVProbeRespondsToSelector, "c@::");
	class_addMethod(probe, @selector(methodSignatureForSelector:), (IMP)PVProbeMethodSignature, "@@::");
	class_addMethod(probe, @selector(forwardInvocation:), (IMP)PVProbeForwardInvocation, "v@:@");
	class_addMethod(probe, @selector(valueForUndefinedKey:), (IMP)PVProbeValueForUndefinedKey, "@@:@");
	class_addMethod(probe, @selector(setValue:forUndefinedKey:), (IMP)PVProbeSetValueForUndefinedKey, "v@:@@");
	objc_registerClassPair(probe);
	return probe;
}

@interface ProVocNibTests : XCTestCase
@end

@implementation ProVocNibTests

+(NSDictionary *)ownerClassNames
{
	return @{@"MainMenu": @"NSApplication",
			 @"ARAbout": @"ARAboutDialog",
			 @"Preferences": @"ProVocPreferences",
			 @"ProVocAction": @"ProVocActionController",
			 @"ProVocBackground": @"ProVocBackground",
			 @"ProVocCardController": @"ProVocCardController",
			 @"ProVocDocument": @"ProVocDocument",
			 @"ProVocInspector": @"ProVocInspector",
			 @"ProVocSpotlighter": @"ProVocSpotlighter",
			 @"ProVocStartingPoint": @"ProVocStartingPoint",
			 @"ProVocSubmitter": @"ProVocSubmitter",
			 @"ProVocTester": @"ProVocTester",
			 @"ProVocTimer": @"ProVocTimer",
			 @"ProVocViewOptions": @"ProVocViewOptions",
			 @"SoundRecorder": @"SoundRecorderController"};
}

// Outlets that no nib has ever connected (checked against the original 2008 nibs).
+(NSSet *)outletsUnconnectedByDesign
{
	return [NSSet setWithArray:@[@"mSecretWindow",			// ARAboutDialog: optional second window, not part of ProVoc's About nib
								 @"mLanguageOptionsWindow",	// ProVocPreferences: a feature that was never finished
								 @"mTestDirectionPopUp"]];	// ProVocDocument: replaced by a binding long ago
}

+(NSArray *)localizations
{
	return @[@"English", @"French", @"German", @"Italian", @"Spanish", @"Danish"];
}

// IBOutlet ivars declared for a class in the sources (including its superclasses).
+(NSSet *)declaredOutletsOfClassNamed:(NSString *)inClassName
{
	static NSMutableDictionary *interfaces = nil;
	if (!interfaces) {
		interfaces = [[NSMutableDictionary alloc] init];
		NSString *sources = [PVTestSourceRoot() stringByAppendingPathComponent:@"Sources"];
		NSRegularExpression *interface = [NSRegularExpression regularExpressionWithPattern:@"@interface\\s+(\\w+)\\s*:\\s*(\\w+)[^{@]*\\{([^}]*)\\}" options:0 error:NULL];
		for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:sources error:NULL]) {
			if (![@[@"h", @"m"] containsObject:[file pathExtension]])
				continue;
			NSString *text = [NSString stringWithContentsOfFile:[sources stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:NULL];
			if (!text)
				text = [NSString stringWithContentsOfFile:[sources stringByAppendingPathComponent:file] encoding:NSMacOSRomanStringEncoding error:NULL];
			for (NSTextCheckingResult *match in [interface matchesInString:text options:0 range:NSMakeRange(0, [text length])])
				interfaces[[text substringWithRange:[match rangeAtIndex:1]]] = @{@"super": [text substringWithRange:[match rangeAtIndex:2]], @"ivars": [text substringWithRange:[match rangeAtIndex:3]]};
		}
	}
	NSMutableSet *outlets = [NSMutableSet set];
	NSRegularExpression *outlet = [NSRegularExpression regularExpressionWithPattern:@"IBOutlet\\s+[^;]*?(\\w+)\\s*;" options:0 error:NULL];
	NSString *name = inClassName;
	while (interfaces[name]) {
		NSString *ivars = interfaces[name][@"ivars"];
		for (NSTextCheckingResult *match in [outlet matchesInString:ivars options:0 range:NSMakeRange(0, [ivars length])])
			[outlets addObject:[ivars substringWithRange:[match rangeAtIndex:1]]];
		name = interfaces[name][@"super"];
	}
	return outlets;
}

-(NSArray *)nibNamesInLocalization:(NSString *)inLocalization
{
	NSMutableArray *names = [NSMutableArray array];
	NSString *resources = [[NSBundle mainBundle] resourcePath];
	for (NSString *directory in @[resources, [resources stringByAppendingPathComponent:[inLocalization stringByAppendingPathExtension:@"lproj"]]])
		for (NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL])
			if ([[file pathExtension] isEqualToString:@"nib"])
				[names addObject:[directory stringByAppendingPathComponent:file]];
	return names;
}

-(void)testNoBackupNibIsShipped
{
	NSString *resources = [[NSBundle mainBundle] resourcePath];
	for (NSString *path in [[NSFileManager defaultManager] enumeratorAtPath:resources])
		XCTAssertFalse([path containsString:@"~"], @"stale backup shipped: %@", path);
}

-(void)testEveryLocalizationHasEveryNib
{
	NSMutableSet *english = [NSMutableSet set];
	for (NSString *path in [self nibNamesInLocalization:@"English"])
		[english addObject:[path lastPathComponent]];
	XCTAssertTrue([english count] >= 13, @"only %@", english);
	for (NSString *localization in [[self class] localizations]) {
		NSMutableSet *nibs = [NSMutableSet set];
		for (NSString *path in [self nibNamesInLocalization:localization])
			[nibs addObject:[path lastPathComponent]];
		XCTAssertEqualObjects(nibs, english, @"%@", localization);
	}
}

-(void)checkNibAtPath:(NSString *)inPath localization:(NSString *)inLocalization
{
	NSString *name = [[inPath lastPathComponent] stringByDeletingPathExtension];
	NSString *what = [NSString stringWithFormat:@"%@/%@", inLocalization, name];
	NSString *ownerClassName = [[self class] ownerClassNames][name];
	XCTAssertNotNil(ownerClassName, @"no owner known for %@: add it to the table so that it gets checked", name);
	if (!ownerClassName)
		return;
	sRealOwnerClass = NSClassFromString(ownerClassName);
	XCTAssertNotNil(sRealOwnerClass, @"%@: owner class %@ does not exist", what, ownerClassName);

	NSSet *declaredOutlets = [[self class] declaredOutletsOfClassNamed:ownerClassName];
	id owner = [[[PVProbeClass(ownerClassName, declaredOutlets) alloc] init] autorelease];
	NSArray *topLevelObjects = nil;
	BOOL loaded = NO;
	NSString *log = nil;
	PVBeginCapturingStderr();
	@try {
		// IB 2.x nibs are folders holding keyedobjects.nib; compiled ones are that file itself.
		NSData *data = [NSData dataWithContentsOfFile:[inPath stringByAppendingPathComponent:@"keyedobjects.nib"]];
		if (!data)
			data = [NSData dataWithContentsOfFile:inPath];
		NSNib *nib = [[[NSNib alloc] initWithNibData:data bundle:[NSBundle mainBundle]] autorelease];
		// (a MainMenu nib makes its menu the main menu of the application: put ours back)
		NSMenu *mainMenu = [[[NSApp mainMenu] retain] autorelease];
		NSMenu *windowsMenu = [[[NSApp windowsMenu] retain] autorelease];
		NSMenu *servicesMenu = [[[NSApp servicesMenu] retain] autorelease];
		loaded = [nib instantiateWithOwner:owner topLevelObjects:&topLevelObjects];
		if ([NSApp mainMenu] != mainMenu) {
			[NSApp setMainMenu:mainMenu];
			[NSApp setWindowsMenu:windowsMenu];
			[NSApp setServicesMenu:servicesMenu];
		}
	} @catch (NSException *exception) {
		XCTFail(@"%@ raised %@", what, exception);
	} @finally {
		log = PVEndCapturingStderr();
	}
	XCTAssertTrue(loaded, @"%@ did not load", what);

	NSMutableArray *complaints = [NSMutableArray array];
	for (NSString *line in [log componentsSeparatedByString:@"\n"])
		for (NSString *pattern in @[@"Unknown class", @"ould not", @"xception", @"***", @"nrecognized"])
			if ([line containsString:pattern] && ![complaints containsObject:line])
				[complaints addObject:line];
	XCTAssertEqualObjects(complaints, @[], @"%@ logged while loading", what);

	NSMutableArray *missing = [NSMutableArray array];
	for (NSString *outlet in declaredOutlets)
		if (!object_getIvar(owner, class_getInstanceVariable([owner class], [outlet UTF8String])) && ![[[self class] outletsUnconnectedByDesign] containsObject:outlet])
			[missing addObject:outlet];
	XCTAssertEqualObjects([missing sortedArrayUsingSelector:@selector(compare:)], @[], @"%@: outlets of %@ left nil", what, ownerClassName);

	int index = 0;
	for (id object in topLevelObjects)
		if ([object isKindOfClass:[NSWindow class]]) {
			PVSaveWindowSnapshot(object, [NSString stringWithFormat:@"nibs/%@/%@-%i", inLocalization, name, index++]);
			[object orderOut:nil];
		}
}

-(void)checkLocalization:(NSString *)inLocalization
{
	NSArray *paths = [self nibNamesInLocalization:inLocalization];
	XCTAssertTrue([paths count] >= 13, @"%@ has only %lu nibs", inLocalization, (unsigned long)[paths count]);
	for (NSString *path in paths)
		[self checkNibAtPath:path localization:inLocalization];
}

-(void)testEnglishNibs { [self checkLocalization:@"English"]; }
-(void)testFrenchNibs { [self checkLocalization:@"French"]; }
-(void)testGermanNibs { [self checkLocalization:@"German"]; }
-(void)testItalianNibs { [self checkLocalization:@"Italian"]; }
-(void)testSpanishNibs { [self checkLocalization:@"Spanish"]; }
-(void)testDanishNibs { [self checkLocalization:@"Danish"]; }

@end
