//
//  PVDriver.h
//
//  End-to-end scenarios played in the stand-alone application.
//
//  The hosted unit tests (ProVocTests) run inside a callout of XCTest: there, the event
//  loop of the application is never back at its top level, so what AppKit does "at the
//  end of the current event" never happens (undo groups are not closed, documents do
//  not become "edited"), and the application cannot be launched in another language,
//  with a document, or quit. This library is inserted into the real application
//  instead (scripts/e2e.py): a scenario is a PVScript whose steps are run by a timer of
//  the application's own event loop, posting key events to its event queue.
//
//  Environment: PV_SCENARIO (name of the scenario), PV_RESULT_FILE (where the verdict
//  is written), PV_WORKDIR (a directory for the files of the scenario).
//

#import <Cocoa/Cocoa.h>
#import "PVTestSupport.h"
#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocWord.h"
#import "ProVocPage.h"
#import "ProVocTester.h"
#import "ProVocPreferences.h"

void PVFail(const char *inFile, int inLine, NSString *inFormat, ...) NS_FORMAT_FUNCTION(3, 4);
#define PVExpect(condition, format, ...) do { if (!(condition)) PVFail(__FILE__, __LINE__, @"%s — " format, #condition, ##__VA_ARGS__); } while (0)
#define PVExpectEqualObjects(a, b, format, ...) do { id _a = (a), _b = (b); if (!(_a == _b || [_a isEqual:_b])) PVFail(__FILE__, __LINE__, @"%s is %@, expected %@ — " format, #a, _a, _b, ##__VA_ARGS__); } while (0)
#define PVExpectEqual(a, b, format, ...) do { long long _a = (long long)(a), _b = (long long)(b); if (_a != _b) PVFail(__FILE__, __LINE__, @"%s is %lld, expected %lld — " format, #a, _a, _b, ##__VA_ARGS__); } while (0)

// The scenarios: -<name>:(PVScript *)inScript adds the steps of the scenario <name>.
@interface PVScenarios : NSObject
+(NSString *)workDirectory;
// The scenario ends with the application quitting by itself (the last step asked it to)
+(void)expectTermination;

// What the user sees
+(ProVocDocument *)document;		// the document of the main window
+(ProVocTester *)tester;
+(NSTextField *)answerField;
+(BOOL)answerFieldHasFocus;
+(NSMenuItem *)menuItemWithAction:(SEL)inAction;
+(NSMenuItem *)menuItemWithAction:(SEL)inAction tag:(NSInteger)inTag;
+(NSButton *)buttonWithTitle:(NSString *)inTitle inWindow:(NSWindow *)inWindow;
+(NSArray *)sourceWordsOf:(ProVocDocument *)inDocument;
@end
