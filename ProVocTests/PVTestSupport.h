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

// Spins the main run loop (default mode) until the condition holds; NO on timeout.
BOOL PVWaitUntil(NSTimeInterval inTimeout, BOOL (^inCondition)(void));

// Copies a deck into a fresh temporary folder and returns the copy's path.
NSString *PVTemporaryCopyOfDeck(NSString *inPath);

// Opens a deck (never the original: a temporary copy) and returns its document.
@class ProVocDocument;
ProVocDocument *PVOpenCopyOfDeck(NSString *inPath);
void PVCloseDocument(NSDocument *inDocument);

#pragma mark Decks built in code

@class ProVocPage, ProVocWord;

// A new untitled document shown in a window, with one lesson holding the given
// words: an array of @[source, target] or @[source, target, comment].
ProVocDocument *PVNewDocumentWithWords(NSArray *inWords);
ProVocPage *PVAddPage(ProVocDocument *inDocument, NSString *inTitle, NSArray *inWords);

#pragma mark Driving the application with key events

// Key codes (ANSI positions) used by the tests
enum {
	PVKeyReturn = 36, PVKeyTab = 48, PVKeySpace = 49, PVKeyDelete = 51, PVKeyEscape = 53, PVKeyKeypadEnter = 76,
	PVKeyLeft = 123, PVKeyRight = 124, PVKeyDown = 125, PVKeyUp = 126,
	PVKeyF1 = 122, PVKeyF2 = 120, PVKeyF3 = 99, PVKeyF4 = 118
};

// Posts a key down / key up pair to the application's event queue, exactly as if
// it came from the window server: it goes through -[NSApplication sendEvent:].
void PVPostKey(unsigned short inKeyCode, NSString *inCharacters, NSEventModifierFlags inModifiers);
void PVPostKeyRepeat(unsigned short inKeyCode, NSString *inCharacters, NSEventModifierFlags inModifiers, BOOL inIsRepeat);
// A mouse click (or double click...) in the middle of a view, or at a point of it.
void PVClickView(NSView *inView, NSInteger inClickCount, NSEventModifierFlags inModifiers);
void PVClickAtPoint(NSView *inView, NSPoint inPoint, NSInteger inClickCount, NSEventModifierFlags inModifiers);
// A modifier key going down (or up, with no flag): windows get -flagsChanged:
void PVPostFlagsChanged(NSEventModifierFlags inModifiers);
// Presses a button of a system alert. (The buttons of the alerts of macOS 26 track the
// real mouse: they ignore mouse events posted to the event queue. This is what
// VoiceOver or "full keyboard access" do.)
void PVPressAlertButton(NSButton *inButton);
// One key event per character.
void PVTypeText(NSString *inText);
// Command-<character>, e.g. PVTypeCommand(@"r", 0); extra modifiers may be added.
void PVTypeCommand(NSString *inCharacter, NSEventModifierFlags inExtraModifiers);

// What a view is told about a drag over it. A real drag session follows the mouse
// pointer of the window server and cannot be played with posted events: the tests
// let the drag source write its pasteboard, then hand this to the methods of the
// destination that AppKit calls (validate, accept).
@interface PVDragInfo : NSObject <NSDraggingInfo> {
	NSPasteboard *mPasteboard;
	id mSource;
	NSDragOperation mOperationMask;
	NSPoint mLocation;
	NSWindow *mWindow;
}
// inCopy: the Option key is held (the only operation offered is a copy)
+(PVDragInfo *)infoWithPasteboard:(NSPasteboard *)inPasteboard source:(id)inSource copy:(BOOL)inCopy;
// A drag of files from the Finder
+(PVDragInfo *)infoWithFiles:(NSArray *)inPaths;
// Where the pointer is, in a view of the destination window
-(void)setLocation:(NSPoint)inPoint inView:(NSView *)inView;
@end

// Does what AppKit does when a menu is about to open: asks its delegate to fill it in
// (the Open Recent menu, for instance, has no items until then), then validates the items.
void PVPrepareMenu(NSMenu *inMenu);

// A script is a list of steps run one after the other while the application's
// event loop is spinning, including inside modal sessions and sheets.
typedef BOOL (^PVCondition)(void);
@interface PVScript : NSObject
+(PVScript *)script;
// Runs the block once.
-(void)then:(void (^)(void))inBlock;
// Waits (up to 5 s) until the condition holds; the script fails otherwise.
-(void)wait:(NSString *)inDescription until:(PVCondition)inCondition;
-(void)wait:(NSString *)inDescription timeout:(NSTimeInterval)inTimeout until:(PVCondition)inCondition;
// Lets the event loop run for a while (to prove that something does NOT happen).
-(void)pause:(NSTimeInterval)inDuration;
// Runs the steps; returns nil on success, otherwise the description of the wait that timed out.
-(NSString *)run;
// Runs the steps from the event loop of the application and returns at once (for the
// driver of the stand-alone application, where nothing but the application's own event
// loop must be on the stack). The block is called at the end, with the failure or nil.
-(void)startWithCompletion:(void (^)(NSString *inFailure))inCompletion;
// Makes the script fail (once it has ended) without stopping it.
-(void)fail:(NSString *)inFailure;
@end

// A real screenshot of one of our own windows, as composited on screen (Core Animation
// content included), into verification/screenshots/<name>.png. Returns the bitmap.
NSBitmapImageRep *PVSaveWindowScreenshot(NSWindow *inWindow, NSString *inName);
// Number of clearly different colors in a bitmap (coarse): 1 means a blank picture.
NSUInteger PVNumberOfDistinctColors(NSBitmapImageRep *inBitmap);

#pragma mark Media files made for the tests

// Small media files generated once per test run: "wav", "aiff", "m4a", "mp3" (nearly
// silent sounds), "png", "jpg" (pictures), "mov", "mp4" (one-second movies), and
// "bad.mov" (a file that is not a movie at all).
NSString *PVMediaFile(NSString *inKind);
