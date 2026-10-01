//
//  PVTestSupport.m
//

#import "PVTestSupport.h"

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
