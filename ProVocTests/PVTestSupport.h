//
//  PVTestSupport.h
//  Helpers shared by the unit tests.
//

#import <Cocoa/Cocoa.h>

// Root of the source tree (set at build time).
NSString *PVTestSourceRoot(void);

// Everything written to stderr (NSLog) between the two calls.
void PVBeginCapturingStderr(void);
NSString *PVEndCapturingStderr(void);

// Renders a window into verification/screenshots/<name>.png (light) and <name>-dark.png.
void PVSaveWindowSnapshot(NSWindow *inWindow, NSString *inName);
