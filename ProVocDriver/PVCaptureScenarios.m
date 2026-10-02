//
//  PVCaptureScenarios.m
//
//  Recording sounds with the microphone, capturing pictures and movies with the
//  camera, from the keyboard. macOS asks once whether ProVoc may use the microphone
//  and the camera; until someone allowed them these scenarios fail, and say so.
//

#import "PVDriver.h"
#import <AVFoundation/AVFoundation.h>
#import "ProVocInspector.h"
#import "SoundRecorderController.h"

@interface PVScenarios (Editing)
-(ProVocDocument *)editedDocument;
-(void)newDocumentWithThreeWordsIn:(PVScript *)inScript;
-(void)selectWord:(NSString *)inSource in:(PVScript *)inScript;
@end

@interface PVScenarios (Application)
-(NSView *)buttonWithAction:(SEL)inAction in:(NSView *)inView;
@end

@interface PVScenarios (Capture)
@end

@implementation PVScenarios (Capture)

-(BOOL)mayUse:(NSString *)inMediaType
{
	BOOL audio = [inMediaType isEqualToString:AVMediaTypeAudio];
	AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:inMediaType];
	if (status != AVAuthorizationStatusAuthorized) {
		PVFail(__FILE__, __LINE__, @"ProVoc IS NOT ALLOWED TO USE THE %@ (status %ld): run scripts/request-capture-access.sh and click Allow twice (see verification/NEEDS_HUMAN.md)", audio ? @"MICROPHONE" : @"CAMERA", (long)status);
		return NO;
	}
	if (![AVCaptureDevice defaultDeviceWithMediaType:inMediaType]) {
		PVFail(__FILE__, __LINE__, @"this Mac has no %@", audio ? @"microphone" : @"camera");
		return NO;
	}
	return YES;
}

-(ProVocWord *)word:(NSString *)inSource
{
	for (ProVocWord *word in [[self editedDocument] allWords])
		if ([[word sourceWord] isEqualToString:inSource])
			return word;
	return nil;
}

-(NSString *)audioFile:(NSString *)inKey ofWord:(NSString *)inSource
{
	NSString *media = [[self word:inSource] mediaForAudio:inKey];
	return media ? [[self editedDocument] pathForMediaFile:media] : nil;
}

-(NSTimeInterval)durationOfFile:(NSString *)inPath
{
	return inPath ? CMTimeGetSeconds([[AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:inPath] options:nil] duration]) : 0;
}

#pragma mark Sounds

