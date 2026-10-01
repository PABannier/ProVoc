#import <XCTest/XCTest.h>
#import "ProVocApplication.h"

@interface ProVocAppTests : XCTestCase
@end

@implementation ProVocAppTests

-(void)testApplicationClass
{
	XCTAssertTrue([NSApp isKindOfClass:[ProVocApplication class]], @"NSApp is %@", [NSApp class]);
}

@end
