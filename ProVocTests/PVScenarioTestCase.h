//
//  PVScenarioTestCase.h
//
//  Base class of the tests that drive a whole training session with key events.
//
//  Every -scenarioXxx method of a subclass becomes two tests: -testXxxInSheet (the
//  test panel is a sheet of the document window) and -testXxxInDimmedModalPanel
//  ("Dim test background" is on: the panel is run as a floating application-modal
//  window).
//

#import <XCTest/XCTest.h>
#import "PVTestSupport.h"
#import "ProVocDocument.h"
#import "ProVocDocument+Lists.h"
#import "ProVocTester.h"
#import "ProVocWord.h"
#import "ProVocPreferences.h"
#import "ProVocBackground.h"

@interface PVScenarioTestCase : XCTestCase {
	ProVocDocument *mDocument;
	NSDictionary *mAnswers;		// source word -> target word
}

// The words of the document of each test: an array of @[source, target] or @[source, target, comment]
-(NSArray *)words;

// What the user sees
-(ProVocTester *)tester;
-(NSPanel *)testPanel;
-(NSPanel *)resultPanel;
-(NSTextField *)answerField;
-(NSString *)question;
-(NSString *)typedAnswer;
-(int)progress;
-(int)progressMax;
-(BOOL)answerFieldHasFocus;
-(BOOL)answerTextIsSelectedOrEmpty;
-(BOOL)testPanelIsReady;
-(BOOL)showsQuestionNumber:(int)inNumber;
-(BOOL)showsSolution;
-(NSString *)displayedSolution;
-(NSString *)visibleStringBoundTo:(NSString *)inKeyPath inView:(NSView *)inView;
-(NSButton *)buttonWithAction:(SEL)inAction inView:(NSView *)inView;
// The view (also in the tabs not shown) with a binding to a key path, e.g. NSValueBinding to "testMCQ"
-(id)viewIn:(NSView *)inView withBinding:(NSString *)inBinding to:(NSString *)inKeyPath;
// In the document window
-(id)controlWithBinding:(NSString *)inBinding to:(NSString *)inKeyPath;
-(NSButton *)retryButton;
-(NSArray *)resultValues;
-(BOOL)testIsOver;
-(NSString *)variant;

-(ProVocWord *)wordWithSource:(NSString *)inSource;
-(ProVocWord *)currentWord;

// Types the right answer of the current question, then Return
-(void)answerCorrectlyIn:(PVScript *)inScript withReturnKeyCode:(unsigned short)inReturnKeyCode;
-(void)answerCorrectlyIn:(PVScript *)inScript;

// Chooses an item of the menu bar (the menu is validated first, as when it is opened)
-(void)chooseMenuItemWithAction:(SEL)inAction tag:(NSInteger)inTag;
-(NSMenuItem *)menuItemWithAction:(SEL)inAction tag:(NSInteger)inTag;

-(void)runScript:(PVScript *)inScript;

@end