// Records with the keys: Command-F1 / Command-F2 and their second shortcuts
// Shift-Command-K / Shift-Command-L record at once (Return keeps the sound, Esc throws
// it away); with the NoShiftRecord preference the plain key records and Command plays;
// Option-click on the record button of the inspector opens the recorder without
// recording (Space = record / stop, Play, Return = OK, Esc = Cancel).
-(void)recordAudio:(PVScript *)inScript
{
	if (![self mayUse:AVMediaTypeAudio])
		return;
	SoundRecorderController *recorder = [SoundRecorderController sharedController];
	NSWindow *(^panel)(void) = ^{ return [recorder window]; };
	AVAudioRecorder *(^audioRecorder)(void) = ^{ return (AVAudioRecorder *)[recorder valueForKey:@"mRecorder"]; };
	PVCondition recordingForAWhile = ^BOOL { return [NSApp modalWindow] == panel() && [panel() isKeyWindow] && [recorder isRecording] && [audioRecorder() currentTime] > 0.7; };
	PVCondition recorderClosed = ^BOOL { return [NSApp modalWindow] == nil && ![panel() isVisible] && [[[self editedDocument] window] isKeyWindow]; };
	__block NSString *firstFile = nil;

	[self newDocumentWithThreeWordsIn:inScript];
	[self selectWord:@"house" in:inScript];

	// Command-F1: records the sound of the word at once; Return keeps it
	[inScript then:^{ PVPostKey(PVKeyF1, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction); }];
	[inScript wait:@"Command-F1 to record (the recorder, recording)" timeout:15 until:recordingForAWhile];
	[inScript then:^{
		PVSaveWindowScreenshot(panel(), @"windows/recorder-recording");
		PVExpect([[[recorder valueForKey:@"mStatusField"] stringValue] length] > 0, @"the recorder says nothing while recording");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[inScript wait:@"Return to keep the sound of the word" timeout:10 until:^BOOL { return recorderClosed() && [[self word:@"house"] canPlayAudio:@"Source"]; }];
	[inScript then:^{
		firstFile = [[self audioFile:@"Source" ofWord:@"house"] copy];
		PVExpect([self durationOfFile:firstFile] > 0.5, @"the recorded sound lasts %g s (%@)", [self durationOfFile:firstFile], firstFile);
		PVExpect(![[self word:@"house"] canPlayAudio:@"Target"], @"Command-F1 recorded the sound of the translation too");
		PVExpect([[self editedDocument] isDocumentEdited], @"recording a sound does not mark the document as changed");
	}];

	// Command-F2: the sound of the translation; Esc throws the recording away
	[inScript then:^{ PVPostKey(PVKeyF2, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction); }];
	[inScript wait:@"Command-F2 to record" timeout:15 until:recordingForAWhile];
	[inScript then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"Esc to close the recorder" timeout:10 until:recorderClosed];
	[inScript then:^{ PVExpect(![[self word:@"house"] canPlayAudio:@"Target"], @"Esc kept the recording"); }];
	[inScript then:^{ PVPostKey(PVKeyF2, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction); }];
	[inScript wait:@"Command-F2 to record again" timeout:15 until:recordingForAWhile];
	[inScript then:^{ PVPostKey(PVKeyKeypadEnter, nil, 0); }];
	[inScript wait:@"Enter to keep the sound of the translation" timeout:10 until:^BOOL { return recorderClosed() && [[self word:@"house"] canPlayAudio:@"Target"]; }];

	// the second shortcuts, without function keys: Shift-Command-K and Shift-Command-L
	[self selectWord:@"cat" in:inScript];
	for (NSArray *shortcut in @[@[@"k", @"Source"], @[@"l", @"Target"]]) {
		[inScript then:^{ PVTypeCommand(shortcut[0], NSEventModifierFlagShift); }];
		[inScript wait:[NSString stringWithFormat:@"Shift-Command-%@ to record", [shortcut[0] uppercaseString]] timeout:15 until:recordingForAWhile];
		[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
		[inScript wait:@"Return to keep the sound" timeout:10 until:^BOOL { return recorderClosed() && [[self word:@"cat"] canPlayAudio:shortcut[1]]; }];
	}
	[inScript then:^{ PVExpect(![[self word:@"dog"] canPlayAudio:@"Source"] && [[self word:@"house"] canPlayAudio:@"Source"], @"the sounds went to the wrong words"); }];

	// NoShiftRecord: the plain function key records, with Command it plays
	[self selectWord:@"dog" in:inScript];
	[inScript then:^{
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"NoShiftRecord"];
		PVPostKey(PVKeyF1, nil, NSEventModifierFlagFunction);
	}];
	[inScript wait:@"F1 to record when NoShiftRecord is set" timeout:15 until:recordingForAWhile];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return to keep the sound" timeout:10 until:^BOOL { return recorderClosed() && [[self word:@"dog"] canPlayAudio:@"Source"]; }];
	[inScript then:^{ PVPostKey(PVKeyF1, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction); }];
	[inScript pause:1.0];
	[inScript then:^{
		PVExpect([NSApp modalWindow] == nil && ![panel() isVisible], @"Command-F1 records although NoShiftRecord is set");
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"NoShiftRecord"];
	}];

	// Option-click on the record button of the inspector: the recorder, not recording yet
	NSButton *(^recordButton)(void) = ^{ return (NSButton *)[self buttonWithAction:@selector(recordSourceAudio:) in:[[[ProVocInspector sharedInspector] window] contentView]]; };
	[self selectWord:@"house" in:inScript];
	[inScript then:^{ PVTypeCommand(@"i", 0); }];
	[inScript wait:@"the inspector (Command-I) with its record button" timeout:10 until:^BOOL { return [[ProVocInspector sharedInspector] isVisible] && recordButton() != nil && ![recordButton() isHiddenOrHasHiddenAncestor] && [recordButton() isEnabled]; }];
	[inScript then:^{ PVClickView(recordButton(), 1, NSEventModifierFlagOption); }];
	[inScript wait:@"the recorder, waiting (Option-click)" timeout:15 until:^BOOL { return [NSApp modalWindow] == panel() && [panel() isKeyWindow] && ![recorder isRecording]; }];
	[inScript then:^{
		PVSaveWindowScreenshot(panel(), @"windows/recorder-ready");
		PVExpect(![[recorder valueForKey:@"mPlayButton"] isEnabled], @"Play is enabled before anything is recorded");
		PVPostKey(PVKeySpace, @" ", 0);
	}];
	[inScript wait:@"Space to record" timeout:10 until:recordingForAWhile];
	[inScript then:^{ PVPostKey(PVKeySpace, @" ", 0); }];
	[inScript wait:@"Space to stop" timeout:10 until:^BOOL { return ![recorder isRecording] && [[recorder valueForKey:@"mPlayButton"] isEnabled] && [NSApp modalWindow] == panel(); }];
	[inScript then:^{ PVClickView([recorder valueForKey:@"mPlayButton"], 1, 0); }];
	[inScript wait:@"Play to play what was recorded" timeout:10 until:^BOOL { return [(NSSound *)[recorder valueForKey:@"mPlayingSound"] isPlaying]; }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return (OK) to replace the sound of the word" timeout:10 until:^BOOL {
		NSString *file = [self audioFile:@"Source" ofWord:@"house"];
		return [NSApp modalWindow] == nil && ![panel() isVisible] && file && ![file isEqualToString:firstFile] && [self durationOfFile:file] > 0.5;
	}];
	// ... and Esc there cancels
	[inScript then:^{ PVClickView(recordButton(), 1, NSEventModifierFlagOption); }];
	[inScript wait:@"the recorder again" timeout:15 until:^BOOL { return [NSApp modalWindow] == panel() && [panel() isKeyWindow]; }];
	[inScript then:^{
		[firstFile release];
		firstFile = [[self audioFile:@"Source" ofWord:@"house"] copy];
		PVPostKey(PVKeyEscape, nil, 0);
	}];
	[inScript wait:@"Esc (Cancel) to leave the sound as it was" timeout:10 until:^BOOL { return [NSApp modalWindow] == nil && ![panel() isVisible] && [[self audioFile:@"Source" ofWord:@"house"] isEqualToString:firstFile]; }];
	[inScript then:^{ [[self editedDocument] updateChangeCount:NSChangeCleared]; }];
}

