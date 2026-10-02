//
//  ProVocApplication.h
//  ProVoc
//
//  Created by Simon Bovet on 14.10.05.
//  Copyright 2005 Arizona Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ProVocApplication : NSApplication {

}

// The media commands of the help book are on F1...F4, which current keyboards use
// for brightness, Mission Control... unless fn is held. The same commands are in the
// Vocabulary > Media menu, with shortcuts that need no fn key. The tag of the sender
// tells which: 1...4 = F1...F4, 5 = Option-F4 (movie in full size), 11...14 = Command-F1...F4 (record).
-(IBAction)performMediaCommand:(id)inSender;
-(void)installMediaMenu;

@end

@interface NSApplication (ProVoc)

-(long)systemVersion;

@end
