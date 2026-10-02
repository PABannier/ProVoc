//
//  main.m
//  ProVoc
//
//  Created by Simon Bovet on 13.05.06.
//  Copyright Arizona Software 2006 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

static void ProVocUncaughtExceptionHandler(NSException *inException)
{
	NSLog(@"*** Uncaught exception %@: %@\n%@", [inException name], [inException reason], [inException callStackSymbols]);
}

int main(int argc, char *argv[])
{
	NSSetUncaughtExceptionHandler(ProVocUncaughtExceptionHandler);
#ifdef DEBUG
	@autoreleasepool {
		// Test hook: "-PVResetDefaults YES" starts from factory settings.
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if ([defaults boolForKey:@"PVResetDefaults"])
			[defaults removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
	}
#endif
    return NSApplicationMain(argc, (const char **) argv);
}
