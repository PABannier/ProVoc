//
//  ARAboutDialog.h
//  Curvus Pro X
//
//  Created by Simon Bovet on Wed Jun 04 2003.
//  Copyright (c) 2003 Arizona. All rights reserved.
//

#import <AppKit/AppKit.h>

@class ARCreditsScrollView;

@interface ARAboutDialog : NSWindowController {
    IBOutlet NSTextField *mAppName;
    IBOutlet NSTextField *mAppVersion;
    IBOutlet ARCreditsScrollView *mCreditsScroll;
    IBOutlet NSTextView *mCredits;
    
    IBOutlet NSWindow *mSecretWindow;
}

+(id)sharedAboutDialog;

-(void)displayAboutWindow:(BOOL)inAnimateAlpha;
-(void)hideAboutWindow:(BOOL)inAnimateAlpha;
-(void)showAboutWindow;

-(void)showSecretAboutWindow;

-(void)show:(id)inSender;
-(void)hide:(id)inSender;

@end

@interface ARAboutWindow : NSPanel {
	BOOL mShownAtLaunch;
}

// At launch the window is only shown for a moment: it must not take the keyboard
// away from the document window.
-(void)setShownAtLaunch:(BOOL)inShownAtLaunch;

@end

@interface ARAboutView : NSView {
}

@end

@interface ARCreditsScrollView : NSScrollView {
}

-(void)setVerticalScroll:(float)inValue;

@end