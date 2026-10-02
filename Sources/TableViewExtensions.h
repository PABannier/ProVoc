//
//  TableViewExtensions.h
//  ProVoc
//
//  Created by Simon Bovet on Tue May 06 2003.
//  Copyright (c) 2003 Arizona Software. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface NSTableView (ProVocExtensions)

+(NSImage *)ascendingSortIndicator;
+(NSImage *)descendingSortIndicator;

-(id)tableColumnStates;
-(void)setTableColumnStates:(id)inStates;

// Same behaviour as the deprecated -selectedRowEnumerator and -selectRow:byExtendingSelection:
-(NSEnumerator *)selectedRowNumberEnumerator;
-(void)selectRowAtIndex:(NSInteger)inRow byExtendingSelection:(BOOL)inExtend;

@end

@interface NSOutlineView (ExpandedState)

-(id)expandedState;
-(void)setExpandedState:(id)inState;

@end
