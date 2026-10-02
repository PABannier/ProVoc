#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/getsect.h>
#import "ProVocApplication.h"

@interface ProVocAppTests : XCTestCase
@end

@implementation ProVocAppTests

-(void)testApplicationClass
{
	XCTAssertTrue([NSApp isKindOfClass:[ProVocApplication class]], @"NSApp is %@", [NSApp class]);
}

// ProVoc adds methods to classes of the system with categories. Where the system class
// has a method of the same name, which of the two is called is undefined: About ProVoc
// opened the standard About panel because of that. No category of the application may
// define a method that the class already has.
-(void)testNoCategoryOfTheApplicationCollidesWithAMethodOfTheSystem
{
	const char *application = [[[NSBundle mainBundle] executablePath] fileSystemRepresentation];
	// the code of the application in memory
	Dl_info main;
	XCTAssertTrue(dladdr(class_getMethodImplementation([ProVocApplication class], @selector(sendEvent:)), &main) != 0);
	unsigned long textSize = 0;
	uintptr_t text = (uintptr_t)getsegmentdata(main.dli_fbase, "__TEXT", &textSize);
	XCTAssertTrue(text && textSize > 0);
	NSMutableArray *collisions = [NSMutableArray array];
	unsigned int classCount = 0;
	Class *classes = objc_copyClassList(&classCount);
	for (unsigned int c = 0; c < classCount; c++) {
		const char *image = class_getImageName(classes[c]);
		if (!image || strcmp(image, application) == 0)
			continue;	// a class of the application itself
		for (int meta = 0; meta <= 1; meta++) {
			Class class = meta ? object_getClass(classes[c]) : classes[c];
			unsigned int methodCount = 0;
			Method *methods = class_copyMethodList(class, &methodCount);
			NSMutableDictionary *ours = [NSMutableDictionary dictionary], *theirs = [NSMutableDictionary dictionary];
			for (unsigned int m = 0; m < methodCount; m++) {
				NSString *name = NSStringFromSelector(method_getName(methods[m]));
				uintptr_t implementation = (uintptr_t)method_getImplementation(methods[m]);
				if (implementation >= text && implementation < text + textSize)
					ours[name] = @YES;
				else
					theirs[name] = @YES;
			}
			free(methods);
			for (NSString *name in ours)
				if (theirs[name])
					[collisions addObject:[NSString stringWithFormat:@"%c[%s %@]", meta ? '+' : '-', class_getName(classes[c]), name]];
		}
	}
	free(classes);
	XCTAssertEqualObjects(collisions, @[], @"methods defined both by the system and by a category of ProVoc");
}

@end
