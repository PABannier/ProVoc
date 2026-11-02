//
//  ProVocBoxesSheet.h
//  ProVoc
//
//  A picture with boxes over its labels: one word per box. The boxes are edited here;
//  from then on they are ordinary words of the lesson (see -[ProVocWord occlusion]).
//

#import <Cocoa/Cocoa.h>

#import "ProVocDocument.h"
#import "ProVocImageView.h"

@interface ProVocBoxesView : ProVocImageView {
	NSMutableArray *mBoxes;		// {rect: NSValue, fractions of the picture, origin top left; answer; word}
	NSUInteger mSelection;
	int mDragKind;
	NSPoint mDragStart;
	NSRect mDragRect;
	NSTextField *mEditor;
}

-(NSMutableArray *)boxes;
-(NSUInteger)selection;
-(void)selectBoxAtIndex:(NSUInteger)inIndex;
-(void)addBoxWithRect:(NSRect)inRect answer:(NSString *)inAnswer;
-(void)editSelectedBox;
-(NSTextField *)editor;
-(void)commitEditing;

@end

@interface ProVocBoxesSheet : NSObject <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate> {
	ProVocDocument *mDocument;
	NSPanel *mPanel;
	NSTextField *mTitleField;
	ProVocBoxesView *mBoxesView;
	NSTableView *mAnswerTable;
	NSButton *mHideOthers;
	NSButton *mShowOthers;
	NSButton *mFindLabels;
	NSButton *mAddButton;
	NSString *mImageFile;	// a new picture...
	int mRow;
	NSArray *mWords;		// ... or the boxes of a picture that has them already
}

-(void)boxesDidChange;

@end

@interface ProVocDocument (Boxes)

-(void)addBoxesOnImageFile:(NSString *)inFile row:(int)inRow;
-(void)applyBoxes:(NSArray *)inBoxes title:(NSString *)inTitle showOthers:(BOOL)inShowOthers imageFile:(NSString *)inFile row:(int)inRow oldWords:(NSArray *)inOldWords;
-(void)editBoxesOfWord:(ProVocWord *)inWord;

@end
