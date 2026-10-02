//
//  ProVocHelpController.h
//  ProVoc
//
//  Shows the help book that ships inside the application (the Help Viewer no
//  longer opens books in the old folder format, and the online help is gone).
//

#import <Cocoa/Cocoa.h>

@class WKWebView;

@interface ProVocHelpController : NSWindowController {
	WKWebView *mWebView;
}

+(ProVocHelpController *)sharedController;
-(void)showPage:(NSString *)inName;

@end
