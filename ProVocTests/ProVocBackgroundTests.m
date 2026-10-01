//
//  ProVocBackgroundTests.m
//
//  The four built-in backgrounds are drawn natively and really show something.
//

#import <XCTest/XCTest.h>
#import "PVTestSupport.h"
#import "ProVocBackground.h"
#import "ProVocBackgroundScene.h"

@interface ProVocBackgroundTests : XCTestCase
@end

@implementation ProVocBackgroundTests

-(void)testBuiltInBackgroundsAreDrawnNatively
{
	NSArray *styles = [ProVocBackgroundStyle availableBackgroundStyles];
	NSMutableSet *names = [NSMutableSet set];
	for (ProVocBackgroundStyle *style in styles)
		if ([style bundle])
			[names addObject:[style identifier]];
	NSSet *expected = [NSSet setWithArray:@[@"ch.arizona-software.provoc.background.plantshades", @"ch.arizona-software.provoc.background.ocean",
											@"ch.arizona-software.provoc.background.globe", @"ch.arizona-software.provoc.background.nature"]];
	XCTAssertTrue([expected isSubsetOfSet:names], @"built-in backgrounds found: %@", names);

	for (ProVocBackgroundStyle *style in styles) {
		if (![expected containsObject:[style identifier]])
			continue;
		XCTAssertTrue([ProVocBackgroundScene canDrawBackgroundOfBundle:[style bundle]], @"%@", [style name]);
		NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(60, 60, 800, 500) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO] autorelease];
		[window setReleasedWhenClosed:NO];
		ProVocBackgroundScene *scene = [[[ProVocBackgroundScene alloc] initWithFrame:NSMakeRect(0, 0, 800, 500)] autorelease];
		[scene setBundle:[style bundle]];
		[window setContentView:scene];
		XCTAssertTrue([[scene inputKeys] count] > 0, @"%@", [style name]);
		[scene setValue:[NSColor colorWithCalibratedRed:0.2 green:0.3 blue:0.5 alpha:1.0] forInputKey:@"Color"];
		[scene setValue:@"the house" forInputKey:@"Question"];
		[scene setValue:@"la maison" forInputKey:@"Answer"];
		[scene startRendering];
		XCTAssertTrue([scene isRendering]);
		[window orderFront:nil];
		PVWaitUntil(2.5, ^BOOL { return NO; });
		NSBitmapImageRep *bitmap = PVSaveWindowScreenshot(window, [@"backgrounds/" stringByAppendingString:[style name]]);
		XCTAssertNotNil(bitmap, @"no screenshot of %@", [style name]);
		XCTAssertTrue(PVNumberOfDistinctColors(bitmap) >= 4, @"the %@ background is blank (%lu colors)", [style name], (unsigned long)PVNumberOfDistinctColors(bitmap));
		// the reactions to answers must not raise
		[scene setValue:@YES forInputKey:@"CorrectAnswer"];
		[scene setValue:@NO forInputKey:@"CorrectAnswer"];
		[scene setValue:@YES forInputKey:@"WrongAnswer"];
		[scene setValue:@NO forInputKey:@"WrongAnswer"];
		[scene setValue:@YES forInputKey:@"NewQuestion"];
		[scene setValue:@NO forInputKey:@"NewQuestion"];
		PVWaitUntil(0.3, ^BOOL { return NO; });
		[scene stopRendering];
		[window close];
	}
}

@end
