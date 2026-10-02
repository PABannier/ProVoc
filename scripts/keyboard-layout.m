// The keyboard layout of the system, for the scripts that type with real keys.
//
// usage: keyboard-layout            prints the identifier of the current layout
//        keyboard-layout --list     prints the identifiers of the enabled layouts
//        keyboard-layout <id>       selects that layout (it must be enabled); exit 1 otherwise
#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

int main(int argc, const char *argv[])
{
	@autoreleasepool {
		if (argc < 2) {
			TISInputSourceRef source = TISCopyCurrentKeyboardLayoutInputSource();
			printf("%s\n", [(__bridge NSString *)TISGetInputSourceProperty(source, kTISPropertyInputSourceID) UTF8String]);
			CFRelease(source);
			return 0;
		}
		NSString *wanted = @(argv[1]);
		BOOL list = [wanted isEqualToString:@"--list"];
		NSDictionary *filter = list ? @{(__bridge id)kTISPropertyInputSourceType: (__bridge id)kTISTypeKeyboardLayout} : @{(__bridge id)kTISPropertyInputSourceID: wanted};
		NSArray *sources = CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)filter, false));
		if (list) {
			for (id source in sources)
				printf("%s\n", [(__bridge NSString *)TISGetInputSourceProperty((__bridge TISInputSourceRef)source, kTISPropertyInputSourceID) UTF8String]);
			return 0;
		}
		return [sources count] > 0 && TISSelectInputSource((__bridge TISInputSourceRef)[sources firstObject]) == noErr ? 0 : 1;
	}
}