#pragma mark Camera

// Command-F3 (Shift-Command-B) takes a picture for the word, Command-F4
// (Shift-Command-M) records a movie: Return captures / keeps, Space starts and stops
// the movie, Esc cancels.
-(void)captureImageAndMovie:(PVScript *)inScript
{
	if (![self mayUse:AVMediaTypeVideo])
		return;
	ProVocCameraGrabber *camera = [ProVocCameraGrabber sharedGrabber];
	NSWindow *(^panel)(void) = ^{ return [camera window]; };
	PVCondition cameraRunning = ^BOOL { return [NSApp modalWindow] == panel() && [panel() isKeyWindow] && [(AVCaptureSession *)[camera valueForKey:@"mSession"] isRunning]; };
	PVCondition cameraClosed = ^BOOL { return [NSApp modalWindow] == nil && ![panel() isVisible] && [[[self editedDocument] window] isKeyWindow]; };

	[self newDocumentWithThreeWordsIn:inScript];
	[self selectWord:@"house" in:inScript];

	// a picture: Esc cancels, Return captures
	[inScript then:^{ PVPostKey(PVKeyF3, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction); }];
	[inScript wait:@"Command-F3 to show the camera" timeout:20 until:cameraRunning];
	[inScript then:^{ PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"Esc to close the camera" timeout:10 until:cameraClosed];
	[inScript then:^{
		PVExpect([[self word:@"house"] imageMedia] == nil, @"Esc took a picture");
		PVTypeCommand(@"b", NSEventModifierFlagShift);
	}];
	[inScript wait:@"Shift-Command-B to show the camera" timeout:20 until:cameraRunning];
	[inScript then:^{
		PVSaveWindowScreenshot(panel(), @"windows/camera-picture");
		PVPostKey(PVKeyReturn, nil, 0);
	}];
	[inScript wait:@"Return to take the picture of the word" timeout:20 until:^BOOL { return cameraClosed() && [[self word:@"house"] imageMedia] != nil; }];
	[inScript then:^{
		NSImage *image = [[self editedDocument] imageOfWord:[self word:@"house"]];
		PVExpect(image && [image size].width > 100 && [image size].height > 100, @"the picture of the word: %@", image);
	}];

	// a movie: Space starts and stops, Return keeps
	[self selectWord:@"cat" in:inScript];
	[inScript then:^{ PVPostKey(PVKeyF4, nil, NSEventModifierFlagCommand | NSEventModifierFlagFunction); }];
	[inScript wait:@"Command-F4 to show the camera" timeout:20 until:cameraRunning];
	[inScript then:^{
		PVExpectEqualObjects([[camera valueForKey:@"mActionButton"] keyEquivalent], @" ", @"the key of the Record button (the window was used for a picture before)");
		PVExpect(![[camera valueForKey:@"mOKButton"] isEnabled], @"OK is enabled before anything is recorded");
		PVPostKey(PVKeySpace, @" ", 0);
	}];
	[inScript wait:@"Space to record a movie" timeout:20 until:^BOOL {
		return [camera isRecordingMovie] && CMTimeGetSeconds([(AVCaptureMovieFileOutput *)[camera valueForKey:@"mMovieOutput"] recordedDuration]) > 1.0; }];
	[inScript then:^{
		PVSaveWindowScreenshot(panel(), @"windows/camera-movie");
		PVPostKey(PVKeySpace, @" ", 0);
	}];
	[inScript wait:@"Space to stop" timeout:20 until:^BOOL { return ![camera isRecordingMovie] && [[camera valueForKey:@"mOKButton"] isEnabled] && [NSApp modalWindow] == panel(); }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return to keep the movie of the word" timeout:20 until:^BOOL { return cameraClosed() && [[self word:@"cat"] movieMedia] != nil; }];
	[inScript then:^{
		NSString *file = [[self editedDocument] pathForMediaFile:[[self word:@"cat"] movieMedia]];
		PVExpect([self durationOfFile:file] > 0.8, @"the movie of the word lasts %g s (%@)", [self durationOfFile:file], file);
		PVExpect([[self word:@"dog"] movieMedia] == nil && [[self word:@"cat"] imageMedia] == nil, @"the picture or the movie went to the wrong word");
	}];
	// Shift-Command-M, Return while recording (stops and keeps), then Esc
	[self selectWord:@"dog" in:inScript];
	[inScript then:^{ PVTypeCommand(@"m", NSEventModifierFlagShift); }];
	[inScript wait:@"Shift-Command-M to show the camera" timeout:20 until:cameraRunning];
	[inScript then:^{ PVPostKey(PVKeySpace, @" ", 0); }];
	[inScript wait:@"Space to record a movie" timeout:20 until:^BOOL { return [camera isRecordingMovie] && CMTimeGetSeconds([(AVCaptureMovieFileOutput *)[camera valueForKey:@"mMovieOutput"] recordedDuration]) > 1.0; }];
	[inScript then:^{ PVPostKey(PVKeyReturn, nil, 0); }];
	[inScript wait:@"Return to stop and keep the movie" timeout:20 until:^BOOL { return cameraClosed() && [[self word:@"dog"] movieMedia] != nil; }];
	[inScript then:^{ PVTypeCommand(@"m", NSEventModifierFlagShift); }];
	[inScript wait:@"the camera again" timeout:20 until:cameraRunning];
	NSString *(^movieOfDog)(void) = ^{ return [[self word:@"dog"] movieMedia]; };
	__block NSString *before = nil;
	[inScript then:^{ before = [movieOfDog() copy]; PVPostKey(PVKeyEscape, nil, 0); }];
	[inScript wait:@"Esc to leave the movie as it was" timeout:10 until:^BOOL { return cameraClosed() && [movieOfDog() isEqualToString:before]; }];
	[inScript then:^{ [[self editedDocument] updateChangeCount:NSChangeCleared]; }];
}

@end
