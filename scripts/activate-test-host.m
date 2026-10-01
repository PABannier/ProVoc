// Brings the ProVoc process that hosts the unit tests to the front.
// xcodebuild starts the test host in the background and macOS does not let a
// background process activate itself; the tests that send key events need the
// application to be active (to have a key window).
//
// usage: activate-test-host <path of the executable>   (runs until killed)
#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[])
{
	@autoreleasepool {
		NSString *executable = argc > 1 ? @(argv[1]) : nil;
		for (;;) {
			@autoreleasepool {
				for (NSRunningApplication *application in [[NSWorkspace sharedWorkspace] runningApplications])
					if ([[[application executableURL] path] isEqualToString:executable] && ![application isActive])
						[application activateWithOptions:NSApplicationActivateAllWindows];
			}
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
		}
	}
	return 0;
}
