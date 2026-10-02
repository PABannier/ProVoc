//
//  ProVocAppleScriptSupport.h
//  ProVoc
//
//  Created by Simon Bovet on 19.05.06.
//  Copyright 2006 Arizona Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ProVocImportFileCommand : NSScriptCommand

@end

@interface ProVocImportTextCommand : NSScriptCommand

@end

@interface ProVocExportFileCommand : NSScriptCommand

@end

// "start test": not in the dictionary of ProVoc 4.2.3, added so that a script can do
// what Command-R does
@interface ProVocStartTestCommand : NSScriptCommand

@end
